#!/usr/bin/env bash
# Runs the opencode agent to update a generated charm's copy of the base
# charm template with upstream changes, while preserving the charm's own
# customizations, then verifies the agent only modified files under the
# charm directory. See .github/prompts/update-base-charm-agent.md for the
# agent's actual instructions -- this script just prepares its environment
# and checks its scope; committing and pushing happens in a later workflow
# step, only if this step succeeds.
#
# Expects the following environment variables:
#   REPO_ROOT            - repository root to run OpenCode in
#   CHARM_NAME           - name of the charm under charms/, e.g. "mycharm"
#   OLD_BASE_VERSION      - version string currently recorded in base-version
#   OLD_BASE_SHA          - commit sha currently recorded in base-version
#   NEW_BASE_VERSION      - version string to record for the update
#   NEW_BASE_SHA          - commit sha to update to
#   OLD_BASE_DIR           - full checkout of the base repo at OLD_BASE_SHA
#   NEW_BASE_DIR           - full checkout of the base repo at NEW_BASE_SHA
#   DIFF_FILE              - unified diff between OLD_BASE_SHA and NEW_BASE_SHA
#   OPENROUTER_API_KEY     - credentials for the openrouter model
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
name="${CHARM_NAME:?CHARM_NAME is required}"
old_base_version="${OLD_BASE_VERSION:?OLD_BASE_VERSION is required}"
old_base_sha="${OLD_BASE_SHA:?OLD_BASE_SHA is required}"
new_base_version="${NEW_BASE_VERSION:?NEW_BASE_VERSION is required}"
new_base_sha="${NEW_BASE_SHA:?NEW_BASE_SHA is required}"
: "${OLD_BASE_DIR:?OLD_BASE_DIR is required}"
: "${NEW_BASE_DIR:?NEW_BASE_DIR is required}"
: "${DIFF_FILE:?DIFF_FILE is required}"
: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}"

charm_dir="charms/${name}"

# Exported so the agent's shell (opencode's bash tool) can see the resolved
# charm paths and base revisions without having to re-derive them.
export CHARM_DIR="$charm_dir"
export EVOLVED_DIR="${charm_dir}/_evolved"
export CHARM_NAME="$name"
export OLD_BASE_VERSION="$old_base_version"
export OLD_BASE_SHA="$old_base_sha"
export NEW_BASE_VERSION="$new_base_version"
export NEW_BASE_SHA="$new_base_sha"

prompt="$(cat .github/prompts/update-base-charm-agent.md)"

# Record the set of changed files before the agent runs.
before="$(cd "$repo_root" && git status --porcelain --untracked-files=all | awk '{print $2}' | sort)"

opencode run --auto --model openrouter/google/gemini-3.8-flash "$prompt"

# Verify the agent only modified files under the charm directory (including
# its _evolved/ subdirectory). Compare against the state before the agent
# ran to isolate agent changes. This matters more here than in other
# agents in this repo: on success, the next workflow step pushes straight
# to the target branch with no PR/review step in between.
after="$(cd "$repo_root" && git status --porcelain --untracked-files=all | awk '{print $2}' | sort)"
new_changes="$(comm -13 <(echo "$before") <(echo "$after"))"
changed_outside=""
for path in $new_changes; do
  case "$path" in
    ${charm_dir}/*|${charm_dir}) ;;
    *) changed_outside="${changed_outside}${path}"$'\n' ;;
  esac
done
if [ -n "$changed_outside" ]; then
  echo "::error::Agent modified files outside ${charm_dir}/:" >&2
  printf '%s' "$changed_outside" >&2
  exit 1
fi
