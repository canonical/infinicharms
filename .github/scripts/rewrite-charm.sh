#!/usr/bin/env bash
# Runs an OpenCode agent to rewrite charmcraft.yaml, pyproject.toml, and
# src/charm.py for a new charm spec, then verifies the agent only modified
# files under the charm directory.
#
# Expects the following environment variables:
#   OPENROUTER_API_KEY - API key for OpenRouter
#   REPO_ROOT          - repository root to run OpenCode in
#   CHARM_NAME         - the charm name (e.g. "myblog")
#   CHARM_DIR          - the charm directory (e.g. "charms/myblog")
#   SPEC_JSON          - the parsed charm shape as JSON
#   CHARM_PURPOSE      - the charm purpose text (for summary/description)
#
# Sets the following step outputs:
#   response - the agent's stdout
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
charm_name="${CHARM_NAME:?CHARM_NAME is required}"
charm_dir="${CHARM_DIR:?CHARM_DIR is required}"
spec_json="${SPEC_JSON:?SPEC_JSON is required}"
charm_purpose="${CHARM_PURPOSE:?CHARM_PURPOSE is required}"

# Derive PascalCase name: myblog -> Myblog, my-blog -> MyBlog.
pascal="$(echo "$charm_name" | sed 's/-\([a-z]\)/\U\1/g; s/^./\U&/')"

# Compose the prompt.
prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"' EXIT
cat > "$prompt_file" << PROMPT_EOF
You are updating a charm generated from a base charm template. The charm
lives in ${charm_dir}/. Using the issue shape below, do TWO things:

1. Rewrite charmcraft.yaml:
   - Set name to ${charm_name}, title to a human-readable title.
   - Write a concise summary and description from this purpose: ${charm_purpose}
   - Add a containers block (one container per shape container, each with
     resource: oci-image).
   - Add a resources block with an oci-image resource of type oci-image.
   - Add a requires block with one entry per shape relation (use the
     interface from the shape; default to postgresql_client for postgres).
   - Add a provides block with one entry per shape provides relation, if
     any.
   - Preserve all existing config options from the base charm. Add new
     config options for each config option from the shape. Do not remove
     or rename existing options.
   - Preserve the existing actions block from the base charm. Add new
     actions from the shape, if any. Do not remove existing actions.
   - Keep base, platforms, assumes, and parts from the base charm unchanged.

2. Update src/charm.py:
   - Rename the charm class to ${pascal}Charm.
   - Update the class docstring to describe the new charm, not the base charm.
   - Keep all existing lifecycle handlers and helper methods from the base
     charm unchanged.
   - If the base charm has a holistic _run method, add one observer per
     relation event (relation_joined, relation_changed, relation_departed)
     for each requires and provides relation, each calling self._run().
     Use the relation name from the shape: self.on["<name>"].relation_joined.
   - If the base charm has no holistic _run method (it uses individual
     lifecycle handlers), route each new observer to the most appropriate
     existing handler. For relation events and pebble_ready, routing to
     _on_config_changed is a reasonable default since it typically runs
     the main reconcile/update logic.
   - Add a pebble_ready observer for each container. Use the container
     name from the shape: self.on.<container>.pebble_ready.
   - Add an observer for each action, if any.
   - Update ops.main(<ClassName>) at the bottom and any __all__ export.

Also update the name field in pyproject.toml to match the charm name.

Issue shape: ${spec_json}

Only modify files under ${charm_dir}/.
PROMPT_EOF

# Run the agent (300s timeout — reads + edits 3 files).
AGENT_NAME=rewrite-charm \
PROMPT_FILE="$prompt_file" \
TIMEOUT=300 \
  bash "$(dirname "$0")/run-agent.sh"

# Verify the agent only modified files under the charm directory.
changed="$(cd "$repo_root" && git status --porcelain | awk '{print $2}')"
changed_outside=""
for path in $changed; do
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
