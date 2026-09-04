#!/usr/bin/env bash
# Extracts the charm name from a bug-report issue body and checks whether a
# matching charms/<name> directory exists in the repo.
#
# The bug report issue form (.github/ISSUE_TEMPLATE/bug_report.yml) renders
# its "charm-name" field as a "### Charm name" heading followed by the
# answer on the next non-empty line, e.g.:
#
#   ### Charm name
#
#   mycharm
#
# Expects the following environment variables:
#   ISSUE_BODY - body of the issue (github.event.issue.body)
#
# Sets the following step outputs:
#   name   - the extracted charm name (empty if none could be found)
#   exists - "true" if charms/<name>/charmcraft.yaml exists, "false" otherwise
set -euo pipefail

body="${ISSUE_BODY:-}"

name="$(printf '%s\n' "$body" \
  | awk '/^### Charm name/{found=1; next} found && NF {print; exit}' \
  | tr -d '\r' \
  | xargs || true)"

echo "Extracted charm name: '${name}'"

if [ -z "$name" ]; then
  echo "Could not extract a charm name from the issue body."
  {
    echo "name="
    echo "exists=false"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi

if [ -f "charms/${name}/charmcraft.yaml" ]; then
  exists=true
else
  exists=false
fi

echo "charms/${name} exists: ${exists}"

{
  echo "name=${name}"
  echo "exists=${exists}"
} >> "$GITHUB_OUTPUT"
