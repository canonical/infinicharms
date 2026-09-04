#!/usr/bin/env bash
# Closes a bug-report issue as "not planned" because the charm it refers to
# does not exist (or couldn't be identified) in this repository.
#
# Expects the following environment variables:
#   GH_TOKEN     - token used by `gh` to comment on / close the issue
#   ISSUE_NUMBER - number of the issue to close
#   CHARM_NAME   - charm name extracted from the issue (may be empty)
set -euo pipefail

issue="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
name="${CHARM_NAME:-}"

if [ -z "$name" ]; then
  message="Couldn't find a charm name in this issue. Please reopen using the bug report template and fill in the \"Charm name\" field with an existing charm's directory name under \`charms/\`."
else
  message="No charm named \`${name}\` exists in this repository (expected a \`charms/${name}\` directory). Closing as not planned."
fi

echo "$message"

gh issue comment "$issue" --body "$message"
gh issue close "$issue" --reason "not planned"
