#!/usr/bin/env bash
# Runs an OpenCode agent (via OpenRouter) and records its stdout as a step
# output. Handles agent definition staging, prompt transport, scrubbed
# environment, timeout, and cleanup.
#
# Expects the following environment variables:
#   OPENROUTER_API_KEY - API key for OpenRouter
#   REPO_ROOT          - repository root to run OpenCode in
#   AGENT_NAME         - name of the agent definition (e.g. "parse-issue")
#   PROMPT_FILE        - path to a file containing the prompt to pass to the agent
#   TIMEOUT            - wall-clock timeout in seconds (default: 300)
#
# Sets the following step outputs:
#   response - the agent's stdout (stripped of trailing whitespace)
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
agent_name="${AGENT_NAME:?AGENT_NAME is required}"
prompt_file="${PROMPT_FILE:?PROMPT_FILE is required}"
timeout="${TIMEOUT:-300}"
: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# Stage the agent definition into .opencode/agents/.
agents_dir="${repo_root}/.opencode/agents"
mkdir -p "$agents_dir"
cp "$(dirname "$0")/../agent/${agent_name}.md" "${agents_dir}/${agent_name}.md"

# Run OpenCode with a scrubbed environment (no GITHUB_TOKEN).
# The trap ensures cleanup even on timeout or failure.
cleanup() {
  rm -f "${agents_dir}/${agent_name}.md"
  rmdir "${agents_dir}" 2>/dev/null || true
  rmdir "${repo_root}/.opencode" 2>/dev/null || true
}
trap cleanup EXIT

response=$(timeout "$timeout" env -i \
  PATH="$PATH" HOME="$HOME" USER="$USER" SHELL="$SHELL" LANG="$LANG" \
  OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  opencode run \
  --dir "$repo_root" \
  --agent "$agent_name" \
  --auto \
  --file "$prompt_file" \
  -- "Follow the instructions in the attached prompt file.") || rc=$?

# Handle timeout (exit code 124 from the `timeout` command).
if [ "${rc:-0}" -eq 124 ]; then
  echo "::error::Agent timed out after ${timeout}s." >&2
  exit 124
elif [ "${rc:-0}" -ne 0 ]; then
  echo "::error::Agent exited with code ${rc}." >&2
  exit "${rc}"
fi

# Write to $GITHUB_OUTPUT for direct use by workflow steps.
{
  echo "response<<EOF"
  echo "$response"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

# Also print to stdout so calling scripts can capture it.
echo "$response"
