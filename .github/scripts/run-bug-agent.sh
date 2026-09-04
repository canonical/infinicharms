#!/usr/bin/env bash
# Runs the opencode agent to investigate a charm bug report and either open
# a PR with a fix (with auto-merge enabled) or close the issue as not
# planned. See .github/prompts/bug-fix-agent.md for the actual instructions
# given to the agent -- this script just prepares its environment.
#
# Expects the following environment variables:
#   ISSUE_NUMBER        - number of the bug-report issue
#   CHARM_NAME           - name of the charm under charms/, e.g. "mycharm"
#   REPO                 - "owner/repo" slug (github.repository)
#   GH_TOKEN             - token for commenting on / closing the issue, and
#                          later for approving the PR and enabling
#                          auto-merge (the default GITHUB_TOKEN is fine for
#                          this)
#   GH_PR_TOKEN          - token for a separate bot account that the agent
#                          must use (explicitly) to fork this repo, push
#                          the fix branch to that fork, and open the PR
#                          from it, so that the resulting PR triggers this
#                          repo's status-check workflows (a PR opened with
#                          the default GITHUB_TOKEN would not trigger them)
#                          and so it can be approved by GH_TOKEN afterwards
#                          (an author can't approve their own PR)
#   OPENROUTER_API_KEY   - credentials for the openrouter/google model
set -euo pipefail

issue="${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
name="${CHARM_NAME:?CHARM_NAME is required}"
repo="${REPO:?REPO is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GH_PR_TOKEN:?GH_PR_TOKEN is required}"
: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}"

branch="bug/${name}-issue-${issue}"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git checkout -b "$branch"

# Exported so the agent's shell (opencode's bash tool) can see the resolved
# charm paths and branch name without having to re-derive them.
export CHARM_DIR="charms/${name}"
export EVOLVED_DIR="charms/${name}/_evolved"
export BRANCH_NAME="$branch"
export REPO="$repo"
export ISSUE_NUMBER="$issue"
export CHARM_NAME="$name"

prompt="$(cat .github/prompts/bug-fix-agent.md)"

opencode run --auto --model openrouter/google/gemini-3.8-flash "$prompt"
