---
name: google-drive
description: "Interact with Google Drive shared drives via service account. Supports list, upload, download, delete operations."
---

# Google Drive

Interact with Google Drive shared drives using a service account.

## Environment Variables

- `GOOGLE_SERVICE_ACCOUNT_JSON` — Service account credentials JSON
- `GOOGLE_SHARED_DRIVE_ID` — Shared drive ID

## Commands

### List files in a folder

```bash
skills/google-drive/list.sh <folder_id>
```

Lists files and folders in the given folder. Use `$GOOGLE_SHARED_DRIVE_ID` for the root.

### Upload a file

```bash
skills/google-drive/upload.sh <local_file> <parent_folder_id> <filename>
```

Uploads a local file to the specified folder with the given name.

### Download a file

```bash
skills/google-drive/download.sh <file_id> <local_path>
```

Downloads a file by ID to a local path.

### Delete a file

```bash
skills/google-drive/delete.sh <file_id>
```

Deletes a file by ID.
