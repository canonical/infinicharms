#!/usr/bin/env bash
# Publishes a single GitHub release (tag <name>-<version>) for a charm,
# attaching the base charm's .charm file and, if present, the _evolved
# charm's .charm file. Assets are expected to already be downloaded into
# dist/<name>/ and dist/<name>-evolved/ by the calling workflow.
#
# Expects the following environment variables:
#   CHARM_NAME    - name of the charm under charms/, e.g. "mycharm"
#   CHARM_VERSION - new version number to tag/release, e.g. "2"
#   GH_TOKEN      - token used by `gh` to create the release
set -euo pipefail

name="${CHARM_NAME:?CHARM_NAME is required}"
version="${CHARM_VERSION:?CHARM_VERSION is required}"

tag="${name}-${version}"

base_dir="dist/${name}"
assets=()
if compgen -G "${base_dir}/*.charm" > /dev/null; then
  for f in "${base_dir}"/*.charm; do
    assets+=("$f")
  done
else
  echo "No charm artifact found in ${base_dir}" >&2
  exit 1
fi

evolved_dir="dist/${name}-evolved"
if compgen -G "${evolved_dir}/*.charm" > /dev/null 2>&1; then
  for f in "${evolved_dir}"/*.charm; do
    assets+=("$f")
  done
fi

echo "Creating release ${tag} with assets: ${assets[*]}"
gh release create "$tag" "${assets[@]}" \
  --target "$(git rev-parse HEAD)" \
  --title "${name} ${version}" \
  --notes "Automated release of ${name} version ${version}."
