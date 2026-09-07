#!/usr/bin/env bash
# Detects which charms under charms/ have changed since they were last
# released, bumps each changed charm's version file, and pushes every bump
# as a single commit.
#
# "Since last released" is determined per charm, from the most recent
# commit that touched that charm's own version file (written as "1" by
# begin-charm.yml when the charm is first generated, and bumped by this
# script on every release after that) -- not from the triggering event's
# before/after commit range. This matters because that range is only
# meaningful for ordinary `push` events: it's empty for a manual
# workflow_dispatch run, and even on a push it can miss changes that
# landed in an earlier commit that didn't itself trigger a release (e.g. a
# commit pushed with the default GITHUB_TOKEN, which GitHub does not use
# to re-trigger `push`-triggered workflows, followed by an unrelated commit
# that does).
#
# Each changed charm actually maps to two buildable charms:
#   charms/<name>          (the base charm)
#   charms/<name>/_evolved  (the evolved charm, if it exists)
# These are emitted as separate entries in `build_matrix` so they can be
# packed in parallel, and grouped back together in `release_matrix` so a
# single release (tag <name>-<version>) can be published with both.
#
# Expects the following environment variables:
#   AFTER_SHA     - commit to evaluate charm state as of (default: HEAD)
#   TARGET_BRANCH - branch to push the version-bump commit to (default: main)
#
# Sets the following step outputs:
#   has_changes    - "true" if any charm was bumped, "false" otherwise
#   commit_sha     - SHA of the pushed version-bump commit (only if has_changes)
#   build_matrix   - JSON array like:
#                     [{"artifact":"mycharm","dir":"charms/mycharm"},
#                      {"artifact":"mycharm-evolved","dir":"charms/mycharm/_evolved"}]
#   release_matrix - JSON array like:
#                     [{"name":"mycharm","version":"2","has_evolved":true}]
set -euo pipefail

after="${AFTER_SHA:-HEAD}"
branch="${TARGET_BRANCH:-main}"

after_sha="$(git rev-parse "$after")"
echo "Checking charms/ for changes as of ${after_sha}"

build_entries=()
release_entries=()
bumped_names=()

for charmcraft_yaml in charms/*/charmcraft.yaml; do
  [ -f "$charmcraft_yaml" ] || continue
  charm_dir="$(dirname "$charmcraft_yaml")"
  name="$(basename "$charm_dir")"
  version_file="${charm_dir}/version"

  # Find the commit where this charm's version file was last written --
  # that's the charm's own "last released" point. Diffing from there to
  # $after_sha tells us whether anything under the charm's directory has
  # changed since then, regardless of how this workflow run was triggered.
  last_release_commit="$(git log -1 --format=%H "$after_sha" -- "$version_file" || true)"

  if [ -z "$last_release_commit" ]; then
    echo "${name}: ${version_file} has no history yet; treating as unreleased."
  else
    changed_files="$(git diff --name-only "$last_release_commit" "$after_sha" -- "$charm_dir")"
    if [ -z "$changed_files" ]; then
      continue
    fi
    echo "${name}: changed since ${last_release_commit:0:12} (last release):"
    echo "$changed_files" | sed 's/^/    /'
  fi

  current_version=0
  if [ -f "$version_file" ]; then
    current_version="$(cat "$version_file")"
  fi
  new_version=$((current_version + 1))

  echo "${name}: bumping version ${current_version} -> ${new_version}"
  echo "$new_version" > "$version_file"

  git add "$version_file"
  bumped_names+=("$name")

  build_entries+=("{\"artifact\":\"${name}\",\"dir\":\"${charm_dir}\"}")

  evolved_dir="${charm_dir}/_evolved"
  has_evolved=false
  if [ -f "${evolved_dir}/charmcraft.yaml" ]; then
    has_evolved=true
    build_entries+=("{\"artifact\":\"${name}-evolved\",\"dir\":\"${evolved_dir}\"}")
  else
    echo "No _evolved charm found for '${name}'."
  fi

  release_entries+=("{\"name\":\"${name}\",\"version\":\"${new_version}\",\"has_evolved\":${has_evolved}}")
done

if [ "${#bumped_names[@]}" -eq 0 ]; then
  echo "No charm versions to bump."
  {
    echo "has_changes=false"
    echo "build_matrix=[]"
    echo "release_matrix=[]"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

joined_names="$(IFS=,; echo "${bumped_names[*]}")"
git commit -m "chore: bump charm version(s) for ${joined_names} [skip ci]"
git push origin "HEAD:${branch}"

commit_sha="$(git rev-parse HEAD)"
build_matrix_json="$(printf '%s\n' "${build_entries[@]}" | jq -s -c .)"
release_matrix_json="$(printf '%s\n' "${release_entries[@]}" | jq -s -c .)"

echo "Bumped charms: ${joined_names}"
echo "Pushed commit: ${commit_sha}"

{
  echo "has_changes=true"
  echo "commit_sha=${commit_sha}"
  echo "build_matrix=${build_matrix_json}"
  echo "release_matrix=${release_matrix_json}"
} >> "$GITHUB_OUTPUT"
