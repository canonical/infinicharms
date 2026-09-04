#!/usr/bin/env bash
# Runs OpenCode to evaluate an issue and records the agent's response
# as a step output.
#
# Expects the following environment variables:
#   OPENROUTER_API_KEY - API key for OpenRouter
#   ISSUE_BODY         - the body text of the issue to evaluate
#   REPO_ROOT          - repository root to run OpenCode in
#
# Sets the following step outputs:
#   response - the agent's assessment ("Sounds tough!" or "Sounds easy!")
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
issue_body="${ISSUE_BODY:?ISSUE_BODY is required}"
agent_name="evaluate-issue"

# Stage the agent definition into .opencode/agents/.
agents_dir="${repo_root}/.opencode/agents"
mkdir -p "$agents_dir"
cp "$(dirname "$0")/../agent/${agent_name}.md" "${agents_dir}/${agent_name}.md"

# Compose the prompt.
prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"; rm -f "${agents_dir}/${agent_name}.md"' EXIT
cat > "$prompt_file" << 'PROMPT_EOF'
You are evaluating a GitHub issue. Read the issue body below and decide
whether it sounds tough or easy to implement. Respond with exactly one
phrase — either "Sounds tough!" or "Sounds easy!" — and nothing else.

<untrusted-content>
PROMPT_EOF
echo "$issue_body" >> "$prompt_file"
echo "</untrusted-content>" >> "$prompt_file"

# Run OpenCode with a scrubbed environment.
response=$(env -i PATH="$PATH" HOME="$HOME" USER="$USER" SHELL="$SHELL" LANG="$LANG" \
  OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  opencode run \
  --dir "$repo_root" \
  --agent "$agent_name" \
  --auto \
  --file "$prompt_file" \
  -- "Evaluate the issue and respond with Sounds tough! or Sounds easy!")

{
  echo "response<<EOF"
  echo "$response"
  echo "EOF"
} >> "$GITHUB_OUTPUT"
