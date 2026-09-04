#!/usr/bin/env bash
# Detects which charms under charms/ changed in this push, bumps each
# changed charm's version file, and pushes every bump as a single commit.
#
# Each changed charm actually maps to two buildable charms:
#   charms/<name>          (the base charm)
#   charms/<name>/_evolved  (the evolved charm, if it exists)
# These are emitted as separate entries in `build_matrix` so they can be
# packed in parallel, and grouped back together in `release_matrix` so a
# single release (tag <name>-<version>) can be published with both.
#
# Expects the following environment variables:
#   BEFORE_SHA    - SHA before the push (github.event.before)
#   AFTER_SHA     - SHA after the push (github.sha)
#   TARGET_BRANCH - branch to push the version-bump commit to (github.ref_name)
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

before="${BEFORE_SHA:-}"
after="${AFTER_SHA:-HEAD}"
branch="${TARGET_BRANCH:-main}"

# On the very first push to a branch (or a force-push with no common
# history) github.event.before is all zeros. Fall back to diffing against
# the parent of the current commit in that case.
if [ -z "$before" ] || [ "$before" = "0000000000000000000000000000000000000000" ]; then
  before="$(git rev-parse "${after}^" 2>/dev/null || git rev-list --max-parents=0 "$after")"
fi

echo "Diffing charms/ between ${before} and ${after}"

mapfile -t changed_charms < <(
  git diff --name-only "$before" "$after" -- charms/ \
    | awk -F/ 'NF >= 2 { print $2 }' \
    | sort -u
)

build_entries=()
release_entries=()
bumped_names=()

for name in "${changed_charms[@]}"; do
  charm_dir="charms/${name}"
  charmcraft_yaml="${charm_dir}/charmcraft.yaml"

  if [ ! -f "$charmcraft_yaml" ]; then
    echo "Skipping '${name}': ${charmcraft_yaml} not found."
    continue
  fi

  version_file="${charm_dir}/version"
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
