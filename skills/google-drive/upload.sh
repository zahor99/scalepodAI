#!/usr/bin/env bash
set -euo pipefail

LOCAL_FILE="${1:?Usage: upload.sh <local_file> <parent_folder_id> <filename>}"
PARENT_FOLDER_ID="${2:?Usage: upload.sh <local_file> <parent_folder_id> <filename>}"
FILENAME="${3:?Usage: upload.sh <local_file> <parent_folder_id> <filename>}"

if [ ! -f "$LOCAL_FILE" ]; then
  echo "Error: File not found: $LOCAL_FILE" >&2
  exit 1
fi

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

# Detect MIME type from extension
EXT="${LOCAL_FILE##*.}"
case "${EXT,,}" in
  jpg|jpeg) MIME_TYPE="image/jpeg" ;;
  png)      MIME_TYPE="image/png" ;;
  gif)      MIME_TYPE="image/gif" ;;
  webp)     MIME_TYPE="image/webp" ;;
  mp4)      MIME_TYPE="video/mp4" ;;
  webm)     MIME_TYPE="video/webm" ;;
  pdf)      MIME_TYPE="application/pdf" ;;
  txt)      MIME_TYPE="text/plain" ;;
  json)     MIME_TYPE="application/json" ;;
  csv)      MIME_TYPE="text/csv" ;;
  *)        MIME_TYPE="application/octet-stream" ;;
esac

# Upload file using multipart upload
METADATA=$(printf '{"name":"%s","parents":["%s"]}' "$FILENAME" "$PARENT_FOLDER_ID")

RESPONSE=$(curl -s -X POST \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&includeItemsFromAllDrives=true" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -F "metadata=${METADATA};type=application/json" \
  -F "file=@${LOCAL_FILE};type=${MIME_TYPE}")

FILE_ID=$(echo "$RESPONSE" | jq -r '.id')
if [ -z "$FILE_ID" ] || [ "$FILE_ID" = "null" ]; then
  echo "Error: Upload failed" >&2
  echo "$RESPONSE" >&2
  exit 1
fi

echo "Uploaded: $FILENAME"
echo "File ID: $FILE_ID"
