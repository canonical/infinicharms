#!/usr/bin/env bash
# Prepares the context an agent needs to update a charm's copy of the base
# charm template: full checkouts of canonical/infinicharms-base at the
# charm's currently-recorded base revision and at the target revision, plus
# a unified diff between the two restricted to the files that
# fetch-base-charm.sh actually copies into a charm directory.
#
# Expects the following environment variables:
#   BASE_CHARM_REPO - repo slug of the base charm (e.g. canonical/infinicharms-base)
#   BASE_CHARM_REF  - branch, tag, or commit to update to (e.g. main)
#   CHARM_NAME      - the charm name (e.g. "myblog"), used to read the
#                     currently-recorded charms/<name>/base-version
#   REPO_ROOT       - repository root
#
# Sets the following step outputs:
#   old_base_version - version string currently recorded in base-version
#   old_base_sha     - commit sha currently recorded in base-version
#   new_sha          - commit sha that BASE_CHARM_REF resolves to
#   old_base_dir     - absolute path to a full checkout at old_base_sha
#   new_base_dir     - absolute path to a full checkout at new_sha
#   diff_file        - absolute path to a unified diff (old_base_sha..new_sha)
set -euo pipefail

base_repo="${BASE_CHARM_REPO:?BASE_CHARM_REPO is required}"
base_ref="${BASE_CHARM_REF:?BASE_CHARM_REF is required}"
charm_name="${CHARM_NAME:?CHARM_NAME is required}"
repo_root="${REPO_ROOT:?REPO_ROOT is required}"

base_version_file="${repo_root}/charms/${charm_name}/base-version"
if [ ! -f "$base_version_file" ]; then
  echo "::error::${base_version_file} not found; is '${charm_name}' a generated charm?" >&2
  exit 1
fi

old_base_version="$(sed -n '1p' "$base_version_file" | tr -d '\r')"
old_base_sha="$(sed -n '2p' "$base_version_file" | tr -d '\r')"
if [ -z "$old_base_version" ] || [ -z "$old_base_sha" ]; then
  echo "::error::Could not parse version/sha from ${base_version_file}" >&2
  exit 1
fi

work_dir="$(mktemp -d)"

echo "Cloning ${base_repo} ..."
git clone "https://github.com/${base_repo}.git" "${work_dir}/repo"

if ! git -C "${work_dir}/repo" cat-file -e "${old_base_sha}^{commit}" 2>/dev/null; then
  echo "::error::Recorded base sha ${old_base_sha} (from ${base_version_file}) is no longer reachable in ${base_repo}." >&2
  exit 1
fi

new_sha="$(git -C "${work_dir}/repo" rev-parse "origin/${base_ref}" 2>/dev/null \
  || git -C "${work_dir}/repo" rev-parse "${base_ref}")"

echo "Old base: ${old_base_version} (${old_base_sha})"
echo "New base: ${base_ref} (${new_sha})"

if [ "$old_base_sha" = "$new_sha" ]; then
  echo "::error::Charm '${charm_name}' is already at ${base_ref} (${new_sha}); nothing to update." >&2
  exit 1
fi

old_base_dir="${work_dir}/old-base"
new_base_dir="${work_dir}/new-base"
git -C "${work_dir}/repo" worktree add --detach "$old_base_dir" "$old_base_sha"
git -C "${work_dir}/repo" worktree add --detach "$new_base_dir" "$new_sha"

# Restrict the diff to the files fetch-base-charm.sh actually copies into a
# charm directory, so it lines up with what's under charms/<name>/.
diff_file="${work_dir}/base-upstream.diff"
git -C "${work_dir}/repo" diff --find-renames "$old_base_sha" "$new_sha" -- \
  src/ charmcraft.yaml pyproject.toml uv.lock tox.ini SOUL.md prompts/ tests/ \
  > "$diff_file" || true

echo "Diff written to ${diff_file} ($(wc -l < "$diff_file") lines)"

{
  echo "old_base_version=${old_base_version}"
  echo "old_base_sha=${old_base_sha}"
  echo "new_sha=${new_sha}"
  echo "old_base_dir=${old_base_dir}"
  echo "new_base_dir=${new_base_dir}"
  echo "diff_file=${diff_file}"
} >> "$GITHUB_OUTPUT"
