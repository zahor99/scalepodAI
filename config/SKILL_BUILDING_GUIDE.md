# Skill Building Guide

## What is a skill?

Skills are lightweight wrappers that extend agent abilities. They live in `skills/<skill-name>/` and are activated by symlinking into `skills/active/`. Both Pi and Claude Code discover skills from the same shared directory.

## Skill structure

- **`SKILL.md`** (required) — YAML frontmatter + markdown documentation
- **Scripts** (optional) — prefer bash (.sh) for simplicity
- **`package.json`** (optional) — only if Node.js dependencies are truly needed

## SKILL.md format

The `description` from frontmatter appears in the system prompt under "Active skills."
Use project-root-relative paths in documentation (e.g., `skills/<skill-name>/script.sh`).

```
---
name: skill-name-in-kebab-case
description: One sentence describing what the skill does and when to use it.
---

# Skill Name

## Usage

```bash
skills/skill-name/script.sh <args>
```
```

## Example: Simple bash skill (most common pattern)

The built-in `transcribe` skill — a SKILL.md and a single bash script:

**skills/transcribe/SKILL.md:**
```
---
name: transcribe
description: Speech-to-text transcription using Groq Whisper API. Supports m4a, mp3, wav, ogg, flac, webm.
---

# Transcribe

Speech-to-text using Groq Whisper API.

## Setup
Requires GROQ_API_KEY environment variable.

## Usage
```bash
skills/transcribe/transcribe.sh <audio-file>
```
```

**skills/transcribe/transcribe.sh:**
```bash
#!/bin/bash
if [ -z "$1" ]; then echo "Usage: transcribe.sh <audio-file>"; exit 1; fi
if [ -z "$GROQ_API_KEY" ]; then echo "Error: GROQ_API_KEY not set"; exit 1; fi
curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F "file=@${1}" \
  -F "model=whisper-large-v3-turbo" \
  -F "response_format=text"
```

## Example: Skill with Node.js dependencies

The built-in `brave-search` skill uses Node.js for HTML parsing (jsdom, readability, turndown). It has a `package.json` and `.js` scripts. Dependencies are installed automatically in Docker. Use this pattern only when bash + curl isn't sufficient.

## Activation

After creating skill files, symlink to activate:
```bash
ln -s ../skill-name skills/active/skill-name
```

## Always build AND test in the same job

Tell the agent to test the skill with real input after creating it and fix any issues before committing. Don't create untested skills.

## Credential setup

If a skill needs an API key, the user should set it up BEFORE the job runs:
- `npx thepopebot set-agent-llm-secret <KEY_NAME> <value>` — creates a GitHub secret with `AGENT_LLM_` prefix, exposed as an env var in the Docker container
- The value is stored exactly as provided, no transformation needed
- Also add to `.env` for local development
- Keys can be rotated later with the same command

**Multi-line secrets** (e.g., JSON service account files): omit the value argument and pipe the file via stdin:
```bash
npx thepopebot set-agent-llm-secret GOOGLE_CREDENTIALS < credentials.json
```
Avoid `$(cat credentials.json)` — it can break on special characters and newlines.
