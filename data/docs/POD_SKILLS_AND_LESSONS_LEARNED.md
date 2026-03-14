# POD Automation — Skills & Lessons Learned

> Compiled 2026-03-09 from 15+ sessions (Mar 3–9), 13 memory files, 112 tools, 43 YAML rules, and 9 niche guides.

---

## Table of Contents

1. [Proposed Skills Catalog](#1-proposed-skills-catalog)
2. [Lessons Learned: Pattern & Tile Generation](#2-lessons-learned-pattern--tile-generation)
3. [Lessons Learned: Mockup Generation](#3-lessons-learned-mockup-generation)
4. [Lessons Learned: Lifestyle Images](#4-lessons-learned-lifestyle-images)
5. [Lessons Learned: Video Generation](#5-lessons-learned-video-generation)
6. [Lessons Learned: Design Rules & YAML](#6-lessons-learned-design-rules--yaml)
7. [Lessons Learned: Post-Processing](#7-lessons-learned-post-processing)
8. [Lessons Learned: Shopify Store Management](#8-lessons-learned-shopify-store-management)
9. [Lessons Learned: Airtable Database Workflow](#9-lessons-learned-airtable-database-workflow)
10. [Lessons Learned: Image Generation Providers](#10-lessons-learned-image-generation-providers)
11. [Lessons Learned: Virtual Try-On (VTON)](#11-lessons-learned-virtual-try-on-vton)
12. [Lessons Learned: Copy & Content Generation](#12-lessons-learned-copy--content-generation)
13. [Agent Army Architecture](#13-agent-army-architecture)

---

## 1. Proposed Skills Catalog

### Existing Skills (already in `rules/.skills/`)

| Skill | Purpose | Status |
|-------|---------|--------|
| `tile-qa` | Validate seamless pattern tiles (edge continuity, density, frame artifacts) | Active |
| `listing-qa` | Validate listing images (10-slot system, quality checks) | Active |
| `pipeline-orchestrator` | End-to-end Shopify dress pipeline (tile→QA→listing→copy→publish) | Active |
| `shopify-seo-copy` | Generate SEO titles, descriptions, tags for Shopify | Active |
| `shopify-aila-theme` | Shopify AILA theme configuration | Active |
| `yoycol-design-rules` | Generate YAML design rules from Yoycol product specs | Active |

### NEW Skills to Create

| # | Skill Name | Purpose | Agent Type | Key Tools/Files |
|---|-----------|---------|------------|-----------------|
| 1 | `pattern-generator` | Generate 4K seamless AOP pattern tiles with niche-aware prompts | Worker | `kie_generator.py`, `generate_pattern_library.py`, `generate_v3_dense_tiles.py` |
| 2 | `white-base-generator` | Generate white garment base images for VTON compositing | Worker | `generate_vton_bases.py`, `generate_peaprint_bases.py`, `generate_shopify_bases.py` |
| 3 | `mockup-compositor` | Composite patterns onto white bases (ghost mannequin + on-model) | Worker | `aop_compositing.py`, `ghost_front_compositor.py`, `generate_v3_listings_twostep.py` |
| 4 | `lifestyle-photographer` | Generate kie.ai lifestyle photos (golden hour, garden, editorial) | Worker | `test_kie_lifestyle.py`, `batch_lifestyle_video.py`, `kie_generator.py` |
| 5 | `video-producer` | Generate fashion show walk+turn videos (Runway Gen-4) | Worker | `kie_video_generator.py`, `batch_lifestyle_video.py` |
| 6 | `listing-image-assembler` | Assemble 7–10 slot listing image sets (Etsy/Shopify platform-aware) | Worker | `producer.py`, `aop_compositing.py`, `aop_templates.py` |
| 7 | `design-rules-builder` | Create YAML product rules from supplier specs (Yoycol/PeaPrint/Printify) | Architect | `rules_loader.py`, `models.py`, existing YAML templates |
| 8 | `niche-bootstrapper` | Bootstrap a new niche (guide, prompts, hex palettes, competitive analysis) | Architect | `niche_loader.py`, `niches/*.yaml`, `bootstrap_niche.py` |
| 9 | `copy-writer` | Generate Etsy/Shopify listing copy (title, description, 13 tags, SEO) | Worker | `copy_generator.py`, Kimi K2.5 |
| 10 | `pricing-strategist` | Calculate pricing with margins, perpetual sale, competitive adjustments | Worker | `suppliers/database.py`, `apply_competitive_adjustments.py` |
| 11 | `shopify-publisher` | Publish products to Shopify (variants, images, SEO, collections, size charts) | Worker | `shopify_publish.py`, `shopify_client.py`, `shopify_size_chart.py` |
| 12 | `shopify-fixer` | Fix/update existing Shopify products (prices, size charts, images) | Worker | `fix_shopify_products.py`, `populate_shopify_products.py` |
| 13 | `airtable-sync` | Sync products between local output, Supabase, and Airtable | Worker | `sync_to_supabase.py`, `sync_v3_listings_to_airtable.py`, `populate_shopify_products.py` |
| 14 | `printify-manager` | Upload artwork, create/update products, download mockups from Printify | Worker | `uploader.py`, `check_printify_products.py`, `audit_printify_statuses.py` |
| 15 | `product-revamper` | Full/partial redesign of existing products | Orchestrator | `revamp_product.py`, `batch_revamp.py` |
| 16 | `supplier-scanner` | Scan new Yoycol/PeaPrint products, extract panel specs, download mockups | Research | `fetch_new_yoycol_products.py`, `add_yoycol_products.py` |
| 17 | `front-compositor` | Enforce safe zones on front panels (hero scaling, pocket clear, frame detection) | Worker | `front_compositor.py` |
| 18 | `token-refresher` | Refresh expired Shopify access tokens via client_credentials grant | Utility | `shopify_auth.py`, client_id/secret from `.env` |
| 19 | `pinterest-publisher` | Publish pins to Pinterest (image + video pins) | Worker | `publish_pins_pinterest.py`, `pinterest_pins.py`, `video_pins.py` |
| 20 | `content-distributor` | Distribute content across social channels via Postiz | Worker | `postiz_client.py`, `distributor.py`, `scheduler.py` |

### Agent Dispatch Teams

| Team | Skills Combined | Trigger |
|------|----------------|---------|
| **New Product** | `pattern-generator` → `tile-qa` → `mockup-compositor` → `listing-image-assembler` → `listing-qa` → `copy-writer` → `pricing-strategist` → `airtable-sync` | "Create new product" |
| **New Niche Launch** | `niche-bootstrapper` → `pattern-generator` (×N) → `tile-qa` (×N) → (full product team ×N) → `shopify-publisher` | "Launch new niche" |
| **Shopify Batch Publish** | `token-refresher` → `shopify-publisher` (×N) → `shopify-fixer` (verify) | "Publish to Shopify" |
| **Content Campaign** | `lifestyle-photographer` → `video-producer` → `pinterest-publisher` → `content-distributor` | "Create marketing content" |
| **Product Refresh** | `product-revamper` → `listing-image-assembler` → `copy-writer` → `airtable-sync` | "Revamp product X" |
| **New Supplier Onboard** | `supplier-scanner` → `design-rules-builder` → `white-base-generator` → `niche-bootstrapper` | "Add Yoycol product Y" |

---

## 2. Lessons Learned: Pattern & Tile Generation

### What Works

1. **"Flat textile swatch" language** is the single most important prompt directive. Without it, AI draws garment silhouettes (arm shapes, trapezoids) instead of edge-to-edge patterns.
   ```
   GOOD: "Seamless all-over textile print design, flat fabric swatch filling entire image edge to edge"
   BAD:  "Hoodie sleeve with floral pattern" (AI draws a sleeve shape)
   ```

2. **kie.ai Nano Banana Pro at $0.12/4K** is the production workhorse. Supports up to 8 reference image URLs for style consistency. Always upload refs to catbox.moe first.

3. **Offset-and-blend seamless tiling** (in `processor.py`):
   - 50% shift on both axes, 18% cross-fade blend zone
   - Edge discontinuity score: <15 = tileable, 15-35 = auto-fix, >35 = needs manual
   - 20 Airtable patterns tested: 7 natively tileable, 13 auto-fixed

4. **Niche-specific density targets**:
   - Dark floral: 60-80% coverage, large crimson/blush/gold florals on black
   - Cottagecore: 70-85% dense ditsy repeat on white/cream
   - Whimsigoth: 55-70% moths+moons+mushrooms on black/purple
   - Celestial: 50-65% gold/silver moons+stars on midnight blue

5. **V3 two-step method for dresses** solves pattern bleed:
   - Step 1: PIL composite pattern onto ghost mannequin (zero bleed, deterministic)
   - Step 2: Single-reference Gemini transfer → patterned ghost becomes on-model (zero bleed, varied poses)
   - Cost: ~$0.52 per pattern per dress (4 Gemini calls)

### What Doesn't Work

1. **Pattern Diffusion** — produces "too seamless, wrong aesthetic." Ignores specific hex codes, tends toward duochrome. CLIP 77-token limit truncates detailed prompts.

2. **"Woodblock print" in prompts** — kie.ai renders paper borders/frames. Use "illustration, bold flat color, no border or frame" instead. Four anti-frame negative prompts in `aop_hoodie.yaml`.

3. **fp16 for Sana 1.5 seamless** — 50% NaN/black output. Must use `torch.bfloat16` (8 exponent bits like fp32). Only patch VAE decoder Conv2d for circular padding, NOT the transformer.

4. **Square generation + center-crop** — kie.ai generates 1:1 by default. When target is 3:4 portrait, center-crop wastes 25% of the image. Gemini natively supports portrait ARs.

---

## 3. Lessons Learned: Mockup Generation

### Ghost Mannequin (Slots 01-03)

1. **Slot 01 (ghost front) MUST use PIL compositing, NOT VTON.** VTON always adds a human body, which defeats the ghost mannequin look. The compositor uses:
   - Printify mockup as artwork source
   - `base_ghost_front.png` grayscale as lighting map
   - Flood-fill background detection (scipy.ndimage.label) → garment mask
   - Edge depth shadow + drop shadow + dark gradient bg = 3D depth effect

2. **8 white base images per garment type** — hoodie bases exist, sweatshirt + tee bases must be generated via `generate_vton_bases.py`.

3. **White base naming convention**:
   - Etsy: `base_dr_{prefix}_{slot}.png`
   - Shopify: `base_dr_{prefix}_shop_{slot}.png`

### On-Model (Slots 04-08)

1. **VTON provider hierarchy**: Vertex AI ($0.362) → Kontext FLUX ($0.035, 90% cheaper) → CatVTON Local (free, lower quality)
2. **Set `VTON_PROVIDER=kontext`** in `.env` for 90% cost reduction with acceptable quality
3. **Transient 500s from Vertex AI** — retry with exponential backoff (2 retries built in)

### Platform Differences

| Aspect | Etsy | Shopify / Google Shopping |
|--------|------|--------------------------|
| Primary image | Ghost mannequin or on-model | On-model front, WHITE background (Google req) |
| Infographics | Size chart + trust badge appended | NONE (text overlays violate Google policy) |
| Slot count | 7 composited + 2 infographics = 9 | 7 composited = 7 |
| Total images | 10 (with slot 10 being infographic) | 7 |

---

## 4. Lessons Learned: Lifestyle Images

### What Works (Approved Prompt v3)

```
The image shows a woman wearing a long body-con dress with thigh-high side slit
with a beautiful dark floral all-over sublimation print pattern.

Show a woman wearing the EXACT same dress with the EXACT same print pattern,
standing outdoors at golden hour in a lush garden. Soft blurred greenery and
warm sunset light in the background. She faces the camera with a relaxed confident pose.

CRITICAL RULES:
- The pattern on the dress must be 100% identical to the input
- Do NOT simplify, reinterpret, or alter ANY element of the pattern
- The dress silhouette, neckline, and length must match exactly
- Background should be SOFT and BLURRED (shallow depth of field)
- Warm golden hour side lighting, moody romantic atmosphere
- Three-quarter length framing (head to mid-calf), model centered
- Editorial fashion photography, clean composition
- No accessories, no shoes
```

### Niche-Specific Scenes

| Niche | Scene | Lighting |
|-------|-------|----------|
| Dark floral | Lush garden at golden hour | Warm sunset side light |
| Whimsigoth | Misty forest clearing at twilight | Cool blue hour, ethereal mist |
| Boho floral | Wildflower meadow at golden hour | Warm natural backlight |
| Celestial | Rooftop terrace at blue hour | Cool ambient city glow |

### What Doesn't Work

1. **v1 prompt (too far)** — model was tiny in frame. Fix: "Three-quarter length framing, model centered and filling the frame"
2. **v2 prompt (conservatory scene)** — iron arches + glass ceiling cramped the model. Fix: switch to "soft blurred garden" — no architectural elements
3. **kie.ai vs Gemini quality gap** — kie.ai lifestyle images look visually different from Gemini-generated slots. The style/lighting doesn't perfectly match. User noticed but hasn't requested regeneration yet.

---

## 5. Lessons Learned: Video Generation

### Runway Gen-4 Turbo via KIE API

- **Cost**: $0.12 per 5-second video
- **Model**: Runway Gen-4 Turbo (image-to-video)
- **Fallback**: Veo 3.1 Fast ($0.30-2.00 per 8s)
- **Retry**: 2 retries with 15/30s backoff

### Critical Rules

1. **Upload reference images to `litterbox.catbox.moe`** — NOT `files.catbox.moe`. Runway can't fetch from the `files` subdomain. This caused silent failures.
2. **Video gated on Airtable approval** — Shopify Products → Status = "Approved" before generating video
3. **5/34 videos needed retry** in the March 9 batch — all succeeded on second attempt
4. **Half of generated videos had quality issues** — user decided to publish WITHOUT videos ("half are broken")

### Approved Video Prompt

```
Professional fashion runway video. A woman wearing a {garment_desc}
with a beautiful all-over sublimation print pattern walks confidently toward the
camera on a clean white runway. She pauses at the mark, does a slow elegant
turn showing the back of the dress, then walks away. The camera is static at
eye level. The dress fabric moves naturally with each step and turn, showing
the print from all angles. Bright even runway lighting.
High-end fashion show quality, 24fps, cinematic.
```

---

## 6. Lessons Learned: Design Rules & YAML

### YAML Rule Structure

Every product type needs a YAML rule file defining:
- **printify**: blueprint_id, provider_id, variant_ids (0 for non-Printify suppliers)
- **generation_order**: [front, back, right_sleeve, ...] — controls reference chaining
- **areas**: per-panel specs (print dimensions, generation AR, composition guidance, spatial zones)
- **coherence**: palette rules, style rules, theme rules, negative prompts
- **seam_allowance**: per-area margins (default 150px, 200px for cuffs/waistband)
- **trim**: solid-fill areas (waistband, cuffs, collar) — NOT patterned

### Key Rules That Prevent Manufacturing Defects

1. **Color coherence across panels**: All panels MUST use exact same `hex_palette.background` color. Mismatched backgrounds create visible patchwork seams on the assembled garment.
   ```yaml
   coherence:
     palette:
       rule: "All panels share exact same hex_palette.background"
       severity: critical
   ```

2. **Sleeve = flat textile swatch** (Rule 10): "flat rectangular textile swatch, not a garment mockup". No arm shapes, no trapezoids, no sleeve silhouettes. Edge-to-edge fill required.

3. **Pocket zone (hoodie only)**: Front panel 59-83% from top must be flat background only. Anything here appears TWICE on the finished hoodie (pocket is cut from front).

4. **Hood crop zone**: Back panel upper 0-50% must be dense atmospheric content (clouds, mist, nebula) — no focal subjects, no faces, no text. This region gets cropped for hood lining.

5. **Two-zone front layout (hoodie)**:
   - Hero zone: 25-48% (compact subject, wider than tall)
   - Below hero: 50-100% flat background, zero gradients/atmosphere
   - No atmospheric haze — hero simply ends, solid color fills below

### Product-Type Differences

| Product | Front Layout | Has Hood? | Has Pocket? | Trim Areas |
|---------|-------------|-----------|-------------|------------|
| aop_hoodie | Two-zone (hero 25-48%) | Yes (cropped from back) | Yes (cropped from front) | waistband + cuffs |
| aop_sweatshirt | Hero 15-55% | No | No | waistband + collar + cuffs |
| aop_tshirt | Hero 12-55% | No | No | collar only |
| aop_dress_* | Full-coverage edge-to-edge | No | No | varies (collar, lace, waistband) |

### Design Director System Prompt Issue (OPEN)

- `prompts.py` PLAN_SYSTEM_PROMPT is 176 lines, **100% hoodie-specific**
- No product-type awareness, no creative WOW factor guidance, no style presets
- **Fix needed**: Split into layered system: base (shared) + product-specific + style preset + niche context
- This is the #1 blocker for multi-product design quality

---

## 7. Lessons Learned: Post-Processing

### Front Compositor (`front_compositor.py`)

| Product Type | Hero Zone | Pocket Clear | Frame Detection |
|-------------|-----------|--------------|-----------------|
| aop_hoodie | 22-52% | Yes, at 55% | Yes (4-edge scan) |
| aop_sweatshirt | 10-70% | No | Yes |
| aop_tshirt | 10-70% | No | Yes |
| aop_dress_* | SKIPPED | No | No |

1. **Frame detection**: Scans all 4 edges for uniform non-background borders (>80% uniformity across edge). If 3+ edges have borders, crops and re-centers. **Fixes kie.ai ukiyo-e border artifacts.**

2. **Hero scaling fallback**: If hero overflows safe zone by >20%, scales down (min 0.65x, Lanczos resampling) instead of just fading bottom. Set `max_scale_factor=1.0` to disable.

3. **Japanese designs on hoodie**: Heroes run 44-50% of panel (vs 28-30% normal). The compositor scaling handles overflow gracefully.

### Asset Pipeline Processing (`processor.py`)

1. **`resize_to_print()`** — Lanczos resize to exact print dimensions
2. **`mirror_image()`** — Horizontal flip for left sleeve/hood from right
3. **`ensure_edge_fill()`** — Validates all 4 edges have pattern coverage (no white gaps)
4. **`generate_trim_artwork()`** — Solid background color fill for waistband/cuffs/collar
5. **`make_seamless()`** — Offset-and-blend tiling fix (50% shift, 18% blend zone)
6. **`tile_to_fill()`** — Tiles pattern to target panel size, center-crops

---

## 8. Lessons Learned: Shopify Store Management

### Token Management

- **Shopify custom-app tokens EXPIRE** (despite documentation saying they don't)
- **Refresh method**: POST `https://{store}.myshopify.com/admin/oauth/access_token` with:
  ```json
  {"client_id": "...", "client_secret": "...", "grant_type": "client_credentials"}
  ```
- Returns new `shpat_*` token. Update `SHOPIFY_ACCESS_TOKEN` in `.env`.
- **Always verify before batch operations**: `python -m suppliers.shopify_auth`

### ShopifyClient Method Names (Common Mistakes)

| Wrong | Correct |
|-------|---------|
| `add_image()` | `upload_image()` |
| `set_seo_metafields()` | `set_seo()` |
| `assign_to_collection()` | `add_to_collection()` |
| Passing dict to `create_product()` | Use keyword args |

### Size Chart Widget

- Collapsible `<details><summary>` HTML element
- Inline CSS/JS tabs for Inches/Centimeters switching
- Auto-conversion between units
- Scoped under `.sc-widget` CSS class (for idempotent re-injection)
- Generated by `suppliers/shopify_size_chart.py`

### Pricing Architecture

| Field | Source | Maps to |
|-------|--------|---------|
| Sale Price | Airtable `fldszHUmj9ZYiteDn` | Fallback variant.price |
| Retail Price | Airtable `fldLBMNnacdwjgh9T` | Preferred variant.price (competitive adjustment) |
| Compare At | Airtable `fldJz9dUcOK7GVIfC` | variant.compare_at_price (crossed-out anchor) |

- Retail Price takes precedence over Sale Price when available
- Compare At creates the "was $109.98, now $54.99" strikethrough display

### Collections Created

Dark Floral Dresses, Boho Floral Dresses, Celestial Dresses, Whimsigoth Dresses, Maxi Dresses, Midi Dresses, Spaghetti Strap Dresses, Hoodie Dresses

### Windows/Unicode Gotcha

- Python scripts with `→` or `…` characters crash on Windows (cp1252 encoding)
- Replace with `->` and `...` respectively
- Always use ASCII in print statements for Windows compatibility

---

## 9. Lessons Learned: Airtable Database Workflow

### Key Tables

| Table | ID | Purpose |
|-------|----|---------|
| Pattern Library | `tblM9r7VqiQtNdFqh` | Pattern tiles + listing images + approval status |
| Shopify Products | `tblQRdKJFMQDTfqZm` | Product records for Shopify publishing |

### Approval Gates

```
Pattern Library:
  Listing Approval = "Pending Review" → "Approved" / "Rejected" / "Needs Regen"

Shopify Products:
  Status = "Ready to Publish" → script publishes → writes back Shopify Product ID
```

### Field ID Gotchas

- **Always verify field IDs against live schema** — they change when fields are recreated
- Size Chart field was `fldY7QGk5kxNECcBD` (placeholder) but actual is `fldl0nfA3DEZ1gMJD`
- Use `returnFieldsByFieldId: true` in API calls to avoid name-based lookups
- Batch updates max 10 records per request
- `typecast: true` required for select fields

### Image Hosting Chain

```
Local PNG → Supabase Storage (`listing-images` bucket) → Public URL → Airtable attachment
```

---

## 10. Lessons Learned: Image Generation Providers

### Provider Cost Comparison

| Provider | Cost/4K | Ref Images | Best For | Gotchas |
|----------|---------|------------|----------|---------|
| kie.ai Nano Banana Pro | $0.09-0.12 | Up to 8 URLs | Pattern tiles, lifestyle | Daily credit limit (433), must use catbox.moe for refs, result URLs expire 24h |
| Gemini 3 Pro | $0.451 | Multimodal (inline) | Prompt-adherent designs, two-step transfer | Rate limit (429), daily quota kills batch runs |
| GoAPI | $0.18 | IGNORED | Last resort | Reference images not supported — designs won't match artwork |

### Auto-Fallback Chain

```
kie.ai (primary, $0.12) → [433 daily limit] → Gemini ($0.45) → [429 rate limit] → GoAPI ($0.18)
```

Override: `IMAGE_PROVIDER=kie|gemini|goapi` env var or `--kie|--gemini|--goapi` CLI flags.

### Reference Image Chaining (Coherence)

```
Front (generated first, anchor)
  → Back receives front as visual reference → matches color/style
  → Sleeves receive front as reference → scaled accent version
  → Left sleeve = mirror of right (no AI cost)
  → Hood = crop from back upper 50% (no AI cost)
  → Pocket = crop from front 59-83% (no AI cost)
```

### Resolution & Aspect Ratios

- Supported: 1:1, 2:3, 3:2, 3:4, 4:3, 4:5, 5:4, 9:16, 16:9
- Max native: 4096×4096 (square), 3712×4608 (portrait)
- kie.ai generates 1:1 by default → center-crop to target AR (25% waste for portrait)
- Gemini supports native portrait generation (no waste)

---

## 11. Lessons Learned: Virtual Try-On (VTON)

### Provider Comparison

| Provider | Cost/img | Quality | Latency | License |
|----------|----------|---------|---------|---------|
| Vertex AI vton-001 | $0.362 | Best | 15-30s cloud | Commercial |
| FLUX Kontext Pro | $0.035 | Good | ~10s | Commercial |
| CatVTON Local | Free | Faded | ~75s local | Open source |
| IDM-VTON (Replicate) | $0.025 | Good | ~15s | Non-commercial only |

### Per-Product Cost Impact

| Provider | Total/product | Savings vs Vertex |
|----------|--------------|-------------------|
| Vertex AI | $2.91 | Baseline |
| Kontext FLUX | $0.52 | 82% cheaper |
| CatVTON Local | $0.00 | Free (lower quality) |

### CatVTON Debugging Lessons (5-session deep dive)

1. **Grey blob output** — Wrong weights loaded. MaskFree weights (198MB, 8ch UNet) loaded into SD-Inpainting UNet (9ch). Must match checkpoint variant to architecture.
2. **NaN on fp16** — 50% failure rate. Fixed by `torch.bfloat16` (8 exponent bits match fp32).
3. **Rectangular masks cause artifacts** — Use garment-contour masks, not full-width rectangles.
4. **Proper config**: `eta=1.0` (DDPM stochastic), mask blur radius=9, ~75s/image at 768×1024 fp16 on RTX 3060 12GB.

---

## 12. Lessons Learned: Copy & Content Generation

### Copy Writer (Kimi K2.5)

- Model: `kimi-k2.5` (NOT `kimi-k2-5-preview`)
- Base URL: `https://api.moonshot.ai/v1`
- **Temperature MUST be 1.0** — rejects any other value
- Cost: ~$0.004 per product

### Etsy Constraints

- Tags: max 20 chars each, exactly 13 tags
- Title: max 140 chars, front-load keywords
- Description: include all keywords naturally

### Platform Tone

| Platform | Tone | Length |
|----------|------|--------|
| Pinterest | Inspirational, SEO-keyword-rich | ≤500 chars desc |
| Twitter/X | Witty, conversational | ≤280 chars total |
| Instagram | Warm, relatable | Variable |

### Postiz Integration Issues

1. `v2.uploadMedia` doesn't work on X Free tier → must use `v1.uploadMedia`
2. Error swallowing: `social.abstract.ts` catches all errors, replaces with "Unknown Error"
3. Cookie domain problem with Cloudflare tunnel → browsers reject cookies
4. 280 char limit on X — exceeding causes 403 Forbidden (not a clear error message)

---

## 13. Lessons Learned: Bundle Compositing (2026-03-11)

### AOP Same-Panel Rule (CRITICAL)

**Problem**: Blazer front and back views had visibly different patterns/colors. Dress front and back looked like "two different designs."

**Root cause**: Each Gemini generation call produces unique artwork, even from the same prompt. Front_right.png and back.png for blazers (or front.png and back.png for dresses) were generated as separate API calls, resulting in different color palettes and design elements.

**Fix**: Always use the SAME artwork panel for both front and back views:
- Blazer: `front_right.png` for both views
- Dress (single mode): `front.png` for both views
- Dress (split mode): each variant's `front.png` for both views

This works because AOP garments use the same seamless pattern on all physical panels — the ghost base provides the silhouette difference between front and back.

### Split vs Single Mode Decisions

After user review of all 15 bundles:
- **Split bundles** (front/back are distinctly different designs): AN-B01, AN-B02, DF-B01, DF-B02, DF-B03
- **Single bundles** (cohesive or too similar to split): BF-B01, CL-B01, DC-B01, DF-B04, FC-B01, VF-B01, WG-B01, WG-B02
- **Rejected**: CC-B01, TR-B01

**Lesson**: If A and B variants look nearly identical after compositing (e.g., DF-B04 had only 60.2 pixel diff in source), merge to single mode. User won't perceive the difference.

### Catbox SSL Flakiness

Catbox.moe (litterbox) has intermittent SSL connection resets (`SSLEOFError`). Always implement retry logic (3 attempts, 5s delay). The AN-B02 `dress_a_front.png` image failed on 3 consecutive upload attempts across 2 sessions before finally succeeding.

### Outfit Compositing (Front + Back)

Initial implementation only generated front outfit views. User flagged missing back views. Now generates both:
- `comp_outfit_{dress_key}_front.png` — blazer open over dress, front view
- `comp_outfit_{dress_key}_back.png` — back view, looking over shoulder

### Airtable Record Strategy for Split Bundles

Split bundles create **separate** Airtable records per variant (e.g., DF-B01-A and DF-B01-B), each containing:
- Shared blazer front/back (same images in both records)
- Variant-specific dress front/back
- Variant-specific outfit front/back

This allows independent approval/rejection of each variant.

### Bundle Compositing Cost (Actual)

| Type | Images | Gemini Calls | Cost |
|------|--------|-------------|------|
| Split bundle (2 products) | 10 | ~14 | ~$1.04 |
| Single bundle (1 product) | 6 | ~9 | ~$0.66 |
| **Total project (13 bundles)** | ~106 | ~150 | **~$11** |

---

## 14. Agent Army Architecture

### Recommended Agent Structure

```
┌─────────────────────────────────────────────────────┐
│                  DISPATCHER AGENT                    │
│  Receives high-level commands, decomposes into tasks │
│  Routes to appropriate specialist teams              │
└────────┬──────────┬──────────┬──────────┬───────────┘
         │          │          │          │
    ┌────▼────┐ ┌───▼────┐ ┌──▼───┐ ┌───▼─────┐
    │ DESIGN  │ │ ASSET  │ │ COPY │ │ PUBLISH │
    │ TEAM    │ │ TEAM   │ │ TEAM │ │ TEAM    │
    └────┬────┘ └───┬────┘ └──┬───┘ └───┬─────┘
         │          │         │         │
    Skills:    Skills:    Skills:   Skills:
    - niche-   - pattern-  - copy-   - shopify-
      bootstrap  generator   writer    publisher
    - design-  - mockup-   - pricing - airtable-
      rules-     compositor  strat.    sync
      builder  - lifestyle- - seo-   - token-
    - tile-qa    photog.     copy      refresher
               - video-             - pinterest-
                 producer             publisher
               - listing-           - content-
                 assembler            distributor
               - white-base
                 generator
               - front-
                 compositor
```

### Dispatch Commands (Natural Language)

| Command | Teams Activated | Skills Chain |
|---------|----------------|-------------|
| "Create 5 dark floral dresses" | Design → Asset → Copy → Sync | niche-bootstrapper → pattern-generator(×5) → tile-qa(×5) → mockup-compositor(×5) → listing-image-assembler(×5) → listing-qa(×5) → copy-writer(×5) → pricing-strategist(×5) → airtable-sync |
| "Launch whimsigoth niche on Shopify" | All teams | niche-bootstrapper → (full product ×N) → shopify-publisher(×N) |
| "Fix prices on all Shopify products" | Publish | token-refresher → shopify-fixer |
| "Generate marketing content for Pinterest" | Asset → Publish | lifestyle-photographer(×N) → video-producer(×N) → pinterest-publisher(×N) |
| "Add this Yoycol dress to catalog" | Design → Asset | supplier-scanner → design-rules-builder → white-base-generator → pattern-generator → tile-qa |
| "Revamp product X with new artwork" | Asset → Copy | product-revamper → listing-image-assembler → copy-writer → airtable-sync |

### Parallelization Opportunities

| Stage | Parallelizable? | Max Concurrency | Bottleneck |
|-------|----------------|-----------------|------------|
| Pattern generation | Yes (independent per product) | 5 (kie.ai rate limit) | Daily credit limit |
| Tile QA | Yes | Unlimited (PIL-based) | CPU |
| Ghost compositing | Yes | Unlimited (PIL-based) | CPU |
| VTON lifestyle | Yes (per slot) | 3 (API rate limits) | Vertex/Kontext quota |
| Video generation | Yes (per product) | 2 (Runway concurrency) | $0.12/video cost |
| Copy generation | Yes | 5 (Kimi K2.5 rate) | Near-instant |
| Shopify publish | Sequential (API rate limit) | 1 (2 req/sec) | 0.55s between calls |
| Airtable sync | Batch 10 records | 5 requests/sec | API rate limit |

### Cost Per Full Product (Optimized)

| Component | Cost | Provider |
|-----------|------|----------|
| Pattern tile (4K) | $0.12 | kie.ai |
| Front artwork | $0.12 | kie.ai |
| Back artwork | $0.12 | kie.ai |
| Sleeve artwork | $0.09 | kie.ai (2K) |
| 7 VTON listing images | $0.245 | Kontext FLUX |
| 2 infographics | $0.00 | PIL (free) |
| Lifestyle photo | $0.12 | kie.ai |
| Video (5s) | $0.12 | Runway Gen-4 |
| Copy writing | $0.004 | Kimi K2.5 |
| **TOTAL** | **~$0.85** | |

vs. Vertex AI VTON path: ~$3.40/product (4x more expensive)

---

## Appendix: File Quick Reference

| Purpose | File |
|---------|------|
| Main pipeline CLI | `8_design_director_pipeline.py` |
| Worker (polls Supabase) | `worker.py` |
| Pipeline adapter | `pipeline_adapter.py` |
| Design Director | `design_director/director.py` |
| System prompts | `design_director/prompts.py` |
| Data models | `design_director/models.py` |
| Rules loader | `design_director/rules_loader.py` |
| kie.ai generator | `asset_pipeline/kie_generator.py` |
| Gemini generator | `asset_pipeline/generator.py` |
| Front compositor | `asset_pipeline/front_compositor.py` |
| VTON generator | `asset_pipeline/vton_generator.py` |
| Ghost compositor | `asset_pipeline/ghost_front_compositor.py` |
| Video generator | `asset_pipeline/kie_video_generator.py` |
| Listing producer | `image_producer/producer.py` |
| AOP compositing | `image_producer/aop_compositing.py` |
| Shopify client | `suppliers/shopify_client.py` |
| Shopify auth | `suppliers/shopify_auth.py` |
| Size chart widget | `suppliers/shopify_size_chart.py` |
| Supplier database | `suppliers/database.py` |
| Copy generator | `content_producer/copy_generator.py` |
| Postiz client | `content_producer/postiz_client.py` |
| Supabase client | `supabase_client.py` |
| Sync to Supabase | `tools/sync_to_supabase.py` |
| Shopify publish | `tools/shopify_publish.py` |
| Fix Shopify | `tools/fix_shopify_products.py` |
| Batch lifestyle+video | `tools/batch_lifestyle_video.py` |
| V3 listings two-step | `tools/generate_v3_listings_twostep.py` |
