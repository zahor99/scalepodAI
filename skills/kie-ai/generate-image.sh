#!/usr/bin/env bash
set -euo pipefail

PROMPT="${1:?Usage: generate-image.sh <prompt> [aspect_ratio] [resolution] [output_format]}"
ASPECT_RATIO="${2:-auto}"
RESOLUTION="${3:-1K}"
OUTPUT_FORMAT="${4:-jpg}"

if [ -z "${KIE_AI_API_KEY:-}" ]; then
  echo "Error: KIE_AI_API_KEY is not set" >&2
  exit 1
fi

# Create task
BODY=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg ar "$ASPECT_RATIO" \
  --arg res "$RESOLUTION" \
  --arg fmt "$OUTPUT_FORMAT" \
  '{
    model: "nano-banana-2",
    input: {
      prompt: $prompt,
      aspect_ratio: $ar,
      resolution: $res,
      output_format: $fmt
    }
  }')

echo "Creating image generation task..." >&2
CREATE_RESPONSE=$(curl -s -X POST \
  "https://api.kie.ai/api/v1/jobs/createTask" \
  -H "Authorization: Bearer ${KIE_AI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

TASK_ID=$(echo "$CREATE_RESPONSE" | jq -r '.data.taskId // .taskId // empty')
if [ -z "$TASK_ID" ]; then
  echo "Error: Failed to create task" >&2
  echo "$CREATE_RESPONSE" >&2
  exit 1
fi

echo "Task ID: $TASK_ID — polling for completion..." >&2

# Poll for completion
while true; do
  sleep 15
  STATUS_RESPONSE=$(curl -s -X GET \
    "https://api.kie.ai/api/v1/jobs/recordInfo?taskId=${TASK_ID}" \
    -H "Authorization: Bearer ${KIE_AI_API_KEY}" \
    -H "Content-Type: application/json")

  STATE=$(echo "$STATUS_RESPONSE" | jq -r '.data.state // empty')
  echo "State: $STATE" >&2

  if [ "$STATE" = "success" ]; then
    # .data.resultJson is a JSON string — parse it, then get .resultUrls[0]
    IMAGE_URL=$(echo "$STATUS_RESPONSE" | jq -r '.data.resultJson' | jq -r '.resultUrls[0]')
    if [ -z "$IMAGE_URL" ] || [ "$IMAGE_URL" = "null" ]; then
      echo "Error: Could not extract image URL" >&2
      echo "$STATUS_RESPONSE" >&2
      exit 1
    fi

    # Download
    OUTPUT_FILE="/tmp/kie-image-${TASK_ID}.${OUTPUT_FORMAT}"
    curl -s -o "$OUTPUT_FILE" "$IMAGE_URL"
    FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
    echo "Image downloaded: $OUTPUT_FILE ($FILE_SIZE bytes)"
    exit 0
  elif [ "$STATE" = "failed" ] || [ "$STATE" = "error" ]; then
    echo "Error: Image generation failed" >&2
    echo "$STATUS_RESPONSE" >&2
    exit 1
  fi
done
