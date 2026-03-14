#!/usr/bin/env bash
set -euo pipefail

PROMPT="${1:?Usage: generate-video.sh <prompt> [aspect_ratio]}"
ASPECT_RATIO="${2:-16:9}"

if [ -z "${KIE_AI_API_KEY:-}" ]; then
  echo "Error: KIE_AI_API_KEY is not set" >&2
  exit 1
fi

# Create task
BODY=$(jq -n \
  --arg prompt "$PROMPT" \
  --arg ar "$ASPECT_RATIO" \
  '{
    prompt: $prompt,
    model: "veo3_fast",
    generationType: "TEXT_2_VIDEO",
    aspect_ratio: $ar
  }')

echo "Creating video generation task..." >&2
CREATE_RESPONSE=$(curl -s -X POST \
  "https://api.kie.ai/api/v1/veo/generate" \
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
    "https://api.kie.ai/api/v1/veo/record-info?taskId=${TASK_ID}" \
    -H "Authorization: Bearer ${KIE_AI_API_KEY}" \
    -H "Content-Type: application/json")

  SUCCESS_FLAG=$(echo "$STATUS_RESPONSE" | jq -r '.data.successFlag // empty')
  echo "Status check... successFlag=$SUCCESS_FLAG" >&2

  if [ "$SUCCESS_FLAG" = "1" ]; then
    VIDEO_URL=$(echo "$STATUS_RESPONSE" | jq -r '.data.response.resultUrls[0]')
    if [ -z "$VIDEO_URL" ] || [ "$VIDEO_URL" = "null" ]; then
      echo "Error: Could not extract video URL" >&2
      echo "$STATUS_RESPONSE" >&2
      exit 1
    fi

    # Download
    OUTPUT_FILE="/tmp/kie-video-${TASK_ID}.mp4"
    curl -s -o "$OUTPUT_FILE" "$VIDEO_URL"
    FILE_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
    echo "Video downloaded: $OUTPUT_FILE ($FILE_SIZE bytes)"
    exit 0
  elif [ "$SUCCESS_FLAG" = "-1" ]; then
    echo "Error: Video generation failed" >&2
    echo "$STATUS_RESPONSE" >&2
    exit 1
  fi
done
