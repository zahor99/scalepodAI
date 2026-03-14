# Revised Multi-Agent Pipeline — Implementation Plan

**Date:** 2026-02-15
**Goal:** Complete the end-to-end pipeline from design to published Etsy listing

## What's Already Built (Agents 1, 2, 5, 6)

| Component | Status | Location |
|-----------|--------|----------|
| Design Director (Agent 1+2) | Working | `prototype/design_director/` |
| Image Generator (Gemini) | Working + reference chaining | `prototype/asset_pipeline/generator.py` |
| Printify Creator (Agent 5) | Working | `prototype/asset_pipeline/uploader.py` |
| Mockup Downloader (Agent 6) | Working (part of Agent 5) | `prototype/asset_pipeline/uploader.py` |
| Review/Regenerate Loop | Working | `prototype/review/` |
| CLI Pipeline | Working | `prototype/8_design_director_pipeline.py` |
| Streamlit UI | Working | `prototype/9_director_ui.py` |

## What Needs to Be Built

### Agent 3 — Copy Writer (`prototype/copy_writer/`)

Generates SEO-optimized Etsy listing content from the DesignPlan + niche guide.

**Inputs:** `DesignPlan` (theme, style, palette, hex_palette), `NicheGuide`, product_type
**Outputs:** `ListingCopy` dataclass with title, description, 13 tags

**Implementation:**
- `prototype/copy_writer/__init__.py`
- `prototype/copy_writer/models.py` — `ListingCopy` dataclass (title, description, tags list)
- `prototype/copy_writer/writer.py` — LLM call to generate copy
- `prototype/copy_writer/prompts.py` — System prompt with title/desc/tag rules
- `prototype/copy_writer/tag_library.py` — Pre-built tag sets from Tags Reference Library (12 niches x 13 tags)

**Rules baked into prompt:**
- Title: max 140 chars, front-load primary keyword, format: `[Theme] [Product]: [Secondary], [Tertiary]`
- Description: structured sections (keyword line, How to Order, Product Details, Shipping, Care, Returns)
- Tags: exactly 13, each max 20 chars, 3 broad + 5 medium + 5 long-tail, no duplicate words across tags
- Pull niche-specific tags from tag_library when niche is provided
- Product details section varies by blank type (Gildan 18500 vs AOP vs Bella Canvas)

### Agent 4 — Pricing Calculator (`prototype/pricing/`)

Deterministic function (no LLM needed) that calculates optimal pricing.

**Inputs:** product_type, niche, blank_model (from suppliers data)
**Outputs:** `PricingResult` dataclass with base_cost, sale_price, listed_price, margin_pct, fee_breakdown

**Implementation:**
- `prototype/pricing/__init__.py`
- `prototype/pricing/models.py` — `PricingResult` dataclass
- `prototype/pricing/calculator.py` — Pure math: fee stack + margin calculation
- `prototype/pricing/suppliers.py` — Supplier cost data (from Pricing Strategy sheet)

**Formula:**
```
etsy_fees = sale_price * 0.065 + sale_price * 0.03 + 0.25 + 0.20
net_profit = sale_price - blank_cost - etsy_fees
margin_pct = net_profit / sale_price
listed_price = sale_price * 2  (perpetual 50% sale)
```

**Niche-aware:** Lookup suggested retail from pricing strategy table. If niche provided, use niche-specific pricing. Otherwise use product_type default.

### Agent 7 — Image Producer (`prototype/image_producer/`)

Generates the 10-image listing set using Gemini + Printify mockups + templates.

**Inputs:** design images (front/back), DesignPlan, product mockups, product_type, niche
**Outputs:** 10 listing images saved to output dir, `ListingImages` dataclass with paths

**Implementation:**
- `prototype/image_producer/__init__.py`
- `prototype/image_producer/models.py` — `ListingImages` dataclass, `ImageSlot` enum
- `prototype/image_producer/producer.py` — Orchestrator for all 10 slots
- `prototype/image_producer/prompts.py` — Per-slot Gemini prompt templates
- `prototype/image_producer/templates.py` — Size chart + trust badge template generators (PIL-based)
- `prototype/image_producer/composites.py` — Color grid compositor

**10-Image Strategy:**

| Slot | Type | Method | Priority |
|------|------|--------|----------|
| 1 | Hero Flat Lay | Gemini: product photo of hoodie with design on styled background | CRITICAL |
| 2 | Lifestyle Styled | Gemini: styled flat lay with niche-appropriate props | CRITICAL |
| 3 | Alt Color Variant | Gemini: same composition, different color hoodie | HIGH |
| 4 | Design Closeup | Crop from high-res front image (already have 4K) | HIGH |
| 5 | Size Chart | PIL template: generate once per blank type, reuse | CRITICAL |
| 6 | Color Grid | PIL composite: render mockups in grid with color labels | HIGH |
| 7 | Model/Lifestyle | Gemini: person wearing hoodie in lifestyle setting | MEDIUM |
| 8 | Back View | Already have from Printify mockups (mockup_01.png = back) | MEDIUM |
| 9 | Gift Context | Gemini: hoodie folded in gift box/tissue paper | MEDIUM |
| 10 | Trust/Info | PIL template: care instructions + quality badges | LOW |

**Key approach:**
- Slots 1, 2, 3, 7, 9 = Gemini generation (product photography prompts, NOT design art prompts)
- Slot 4 = intelligent crop from existing 4K front artwork
- Slots 5, 10 = PIL-generated templates (create once per blank type, reuse)
- Slot 6 = PIL composite from Printify mockups across colors
- Slot 8 = already exists from Printify mockup download
- Reference image chaining: pass the hero image (slot 1) as reference to slots 2, 3, 7, 9 for visual consistency

### Agent 8 — Publisher Enhancement (`prototype/publisher/`)

Extends existing Printify publish with Etsy API integration for tags/taxonomy.

**Inputs:** printify_product_id, ListingCopy, PricingResult, ListingImages
**Outputs:** etsy_listing_id, etsy_url

**Implementation:**
- `prototype/publisher/__init__.py`
- `prototype/publisher/etsy_api.py` — Etsy OAuth 2.0 client, tag/taxonomy update
- `prototype/publisher/publish.py` — Orchestrator: Printify publish → Etsy tag update → image upload

**Note:** Etsy OAuth 2.0 setup is a prerequisite. Needs API key registration. For MVP, can skip direct Etsy API and rely on Printify's publish endpoint (already working).

### Pipeline Orchestrator Update

Update `8_design_director_pipeline.py` and `9_director_ui.py` to chain the new agents:

```
[EXISTING] Design Director → Image Generator → Printify Creator + Mockups
    ↓ [NEW]
Copy Writer → Pricing Calculator → Image Producer → Publisher
```

## Implementation Status

| # | Component | Status | Date |
|---|-----------|--------|------|
| 1 | Copy Writer | COMPLETE | 2026-02-15 |
| 2 | Pricing Calculator | COMPLETE | 2026-02-15 |
| 3 | Image Producer | COMPLETE | 2026-02-15 |
| 4 | Pipeline Integration (CLI + Streamlit) | COMPLETE | 2026-02-15 |
| 5 | Publisher Enhancement | NOT STARTED | — |

### Pipeline Integration Details
- CLI (`8_design_director_pipeline.py`): Steps 6b (copy), 6c (pricing), 6d (listing images) added between Printify upload and review
- Streamlit (`9_director_ui.py`): 8-step flow — input → plan → generate → upload → copy_pricing → listing_images → review → done
- All new steps are non-fatal: failures are caught and reported without aborting the pipeline

## File Structure

```
prototype/
  copy_writer/
    __init__.py
    models.py          # ListingCopy dataclass
    writer.py          # LLM-powered copy generation
    prompts.py         # System prompt with Etsy listing rules
    tag_library.py     # Pre-built tag sets per niche
  pricing/
    __init__.py
    models.py          # PricingResult dataclass
    calculator.py      # Fee stack + margin math
    suppliers.py       # Blank costs per product type
  image_producer/
    __init__.py
    models.py          # ListingImages, ImageSlot
    producer.py        # 10-slot orchestrator
    prompts.py         # Per-slot Gemini prompt templates
    templates.py       # Size chart + trust badge (PIL)
    composites.py      # Color grid compositor (PIL)
  publisher/
    __init__.py
    etsy_api.py        # Etsy OAuth client (future)
    publish.py         # Publish orchestrator
```
