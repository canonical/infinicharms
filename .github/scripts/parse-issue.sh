#!/usr/bin/env bash
# Parses a GitHub issue body into a structured charm spec using an OpenCode
# agent, then validates the JSON output and extracts fields as step outputs.
#
# Expects the following environment variables:
#   OPENROUTER_API_KEY - API key for OpenRouter
#   ISSUE_BODY         - the body text of the issue to evaluate
#   REPO_ROOT          - repository root to run OpenCode in
#
# Sets the following step outputs:
#   name    - the charm name (validated)
#   purpose - the charm purpose (one or two sentences)
#   shape   - the raw JSON shape object (containers, requires, etc.)
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
issue_body="${ISSUE_BODY:?ISSUE_BODY is required}"

# Compose the prompt.
prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"' EXIT
cat > "$prompt_file" << 'PROMPT_EOF'
You are given a GitHub issue body that describes a charm to be generated.
Extract three things and return them as JSON:
1. `name` — the charm name (a single token, lowercase, hyphens allowed).
2. `purpose` — one or two sentences describing what the charm does.
3. `shape` — a structured object with keys:
   - `containers`: list of `{name, resource}` (resource is `oci-image` when
     the OCI image is specified at deploy-time).
   - `requires`: list of `{name, interface}` relations the charm needs.
   - `provides`: list of `{name, interface}` relations the charm offers
     (optional).
   - `config_options`: list of `{name, type, default, description}`.
   - `actions`: list of `{name}` (optional).
Return ONLY the JSON, no prose.

<untrusted-content>
PROMPT_EOF
echo "$issue_body" >> "$prompt_file"
echo "</untrusted-content>" >> "$prompt_file"

# Run the agent (60s timeout — this is a single text-extraction call).
# run-agent.sh prints the agent's stdout and also writes it to $GITHUB_OUTPUT.
response=$(AGENT_NAME=parse-issue \
  PROMPT_FILE="$prompt_file" \
  TIMEOUT=60 \
  bash "$(dirname "$0")/run-agent.sh")

# Validate JSON.
if ! echo "$response" | jq -e . > /dev/null 2>&1; then
  echo "::error::Agent did not return valid JSON." >&2
  echo "Agent output: $response" >&2
  exit 1
fi

# Extract and validate name.
name="$(echo "$response" | jq -r '.name // empty')"
if [ -z "$name" ]; then
  echo "::error::Agent output is missing 'name'." >&2
  exit 1
fi
if ! echo "$name" | grep -qE '^[a-z][a-z0-9-]*[a-z0-9]$'; then
  echo "::error::Agent returned invalid charm name: '$name'. Must match ^[a-z][a-z0-9-]*[a-z0-9]\$ (lowercase, no leading digit, no trailing hyphen)." >&2
  exit 1
fi

# Extract purpose.
purpose="$(echo "$response" | jq -r '.purpose // empty')"
if [ -z "$purpose" ]; then
  echo "::error::Agent output is missing 'purpose'." >&2
  exit 1
fi

# Extract shape.
shape="$(echo "$response" | jq -c '.shape // empty')"
if [ -z "$shape" ] || [ "$shape" = "null" ]; then
  echo "::error::Agent output is missing 'shape'." >&2
  exit 1
fi

{
  echo "name=${name}"
  echo "purpose<<EOF"
  echo "$purpose"
  echo "EOF"
  echo "shape<<EOF"
  echo "$shape"
  echo "EOF"
} >> "$GITHUB_OUTPUT"
