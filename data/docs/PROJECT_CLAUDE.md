# POD Automation System - Etsy Seller Platform

## CRITICAL RULES (HIGH IMPORTANCE)
- **ALWAYS KEEP SUPABASE IN SYNC**: Every product creation, update, or batch operation MUST write to the Supabase `products` table — not just local files. The Kanban board and dashboard read exclusively from Supabase. If a CLI script or batch tool creates/modifies products in `output/director/`, it MUST also create/update the corresponding row in Supabase.
- **Sync tool**: `prototype/tools/sync_to_supabase.py` — run after any batch operation that creates products locally without Supabase writes
- **No orphaned products**: Never leave products only in `output/director/` without a corresponding Supabase row
- **Publishing flow**: `draft` → user clicks "Approve" on Kanban → `approved` → DB trigger fires Edge Function → Printify publish → `published`

## Project Overview
AI-powered Print-on-Demand automation system that manages the product lifecycle from design concept to published Etsy listing. Python prototype pipeline (Design Director + Gemini AI) with a Next.js dashboard and Supabase backend for product management and approval gates.

**Shop name:** LunarAuraDesignStore
**Status:** 96 products on Printify (25 hoodies + 25 sweatshirts + 25 tees + extras), 70+ with listing images
**Current focus:** Sync all products to Supabase Kanban, publish approved designs to Etsy
**Target:** Personal use first, then SaaS for Etsy sellers
**ICP:** Women 22-34, whimsigoth/dark cottagecore/boho goth aesthetic

## Technology Stack

| Layer | Technology |
|-------|-----------|
| **Prototype Pipeline** | Python 3 (PIL, requests, google-generativeai, supabase-py) |
| **Image Generation** | Google Gemini 2.0 Flash (artwork) + Gemini multi-reference compositing (mockups) |
| **AI Content** | Kimi K2.5 (copy writing: titles, descriptions, tags) |
| **POD Platform** | Printify API (Blueprint 450 AOP Hoodie + Blueprint 12 Bella+Canvas 3001 Tee + Blueprint 162 Gildan 18000 Crew) |
| **Sales Channel** | Etsy (via Printify publishing) |
| **Marketing** | Pinterest API v5 (OAuth 2.0, pin publishing — Standard access pending) |
| **Frontend** | Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS v4, shadcn/ui |
| **Backend** | Supabase Local (PostgreSQL, Storage, Realtime) |
| **Worker** | Python polling loop (`worker.py`) — bridges dashboard to existing pipeline |

## Working Prototype Pipeline

```
Design Brief (theme + niche)
    ↓
Design Director (director.py) — Claude generates DesignPlan with per-area prompts
    ↓
Gemini 2.0 Flash — Generates artwork for each AOP area (front, back, right_sleeve)
    ↓
Asset Pipeline — Resize, mirror sleeves, crop hood/pocket from parent panels
    ↓
Copy Writer (Claude) — SEO title, description, 13 Etsy tags
    ↓
Pricing Calculator — Niche-based pricing with perpetual 50% sale strategy
    ↓
Printify Uploader — Upload artwork to print areas, create product, publish
    ↓
Image Producer — 10-slot listing image set (mockups, closeups, gift scenes)
    ↓
Output Package — result.json + copy.json + all artwork + listing images
```

### Key Files

| File | Purpose |
|------|---------|
| `prototype/worker.py` | **Worker** — polls Supabase, routes products to pipeline stages |
| `prototype/pipeline_adapter.py` | **Adapter** — bridges worker to existing pipeline functions |
| `prototype/supabase_client.py` | **DB client** — Supabase wrapper (fetch, claim, update, log, upload) |
| `prototype/8_design_director_pipeline.py` | CLI orchestrator (standalone, also imported by adapter) |
| `prototype/design_director/director.py` | Design Director — LLM-powered prompt planning per AOP area |
| `prototype/design_director/models.py` | Data models (DesignBrief, DesignPlan, AreaPrompt, ProductRules, etc.) |
| `prototype/rules/aop_hoodie.yaml` | Product rules — print dimensions, composition guidance, coherence rules |
| `prototype/asset_pipeline/uploader.py` | Printify API integration — upload artwork, create/publish product |
| `prototype/image_producer/producer.py` | Listing image generator (10-slot system) |
| `prototype/image_producer/aop_templates.py` | AOP mockup template system (10 Gemini prompts T1-T9+T5B) |
| `prototype/niche_guides/*.yaml` | Per-niche style guides (japanese_art, celestial_boho, mushroom_cottagecore, etc.) |

### AOP Areas (7 print zones per hoodie)

| Area | Generation | Dimensions | Notes |
|------|-----------|------------|-------|
| front | Gemini (hero scene) | 4500×5400 | Main focal design |
| back | Gemini (complementary) | 4500×5400 | Hood panels cropped from upper half |
| right_sleeve | Gemini (accent pattern) | 3700×3620 | Edge-to-edge textile swatch |
| left_sleeve | Mirror of right_sleeve | 3700×3620 | Horizontal flip |
| right_hood | Crop from back | 2500×3000 | Upper portion of back panel |
| left_hood | Mirror of right_hood | 2500×3000 | Horizontal flip |
| pocket | Crop from front | 2830×1510 | Lower-center of front panel |

### AOP Mockup Template System (10 slots)

| Template | Type | Description |
|----------|------|-------------|
| T1 | Ghost mannequin front | Dark black bg, hood down |
| T2 | Ghost mannequin back | Dark black bg, hood down |
| T3 | Ghost mannequin front | Dark black bg, hood UP (dramatic) |
| T4 | Ghost mannequin back | Dark black bg, hood UP (dramatic) |
| T5 | On-model lifestyle front | Editorial, outdoor/studio setting |
| T5B | On-model lifestyle back | Editorial, outdoor/studio setting |
| T6 | Fabric texture close-up | Macro detail of print quality |
| T7 | Folded & styled | Gift-ready presentation |
| T8 | Sleeve/hood detail | Print continuity across seams |
| T9 | On-model close-up | Chest-up, print quality focus |

Spec: `prototype/AOP_MOCKUP_TEMPLATES_SPEC.md`
Competitive research basis: QMLDesignLab, ForestFablesShop, CulturalThemesStudio (all top AOP sellers on Etsy)

### Listing Image Platform Support (Etsy vs Shopify)

The compositing pipeline supports two platform modes via `platform` parameter:

**Usage:**
```python
produce_aop_composited_images(..., platform="etsy")   # default
produce_aop_composited_images(..., platform="shopify")
```

**CLI:** `python tools/listing_ruffle_bf05.py --platform shopify`

**Worker:** Reads from `product.sales_channel` → env `LISTING_PLATFORM` → defaults `"etsy"`.

| Aspect | Etsy | Shopify / Google Shopping |
|--------|------|--------------------------|
| Slot source | `COMPOSITING_SLOTS_BY_TYPE` | `_SHOPIFY_DRESS_SLOTS` |
| Primary image | Ghost mannequin or on-model | On-model front, white bg (Google Merchant req) |
| Infographics | size_chart + trust_badge appended | NONE (text overlays violate Google policy) |
| Dress slots | 7 composited + 2 infographics = 9 | 7 composited = 7 |
| Hoodie/tee slots | Same for both platforms (8+2=10) | Falls back to Etsy slots |

**Shopify dress slot lineup** (optimized from Google Shopping competitive analysis):

| Slot | Type | Why |
|------|------|-----|
| 01_model_front | On-model front, white bg | Google Shopping primary — industry standard for dresses |
| 02_model_back | On-model back, white bg | Shows full back design |
| 03_model_angle | 3/4 angle, gray bg | Shows drape and movement |
| 04_lifestyle | Editorial scene | Social ads + Shopify hero |
| 05_detail_closeup | Fabric macro (PIL, no API) | Print quality proof |
| 06_model_midsize | Mid-size model, white bg | Size inclusivity, builds trust |
| 07_flat_lay | Top-down on marble | Gift appeal, Pinterest sharing |

**Key files:**
- `prototype/image_producer/aop_compositing.py` — slot definitions + `_build_shopify_dress_slots()` factory
- `prototype/pipeline_adapter.py` — platform routing in `run_production_stage()`
- `prototype/tools/listing_ruffle_bf05.py` — example CLI with `--platform` flag

**White base naming convention:**
- Etsy: `base_dr_{prefix}_{slot}.png` (e.g. `base_dr_ruffle_ghost.png`)
- Shopify: `base_dr_{prefix}_shop_{slot}.png` (e.g. `base_dr_ruffle_shop_front.png`)

**Research basis:** `docs/GOOGLE_SHOPPING_VIABILITY_ASSESSMENT.md` — visual analysis of Google Shopping SERPs confirmed on-model shots on white/gray bg are the standard for women's dresses (NOT ghost mannequin).

## Dashboard + Worker Architecture

### 3-Stage Pipeline with 2 Approval Gates

```
Stage 1: IDEATION (free — only LLM call)
  pending → planning → plan_ready  [GATE 1: User approves design concept]

Stage 2: ASSET GENERATION (costs Gemini credits)
  concept_approved → generating → uploading → mockups_ready  [GATE 2: User reviews mockups]

Stage 3: PRODUCTIZATION (costs Gemini + LLM)
  production_approved → copy_pricing → listing_images → draft → published
```

**Worker pattern:** Frontend writes to Supabase → Python worker polls and processes → Supabase Realtime pushes live updates to UI.

### Dashboard Files (`dashboard/`)

| File | Purpose |
|------|---------|
| `src/app/products/page.tsx` | Product list with 8 status filter tabs |
| `src/app/products/new/page.tsx` | Create product form (theme, product type, niche, style hint) |
| `src/app/products/[id]/page.tsx` | Product detail with Gate 1 + Gate 2 approval UI |
| `src/components/plan-viewer.tsx` | Design plan display (palette swatches, area prompts, rationale) |
| `src/components/pipeline-progress.tsx` | 3-stage progress indicator + real-time activity log |
| `src/components/artwork-gallery.tsx` | Image grid for artwork and mockups |
| `src/hooks/use-realtime-product.ts` | Product UPDATE subscription via Supabase Realtime |
| `src/hooks/use-realtime-logs.ts` | Workflow log INSERT subscription for live progress |
| `src/lib/supabase/client.ts` | Browser Supabase client |
| `src/lib/supabase/server.ts` | Server Supabase client (SSR) |
| `src/lib/pinterest.ts` | Pinterest OAuth helpers (authorize URL, token exchange, refresh, user/boards fetch) |
| `src/app/api/auth/pinterest/route.ts` | OAuth initiation — sets CSRF state cookie, redirects to Pinterest |
| `src/app/api/auth/pinterest/callback/route.ts` | OAuth callback — validates state, exchanges code for tokens, stores in Supabase |
| `src/app/api/auth/pinterest/boards/route.ts` | Returns authenticated user's Pinterest boards |
| `src/app/content/settings/content-settings-form.tsx` | Content settings with Pinterest connect/disconnect UI + board selector |

### Worker Files (`prototype/`)

| File | Purpose |
|------|---------|
| `worker.py` | Polling loop (10s), 3-stage routing, atomic claims, graceful shutdown |
| `pipeline_adapter.py` | `run_plan_stage()`, `run_asset_stage()`, `run_production_stage()` |
| `supabase_client.py` | `fetch_pending_products()`, `claim_product()`, `update_status()`, `log_progress()` |

### Database Migrations (`supabase/migrations/`)

| Migration | Purpose |
|-----------|---------|
| `20260215000001_initial_schema.sql` | 9 core tables (products, supplier_products, niche_guides, etc.) |
| `20260215000002_schema_fixes.sql` | FK changes, index additions |
| `20260215000003_allow_null_product_id_in_logs.sql` | Nullable product_id in workflow_logs |
| `20260216000001_shops_and_worker_support.sql` | Shops table, worker columns, 13-status enum, storage buckets |

### Local Dev URLs

| Service | URL |
|---------|-----|
| Dashboard | http://localhost:3000 |
| Supabase Studio | http://127.0.0.1:54323 |
| Supabase API | http://127.0.0.1:54321 |

### How to Run

```bash
# Terminal 1: Start Supabase (if not running)
supabase start

# Terminal 2: Reset DB + apply migrations + seeds
supabase db reset

# Terminal 3: Start dashboard
cd dashboard && npm run dev

# Terminal 4: Start worker (requires API keys in prototype/.env)
cd prototype && python worker.py
```

## Products Generated (as of Feb 22, 2026)

**Total on Printify:** 25 products (16 listing-ready, 9 in progress)
**Verified Winners:** 11 products visually confirmed as launch-worthy
**Pricing:** $149.98 listed / $74.99 sale (50% perpetual sale) — market-validated against top AOP sellers

### Supplier Details
- **Blueprint:** 450 AOP Unisex Pullover Hoodie
- **Provider:** MWW On Demand (Provider ID 10) — ONLY provider for BP450
- **Cost:** $44.25 (S-XL), $49.89 (2XL+)
- **Fabric:** 86% polyester / 14% cotton blend
- **Pricing:** $149.98 listed / $74.99 sale (50% perpetual sale)
- **Net Profit:** ~$22.07/unit after Etsy fees (29.4% margin)

### Known Issue: Stale Product IDs
8 of 11 winner directories were deleted during batch redesigns. `launch_winners.py` has STALE Printify product IDs. Must retrieve current IDs from Printify before launching.

Full inventory & launch plan: `research/product-launch-plan-2026-02-22.md`

## Known Bugs

### CRITICAL: Sleeve Artwork Not Filling Printify Panel Templates
**File:** `prototype/BUG_SLEEVE_SIZING.md`
**Status:** Open — root cause confirmed, fix documented
**Root cause:** Gemini draws garment shapes (trapezoid silhouettes, arm shapes, full hoodie mockups) inside the image instead of flat edge-to-edge textile swatches. The YAML guidance in `rules/aop_hoodie.yaml` lines 106-136 describes the garment panel shape too explicitly, and Gemini interprets it literally.
**Fix approach:**
- Part A: Simplify sleeve composition guidance to "flat textile swatch" language, remove all garment shape references
- Part B: Add edge-fill validation post-processing as safety net

### Slot 08 Back View Shows Raw Artwork
**Status:** Open — known limitation of current producer.py
**Issue:** Listing image slot 08 (back_view) displays the raw back artwork PNG instead of a product mockup. Will be resolved when T2 ghost mannequin template is integrated into producer.py.

### Fixed Bugs
| Bug | Status | Fixed In |
|-----|--------|----------|
| C1: Tag truncation at 20 chars mid-word | Fixed | Batch 2 |
| C3: Printify title not updated with listing_title | Fixed | Batch 2 |

## Multi-Tier Listing Strategy

Each design = ONE Etsy listing with 3 product tiers as variants (ISHIRTLAB model):

| Tier | Product | Blank | Printify Cost | Sale Price | Margin | Purpose |
|------|---------|-------|---------------|-----------|--------|---------|
| Entry | Unisex T-Shirt | Bella+Canvas 3001 | ~$9-12 | $24.99 | ~45-50% | Impulse buy, first reviews |
| Mid | Crewneck Sweatshirt | Gildan 18000 | ~$13.20 | $39.99 | ~50-55% | Sweet spot, upgrade path |
| Premium | AOP Hoodie | MWW On Demand (BP 450) | ~$35.10 | $69.99-79.99 | ~50-55% | Brand differentiator, margin maximizer |

- Perpetual 50% sale on all tiers (listed at 2× sale price)
- AOP images are the hero (sell all tiers), t-shirt captures impulse buyers
- ~56 SKUs per listing (25 tee + 25 crew + 6 AOP)
- Full strategy: `research/multi-tier-listing-strategy-2026-02-16.md`

### NEW: All-AOP 3-Tier Strategy (Feb 22, 2026)

Replacing DTG tee/crew with AOP equivalents — same artwork reuses perfectly:

| Tier | Product | Blueprint | Cost (M) | Sale Price | Profit | Margin |
|------|---------|-----------|----------|-----------|--------|--------|
| Entry | AOP Tee | BP 1242 (Miami Sublimation, FL) | $19.54 | $39.99 | $16.20 | 40.5% |
| Mid | AOP Sweatshirt | BP 449 (MWW On Demand, NC) | $29.31 | $59.99 | $24.53 | 40.9% |
| Premium | AOP Hoodie | BP 450 (MWW On Demand, NC) | $45.35 | $74.99 | $22.07 | 29.4% |

Key: All 3 tiers are full AOP (not DTG). Zero additional artwork needed. Buyer pays shipping ($6-9).
Full size-dependent costs: `memory/research/printify-suppliers.md`

## Key Market Research Findings

- Top POD opportunity: graphic hoodie (49.5K monthly search volume)
- Best niches: Japanese Art, Celestial/Boho, Animal Spirit, Mushroom/Cottagecore, Spiritual/Tarot
- Primary blank: MWW On Demand AOP Hoodie (Blueprint 450)
- Seasonal peak: Oct-Jan (2-3x summer volumes)
- Top seller pattern: Perpetual 50% sale + multi-product listings + 15+ colors
- ISHIRTLAB benchmark: 240 sales/mo, $16.87 CAD, 1.7% conversion rate

## Memory (Persistent Context)

All research data, templates, and architecture decisions are stored in `memory/`:

| File | Contents |
|------|----------|
| `memory/glossary.md` | POD/Etsy terminology, acronyms, niche shorthand |
| `memory/research/market-research-2026-02-14.md` | Keyword volumes, niche analysis, top bestsellers, seasonal trends |
| `memory/research/printify-suppliers.md` | All blank models, costs, pricing strategy per niche |
| `memory/research/top-sellers-analysis.md` | 6 top shops analyzed (ISHIRTLAB, CozyThreads, etc.), success patterns |
| `memory/research/listing-templates.md` | Title/description/tag templates, 10-image strategy, pricing formula |
| `memory/projects/agent-pipeline.md` | 8-agent sequential pipeline architecture (idea → published listing) |

Strategy & research in `research/`:
- `research/product-launch-plan-2026-02-22.md` — **CURRENT** launch plan: 25-product inventory, supplier analysis, $99.99 pricing, winner list
- `research/product-launch-plan-2026-02-16.md` — Original 20-product catalog, keyword research, seasonal strategy (superseded)
- `research/product-strategy-15-new-designs-2026-02-16.md` — ICP analysis, 15 new product ideas with prompts/tags, pricing, ads strategy
- `research/multi-tier-listing-strategy-2026-02-16.md` — Multi-tier listing structure (tee + crew + AOP), revenue model, pipeline changes
- `research/keyword_analysis_2026-02-16.xlsx` — Raw keyword data

Research reports (Excel + HTML) in `EtsyResearch/`:
- `Etsy_Hoodie_Market_Research_Complete_2026-02-14.xlsx` (14 sheets, full data)
- `Etsy_Hoodie_Market_Research_Report_2026-02-14.html` (interactive visual report)
- `Yoycol_Market_Verification_Report_V2_2026-02-24.xlsx` — Visual design comparison, Yoycol catalog verification (11 sheets)
- `Yoycol_Dress_Feasibility_Analysis_2026-02-24.xlsx` — Dress niche viability for Google Shopping (5 sheets)
- `Google_Ads_Feasibility_AOP_Dresses_2026-02-24.xlsx` — Google Shopping Ads ROAS analysis (4 sheets)
- `AOP_Dress_Design_Guide_2026-02-24.xlsx` — **DESIGN GUIDE**: Color palettes, motifs, AI prompts, product×keyword matrix, launch priorities (8 sheets)

## Yoycol AOP Dress Expansion (Feb 24, 2026)

**Supplier:** Yoycol (AOP sublimation, China-based, 2.5 day production, UPS/DHL shipping ~$9.50)
**Product line:** 128 AOP dress types, $6-$24 COGS
**Sales channel:** Google Shopping (primary) + Etsy (secondary)

### Top 6 Keywords for AOP Dresses
| Keyword | Volume/mo | CPC | ROAS (1.5% CVR) | Break-even CVR |
|---------|-----------|-----|------------------|----------------|
| dark floral dress | 22,200 | $0.28 | 2.6x | 1.12% |
| cottagecore dress | 18,100 | $0.28 | 2.7x | 1.21% |
| celestial dress | 5,400 | $0.48 | 2.2x | 1.44% |
| vintage floral dress | 4,400 | $0.27 | 2.4x | 1.32% |
| whimsigoth dress | 1,900 | $0.29 | 2.9x | 1.02% |
| boho floral maxi dress | 880 | $0.37 | 2.4x | 1.32% |

### Top 4 Yoycol Products for Google Shopping
| Product | COGS | Best Keywords | Sale Price | Margin |
|---------|------|---------------|-----------|--------|
| Elegant Long Dress | $15.87 | dark floral, celestial, whimsigoth | $49.99 | 49.2% |
| Slip Dress | $7.11 | dark floral, celestial, whimsigoth | $34.99 | 52.5% |
| Ruffle Hem Dress | $14.60 | boho, cottagecore, vintage | $44.99 | 46.4% |
| V-Neck Maxi Dress | $14.89 | boho, dark floral, vintage | $44.99 | 45.8% |

### Design Guide Summary (from visual Google Shopping analysis)
- **Dark floral**: Black/navy backgrounds, large crimson/blush/gold florals, 60-80% coverage, moody romantic mood
- **Boho floral**: Ivory/cream/rust backgrounds, oversized wildflowers in earth+jewel tones, 50-70% coverage, free-spirited
- **Cottagecore**: White/cream/lavender backgrounds, ditsy florals/strawberries/daisies, 70-85% dense repeat, nostalgic
- **Celestial**: Black/midnight blue backgrounds, gold/silver moons+stars+constellations, 50-65% coverage, mystical
- **Vintage floral**: White/ivory/powder blue backgrounds, cabbage roses+chintz, 75-90% dense coverage, timeless elegance
- **Whimsigoth**: Black/dark purple backgrounds, moths+moons+mushrooms+tarot, 55-70% coverage, dark romantic

Full design guide with AI prompts, color hex codes, mockup templates: `EtsyResearch/AOP_Dress_Design_Guide_2026-02-24.xlsx`

## Pinterest Integration

**App ID:** 1548553 | **Business account:** lunarauradesigns
**Access level:** Trial (sandbox only) — Standard access application pending video demo
**Board ID:** 1135610930980088168

### OAuth Flow
```
Settings page → "Connect Pinterest" button → /api/auth/pinterest
  → Sets CSRF state cookie, redirects to Pinterest OAuth consent screen
  → User authorizes → Pinterest redirects to /api/auth/pinterest/callback
  → Validates state, exchanges code for tokens, stores in Supabase
  → Redirects to /content/settings?pinterest=connected
```

**Token storage:** `user_preferences.style_preferences.content_config.pinterest`
```json
{ "access_token": "...", "refresh_token": "...", "expires_at": "...", "username": "lunarauradesigns", "connected": true, "selected_board_id": "..." }
```

**Env vars** (`dashboard/.env.local`): `PINTEREST_APP_ID`, `PINTEREST_APP_SECRET`, `NEXT_PUBLIC_APP_URL`
**Pinterest portal redirect URI:** `http://localhost:3000/api/auth/pinterest/callback`
**Scopes:** `boards:read,boards:write,pins:read,pins:write,user_accounts:read`

### Content Publishing Pipeline (stub)
- `prototype/content_producer/publisher.py` — `publish_static_pin()` and `publish_video_pin()` stubs
- `prototype/tools/publish_pins_pinterest.py` — Sandbox test script (3 test pins published successfully)
- Will use OAuth tokens from Supabase once Standard access is granted

## Key External API Constraints

- **Printify**: 200 requests per 30 minutes, max 50MB images
- **Etsy**: OAuth 2.0, tags max 20 chars each, 13 tags exactly
- **Gemini**: 4K max native output (4096×4096 square, 3712×4608 portrait)
- **Pinterest**: OAuth 2.0, access token expires 30 days, refresh token 365 days. Trial = sandbox only (pins invisible). Standard access requires video demo of OAuth flow.

## Next Steps (Priority Order — Updated Feb 24)

1. **Record Pinterest OAuth video demo** — Open Settings → Connect → Authorize → Connected state → Submit for Standard access
2. **Retrieve current Printify product IDs** — Log into Printify, get IDs for all 25 products (8 orphaned winners critical)
3. **Update launch_winners.py** — Fix stale product IDs for all 11 winners
4. **Verify pricing** — Confirm all 16 listing-ready products at $149.98/$74.99
5. **Fix sleeve bug** — Simplify `rules/aop_hoodie.yaml` sleeve guidance, add edge-fill validation
6. **Fix fabric description** — database.py says "100% Polyester", should be "86% polyester / 14% cotton"
7. **Generate copy for 6 in-progress products** — Assets exist but no titles/tags/pricing
8. **Test AOP template system** — Run `9_test_aop_templates.py` with Death Moth (strongest winner)
9. **Launch first 5 winners on Etsy** — Death Moth, Luna Moth, Oracle, Raven's Garden, Moon Phases
10. **Enable Etsy Ads** — $3-5/day on top 3 performers
11. **Wire up Pinterest publishing** — Connect `publisher.py` stubs to OAuth tokens from Supabase after Standard access granted
12. **Add RLS to user_preferences** — Required before Phase 2 cloud migration (tokens stored in plaintext)

## Future Architecture

Phase 1 (current): Local Supabase + Python worker + Next.js dashboard (personal use)
Phase 2: Cloud Supabase + Supabase Edge Functions replacing Python worker
Phase 3: Multi-tenant SaaS with RLS policies + Auth + billing

Full architecture details in original SOW: `Specs/` directory

## Project Conventions

- TypeScript strict mode, no `any` types (for Next.js code)
- snake_case for database columns, camelCase for TypeScript
- Python prototype uses snake_case throughout
- YAML rules files define product types (one per product)
- All output organized under `prototype/output/director/` with timestamped folders

## Yoycol Design Editor — Panel Spec Extraction Workflow

**When to use:** Whenever adding a new Yoycol product line or verifying panel dimensions for existing products.

### What This Workflow Does
Opens each Yoycol product in their Classic Design Editor, clicks through every garment panel (front, back, sleeves, collars, laces, pockets, etc.), and reads the "Max W*H px" resolution requirement for each panel. Produces a structured asset requirement table per product.

### Reference Files
| File | Purpose |
|------|---------|
| `memory/workflows/yoycol-design-editor-workflow.md` | Full step-by-step workflow + DOM selectors + URL patterns |
| `memory/research/yoycol-dress-design-specs.md` | First 3 dress panel specs (detailed, with aspect ratios + design notes) |
| `memory/research/yoycol-15-dress-design-specs.md` | All 15 dress panel specs (SPU codes, COGS, panel dimensions, complexity ratings) |
| `memory/research/yoycol-new-products-design-specs.md` | **18 new products** (17 Yoycol + 1 Printify) — 5 re-scanned with corrected dimensions ✅ |
| `docs/YOYCOL_TOOLS.md` | Full Yoycol API client + scraping tools reference |

### Quick Steps (Claude in Chrome) — PHYSICAL CLICK METHOD (Recommended)

> **⚠️ CRITICAL: The 3-Second Rule**
> Yoycol's Design Editor canvas does NOT re-render reliably with JS `.dispatchEvent()` clicks.
> Programmatic clicks cause a **lag-by-one-panel bug** where each panel reads the PREVIOUS panel's dimensions.
> **ALWAYS use physical mouse clicks via the `computer` tool with a 3-second wait between panels.**
> This was discovered 2026-03-01 after 15 panels across 5 products had to be manually re-scanned.

1. **Open a fresh tab** via `tabs_create_mcp` (editor pages are heavy and cause tab hangs — never reuse tabs)
2. **Navigate** to the Yoycol Design Editor URL:
   ```
   https://www.yoycol.com/design/{"type":"new","spuCode":"<SPU>","skuCode":"ADS-<SPU>-00000-FFFFFF-S"}
   ```
3. **Wait 8 seconds** for editor to fully load (left sidebar shows panel piece icons)
4. **Take a screenshot** to identify panel icon positions in the left sidebar
5. **For each panel icon** (top to bottom):
   a. **Physical click** the panel icon using `computer` tool `left_click` action on the icon coordinates
   b. **Wait 3 seconds** (`computer` tool `wait` action, `duration: 3`)
   c. **Take a screenshot** to read the "Max {W}*{H} px" text from the canvas center
   d. **Record** the panel name (shown as tooltip near the orange-highlighted icon) and dimensions
6. **Repeat** for each product SPU code (use a **new tab** for each product)

### Stale Read Detection (Post-Scan Verification)
After scanning, check for this pattern in your results:
- If panel N+1 has **identical dimensions** to panel N → panel N+1 is likely stale
- Waistbands, collars, lace strips should be **thin horizontal strips** (height << width), not matching body panels
- Left/right sleeve pairs should have **matching** dimensions
- Left/right pocket pairs should have **matching** dimensions
If suspicious, re-scan the specific product using the physical click method above.

### Legacy JS Automation (DO NOT USE for dimension reads)
The JS automation snippet below is **DEPRECATED for reading panel dimensions** due to the canvas re-render bug.
It can still be used to **count panels** and **read panel names** (which update instantly via DOM, not canvas):
```javascript
// ONLY for counting panels and reading names — NOT for reading dimensions
const pieces = document.querySelectorAll('[class*="_piece_"]');
const names = Array.from(pieces).map((p, i) => {
  const img = p.querySelector('img');
  return {panel: i+1, name: img ? (img.alt || '') : ''};
});
console.log(JSON.stringify(names, null, 2));
```

### Key Details
- **DOM selector for panel icons:** `[class*="_piece_"]` — each contains an `img` with `alt` = panel name
- **Resolution text location:** Canvas center area, format "Max {W}*{H} px"
- **Default variant:** Always use White/S (`-FFFFFF-S`) for consistent mockup downloads
- **The 3-second rule:** Physical clicks + 3s wait = accurate reads. JS clicks + any delay = stale reads. No exceptions.
- **Fresh tabs required:** Design Editor pages are memory-heavy canvas apps that frequently hang. Create a new tab for each product.
- **Panel types:** front, back, sleeves (L/R mirror), collars (inner/outer), lace/trim strips, pockets, waistbands, plackets, belts, flaps

### Output Format
Save results to `memory/research/yoycol-{category}-design-specs.md` with this structure per product:
```markdown
## Product N: {Product Name}
| Field | Value |
|-------|-------|
| SPU Code | {code} |
| COGS | ${price} |
| Panels | {count} |

| # | Panel Name | Max Width (px) | Max Height (px) |
|---|-----------|----------------|-----------------|
| 1 | Front | XXXX | XXXX |
...
```
