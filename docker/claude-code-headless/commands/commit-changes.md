---
description: Stage all changes, commit with a detailed message, and push
---

Stage all changes, commit, and push to the remote feature branch.

Review the full diff before writing the commit message. The message should:
- Have a short summary line (under 72 chars) with a conventional prefix (`fix:`, `feat:`, `refactor:`, `chore:`, `docs:`)
- Include a body explaining WHAT changed and WHY, grouped by area if there are multiple changes
- Be detailed but not excessive

Do NOT commit files that look like secrets (.env, credentials, tokens).

If there are $ARGUMENTS, use them as additional context for the commit message.
