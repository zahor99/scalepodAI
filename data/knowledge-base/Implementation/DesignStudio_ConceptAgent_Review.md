# Design Studio: Concept Agent -> Python Pipeline Integration Review

**Date:** 2026-03-05

## Architecture Summary

```
Dashboard (Next.js)              Tool Server (FastAPI :8100)        Python Pipeline
---------------------           --------------------------         -----------------
chat-panel.tsx                   endpoints/plan.py                  pipeline_adapter.py
  -> POST /api/chat/design        -> /tools/generate_plan             -> run_plan_stage()
    (Kimi K2.5 LLM)               -> /tools/generate_all_artwork     -> run_asset_stage()
    (agent routing)                -> /tools/generate_copy            -> run_production_stage()
    (tool execution)               -> /tools/publish                  -> publish_to_etsy()
```

## 5-Agent Pipeline Status

| Agent | Status Triggers | Tools | Integration Status |
|-------|----------------|-------|--------------------|
| **Concierge** | `null`, `pending` | `suggest_niches`, `create_product` | **Direct Supabase** -- no HTTP bridge needed |
| **Design Director** | `planning`, `plan_ready` | `generate_plan`, `edit_area_prompt`, `edit_palette` | **HTTP -> plan_service -> pipeline_adapter** |
| **Asset Producer** | `concept_approved`, `generating`, `uploading`, `mockups_ready` | `generate_all_artwork`, `regenerate_area` | **HTTP -> artwork_service -> pipeline_adapter** |
| **Listing Producer** | `production_approved`, `copy_pricing`, `listing_images`, `draft` | `generate_copy`, `calculate_pricing`, `generate_listing_images`, `regenerate_listing_slot`, `publish` | **HTTP -> production_service -> pipeline_adapter** |
| **Published** | `approved`, `publishing`, `published` | none | Display-only |

## Cloud Supabase Integration -- Reads & Writes

**Everything points to cloud Supabase.**

- `prototype/.env` sets `SUPABASE_URL=https://jtptaswggfdgzmuifnzi.supabase.co` -- both `tool_server/config.py` and `supabase_client.py` read from this env var
- The tool server's `db.py` singleton uses `settings.supabase_url` from config, which reads the `.env`
- The dashboard's Supabase client reads from `dashboard/.env.local` (also cloud)
- Studio context subscribes to Realtime on the same cloud DB

### Where data is saved at each stage

| Stage | Cloud Supabase Write | Local File Write | Storage Upload |
|-------|---------------------|-----------------|----------------|
| **Create product** (Concierge) | `products` INSERT with status, theme, product_type, niche_slug | None | None |
| **Generate plan** (Design Director) | `products.design_plan` JSONB + status->`plan_ready` | `plan.json` in output dir | None |
| **Edit area/palette** | `products.design_plan` JSONB update | None | None |
| **Generate artwork** (Asset Producer) | status->`mockups_ready`, `printify_product_id`, `output_dir`, `image_urls` | PNGs in output dir + `result.json` | Artwork -> Storage/Drive, Mockups -> Storage/Drive |
| **Generate copy** (Listing Producer) | `products.title`, `.description`, `.tags` | `copy.json` | None |
| **Calculate pricing** | `products.sale_price`, `.base_price`, `.margin_pct`, `.fee_breakdown` | `pricing.json` | None |
| **Listing images** | `image_urls.listing` entries | PNGs in `listing_images/` | Each slot -> Storage/Drive |
| **Publish** | status->`published` | None | None |

**All stages write to cloud Supabase first (source of truth), then optionally write local files.**

## Multi-Product Type Support

| Product Type | YAML Rules | Concierge Mapping | Plan Service | Asset Service | Production Service |
|-------------|-----------|-------------------|-------------|---------------|-------------------|
| `aop_hoodie` | `aop_hoodie.yaml` | `hoodie` -> `aop_hoodie` | Pass-through via `load_rules()` | Printify path (BP450) | Printify path + VTON listing images |
| `aop_sweatshirt` | `aop_sweatshirt.yaml` | `sweatshirt` -> `aop_sweatshirt` | Same | Printify path (BP449) | Same |
| `aop_tshirt` | `aop_tshirt.yaml` | `tshirt` -> `aop_tshirt` | Same | Printify path (BP1242) | Same |
| `aop_dress_*` (10 types) | `aop_dress_*.yaml` | `dress_*` -> `aop_dress_*` | Same | **Non-Printify path** (compositing preview) | Non-Printify path (white-base compositing) |
| `pp_*` (PeaPrint, 6 types) | `pp_*.yaml` | `pp_*` -> `pp_*`? | Same | Non-Printify path | Non-Printify path |

## Issues Found

### 1. Concierge product_type mapping -- incomplete for dresses and PeaPrint

**File:** `dashboard/src/lib/agent-tools.ts:154-157`

The mapping was:
```typescript
const productType = productCategory === "hoodie" ? "aop_hoodie"
  : productCategory === "sweatshirt" ? "aop_sweatshirt"
  : productCategory === "tshirt" ? "aop_tshirt"
  : `aop_${productCategory}`;
```

This fallback `aop_${productCategory}` works for dresses **only if** `supplier_products.product_category` is stored as `dress_elegant`, `dress_slip`, etc. But PeaPrint products (prefix `pp_`) would get incorrectly mapped to `aop_pp_blazer_casual` instead of `pp_blazer_casual`. It depends on what's actually in the `supplier_products` table -- if PeaPrint products store `product_category` with the `pp_` prefix already stripped, this breaks.

**STATUS: FIXED** (2026-03-05) — Added `startsWith("pp_")` / `startsWith("aop_")` guard: categories that already carry the correct prefix are passed through unchanged. Only bare categories (`hoodie`, `sweatshirt`, `tshirt`, or Yoycol-style `dress_elegant`) get the `aop_` prefix prepended.

### 2. Design Director system prompt is still hoodie-centric

**File:** `dashboard/src/lib/agent-configs.ts:53-67`

The Design Director prompt mentioned "front is the hero scene, back is complementary, sleeves are accent patterns" -- this is hoodie/sweatshirt-specific. Dress products (`aop_dress_*`) have different area layouts (front, back, sleeves, collar -- full_coverage_pattern role, not hero_scene). The LLM will receive misleading instructions for dress products.

**STATUS: FIXED** (2026-03-05) — Added `PRODUCT-TYPE AREA RULES` section to the Design Director system prompt with per-type guidance: hoodies use hero/complementary, dresses/blazers use full_coverage_pattern (edge-to-edge textile). Also fixed the Asset Producer prompt which had the same hoodie-centric language.

### 3. Tool server `regenerate_area` uses Gemini directly -- bypasses fallback chain

**File:** `prototype/tool_server/services/artwork_service.py:186-192`

`regenerate_area()` imports from `asset_pipeline.generator.generate_design` which is the Gemini generator. It doesn't go through the kie.ai -> Gemini -> GoAPI fallback chain that the main pipeline uses. Single-area regeneration will always use Gemini regardless of `IMAGE_PROVIDER` env var.

**STATUS: NOT A BUG** (2026-03-05) — On inspection, `asset_pipeline.generator.generate_design` IS the chain dispatcher. It reads `IMAGE_PROVIDER` env var and routes to kie.ai → Gemini → GoAPI with automatic fallback. The import is correct. The `artwork_service.generate_all()` method also sets/restores `IMAGE_PROVIDER` env var when `force_provider` is passed.

### 4. Listing image slot map is hoodie-specific

**File:** `prototype/tool_server/services/production_service.py:404-415`

`_SLOT_MAP` hardcoded hoodie-specific slot names (`03_ghost_front_hoodup`, `04_ghost_back_hoodup`). Sweatshirts and tees use different slot 03/04 (3/4 quarter angle instead of hood up). Dresses have an entirely different slot system. `regenerate_listing_slot` will map to wrong filenames for non-hoodie products.

**STATUS: FIXED** (2026-03-05) — Replaced static `_SLOT_MAP` with `_get_slot_map(product_type)` that reads slot keys from `aop_compositing.COMPOSITING_SLOTS_BY_TYPE` (the canonical source of truth for all 25+ product types). `_slot_number_to_name()` now accepts `product_type` parameter. `regenerate_listing_slot()` fetches the product to get the type.

### 5. `production_service.generate_listing_images` uses Printify path only -- no non-Printify branching

**File:** `prototype/tool_server/services/production_service.py:188`

It imported `produce_listing_images` from the Printify-oriented `image_producer.producer`. But `pipeline_adapter.run_production_stage()` (lines 868-887) has a separate code path for non-Printify products that uses `produce_aop_composited_images`. The tool server's individual `generate_listing_images` endpoint **did NOT have this branching logic** -- it always called `produce_listing_images`, which expects Printify mockups. Dress products called through the Design Studio would fail at listing image generation.

**STATUS: FIXED** (2026-03-05) — Added `_is_non_printify_product(rules)` check (imported from `pipeline_adapter`). Non-Printify products now route to `produce_aop_composited_images` (white-base compositing system). Printify products continue using `produce_listing_images` with VTON/mockups. Also fixed `is_aop` check to include `pp_*` types.

### 6. `production_service.generate_copy` releases lock without setting final status

**File:** `prototype/tool_server/services/production_service.py:80`

`lock_service.release(product_id, db=db)` doesn't pass `final_status`. Compare to `plan_service.py:76` which properly sets `final_status="plan_ready"`. After copy generation the product status stays at `copy_pricing`, which is likely fine since pricing + listing images follow, but it's inconsistent.

**STATUS: NOT A BUG** — By design. The copy stage is not a terminal stage — pricing and listing images follow immediately. Staying at `copy_pricing` is the expected behavior. The plan stage sets `final_status="plan_ready"` because it IS terminal before the user approval gate.

## Summary

**Overall integration is solid** -- the 5-agent Design Studio correctly routes through tool_server -> Python pipeline -> cloud Supabase for all reads and writes. The main 3 product types (hoodie, sweatshirt, tee) are well-supported end-to-end.

### Key Gaps — Resolution Status

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Concierge `pp_*` mapping | High | **FIXED** — prefix guard in `agent-tools.ts` |
| 2 | Design Director prompt hoodie-centric | Medium | **FIXED** — product-type area rules added to `agent-configs.ts` |
| 3 | `regenerate_area` bypasses fallback chain | N/A | **NOT A BUG** — `generator.py` IS the chain dispatcher |
| 4 | Slot map hoodie-specific | High | **FIXED** — dynamic `_get_slot_map(product_type)` in `production_service.py` |
| 5 | Listing images no non-Printify branch | Critical | **FIXED** — compositing path added to `production_service.py` |
| 6 | Lock release without final_status | Low | **NOT A BUG** — by design (non-terminal stage) |

### Key Files Referenced

| File | Purpose |
|------|---------|
| `dashboard/src/lib/agent-configs.ts` | 5 agent definitions with system prompts and status triggers |
| `dashboard/src/lib/agent-tools.ts` | Tool definitions -- Concierge (direct Supabase), others (HTTP bridge) |
| `dashboard/src/app/api/chat/design/route.ts` | Chat API route -- agent selection, tool resolution, Kimi K2.5 streaming |
| `dashboard/src/components/studio/studio-context.tsx` | Client-side state, Realtime subscription, handoff briefings |
| `prototype/tool_server/__init__.py` | FastAPI app factory, mounts all endpoint routers |
| `prototype/tool_server/config.py` | Config from `.env` -- Supabase URL, API keys |
| `prototype/tool_server/services/db.py` | Supabase client singleton (thread-safe) |
| `prototype/tool_server/services/plan_service.py` | Plan generation/editing -- wraps director.generate_plan() |
| `prototype/tool_server/services/artwork_service.py` | Artwork generation -- wraps pipeline_adapter.run_asset_stage() |
| `prototype/tool_server/services/production_service.py` | Copy, pricing, listing images, publish |
| `prototype/pipeline_adapter.py` | Bridge between worker/tool_server and Python pipeline |
| `prototype/rules/*.yaml` | 25 product type YAML rules files |
