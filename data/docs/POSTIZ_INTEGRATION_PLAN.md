# Postiz Integration Plan — ScalePod AI Marketing Subdomain

## Overview

Use Postiz as a self-hosted social media scheduling engine behind `marketing.scalepod.ai`. Customers access it via SSO from the main ScalePod SaaS. AI agents push content from the product pipeline to Postiz via its Public API.

**License**: AGPL v3 — legal as long as users interact with Postiz directly (it's already open source). No AGPL contamination of proprietary ScalePod code since Postiz runs as a separate service.

**Status**: Postiz Docker instance running locally at `http://localhost:4007`

## Architecture

```
scalepod.ai              -> ScalePod SaaS (Next.js, proprietary)
marketing.scalepod.ai    -> Postiz (single instance, multi-org, AGPL)

Customer signs up on ScalePod
    -> Clicks "Marketing" button
    -> SSO into Postiz (auto-creates their org on first login)
    -> Customer connects their own Pinterest, X, IG, etc.
    -> Customer schedules posts manually in Postiz UI

Meanwhile:
    -> ScalePod AI agent pushes posts via Postiz Public API
    -> ScalePod pulls analytics back from Postiz API
```

## Responsibilities

| ScalePod (proprietary) | Postiz (open source, self-hosted) |
|------------------------|-----------------------------------|
| Product design pipeline | OAuth with 20+ social platforms |
| AI generates pin images + captions | Token management & refresh |
| "Push to Marketing" sends to Postiz API | Post scheduling & calendar UI |
| Product data in Supabase | Actual publishing to platforms |
| Analytics dashboard (pulls from Postiz) | Platform-specific formatting |
| User auth + billing | Multi-org user management |

## Multi-Org Model

- Single Postiz instance serves all customers
- Each customer = one Postiz organization
- Each org has its own API key, connected channels, posts
- Postiz has built-in org switching and team management

## SSO Configuration

Postiz supports generic OAuth. Configure in Postiz `.env`:

```
POSTIZ_GENERIC_OAUTH=true
POSTIZ_OAUTH_URL=https://auth.scalepod.ai
POSTIZ_OAUTH_AUTH_URL=https://auth.scalepod.ai/authorize
POSTIZ_OAUTH_TOKEN_URL=https://auth.scalepod.ai/token
POSTIZ_OAUTH_USERINFO_URL=https://auth.scalepod.ai/userinfo
POSTIZ_OAUTH_CLIENT_ID=<your-client-id>
POSTIZ_OAUTH_CLIENT_SECRET=<your-client-secret>
```

Options for OAuth provider:
- Supabase Auth (already in stack)
- NextAuth.js in ScalePod dashboard
- External provider (Auth0, Clerk)

## Postiz Public API v1 Reference

**Base URL**: `http://localhost:4007/api/public/v1`
**Auth**: `Authorization: <api-key>` (no Bearer prefix)
**Rate limit**: 30 POST /posts per hour (configurable via API_LIMIT env var)

### Core Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/is-connected` | Verify API key |
| GET | `/integrations` | List connected channels |
| GET | `/find-slot/{id}` | Find next posting slot |
| GET | `/integration-settings/{id}` | Get platform rules/limits |
| POST | `/upload` | Upload media (multipart) |
| POST | `/upload-from-url` | Upload media from URL |
| POST | `/posts` | Create/schedule posts |
| GET | `/posts?startDate=&endDate=` | List posts by date range |
| DELETE | `/posts/{id}` | Delete a post |
| GET | `/analytics/{integrationId}?date=30` | Channel analytics |
| GET | `/analytics/post/{postId}?date=7` | Per-post analytics |
| GET | `/notifications?page=0` | List notifications |

### Post Creation Schema

```json
{
  "type": "schedule | now | draft",
  "date": "2026-03-01T14:00:00.000Z",
  "shortLink": false,
  "tags": [],
  "posts": [
    {
      "integration": {"id": "integration-uuid"},
      "value": [
        {
          "content": "Post text content",
          "image": [{"id": "media-uuid", "path": "https://..."}]
        }
      ],
      "settings": {
        "__type": "pinterest",
        "board": "board-id",
        "title": "Pin Title",
        "link": "https://etsy.com/listing/..."
      }
    }
  ]
}
```

### Platform Settings (__type values)

| Platform | __type | Key Settings |
|----------|--------|-------------|
| Pinterest | `pinterest` | board (required), title, link, dominant_color |
| X/Twitter | `x` | who_can_reply_post (required) |
| Instagram | `instagram` | post_type: post/story/reel (required) |
| Facebook | `facebook` | url (optional) |
| TikTok | `tiktok` | privacy_level, duet, stitch, comment (all required) |
| Reddit | `reddit` | subreddit array with title+type (required) |
| LinkedIn | `linkedin` | post_as_images_carousel (optional) |
| YouTube | `youtube` | title, type: public/private/unlisted (required) |
| Threads | `threads` | (none extra) |
| Bluesky | `bluesky` | (none extra) |
| Mastodon | `mastodon` | (none extra) |
| Medium | `medium` | title, subtitle (required) |

### Media Upload Flow

```python
# Option A: Upload from URL (best for Supabase Storage images)
media = requests.post(f"{API}/upload-from-url",
    headers={"Authorization": api_key},
    json={"url": "https://supabase.co/storage/v1/object/public/mockup.png"}
).json()
# Returns: {"id": "uuid", "path": "https://...", "name": "..."}

# Option B: Multipart upload
media = requests.post(f"{API}/upload",
    headers={"Authorization": api_key},
    files={"file": open("mockup.png", "rb")}
).json()
```

### Multi-Platform Example

```python
requests.post(f"{API}/posts", headers=headers, json={
    "type": "schedule",
    "date": "2026-03-01T14:00:00.000Z",
    "shortLink": False,
    "tags": [],
    "posts": [
        {
            "integration": {"id": "pinterest-uuid"},
            "value": [{"content": "Gothic dress", "image": [media]}],
            "settings": {"__type": "pinterest", "board": "board-id",
                         "title": "Gothic Dress", "link": "https://etsy.com/..."}
        },
        {
            "integration": {"id": "x-uuid"},
            "value": [{"content": "New drop! #whimsigoth", "image": [media]}],
            "settings": {"__type": "x", "who_can_reply_post": "everyone"}
        },
        {
            "integration": {"id": "instagram-uuid"},
            "value": [{"content": "New in shop! #darkfloral", "image": [media]}],
            "settings": {"__type": "instagram", "post_type": "post"}
        }
    ]
})
```

## Two-Way Sync

### Direction 1: ScalePod -> Postiz (AI agent pushes content)

```
Product approved on Kanban
  -> AI generates captions per platform
  -> POST /upload-from-url (product mockup from Supabase Storage)
  -> POST /posts (schedule across connected channels)
  -> Customer sees post on their Postiz calendar
```

### Direction 2: Postiz -> ScalePod (analytics back)

```
Cron job or webhook
  -> GET /analytics/post/{id} for each published post
  -> Store engagement metrics in ScalePod Supabase
  -> Show customers which products perform best on social
```

## Implementation Phases

### Phase 1: Personal Use (NOW)
- [x] Postiz Docker running at localhost:4007
- [x] Pinterest API keys configured
- [x] Register account in Postiz UI (gergelyracz0@gmail.com)
- [x] Cloudflare Tunnel for HTTPS OAuth callbacks
- [x] Connect X channel (@LunarAuraDesign via OAuth 1.0a)
- [x] First tweet posted with product image (Luna Moth hoodie, 2026-03-01)
- [x] Delayed reply pattern for Etsy link comments
- [ ] Connect Pinterest (after Standard access approval)
- [ ] Connect Reddit, Bluesky, Mastodon
- [ ] Test manual posting from Postiz UI
- [ ] Fix Postiz X provider for image tweets (upstream issue)
- [ ] Volume-mount nginx.conf for persistent cookie domain fix

### Phase 2: AI Agent Relay
- [ ] Build Python script: `prototype/tools/publish_social_content.py`
- [ ] Integrate with product approval pipeline
- [ ] Auto-generate platform-specific captions (LLM)
- [ ] Push approved products to Postiz on schedule
- [ ] Pull analytics back to Supabase

### Phase 3: SaaS Integration
- [ ] Deploy Postiz to cloud (VPS or Railway)
- [ ] Configure subdomain: marketing.scalepod.ai
- [ ] Set up SSO (Postiz generic OAuth -> ScalePod auth)
- [ ] "Marketing" button in ScalePod dashboard
- [ ] Per-customer org creation via API
- [ ] API key storage per customer in ScalePod Supabase
- [ ] Analytics integration in ScalePod dashboard

## API Limitations

| Limitation | Impact | Workaround |
|-----------|--------|------------|
| Can't connect channels via API | Users must OAuth through Postiz UI | This is by design - users go to marketing subdomain |
| 30 POST /posts per hour | Fine for most users | Increase API_LIMIT env var |
| No recurring posts via API | Each post must be individually scheduled | Build recurrence in your agent |
| No user/org creation via public API | Can't auto-provision orgs | Use internal API or enterprise endpoint |

## X/Twitter Integration Notes (2026-03-01)

### X Developer Portal Setup
- **App name**: LunarAuraDe
- **Tier**: Free (1,500 tweets/month, 280 char limit)
- **Permissions**: Read and Write
- **Callback URL**: `https://<tunnel-url>/api/integrations/social/x`
- **Website URL**: `https://scalepod.ai` (must be clean — no query params or fragments)

### X Free Tier Constraints
| Constraint | Detail | Error if violated |
|------------|--------|-------------------|
| Character limit | 280 chars max | HTTP 403 "Forbidden" |
| Media upload | v1.uploadMedia only | HTTP 403 via v2.uploadMedia |
| Credits | Must be enrolled in Free plan | HTTP 402 "CreditsDepleted" |
| Rate | 300 posts per 3 hours | HTTP 429 |

### Known Postiz Bug: Image Tweets Fail
Postiz's `XProvider` uses `client.v2.uploadMedia()` (x.provider.ts:320) which doesn't work on X Free tier. The error is caught by `social.abstract.ts:runInConcurrent()` and replaced with generic "Unknown Error" / `bad_body`, losing the actual X API error.

**Workaround**: Post image tweets directly via X API inside the Postiz container using `client.v1.uploadMedia()` + `client.v2.tweet()`. Text-only tweets under 280 chars work through Postiz if under character limit.

### Posting via Direct X API (bypassing Postiz orchestrator)
```javascript
// Run inside Postiz container (has twitter-api-v2)
const { TwitterApi } = require("twitter-api-v2");
const client = new TwitterApi({
  appKey: process.env.X_API_KEY,
  appSecret: process.env.X_API_SECRET,
  accessToken: "<from Integration table>",
  accessSecret: "<from Integration table>"
});
const mediaId = await client.v1.uploadMedia(buffer, { mimeType: "image/jpeg" });
const tweet = await client.v2.tweet({ text: "...", media: { media_ids: [mediaId] } });
```

## Docker Setup

**Location**: `EtsyAutomation/postiz/`
**Files**: `docker-compose.yml`, `.env`, `dynamicconfig/`

```bash
# Start
cd postiz && docker compose up -d

# After container recreation (restores .env for backend)
docker exec postiz sh -c 'sh /config/restore-env.sh'
docker exec postiz sh -c 'pm2 restart backend'

# Logs
docker compose logs -f postiz

# Stop
docker compose down
```

**Ports**: Postiz UI :4007, Temporal UI :8233
**No conflicts** with dashboard :3000 or Supabase :54321/:54323

**IMPORTANT**: Use `sh -c '...'` wrapper for docker exec commands in Git Bash on Windows — otherwise `/config/` gets expanded to `C:/Program Files/Git/config/`.

## Cloudflare Tunnel (for OAuth)

OAuth callbacks (X, Pinterest) require HTTPS. Use Cloudflare's free quick tunnel:

```bash
cloudflared tunnel --url http://localhost:4007
```

After tunnel starts (URL changes every restart):
1. Update `postiz/.env`: set MAIN_URL, FRONTEND_URL, NEXT_PUBLIC_BACKEND_URL to tunnel URL
2. Recreate container: `docker compose up -d --force-recreate postiz`
3. Fix nginx cookie domain inside container (see below)
4. Update X Developer Portal callback URL

## Known Issue: Backend .env

The Postiz backend uses `dotenv -e ../../.env` to load config. Files copied via `docker cp` from Windows cause the backend to hang silently. Must write the .env directly inside the container via heredoc or shell redirect. Backup is stored at `/config/.env.backup` (persistent volume).

**CRITICAL**: `docker-compose.yml` `env_file:` loads `postiz/.env` as container environment variables, which take precedence over dotenv files at runtime. Always update the host `.env` file and recreate the container.

## Known Issue: Cookie Domain on Tunnel

`.trycloudflare.com` is on the Public Suffix List. Browsers silently reject cookies set to public suffixes. Postiz sets cookie `Domain` from `MAIN_URL`, resulting in `Domain=.trycloudflare.com`.

**Fix**: Add `proxy_cookie_domain` to nginx config inside the container:

```nginx
# In /etc/nginx/nginx.conf, inside location /api/ block:
proxy_cookie_domain ~\.trycloudflare\.com$ <your-tunnel-subdomain>.trycloudflare.com;
```

Then reload: `docker exec postiz sh -c 'nginx -s reload'`

**WARNING**: This change is NOT persistent — lost on container recreation. TODO: Volume-mount a custom nginx.conf.

## Pinterest Video Demo Script

Record using Postiz UI at localhost:4007 (60-90 seconds):
1. Show Postiz dashboard (calendar, post creation)
2. Navigate to Channels -> Add Pinterest
3. Pinterest OAuth consent screen (show permissions)
4. Click Allow -> redirected back showing "Connected"
5. Create a post: select Pinterest, upload product image, add title/description
6. Show scheduling options and calendar view
7. Submit at developers.pinterest.com -> Request Standard Access
