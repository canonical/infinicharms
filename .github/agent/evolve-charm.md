---
name: evolve-charm
description: Write a minimal evolved charm from scratch with no-op stub handlers
mode: primary
model: openrouter/z-ai/glm-5.2
temperature: 0.1
steps: 20
permission:
  edit: allow
  bash: deny
  read: allow
  network: deny
  web: deny
  task: deny
---

# Charm evolver

The complete prompt is provided in the attached workflow-prompt.md file.
Follow the instructions in the prompt to write a minimal evolved charm
from scratch. Only modify files under the _evolved/ charm directory.
