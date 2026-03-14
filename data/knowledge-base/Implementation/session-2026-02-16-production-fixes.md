# Session: Production Quality Fixes & E2E Testing
**Date:** 2026-02-16
**Duration:** ~4 hours across 2 context windows
**Focus:** Fix 15 issues found in initial E2E runs, achieve production-ready listing quality

---

## Session Overview

This session took the working prototype pipeline and fixed all quality issues discovered during the first batch of E2E test runs. Work was split across two context windows due to the volume of changes.

### Context Window 1 (Earlier)
- Monitored 3 background E2E runs, fixed `--auto-approve` not skipping plan confirmation
- Fixed Python stdout buffering for background tasks (`PYTHONUNBUFFERED=1`)
- Completed 3 initial E2E runs (minimalist, floral, whimsical celestial)
- User reviewed output and provided 8 feedback issues
- Implemented Round 1 fixes (8 issues): color grid, hero images, front/back similarity, sleeve silhouette, copy formatting, title format, tag quality, return policy
- Devil's advocate review found 3 critical + 9 minor issues, all fixed
- Completed 3 test runs verifying Round 1 fixes

### Context Window 2 (This Session)
- User reviewed Round 1 test output and provided 8 more feedback items
- Implemented Round 2 fixes (7 issues): keyword tags, word-boundary truncation, hero positioning, Printify title update, back view, alt color, color diversity
- Devil's advocate review — no critical issues found
- Completed 3 final E2E test runs across 3 different niches

---

## Round 1 Fixes (Context Window 1)

### Issues Found by User
1. **Color grid shows "XS" labels** — AOP has no color variants
2. **Hero images don't match actual design** — Gemini generates "inspired by" products
3. **Front/back nearly identical** — Reference image chaining copies too closely
4. **Sleeve renders garment silhouette** — Gemini draws clothing shapes
5. **Description formatting inconsistent** — Mixed bullet chars, varying return policy
6. **Title keyword-stuffing** — Comma-separated keyword dump
7. **Generic single-word tags** — "hoodie", "sweatshirt", "celestial"
8. **Return policy inconsistency** — "14 days" in one place, "24 hours" in another

### Fixes Implemented
| Fix | File(s) | Change |
|-----|---------|--------|
| Color grid → Design Details | `producer.py`, `composites.py` | 4-panel 2x2 grid showing actual artwork crops |
| AOP uses Printify mockups | `producer.py` | Hero/lifestyle/model use real mockups for AOP |
| Front/back similarity check | `director.py`, `pipeline.py` | numpy MSE comparison, 0.70 threshold, auto-regen |
| Sleeve prompt fix | `prompts.py` (design_director) | Rule 10: "flat rectangular textile swatch" |
| Description normalizer | `writer.py` | `_normalize_description()` standardizes formatting |
| Pipe-separated titles | `prompts.py` (copy_writer) | Pattern: `[Theme] [Product] \| [Style] \| [Occasion]` |
| Multi-word tag filter | `writer.py` | `" " in tag` filter, multi-word fallbacks |
| Return policy hardcoded | `prompts.py`, `writer.py` | Consistent 14-day policy in both prompt and post-processor |

### Devil's Advocate Findings (Round 1)
- Tag filter allowed single-word >12 char tags → Fixed to `" " in tag` only
- numpy import without fallback → Added try/except
- Return policy matching too narrow → Expanded to REFUND/RETURNS/EXCHANGE
- Case-sensitive AOP detection → Added `.lower()`

---

## Round 2 Fixes (This Session)

### Issues Found by User
1. **Tags chopped mid-word** — "celestial moon hoodi", "astrology gift for h"
2. **No keyword research in tags** — Generic tags instead of researched high-volume keywords
3. **Hero subject cropped at top** — Needs 15% lower positioning
4. **Printify title still debug format** — "DD - All-Over Print Hoodie - ..." on Etsy
5. **Back view shows front mockup** — Falls back to mockup_paths[0]
6. **Alt color is AI-generated fake** — Gemini creates non-existent product
7. **Same color schemes** — Purple/black across all designs

### Fixes Implemented

#### Fix 1: Tag Library Rebuild (`copy_writer/tag_library.py`)
- **Complete rewrite** using keyword research from 20 products in `research/product-launch-plan-2026-02-16.md`
- 15 niches × 13 tags = 195 validated tags
- All tags: 2+ words AND ≤20 characters
- New niches added: `whimsigoth`, `dark_cottagecore`, `wolf_nature`
- Data sourced from keyword volumes (22K "whimsigoth" to 90 "sacred geometry hoodie")

#### Fix 2: Word-Boundary Tag Truncation (`copy_writer/writer.py`)
- Replaced `tag.strip()[:20]` with word-boundary-aware truncation
- Finds last space within 20 chars, truncates there
- Single long words with no spaces → skipped entirely
- Added warning log when fallback padding is triggered

#### Fix 3: Hero Subject Positioning (`image_producer/prompts.py`)
- HERO_PROMPT: Added "product centered in the lower 70 percent of the frame with 20 percent clear margin above"
- MODEL_PROMPT: Added "15 percent headroom above the model"

#### Fix 4: Printify Title Update (`asset_pipeline/uploader.py` + `8_design_director_pipeline.py`)
- New function: `update_printify_product(product_id, title, description, tags)`
- Uses `PUT /v1/shops/{SHOP_ID}/products/{product_id}.json`
- Called after copy generation in pipeline, so Printify product gets SEO title + full description + tags
- Non-fatal error handling — pipeline continues even if update fails

#### Fix 5: Back View Fix (`image_producer/producer.py`)
- AOP: Uses `back_image_path` (actual back artwork) resized to 2000x2000
- Non-AOP: Uses `mockup_paths[3]` or `mockup_paths[-1]` as fallback
- No longer searches for "back" in mockup filenames (they're all front views)

#### Fix 6: Alt Color Replacement (`image_producer/producer.py`)
- AOP: Uses `mockup_paths[2]` (3rd Printify mockup — different color variant)
- Model slot updated to use `mockup_paths[3]` (4th mockup) to avoid overlap
- Non-AOP: Still uses Gemini for alternate color generation

#### Fix 7: Color Palette Diversity (`design_director/prompts.py`)
- Rule 11 in PLAN_SYSTEM_PROMPT: "Avoid defaulting to purple/black or navy/black"
- Suggests alternatives: deep teal, burnt sienna, forest green, burgundy, copper, sage, rust
- Requires 3+ distinct hues, background contrasting with accents

### AOP Mockup Index Allocation
```
mockup_paths[0] → Hero (slot 1)
mockup_paths[1] → Lifestyle (slot 2)
mockup_paths[2] → Alt Color (slot 3)
mockup_paths[3] → Model (slot 7) + Back View fallback (slot 8)
mockup_paths[4] → unused reserve
```
All guarded by `len(mockup_paths) > N` checks; falls through to Gemini on insufficient mockups.

### Devil's Advocate Findings (Round 2)
- New niche keys (whimsigoth, dark_cottagecore, wolf_nature) don't have YAML files → Non-issue: `NICHE_TAGS.get()` returns None gracefully, tags still generated by LLM
- Mockup index bounds → Handled: conditions check `> 2` and `> 3` before accessing
- Printify PUT endpoint → Verified correct: works on DRAFT products
- Tag fallback padding → Added warning log

---

## E2E Test Results

### Round 1 Tests (3 runs, Context Window 1)
All celestial_boho niche:
1. **Moonlit Forest Celestial Moths** — 10/10 images, similarity 0.85→0.37
2. **Celestial Wildflower Meadow** — 10/10 images
3. **Sun and Moon Garden** — 10/10 images, similarity 0.75→0.73

### Round 2 Tests (3 runs, This Session)
Three different niches for diversity testing:

#### Run 1: Whimsigoth Death Moth (celestial_boho)
- **Product ID:** `6993288281551e76130b7612`
- **Title:** `Whimsigoth Death Moth Crescent Hoodie | Dark Romantic Botanical Crystal All Over Print | Gothic Celestial Moon Gift For Her`
- **Palette:** midnight navy, deep burgundy, antique gold, dusty rose, forest green
- **Hex:** primary #1B263B, secondary #6B2737, accent #C9A227
- **Tags:** 13 multi-word (whimsigoth hoodie, death moth hoodie, celestial hoodie, etc.)
- **Similarity:** 0.44 (good)
- **Images:** 10/10
- **Printify title:** Updated with SEO title

#### Run 2: Dark Cottagecore Toadstool (mushroom_cottagecore)
- **Product ID:** `69932884cec1eb89690701c9`
- **Title:** `Enchanted Toadstool Forest Hoodie | Dark Cottagecore Mushroom All Over Print | Whimsical Fairy Snail Gift For Her`
- **Palette:** moss green, saddle brown, warm cream, earthy red, dark bark
- **Hex:** primary #3D5A45, secondary #8B4513, accent #F5E6C8
- **Tags:** 13 multi-word (mushroom hoodie, cottagecore mushroom, goblincore hoodie, etc.)
- **Similarity:** 0.88 → 0.62 (auto-regenerated)
- **Images:** 10/10
- **Printify title:** Updated with SEO title

#### Run 3: Japanese Koi Dragon (japanese_art)
- **Product ID:** `6993283a4ef083e0eb0efdee`
- **Title:** `Japanese Koi Dragon Hoodie | Traditional Ukiyo-e Woodblock Cherry Blossom Wave Print | Vintage Edo Streetwear Art Gift For Him Her`
- **Palette:** deep indigo, antique gold, crimson, rice paper cream, ink black
- **Hex:** primary #2E3A59, secondary #D4AF37, accent #C41E3A
- **Tags:** 13 multi-word (koi fish hoodie, japanese art hoodie, ukiyo-e aesthetic, etc.)
- **Similarity:** 0.00 (completely different)
- **Images:** 10/10
- **Printify title:** Updated with SEO title

### Color Diversity Validation
| Run | Primary | Secondary | Accent | Background |
|-----|---------|-----------|--------|------------|
| Death Moth | navy #1B263B | burgundy #6B2737 | gold #C9A227 | deep black #0D1117 |
| Toadstool | moss #3D5A45 | brown #8B4513 | cream #F5E6C8 | bark #2C2416 |
| Koi Dragon | indigo #2E3A59 | gold #D4AF37 | crimson #C41E3A | cream #F5F0E1 |

No duplicate purple/black schemes. Three genuinely distinct palettes.

---

## Files Modified (Complete List)

### Round 1 (8 files)
| File | Lines Changed | Summary |
|------|---------------|---------|
| `8_design_director_pipeline.py` | +30 | auto-approve, similarity check, is_aop, new params |
| `image_producer/producer.py` | +40 | AOP mockup branches, design details |
| `image_producer/composites.py` | +60 | `generate_design_details()` function |
| `copy_writer/prompts.py` | +20 | Pipe-separated titles, multi-word tag rules |
| `copy_writer/writer.py` | +40 | `_normalize_description()`, tag filter |
| `design_director/director.py` | +25 | `compute_image_similarity()` |
| `design_director/prompts.py` | +15 | REFERENCE_IMAGE_DIFFERENTIATION, Rule 10 |
| `copy_writer/tag_library.py` | minor | No changes in Round 1 |

### Round 2 (7 files)
| File | Lines Changed | Summary |
|------|---------------|---------|
| `copy_writer/tag_library.py` | full rewrite | 15 niches × 13 research-backed tags |
| `copy_writer/writer.py` | +15 | Word-boundary truncation, warning log |
| `image_producer/producer.py` | +25 | Back view artwork, alt color mockup, model index |
| `image_producer/prompts.py` | +5 | Hero positioning, model headroom |
| `asset_pipeline/uploader.py` | +40 | `update_printify_product()` function |
| `8_design_director_pipeline.py` | +15 | Import + call update_printify_product |
| `design_director/prompts.py` | +5 | Rule 11: color diversity |

---

## Total E2E Runs This Session: 9
- 3 initial runs (discovered issues)
- 3 Round 1 verification runs
- 3 Round 2 verification runs
- **All 90/90 listing images generated successfully**
- **All 9 Printify products created as DRAFT**

---

## Remaining Known Issues
1. **New niches without YAML** — `whimsigoth`, `dark_cottagecore`, `wolf_nature` in tag library but no `prototype/niches/*.yaml` files
2. **Publisher agent** (Agent 8) — Not yet built, using Printify publish for MVP
3. **Streamlit UI** — Not updated with Round 1/2 changes, may need adjustments
4. **Waistband/cuff panels** — Not yet using 3/10 available AOP print areas
5. **Batch processing** — Pipeline runs one at a time; no parallel batch support yet
6. **Etsy direct API** — Tags/taxonomy not yet pushed via Etsy API (only via Printify)

---

## Key Architectural Decisions

1. **Printify mockups over Gemini for AOP product photos** — Real mockups show the ACTUAL design, Gemini generates "inspired by" approximations
2. **Back artwork as back view** — Printify doesn't provide back-angle mockups, so we show the actual back panel artwork
3. **Keyword research as tag source** — 20 products × 13 keywords from volume/competition analysis, not LLM guesswork
4. **Word-boundary truncation** — Skip tags that can't fit complete words in 20 chars, rather than producing broken words
5. **Non-fatal Printify update** — If title/description update fails, pipeline continues with debug title
6. **Color diversity as LLM rule** — Rule 11 in system prompt guides palette selection without overriding user preferences
