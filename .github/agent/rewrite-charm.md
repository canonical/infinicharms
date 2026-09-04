---
name: rewrite-charm
description: Rewrite charmcraft.yaml, pyproject.toml, and src/charm.py for a new charm spec
mode: primary
model: openrouter/z-ai/glm-5.2
temperature: 0.1
steps: 25
permission:
  edit: allow
  bash: deny
  read: allow
  network: deny
  web: deny
  task: deny
---

# Charm rewriter

The complete prompt is provided in the attached workflow-prompt.md file.
Follow the instructions in the prompt to rewrite `charmcraft.yaml`,
`pyproject.toml`, and `src/charm.py` for the new charm spec.
Only modify files under the charm directory.
