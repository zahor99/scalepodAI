---
name: google-docs
description: "Create and manage Google Docs on a shared drive via service account."
---

# Google Docs

Create and manage Google Docs on a shared drive using a service account.

## Environment Variables

- `GOOGLE_SERVICE_ACCOUNT_JSON` — Service account credentials JSON
- `GOOGLE_SHARED_DRIVE_ID` — Shared drive ID

## Commands

### Create a Google Doc

```bash
skills/google-docs/create.sh <title> <content> <parent_folder_id>
```

Creates a new Google Doc with the given title and text content in the specified folder. Returns the document ID and URL.
