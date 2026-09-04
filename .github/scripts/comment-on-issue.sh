#!/usr/bin/env bash
# Posts a comment on the issue that triggered the workflow run.
#
# Expects the following environment variables:
#   GH_TOKEN      - token used by `gh` to post the comment
#   ISSUE_NUMBER  - number of the issue to comment on
#   COMMENT_BODY  - text of the comment to post
set -euo pipefail

issue_number="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
comment_body="${COMMENT_BODY:?COMMENT_BODY is required}"

echo "Posting comment on issue #${issue_number}"
gh issue comment "$issue_number" --body "$comment_body"
