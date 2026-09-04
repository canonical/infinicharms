---
name: evaluate-issue
description: Evaluate whether an issue sounds tough or easy
mode: primary
model: openrouter/z-ai/glm-5.2
temperature: 0.1
steps: 10
permission:
  edit: deny
  bash: deny
  read: allow
  network: deny
  web: deny
  task: deny
---

# Issue evaluator

The complete prompt is provided in the attached workflow-prompt.md file.
Read it and respond with exactly one phrase: "Sounds tough!" or "Sounds easy!".
Do not output anything else.
