---
name: parse-issue
description: Extract a structured charm spec from a GitHub issue body
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

# Issue parser

The complete prompt is provided in the attached workflow-prompt.md file.
Read it and respond with the JSON spec described in the prompt.
Do not output anything other than the JSON.
