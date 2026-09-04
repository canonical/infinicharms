#!/usr/bin/env bash
# Fetches the base charm source from a GitHub branch and copies it into
# the charm directory. Records the base version and sha as step outputs.
#
# Expects the following environment variables:
#   BASE_CHARM_REPO  - repo slug of the base charm (e.g. canonical/infinicharms-base)
#   BASE_CHARM_REF   - branch or tag to fetch (e.g. tromai-init-base-charm)
#   BASE_CHARM_VERSION - the version to record (e.g. 0.0.1)
#   CHARM_DIR        - the destination charm directory (e.g. charms/myblog)
#   REPO_ROOT        - repository root
#
# Sets the following step outputs:
#   base_version - the base charm version
#   base_sha     - the commit sha of the fetched ref
set -euo pipefail

base_repo="${BASE_CHARM_REPO:?BASE_CHARM_REPO is required}"
base_ref="${BASE_CHARM_REF:?BASE_CHARM_REF is required}"
base_version="${BASE_CHARM_VERSION:?BASE_CHARM_VERSION is required}"
charm_dir="${CHARM_DIR:?CHARM_DIR is required}"
repo_root="${REPO_ROOT:?REPO_ROOT is required}"

# Fetch the base charm source to a temp directory.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Fetching ${base_repo}@${base_ref} ..."
git clone --depth 1 --branch "$base_ref" "https://github.com/${base_repo}.git" "$tmp_dir/base-charm"
base_sha="$(cd "$tmp_dir/base-charm" && git rev-parse HEAD)"

# Copy source files into the charm directory (excluding build artifacts).
dest="${repo_root}/${charm_dir}"
mkdir -p "${dest}/src"
cp -r "$tmp_dir/base-charm/src/"* "${dest}/src/"
cp "$tmp_dir/base-charm/charmcraft.yaml" "${dest}/"
cp "$tmp_dir/base-charm/pyproject.toml" "${dest}/"
cp "$tmp_dir/base-charm/uv.lock" "${dest}/"
[ -f "$tmp_dir/base-charm/tox.ini" ] && cp "$tmp_dir/base-charm/tox.ini" "${dest}/"
[ -f "$tmp_dir/base-charm/SOUL.md" ] && cp "$tmp_dir/base-charm/SOUL.md" "${dest}/"
[ -d "$tmp_dir/base-charm/prompts" ] && cp -r "$tmp_dir/base-charm/prompts" "${dest}/"
[ -d "$tmp_dir/base-charm/tests" ] && cp -r "$tmp_dir/base-charm/tests" "${dest}/"

# Write base-version file.
printf '%s\n%s\n' "$base_version" "$base_sha" > "${dest}/base-version"

{
  echo "base_version=${base_version}"
  echo "base_sha=${base_sha}"
} >> "$GITHUB_OUTPUT"
