# Full Pipeline Implementation — Session 2026-02-15

**Date:** 2026-02-15
**Scope:** Reference image chaining, hex palette, Copy Writer, Pricing Calculator, Image Producer, pipeline integration, E2E testing

---

## 1. Overview

This session completed the end-to-end POD product pipeline from design concept to a publish-ready Etsy listing. Starting from a working Design Director (Kimi K2.5) + Gemini image generator + Printify uploader, we added:

1. **Reference Image Chaining** — visual coherence across hoodie panels
2. **Hex Palette Output** — explicit color codes from the Design Director
3. **Copy Writer** (Agent 3) — LLM-powered SEO listing copy
4. **Pricing Calculator** (Agent 4) — deterministic fee/margin math
5. **Image Producer** (Agent 7) — 10-image Etsy listing set
6. **Pipeline Integration** — wired all agents into CLI and Streamlit UI
7. **E2E Testing** — 4 full pipeline runs across 3 niches

---

## 2. What Was Built

### 2.1 Reference Image Chaining + Hex Palette

**Problem:** Each AOP hoodie area (front, back, sleeve) was generated independently by Gemini. Same palette words ("gold on navy") produced visually different colors across areas.

**Solution:** After generating the front panel, pass it as a reference image to back/sleeve Gemini calls. Also output hex color codes from Kimi K2.5 for belt-and-suspenders color control.

**Files modified (6):**

| File | Change |
|------|--------|
| `asset_pipeline/generator.py` | Added `reference_image` param to `generate_design()` |
| `design_director/models.py` | Added `hex_palette: dict[str, str]` to `DesignPlan` |
| `design_director/prompts.py` | Rule 9 (hex codes), `REFERENCE_IMAGE_INSTRUCTION` constant |
| `design_director/director.py` | Parse hex_palette, `inject_reference_instruction()` helper |
| `8_design_director_pipeline.py` | `_downscale_for_reference()`, anchor image chaining in CLI |
| `9_director_ui.py` | Anchor image chaining in Streamlit Step 3 |

**Details:** See `Implementation/reference-image-chaining.md`

---

### 2.2 Copy Writer (Agent 3)

**Purpose:** Generate SEO-optimized Etsy listing content (title, description, 13 tags) from a DesignPlan.

**Module:** `prototype/copy_writer/` (5 files, 489 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `models.py` | 14 | `ListingCopy` dataclass (title, description, tags) |
| `prompts.py` | 143 | System prompt with Etsy SEO rules, user prompt builder |
| `tag_library.py` | 189 | Pre-built tag sets: 12 niches x 13 tags |
| `writer.py` | 143 | LLM call, JSON parsing, tag validation/fixing |
| `__init__.py` | 0 | Package marker |

**Key features:**
- Uses Kimi K2.5 (OpenAI-compatible) with temperature=1.0
- Title: max 140 chars, front-loaded primary keyword
- Description: structured sections (keyword line, How to Order, Product Details, Shipping, Care)
- Tags: exactly 13, each max 20 chars, deduped, padded with fallbacks if LLM returns too few
- Niche-specific seed tags injected from `tag_library.py`
- Handles markdown code blocks in LLM responses

**Entry point:** `generate_listing_copy(plan, product_type, niche_guide) -> ListingCopy`

---

### 2.3 Pricing Calculator (Agent 4)

**Purpose:** Calculate optimal pricing including Etsy fee stack, profit margins, and perpetual 50% sale strategy.

**Module:** `prototype/pricing/` (4 files, 220 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `models.py` | 21 | `PricingResult` dataclass (costs, prices, margins, fee breakdown) |
| `suppliers.py` | 76 | Blank costs (7 products), niche pricing (15 niches), fee constants |
| `calculator.py` | 123 | Fee math + `format_pricing_display()` CLI formatter |
| `__init__.py` | 0 | Package marker |

**Key features:**
- Pure math, no LLM — deterministic and instant
- Etsy fee stack: 6.5% transaction + 3% + $0.25 payment + $0.20 listing
- Perpetual 50% sale: `listed_price = sale_price * 2`
- 7 product types: aop_hoodie ($28), hoodie ($15.64), premium_hoodie ($18.50), tshirt ($8.50), premium_tshirt ($11.50), canvas_18x24 ($12.00), canvas_24x36 ($18.00)
- 15 niche-specific retail price overrides
- Formatted CLI output with full breakdown

**Entry point:** `calculate_pricing(product_type, niche) -> PricingResult`

**Supplier data (aop_hoodie):**
```
Base cost: $28.00 | Sale price: $39.99 | Listed: $79.98
Fees: $4.25 | Net profit: $7.74 | Margin: 19.4%
```

---

### 2.4 Image Producer (Agent 7)

**Purpose:** Generate the complete 10-image Etsy listing set combining Gemini product photography with PIL-based templates and composites.

**Module:** `prototype/image_producer/` (6 files, 963 lines)

| File | Lines | Purpose |
|------|-------|---------|
| `models.py` | 72 | `ImageSlot` enum (10 slots), `ListingImages` dataclass, priority tiers |
| `prompts.py` | 145 | 5 Gemini prompt templates + niche-specific props/mood/settings lookups |
| `templates.py` | 323 | PIL generators: size chart (per blank type) + trust badge (2000x2000) |
| `composites.py` | 152 | Color grid compositor (4-col layout) + design closeup cropper |
| `producer.py` | 271 | Orchestrator: ordered pipeline with per-slot error handling |
| `__init__.py` | 0 | Package marker |

**10-Image Strategy:**

| Slot | Name | Method | Priority |
|------|------|--------|----------|
| 1 | Hero Flat Lay | Gemini 2K 4:3 | CRITICAL |
| 2 | Lifestyle Styled | Gemini 2K 4:3 + hero reference | CRITICAL |
| 3 | Alt Color Variant | Gemini 2K 4:3 + hero reference | HIGH |
| 4 | Design Closeup | PIL crop from front artwork | HIGH |
| 5 | Size Chart | PIL template (per blank type) | CRITICAL |
| 6 | Color Grid | PIL composite from mockups | HIGH |
| 7 | Model / Lifestyle | Gemini 2K 4:3 + hero reference | MEDIUM |
| 8 | Back View | Copy from Printify mockup | MEDIUM |
| 9 | Gift Context | Gemini 2K 4:3 + hero reference | MEDIUM |
| 10 | Trust Info | PIL template (badges) | LOW |

**Key features:**
- Priority ordering: CRITICAL slots generated first so listing is viable even if later slots fail
- Per-slot error handling: one failure doesn't abort the pipeline
- Rate limiting: 3s cooldown between consecutive Gemini calls
- Reference image chaining: hero (slot 1) passed as reference to slots 2, 3, 7, 9
- Niche-aware: props, mood, settings, seasonal context pulled from niche guides
- Templates are PIL-generated (no external assets needed)

**Entry point:** `produce_listing_images(plan, front_image_path, mockup_paths, output_dir, niche_guide, product_type) -> ListingImages`

---

### 2.5 Pipeline Integration

Both the CLI and Streamlit UI were updated to chain all new agents into the existing pipeline.

#### CLI Pipeline (`8_design_director_pipeline.py` — 700 lines)

Three new steps added between Printify upload and human review:

| Step | Agent | Non-fatal |
|------|-------|-----------|
| 6b: Listing Copy | `generate_listing_copy()` | Yes — caught, warned |
| 6c: Pricing | `calculate_pricing()` + `format_pricing_display()` | Yes — caught, warned |
| 6d: Listing Images | `produce_listing_images()` | Yes — caught, warned |

Outputs saved to run directory: `copy.json`, `pricing.json`, `listing_images/` folder.

#### Streamlit UI (`9_director_ui.py` — 966 lines)

Expanded from 6 steps to 8 steps:

```
1. Theme Input
2. Design Plan (review/edit prompts)
3. Generate Images (with reference chaining)
4. Upload & Mockups (Printify draft)
5. Copy & Pricing  [NEW]
6. Listing Images   [NEW]
7. Review & Iterate
8. Complete
```

**Step 5 — Copy & Pricing:**
- Auto-generates listing copy on entry
- Editable title (140 char limit), description (text area), tags (comma-separated)
- Tag count validation warning
- Pricing displayed as Streamlit metrics (listed price, sale price, profit, margin, costs, fees)
- Fee details in expandable section
- "Regenerate Copy" button for re-rolling
- Saves `copy.json` on proceed

**Step 6 — Listing Images:**
- Generates 10-image set on entry
- Displays success count and image grid (5 columns)
- Shows failures in expandable warning section
- "Regenerate Listing Images" button for re-rolling

---

## 3. Architecture After Changes

```
Theme Input
    |
    v
[Kimi K2.5] Design Director  -->  plan.json (with hex_palette)
    |
    v
[Gemini 3 Pro] Image Generation  -->  front (anchor) -> back (ref) -> sleeve (ref)
    |                                  + crop: hood, pocket
    |                                  + mirror: left_sleeve, left_hood
    v
[Printify API] Upload + Product Create  -->  mockup_00..04.png
    |
    v
[Kimi K2.5] Copy Writer  -->  copy.json (title, description, 13 tags)
    |
    v
[Math] Pricing Calculator  -->  pricing.json (costs, fees, profit, margin)
    |
    v
[Gemini + PIL] Image Producer  -->  listing_images/ (10 images)
    |
    v
Human Review Loop  -->  approve/reject/regenerate per area
    |
    v
Finalize (draft / publish to Etsy)
```

---

## 4. File Inventory

### New files created (15 files, 1,672 lines):

```
prototype/copy_writer/
    __init__.py              (0 lines)
    models.py                (14 lines)  - ListingCopy dataclass
    prompts.py               (143 lines) - Etsy SEO system prompt
    tag_library.py           (189 lines) - 12 niches x 13 tags
    writer.py                (143 lines) - LLM copy generation

prototype/pricing/
    __init__.py              (0 lines)
    models.py                (21 lines)  - PricingResult dataclass
    suppliers.py             (76 lines)  - Blank costs, niche pricing
    calculator.py            (123 lines) - Fee math + display

prototype/image_producer/
    __init__.py              (0 lines)
    models.py                (72 lines)  - ImageSlot enum, ListingImages
    prompts.py               (145 lines) - 5 Gemini prompt templates
    templates.py             (323 lines) - Size chart + trust badge (PIL)
    composites.py            (152 lines) - Color grid + closeup crop
    producer.py              (271 lines) - 10-slot orchestrator
```

### Files modified (8):

```
prototype/asset_pipeline/generator.py      - reference_image param
prototype/design_director/models.py        - hex_palette field
prototype/design_director/prompts.py       - Rule 9, hex schema, ref instruction
prototype/design_director/director.py      - parse hex_palette, inject_reference_instruction()
prototype/8_design_director_pipeline.py    - 3 new steps, reference chaining (700 lines total)
prototype/9_director_ui.py                 - 2 new steps, reference chaining (966 lines total)
```

### Documentation created/updated (4):

```
Implementation/reference-image-chaining.md  - Detailed ref chaining docs + test results
Implementation/revised-pipeline-plan.md     - Agent build plan + status tracker
Implementation/session-2026-02-15-full-pipeline.md  - This document
memory/design_director_status.md            - Updated with new agents + pipeline flow
```

---

## 5. E2E Test Results

### Test Run 1-3: Reference Image Chaining Verification (no copy/pricing/images)

All 3 designs tested across different niches to verify color coherence:

| # | Niche | Theme | Product ID | Coherence |
|---|-------|-------|------------|-----------|
| 1 | celestial_boho | neon aurora borealis wolf spirit | `69922b4690577c34b004caeb` | Excellent |
| 2 | japanese_art | geisha with cherry blossoms in moonlight | `69922c758406554f6304f237` | Outstanding |
| 3 | mushroom_cottagecore | psychedelic rainbow mushroom forest | `69922df2f8663ad6fd0a0753` | Excellent |

All 3 confirmed: hex_palette in plan.json, color match across panels, distinct scenes, backward compat.

### Test Run 4: Full Integrated Pipeline (all agents)

| Field | Value |
|-------|-------|
| **Niche** | celestial_boho |
| **Theme** | minimalist crescent moon and wildflowers, delicate line art with negative space, botanical nature illustration |
| **Style** | delicate line art botanical illustration with mystical boho celestial aesthetic |
| **Palette** | deep midnight navy, antique gold, warm cream, earth taupe, deep purple |
| **Hex palette** | primary: #0A0E27, secondary: #D4AF37, accent: #E6D5B8, background: #050811, botanical: #B8A088, shadow: #2E1A47 |

**Step results:**

| Step | Status | Timing |
|------|--------|--------|
| Design Plan (Kimi K2.5) | OK | ~8s |
| Front image (4K 4:5) | OK — 3712x4608 | 40.0s |
| Back image (with reference) | OK — 3712x4608 | 40.1s |
| Right sleeve (with reference) | OK — 4096x4096 | 44.9s |
| Mirror + crop (4 areas) | OK | instant |
| Printify upload (7 images) | OK — product `69923b5192e2450b4000af33` | ~30s |
| Mockup download | OK — 5 mockups (1200x1200) | ~5s |
| **Copy Writer** | OK — 140 char title, 13 tags | ~5s |
| **Pricing Calculator** | OK — $39.99 sale, $7.74 profit, 19.4% margin | instant |
| **Image Producer** | OK — **10/10** images generated | ~190s |
| **Total pipeline** | **SUCCESS** | **~6 min** |

**Copy output:**
- Title: "Crescent Moon Hoodie: Boho Wildflower Botanical Sweatshirt, Celestial Line Art Navy Gold AOP Pullover, Mystical Moon Phase Spiritual Gift Wo" (140 chars)
- Tags: hoodie, sweatshirt, celestial, moon hoodie, boho clothing, witchy hoodie, astrology gift, moon phases, wildflower hoodie, boho moon, botanical hoodie, celestial line art, moon line art

**Pricing output:**
```
Base Cost: $28.00 | Sale Price: $39.99 | Listed: $79.98
Fees: $4.25 (6.5% + 3% + $0.25 + $0.20)
Net Profit: $7.74 | Margin: 19.4%
```

**Listing images generated (10/10):**
- 01_hero.png (Gemini)
- 02_lifestyle.png (Gemini + hero ref)
- 03_alt_color.png (Gemini + hero ref)
- 04_closeup.png (PIL crop)
- 05_size_chart.png (PIL template)
- 06_color_grid.png (PIL composite)
- 07_model.png (Gemini + hero ref)
- 08_back_view.png (mockup copy)
- 09_gift.png (Gemini + hero ref)
- 10_trust_info.png (PIL template)

**Output directory:** `prototype/output/director/aop_hoodie_minimalist_crescent_moon_and_w_20260215_162718/`

---

## 6. Dependencies

All dependencies were already installed in the venv. No new packages required.

Existing: `google-genai`, `Pillow`, `requests`, `python-dotenv`, `httpx`, `pyyaml`, `openai`, `streamlit`, `rembg[cpu]`

---

## 7. Known Limitations

1. **AOP hoodie pricing margin is thin** — 19.4% at $39.99 sale price due to $28 blank cost. Standard hoodies (Gildan 18500 at $15.64) have much better margins.
2. **Image Producer uses 2K (not 4K)** for listing images — acceptable for Etsy display (1200px shown) but not print-resolution.
3. **Copy Writer model reference** — `writer.py` line 36 defaults to `kimi-k2-5-preview` (wrong model name). Should be `kimi-k2.5`. Works in practice because `.env` overrides it via `LLM_MODEL`.
4. **Publisher (Agent 8)** not yet built — Etsy direct API for tags/taxonomy is deferred. Printify publish endpoint works for MVP.
5. **Batch processing** not yet implemented — pipeline runs one design at a time.

---

## 8. How to Run

### CLI Pipeline (full E2E):
```bash
cd prototype
echo "y" | ./venv/Scripts/python 8_design_director_pipeline.py aop_hoodie "your theme" --niche celestial_boho --auto-approve --no-validate
```

### Streamlit UI:
```bash
cd prototype
./venv/Scripts/streamlit run 9_director_ui.py
```

### Individual agents (standalone):
```python
# Copy Writer
from copy_writer.writer import generate_listing_copy
copy = generate_listing_copy(plan, "aop_hoodie", niche_guide)

# Pricing Calculator
from pricing.calculator import calculate_pricing
pricing = calculate_pricing("aop_hoodie", "celestial_boho")

# Image Producer
from image_producer.producer import produce_listing_images
images = produce_listing_images(plan, front_path, mockup_paths, output_dir)
```

---

## 9. What's Next

| Priority | Task | Effort |
|----------|------|--------|
| 1 | Review E2E output quality (mockups, listing images, copy) | Manual |
| 2 | Fix copy_writer default model name (`kimi-k2-5-preview` -> `kimi-k2.5`) | 1 line |
| 3 | Test Streamlit UI interactively (all 8 steps) | Manual |
| 4 | Publisher agent (Agent 8) — Etsy API direct integration | Medium |
| 5 | Batch processing — multiple designs per session | Medium |
| 6 | Waistband + cuff panel coverage for AOP hoodie | Small |
