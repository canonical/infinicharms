#!/usr/bin/env bash
# Packs a single charm directory with charmcraft (LXD-backed) and records
# the resulting .charm file's path as a step output.
#
# Expects the following environment variables:
#   CHARM_DIR      - directory containing the charm's charmcraft.yaml
#   ARTIFACT_NAME  - name used purely for logging
#
# Sets the following step outputs:
#   charm_path - path to the packed .charm file
set -euo pipefail

dir="${CHARM_DIR:?CHARM_DIR is required}"
artifact_name="${ARTIFACT_NAME:?ARTIFACT_NAME is required}"

rm -f "${dir}"/*.charm

echo "Packing ${artifact_name} from ${dir}"
(cd "$dir" && charmcraft pack -v)

charm_path="$(find "$dir" -maxdepth 1 -name '*.charm' | sort | head -n1)"
if [ -z "$charm_path" ]; then
  echo "charmcraft pack produced no .charm file in ${dir}" >&2
  exit 1
fi

echo "Built ${charm_path}"
echo "charm_path=${charm_path}" >> "$GITHUB_OUTPUT"
