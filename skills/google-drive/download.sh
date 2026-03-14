#!/usr/bin/env bash
set -euo pipefail

FILE_ID="${1:?Usage: download.sh <file_id> <local_path>}"
LOCAL_PATH="${2:?Usage: download.sh <file_id> <local_path>}"

if [ -z "${GOOGLE_SERVICE_ACCOUNT_JSON:-}" ]; then
  echo "Error: GOOGLE_SERVICE_ACCOUNT_JSON is not set" >&2
  exit 1
fi

# Extract service account email and private key
SA_EMAIL=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.client_email')
SA_KEY=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.private_key')
TOKEN_URI=$(echo "$GOOGLE_SERVICE_ACCOUNT_JSON" | jq -r '.token_uri')

# Build JWT
NOW=$(date +%s)
EXP=$((NOW + 3600))
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
CLAIMS=$(printf '{"iss":"%s","scope":"https://www.googleapis.com/auth/drive","aud":"%s","iat":%d,"exp":%d}' \
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

# Download file
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$LOCAL_PATH" \
  "https://www.googleapis.com/drive/v3/files/${FILE_ID}?alt=media&supportsAllDrives=true&includeItemsFromAllDrives=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}")

if [ "$HTTP_CODE" -ne 200 ]; then
  echo "Error: Download failed with HTTP $HTTP_CODE" >&2
  cat "$LOCAL_PATH" >&2
  rm -f "$LOCAL_PATH"
  exit 1
fi

FILE_SIZE=$(stat -c%s "$LOCAL_PATH" 2>/dev/null || stat -f%z "$LOCAL_PATH" 2>/dev/null)
echo "Downloaded to: $LOCAL_PATH ($FILE_SIZE bytes)"
