---
name: kie-ai
description: "Generate images and videos using kie.ai API. Use for AI image and video generation tasks."
---

# KIE AI

Generate images and videos using the kie.ai API.

## Environment Variables

- `KIE_AI_API_KEY` — API key for kie.ai

## Commands

### Generate an image

```bash
skills/kie-ai/generate-image.sh <prompt> [aspect_ratio] [resolution] [output_format]
```

- `prompt` (required) — Text prompt for image generation
- `aspect_ratio` (optional, default: `auto`) — One of: `auto, 1:1, 1:4, 16:9, 1:8, 21:9, 2:3, 3:2, 3:4, 4:1, 4:3, 4:5, 5:4, 8:1, 9:16`
- `resolution` (optional, default: `1K`) — One of: `1K, 2K, 4K`
- `output_format` (optional, default: `jpg`) — One of: `jpg, png`

Downloads the generated image to a local file and prints the path.

### Generate a video

```bash
skills/kie-ai/generate-video.sh <prompt> [aspect_ratio]
```

- `prompt` (required) — Text prompt for video generation
- `aspect_ratio` (optional, default: `16:9`) — One of: `16:9, 9:16, Auto`

Downloads the generated video to a local file and prints the path.
