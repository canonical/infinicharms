#!/usr/bin/env bash
# Runs an OpenCode agent to write a minimal evolved charm from scratch,
# then verifies the agent only modified files under the _evolved/ directory.
#
# Expects the following environment variables:
#   OPENROUTER_API_KEY - API key for OpenRouter
#   REPO_ROOT          - repository root to run OpenCode in
#   CHARM_NAME         - the charm name (e.g. "myblog")
#   EVOLVED_DIR        - the evolved charm directory (e.g. "charms/myblog/_evolved")
#
# Sets the following step outputs:
#   response - the agent's stdout
set -euo pipefail

repo_root="${REPO_ROOT:?REPO_ROOT is required}"
charm_name="${CHARM_NAME:?CHARM_NAME is required}"
evolved_dir="${EVOLVED_DIR:?EVOLVED_DIR is required}"

# Derive PascalCase name: myblog -> Myblog, my-blog -> MyBlog.
pascal="$(echo "$charm_name" | sed 's/-\([a-z]\)/\U\1/g; s/^./\U&/')"

# Compose the prompt.
prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"' EXIT
cat > "$prompt_file" << PROMPT_EOF
You are creating a minimal evolved charm in ${evolved_dir}/. The directory
already contains charmcraft.yaml, pyproject.toml, uv.lock, and an empty
src/ directory. Do the following:

1. In charmcraft.yaml: change name to ${charm_name}-evolved and title
   accordingly. Leave all other fields (containers, resources, requires,
   config, actions, platforms) unchanged. **Remove the `soul-and-prompts`
   part** from the `parts` block (if present) — the evolved charm doesn't
   use the failure agent or self-update loop, so it doesn't need SOUL.md
   or prompts/. Keep the `charm` part unchanged.
2. In pyproject.toml: change the project name to "${charm_name}-evolved".
   Replace the entire dependencies list with just ops — the evolved charm
   only imports ops, so any base charm dependencies (e.g.
   pydantic-ai-slim[openai]) are unnecessary bloat. The result must be
   exactly:
   dependencies = [
       "ops~=3.8",
   ]
   Remove any comments inside the dependencies block that reference base
   charm modules. Be careful to produce valid TOML — do not leave stray
   lines or trailing commas.
3. Write src/charm.py from scratch as a minimal charm:
   - Define a class ${pascal}EvolvedCharm(ops.CharmBase).
   - In __init__, observe these lifecycle events: install, start,
     config_changed, update_status, upgrade_charm, collect_unit_status.
     Also observe the shape-specific events: one observer per relation
     event (relation_joined, relation_changed, relation_departed) for
     each requires and provides relation, and a pebble_ready observer for
     each container.
   - Each handler method should be a no-op stub: just pass. No
     functionality, no imports beyond ops, no helper methods.
   - End with if __name__ == "__main__": ops.main(${pascal}EvolvedCharm).

Do NOT copy any code from the main charm. Do NOT import any packages
beyond ops. The evolved charm is a fresh, minimal standalone charm.

Only modify files under ${evolved_dir}/.
PROMPT_EOF

# Run the agent (180s timeout — writes charm.py from scratch + edits 2 files).
AGENT_NAME=evolve-charm \
PROMPT_FILE="$prompt_file" \
TIMEOUT=180 \
  bash "$(dirname "$0")/run-agent.sh"

# Verify the agent only modified files under the evolved directory.
# Use --untracked-files=all so git lists individual files, not just the parent dir.
changed="$(cd "$repo_root" && git status --porcelain --untracked-files=all | awk '{print $2}')"
changed_outside=""
for path in $changed; do
  case "$path" in
    ${evolved_dir}/*|${evolved_dir}) ;;
    *) changed_outside="${changed_outside}${path}"$'\n' ;;
  esac
done
if [ -n "$changed_outside" ]; then
  echo "::error::Agent modified files outside ${evolved_dir}/:" >&2
  printf '%s' "$changed_outside" >&2
  exit 1
fi
