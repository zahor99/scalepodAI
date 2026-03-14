# Content Automation System — Remaining Work

> Last updated: 2026-03-04
> Phase 1 (Minimum Viable Publishing) is COMPLETE and E2E VERIFIED.
> This document tracks everything still needed for Phases 2–5.

---

## Status Summary

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1: MVP Publishing | **DONE + VERIFIED** | Full E2E: seed → generate → publish via Postiz → live on Twitter |
| Phase 2: ICP + Playbooks + Scheduler | **PARTIAL** | Migration + scheduler code done, dashboard UI NOT done |
| Phase 3: Advanced Content Types | NOT STARTED | Threads, articles, video pins, metrics |
| Phase 4: Full Automation + ScalePOD | NOT STARTED | Cron, ScalePOD Twitter, repurposing, Pinterest Standard |
| Phase 5: OpenClaw Agents | NOT STARTED | OpenClaw CLI installed (v2026.2.17), no Docker/skills/config |

---

## Phase 1: DONE + E2E VERIFIED ✓

Files created/modified — see `memory/content-automation.md` for full inventory.

### What's Working (verified 2026-03-04)
- [x] **Postiz client** (`postiz_client.py`) — API v1 wrapper with correct nested payload format
- [x] **Tweet generator** (`tweet_generator.py`) — PIL 16:9 crop with vignette + watermark
- [x] **Copy generator** (`copy_generator.py`) — Gemini 2.5 Pro generates witty 280-char tweets
- [x] **Distributor** (`distributor.py`) — uploads media, creates Postiz post, logs to content_publish_log
- [x] **Pipeline adapter** (`pipeline_adapter.py`) — routes `content_type=tweet`, handles HTTP URLs, uploads to Supabase Storage
- [x] **Worker** (`worker.py`) — distribution polling block picks up `status=ready` items
- [x] **Seed tool** (`tools/seed_pipeline_content.py`) — creates pending content_items from products with listing images
- [x] **Playbooks migration** applied to cloud Supabase (9 seed playbooks)
- [x] **POSTIZ_API_KEY** configured in `prototype/.env`
- [x] **Twitter integration** active: @LunarAuraDesign via Postiz (integration ID: `cmm7wf6bo0001p38fff0zg1kn`)

### First Successful Publish
- **TWEET-001**: Samurai Dragon Hoodie → published to @LunarAuraDesign
- Postiz post ID: `cmmbhgnir0004qm8ic0ld6ntl`
- Generated copy: "My tarot cards told me to embrace my inner warrior..." (170 chars + 2 hashtags)
- Image: 1200x675 cropped from listing mockup with vignette effect

### Bugs Fixed During E2E (2026-03-04)
1. **pipeline_adapter.py**: Added HTTP URL download for source images (Google Drive URLs)
2. **pipeline_adapter.py**: Bypass `STORAGE_BACKEND=gdrive` for content-pins — Postiz needs Supabase Storage URL
3. **postiz_client.py**: Corrected `create_post()` payload — Postiz requires nested `integration.id`, `value[]` array, full media objects in `image`, and mandatory `date`/`shortLink`/`tags` fields
4. **distributor.py**: Pass full media upload result objects (not just string IDs) in image array
5. **seed_pipeline_content.py**: Handle `image_urls` as dict `{artwork, listing, thumbnail}` not array
6. **prototype/.env**: Fixed SUPABASE_URL/KEY to point to cloud (was dead local instance)
7. **postiz_client.py**: Twitter integration uses `"x"` as providerIdentifier (alias map added)

### How to Run (E2E test)
```bash
cd prototype

# 1. Seed tweet content items
python tools/seed_pipeline_content.py --count 2 --platform twitter

# 2. Run worker (generates copy+image, then publishes via Postiz)
python worker.py

# 3. Or test manually step by step:
python -c "
from dotenv import load_dotenv; load_dotenv('.env')
from supabase_client import get_client
from pipeline_adapter import run_content_generation
from content_producer.postiz_client import PostizClient
from content_producer.distributor import publish_content_item

client = get_client()
item = client.table('content_items').select('*').eq('status', 'pending').limit(1).single().execute().data
client.table('content_items').update({'status': 'generating', 'worker_claimed_at': 'now()'}).eq('id', item['id']).execute()
run_content_generation(client, item)  # pending -> ready

item = client.table('content_items').select('*').eq('id', item['id']).single().execute().data
postiz = PostizClient()
publish_content_item(client, postiz, item)  # ready -> published
"
```

---

## Phase 2: ICP + Playbooks + Scheduler (PARTIAL)

### Done ✓
- [x] `content_playbooks` table migration with 9 seed playbooks (applied to cloud Supabase)
- [x] `content_items` columns: `playbook_id`, `content_pillar`
- [x] `scheduler.py` — ICP-aware batch scheduling with product rotation
- [x] CLI entry: `python -m content_producer.scheduler --days 7`

### Remaining
- [ ] **Dashboard: Playbooks tab** — `dashboard/src/app/content/playbooks/page.tsx`
  - Card grid showing all playbooks with name, platform icon, pillar badge, frequency
  - Active/inactive toggle per playbook
  - Edit playbook: copy_prompts, product_filter, frequency, best_times
  - Add new playbook form
- [ ] **Dashboard: Content tab nav** — Add "Playbooks" tab to `dashboard/src/app/content/content-tab-nav.tsx`
- [ ] **Dashboard: ICP Editor** — Extend `content-settings-form.tsx`:
  - Brand voice textarea
  - Target audience fields (demographics, psychographics, interests)
  - Platform tones (voice, max chars per platform)
  - Content mix sliders (5 pillars, must sum to 100%)
  - Save to `user_preferences.style_preferences.content_config.icp`
- [ ] **Dashboard: Content Calendar** — `dashboard/src/app/content/calendar/page.tsx`
  - Week view showing scheduled content_items
  - Drag to reschedule
  - Click to preview generated content

---

## Phase 3: Advanced Content Types

### 3.1 Thread Generator
- [ ] **Extend** `tweet_generator.py` with `generate_thread(product, playbook, icp) -> list[dict]`
- [ ] 3-5 tweet thread with per-tweet prompts from playbook.copy_prompts (hook, body, reveal, CTA)
- [ ] Store thread tweets in `generated_assets.thread_tweets` (jsonb array)
- [ ] Update `pipeline_adapter.py` to route `content_type='thread'`
- [ ] Update `distributor.py` to publish threads (multiple sequential Postiz posts)

### 3.2 Article Generator + ScalePOD.ai Blog
- [ ] **New file**: `content_producer/article_generator.py`
  - `generate_article(products, playbook, icp) -> dict` (title, subtitle, body_markdown, tags, hero_image)
  - Article types: style guide, gift guide, behind-the-design, AI process showcase
- [ ] **New file**: `content_producer/github_pages_publisher.py`
  - Auto-generates Markdown with front-matter → git add/commit/push to ScalePOD.ai repo
  - Hero image copy to assets directory
- [ ] **Medium publishing** via Postiz (already has Medium integration capability)

### 3.3 Video Pins (Front+Back Reveal)
- [ ] **Extend** `video_pins.py` with `generate_product_reveal_video(front_image, back_image) -> Path`
- [ ] GoAPI Kling (~$0.13/video) or kie.ai video
- [ ] 6-15 seconds: front reveal → rotate → back reveal
- [ ] 2:3 for Pinterest, 9:16 for TikTok/Reels

### 3.4 Metrics Worker
- [ ] **Extend** `worker.py` — new polling block every 6 hours:
  - Query `content_items WHERE status=published AND metrics_updated_at < now() - 6h`
  - Call `postiz.get_analytics(platform_post_id)` per item
  - Update `impressions`, `clicks`, `saves`, `video_views`, `metrics_updated_at`

### 3.5 Dashboard Analytics
- [ ] **Modify** `dashboard/src/app/content/[id]/content-detail.tsx` — metrics cards + refresh button
- [ ] **New** `dashboard/src/app/api/content/metrics/route.ts` — trigger metric refresh

---

## Phase 4: Full Automation + ScalePOD Presence

### 4.1 Cron-based Scheduling
- [ ] Daily cron job (could be Supabase Edge Function or system cron) calls `schedule_content_batch(days_ahead=7)`
- [ ] Idempotent: skip if items already scheduled for that day

### 4.2 ScalePOD Twitter (@ScalePOD)
- [ ] Create Twitter account @ScalePOD
- [ ] Connect to Postiz as second integration
- [ ] Create separate playbooks with SaaS-focused ICP:
  - ICP: POD sellers, Etsy entrepreneurs (NOT end consumers)
  - Content: SaaS demos, design showcases ("made with ScalePOD"), POD seller tips
- [ ] Separate content_mix ratios from LunarAura account

### 4.3 Content Repurposing
- [ ] Auto-create Pinterest pins from published tweet images (crop 16:9 → 2:3 + add title overlay)
- [ ] Auto-create tweets from published pin images (crop 2:3 → 16:9)
- [ ] Track `source_content_item_id` to avoid infinite loops

### 4.4 Pinterest Standard Access
- [ ] Record video demo of OAuth flow (Settings → Connect → Authorize → Connected state)
- [ ] Submit application to Pinterest for Standard access
- [ ] Switch from sandbox (pins invisible) to production publishing
- [ ] Verify via `publisher.py` or via Postiz Pinterest integration

---

## Phase 5: OpenClaw Autonomous Optimization Agents

### Current State
- **OpenClaw CLI**: Installed globally, `v2026.2.17` (via npm)
- **OpenClaw Docker**: NOT set up — no containers, no docker-compose, no skills directory
- **OpenClaw onboarding**: NOT run (`openclaw onboard` never executed)
- **Reference**: [Docker install docs](https://docs.openclaw.ai/install/docker), [GitHub](https://github.com/openclaw/openclaw)

### 5.1 Infrastructure Setup
- [ ] Run `openclaw onboard` to initialize gateway + workspace
- [ ] Create `openclaw/` directory in project root
- [ ] Create `openclaw/docker-compose.yml`:
  ```yaml
  services:
    openclaw-marketing:
      image: openclaw/openclaw:latest
      read_only: true
      cap_drop: [ALL]
      environment:
        - SUPABASE_URL=${SUPABASE_URL}
        - SUPABASE_KEY=${SUPABASE_SERVICE_KEY_READONLY}
        - POSTIZ_API_URL=http://postiz:4007/api/public/v1
        - POSTIZ_API_KEY=${POSTIZ_API_KEY}
      volumes:
        - ./skills:/app/skills:ro
      networks:
        - openclaw-net
        - postiz_default
  ```
- [ ] Create read-only Supabase role for agents (see migration below)
- [ ] Test basic connectivity: agent can read products but cannot write

### 5.2 Database: Read-Only Role + Suggestions Table
- [ ] **Migration**: `supabase/migrations/20260305000001_openclaw_support.sql`
  ```sql
  CREATE ROLE openclaw_reader WITH LOGIN PASSWORD 'openclaw_readonly';
  GRANT USAGE ON SCHEMA public TO openclaw_reader;
  GRANT SELECT ON products, content_items, content_publish_log,
    content_templates, content_playbooks, supplier_products,
    niche_guides, user_preferences TO openclaw_reader;

  CREATE TABLE optimization_suggestions (
      id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      agent_type      text NOT NULL,
      target_table    text NOT NULL,
      target_id       uuid NOT NULL,
      suggestion_type text NOT NULL,
      current_value   jsonb,
      suggested_value jsonb NOT NULL,
      reasoning       text NOT NULL,
      confidence      float CHECK (confidence BETWEEN 0 AND 1),
      status          text DEFAULT 'pending',
      created_at      timestamptz DEFAULT now(),
      reviewed_at     timestamptz
  );
  ```

### 5.3 Custom OpenClaw Skills (3 agents)

#### Marketing Agent — `openclaw/skills/pod-marketing/SKILL.md`
- [ ] Read products + content_items from Supabase
- [ ] Analyze published content performance (impressions, clicks, saves)
- [ ] Generate new content items via Postiz API based on what's performing
- [ ] Adapt posting schedule based on engagement patterns
- [ ] KPI targets: Pinterest saves/pin > 5, Twitter impressions/tweet > 500

#### Analytics Agent — `openclaw/skills/pod-analytics/SKILL.md`
- [ ] Pull metrics from `content_publish_log` + Postiz analytics
- [ ] Identify top-performing niches, content pillars, posting times
- [ ] Generate weekly reports with recommendations
- [ ] Write strategy adjustment suggestions to `optimization_suggestions`

#### Listing Optimizer — `openclaw/skills/etsy-optimizer/SKILL.md`
- [ ] Read product titles, tags, descriptions from Supabase
- [ ] Compare against keyword research (niche guides)
- [ ] Suggest tag replacements, title rewrites, description improvements
- [ ] Write suggestions to `optimization_suggestions` (human reviews before applying)
- [ ] Track which changes improved views/favorites after approval

### 5.4 Dashboard: Suggestions Review UI
- [ ] **New page**: `dashboard/src/app/content/suggestions/page.tsx`
  - Card list of pending suggestions from `optimization_suggestions`
  - Current vs suggested values side-by-side
  - Approve/Reject buttons
  - Filter by agent_type, suggestion_type, confidence
- [ ] **API route**: `dashboard/src/app/api/suggestions/[id]/route.ts`
  - PATCH to approve/reject
  - On approve: update target table with suggested_value

### 5.5 Feedback Loop
```
Marketing Agent → creates posts via Postiz → waits 24-48h → pulls metrics
  → identifies winning patterns → adjusts content mix → writes to optimization_suggestions
  → human approves → feeds back into playbooks

Analytics Agent (weekly) → aggregates all metrics → generates report
  → flags underperforming pillars → specific action items

Listing Optimizer (daily) → reads Etsy data + keyword trends
  → suggests tag/title/description changes → tracks impact after approval
```

---

## Postiz API Reference (learned from E2E testing)

### Authentication
- Header: `Authorization: <api-key>` (NO Bearer prefix)
- API key from: Postiz DB `Organization.apiKey` or Postiz UI Settings

### POST /api/public/v1/posts (Create Post)
```json
{
  "posts": [{
    "integration": {"id": "<postiz-integration-id>"},
    "value": [{
      "content": "Tweet text here",
      "image": [{"id": "...", "path": "https://...", "name": "..."}]
    }],
    "settings": {"who_can_reply_post": "everyone"}
  }],
  "type": "now",
  "date": "2026-03-04T00:00:00Z",
  "shortLink": false,
  "tags": []
}
```

**Critical format notes:**
- `integration` is a nested object `{id: "..."}`, NOT flat `integration_id`
- `value` is an array of content objects, NOT flat `content`
- `image` array elements must be full media objects from `/upload-from-url`, NOT just IDs
- `date`, `shortLink`, `tags` are ALL required even for `type: "now"`
- Twitter integration uses `"x"` as `providerIdentifier` (not `"twitter"`)

### POST /api/public/v1/upload-from-url (Upload Media)
```json
{"url": "https://example.com/image.png"}
```
Returns: `{id, name, path, thumbnail, alt}` — pass full object to `image[]` in posts.

---

## Content Strategy Reference (for implementation)

### Platform Cadence
| Platform | Frequency | Best Times | Content Types |
|----------|-----------|------------|---------------|
| Pinterest | 5-8 pins/day | 8-11 PM, weekends | Product pins, lifestyle, video reveals |
| Twitter | 1-2 tweets/day | Varies | Product drops, threads, polls |
| Medium | 1-2 articles/month | N/A | Style guides, niche explainers, gift guides |

### Content Mix (80/20 Rule)
| Pillar | % | Examples |
|--------|---|---------|
| Product & Drops | 20% | New design reveals, product close-ups, video try-ons |
| Aesthetic & Inspiration | 25% | Mood boards, color palettes, outfit ideas |
| Behind the Design | 20% | AI art process, design threads, sketch-to-product |
| Education & Value | 20% | "What is whimsigoth?", style guides, care tips |
| Community | 15% | Polls, questions, customer spotlights |

### Seasonal Hooks (Whimsigoth Calendar)
- **Samhain/Halloween** (Oct 31): Peak — dark aesthetic + hoodie season
- **Yule/Winter Solstice** (Dec 21): Gift guide season, cozy content
- **Imbolc** (Feb 1): Spring transition, new collection teasers
- **Beltane** (May 1): Floral/botanical, lighter layers
- **Litha** (Jun 21): Summer tees, outdoor lifestyle
- **Mabon** (Sep 22): Fall preview, hoodie season kickoff

---

## Quick Reference: What to Do Next

### Short-term (Phase 2 completion)
1. Build Playbooks dashboard tab
2. Build ICP editor in content settings
3. Build content calendar view

### Medium-term (Phase 3-4)
4. Thread generator + distributor support
5. Article generator + GitHub Pages publisher
6. Metrics polling in worker
7. Pinterest Standard access (record video, submit)
8. ScalePOD Twitter account + playbooks

### Long-term (Phase 5)
9. Run `openclaw onboard` + set up Docker
10. Write 3 SKILL.md files
11. Create optimization_suggestions table
12. Build suggestions review UI
13. Deploy feedback loop
