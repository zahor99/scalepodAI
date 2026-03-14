#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:?Usage: create.sh <title> <content> <parent_folder_id>}"
CONTENT="${2:?Usage: create.sh <title> <content> <parent_folder_id>}"
PARENT_FOLDER_ID="${3:?Usage: create.sh <title> <content> <parent_folder_id>}"

if [ -z "${GOOGLE_SERVICE_ACCOUNT_JSON:-}" ]; then
  echo "Error: GOOGLE_SERVICE_ACCOUNT_JSON is not set" >&2
  exit 1
fi

# Extract service account email and private key
SA_EMAIL=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.client_email')
SA_KEY=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.private_key')
TOKEN_URI=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.token_uri')

# Build JWT with both drive and docs scopes
NOW=$(date +%s)
EXP=$((NOW + 3600))
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
CLAIMS=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/documents","aud":"%s","iat":%d,"exp":%d}' \
  "$SA_EMAIL" "$TOKEN_URI" "$NOW" "$EXP" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
SIGNING_INPUT="${HEADER}.${CLAIMS}"
SIGNATURE=$(printf '%s' "$SIGNING_INPUT" | openssl dgst -sha256 -sign <(echo "$SA_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
JWT="${SIGNING_INPUT}.${SIGNATURE}"

# Exchange JWT for access token
ACCESS_TOKEN=$(curl -s -X POST "$TOKEN_URI" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${JWT}" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Error: Failed to obtain access token" >&2
  exit 1
fi

# Create Google Doc via Drive API (creates empty doc in the shared drive)
METADATA=$(jq -n --arg title "$TITLE" --arg parent "$PARENT_FOLDER_ID" \
  '{name: $title, mimeType: "application/vnd.google-apps.document", parents: [$parent]}')

CREATE_RESPONSE=$(curl -s -X POST \
  "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&includeItemsFromAllDrives=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$METADATA")

DOC_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
if [ -z "$DOC_ID" ] || [ "$DOC_ID" = "null" ]; then
  echo "Error: Failed to create document" >&2
  echo "$CREATE_RESPONSE" >&2
  exit 1
fi

# Insert content using Docs API batchUpdate
if [ -n "$CONTENT" ]; then
  UPDATE_BODY=$(jq -n --arg text "$CONTENT" \
    '{requests: [{insertText: {location: {index: 1}, text: $text}}]}')

  curl -s -X POST \
    "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$UPDATE_BODY" > /dev/null
fi

echo "Created Google Doc: $TITLE"
echo "Doc ID: $DOC_ID"
echo "URL: https://docs.google.com/document/d/${DOC_ID}/edit"
