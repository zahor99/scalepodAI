# Social Marketing Integration — Implementation Status

**Last updated**: 2026-03-02

## Overview

Two social marketing channels being integrated:
1. **Postiz** — Self-hosted social media scheduler (X/Twitter, Pinterest, Reddit, etc.)
2. **Pinterest API** — Direct OAuth integration in the Next.js dashboard

---

## 1. Postiz (X/Twitter posting) — WORKING

### Infrastructure
- **Docker**: 7 containers running at `http://localhost:4007` (`postiz/docker-compose.yml`)
- **Cloudflare Tunnel**: `cloudflared tunnel --url http://localhost:4007` (URL changes per restart)
- **Login**: `gergelyracz0@gmail.com`
- **Detailed setup**: `memory/postiz-integration.md`
- **Integration plan**: `docs/POSTIZ_INTEGRATION_PLAN.md`

### X/Twitter — Connected & Tested
- **Account**: @LunarAuraDesign
- **OAuth**: 1.0a (connected through Postiz UI via Cloudflare tunnel)
- **First tweet**: Luna Moth Celestial Garden Hoodie (2026-03-01, tweet ID: `2028154971129004439`)
- **Delayed reply**: Etsy link posted 1hr later (tweet ID: `2028171720008294669`)

### Known Postiz Bugs
| Bug | Impact | Workaround |
|-----|--------|------------|
| `v2.uploadMedia()` in XProvider | Image tweets fail on X Free tier | Post directly via X API using `v1.uploadMedia()` + `v2.tweet()` |
| `runInConcurrent()` error swallowing | Actual X API errors replaced with "Unknown Error" | Check X API directly for real errors |
| Cookie domain on tunnel | `.trycloudflare.com` is a public suffix, cookies rejected | Add `proxy_cookie_domain` in nginx (NOT persistent across container recreation) |

### X Free Tier Constraints
| Constraint | Detail |
|------------|--------|
| Character limit | 280 chars (403 Forbidden if exceeded) |
| Media upload | Must use `client.v1.uploadMedia()` (v2 fails) |
| Rate | 1,500 tweets/month, 300 per 3 hours |
| Credits | Must be enrolled in Free plan in X Developer Portal |

### Phase 1 Status
- [x] Postiz Docker running
- [x] Cloudflare Tunnel for HTTPS OAuth callbacks
- [x] X channel connected (@LunarAuraDesign)
- [x] First tweet with product image posted
- [x] Delayed reply pattern working (`postiz/delayed_reply.cjs`)
- [ ] Connect Pinterest channel (blocked — see below)
- [ ] Connect Reddit, Bluesky, Mastodon
- [ ] Fix Postiz X provider image upload (upstream issue)
- [ ] Volume-mount nginx.conf for persistent cookie domain fix

---

## 2. Pinterest OAuth (Dashboard) — BLOCKED

### Current Status: Redirect URI Mismatch

**Error**: "redirect uri is not registered in the app" when completing OAuth consent on Pinterest.

### What's Configured

| Setting | Value |
|---------|-------|
| Pinterest App ID | `1548553` |
| App name (portal) | ScalePOD AI |
| Access level | **Trial** (sandbox only) |
| Dashboard OAuth route | `GET /api/auth/pinterest` → redirects to Pinterest |
| Callback route | `GET /api/auth/pinterest/callback` → exchanges code for tokens |
| redirect_uri sent in OAuth | `http://localhost:3000/api/auth/pinterest/callback` |

### What Needs to Happen

1. **Add redirect URI in Pinterest Developer Portal**:
   - Go to https://developers.pinterest.com/apps/ → ScalePOD AI → Settings
   - Add **exactly**: `http://localhost:3000/api/auth/pinterest/callback`
   - (The Vercel URL was previously set but localhost was removed or never re-added)

2. **After connecting, record video demo for Standard access**:
   - Open `http://localhost:3000/content/settings`
   - Click "Connect Pinterest" → authorize → show connected state
   - Show board selection dropdown
   - Submit video at developers.pinterest.com → Request Standard Access

3. **Standard access required for**:
   - Publishing pins visible to the public (Trial = sandbox only, pins invisible)
   - Token exchange may also be restricted on Trial (code 29 seen in Postiz flow)

### Dashboard Files
| File | Purpose |
|------|---------|
| `dashboard/src/lib/pinterest.ts` | OAuth helpers: buildAuthorizeUrl, exchangeCodeForToken, refreshAccessToken, fetchPinterestUser, fetchPinterestBoards |
| `dashboard/src/app/api/auth/pinterest/route.ts` | OAuth initiation — sets CSRF state cookie, redirects to Pinterest |
| `dashboard/src/app/api/auth/pinterest/callback/route.ts` | OAuth callback — validates state, exchanges code for tokens, stores in Supabase `user_preferences` |
| `dashboard/src/app/api/auth/pinterest/boards/route.ts` | Returns authenticated user's Pinterest boards |
| `dashboard/src/app/content/settings/content-settings-form.tsx` | Pinterest connect/disconnect UI + board selector |

### Token Storage (Supabase)
- Table: `user_preferences`
- Path: `style_preferences.content_config.pinterest`
- Fields: `access_token`, `refresh_token`, `expires_at`, `username`, `connected`, `selected_board_id`

### Env Vars Required
```
# dashboard/.env.local
PINTEREST_APP_ID=1548553
PINTEREST_APP_SECRET=c1dd56f05877e2530a864e423a6d9459f77eb38a
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## 3. Vercel Deployment — PARTIALLY WORKING

### Status
- **URL**: `https://dashboard-xi-snowy.vercel.app`
- **Project**: linked in `dashboard/.vercel/project.json` (ID: `prj_8YFiVJgZxk86FK4ensFXfwGCZqDi`)
- **Issue**: Environment variables not set → Pinterest OAuth shows `client_id=undefined`

### Env Vars Needed on Vercel (Production)
| Variable | Value |
|----------|-------|
| `NEXT_PUBLIC_SUPABASE_URL` | `https://jtptaswggfdgzmuifnzi.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (from `.env.local`) |
| `NEXT_PUBLIC_APP_URL` | `https://dashboard-xi-snowy.vercel.app` |
| `PINTEREST_APP_ID` | `1548553` |
| `PINTEREST_APP_SECRET` | `c1dd56f05877e2530a864e423a6d9459f77eb38a` |

### Vercel Token Issue
- Token `vck_6SzUB3Q...` has **limited scope** — can read user info but NOT access projects/deployments/env vars
- Need either: (a) generate "Full Account" scope token at vercel.com/account/tokens, or (b) `vercel login` interactively

### After Setting Env Vars
Must trigger a **full redeploy** (not cached) since `NEXT_PUBLIC_*` vars are baked at build time:
- Vercel Dashboard → Deployments → latest → ⋮ menu → Redeploy → **uncheck** "Use existing Build Cache"

Also update Pinterest portal redirect URI to include the Vercel URL:
- `https://dashboard-xi-snowy.vercel.app/api/auth/pinterest/callback`

---

## 4. Next Steps (Priority Order)

1. **Fix Pinterest redirect URI** — Add `http://localhost:3000/api/auth/pinterest/callback` in Pinterest Developer Portal
2. **Test Pinterest OAuth locally** — Connect Pinterest, verify token storage in Supabase
3. **Record video demo** — Show OAuth flow for Standard access application
4. **Submit Standard access application** — At developers.pinterest.com
5. **Fix Vercel env vars** — Either via new full-scope token or Vercel dashboard UI
6. **Connect remaining Postiz channels** — Reddit, Bluesky, Mastodon
7. **Build AI agent relay** — `prototype/tools/publish_social_content.py` (Phase 2)

---

## Architecture Reference

```
ScalePod Dashboard (localhost:3000 / Vercel)
    ├── Content Settings → Pinterest OAuth → stores tokens in Supabase
    ├── Future: "Push to Marketing" → Postiz API → schedules cross-platform posts
    └── Future: Pull analytics from Postiz API → display in dashboard

Postiz (localhost:4007 via Docker)
    ├── X/Twitter → @LunarAuraDesign (connected, posting works)
    ├── Pinterest → (blocked on redirect URI + Trial access)
    ├── Reddit, Bluesky, Mastodon → (not yet connected)
    └── Public API → POST /posts, GET /analytics (for AI agent relay)

Pinterest Direct (dashboard OAuth)
    ├── Trial access → sandbox only (pins invisible)
    ├── Standard access → pending video demo
    └── Redirect URI: http://localhost:3000/api/auth/pinterest/callback
```
