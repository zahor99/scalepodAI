# Devil's Advocate Pipeline Review: Full System Sync
**Date:** 2026-03-05
**Last updated:** 2026-03-05
**Scope:** Python pipeline + Supabase schema + Frontend-backend contract
**Sources:** 3 parallel review agents + manual cross-referencing

**Final scorecard:** 22 issues found → **18 FIXED**, **2 NOT A BUG**, **2 DEFERRED**, **1 ACCEPTED**

---

## CRITICAL Issues

### C1. ~~Compositing slot key mismatches — 5 product types get hoodie slots~~ ✅ FIXED

**Files:** `prototype/image_producer/aop_compositing.py:281-304` + `prototype/rules/pp_*.yaml`

**Fix:** Added 5 alias entries to `COMPOSITING_SLOTS_BY_TYPE` mapping YAML product_type values to correct slot dicts.

### C2. ~~`_find_dress_base()` only strips `aop_dress_` prefix — PeaPrint broken~~ ✅ FIXED

**File:** `prototype/pipeline_adapter.py:500`

**Fix:** Now strips both prefixes: `.removeprefix("aop_dress_").removeprefix("pp_dress_")`

### C3. ~~`publish()` crashes for non-Printify products~~ ✅ FIXED

**File:** `prototype/tool_server/services/production_service.py`

**Fix:** Added non-Printify guard that returns `{"published": false, "reason": "non_printify_product", ...}` with a helpful message instead of crashing.

### C4. ~~`"approved"` status in TypeScript but NOT in DB CHECK constraint~~ ✅ FIXED

**Fix:** Migration `20260305000001_sync_check_constraints.sql` adds both `"approved"` and `"publishing"` to the status CHECK constraint. Applied to cloud Supabase.

### C5. ~~`printify_id` typo in product_status endpoint — wrong column name~~ ✅ FIXED

**File:** `prototype/tool_server/endpoints/query.py:23`

**Fix:** Changed `printify_id` → `printify_product_id`.

### C6. ~~`api_cost_log` CHECK constraint rejects `"kie"` provider~~ ✅ FIXED

**Fix:** Migration `20260305000001_sync_check_constraints.sql` adds `"kie"` to the provider CHECK constraint. Applied to cloud Supabase.

### C7. ~~Canvas handoff reads `plan.areas` (array) but Python writes `plan.area_prompts` (dict)~~ ✅ FIXED

**File:** `dashboard/src/components/studio/studio-context.tsx`

**Fix:** Changed to read `plan.area_prompts` as a dict with `Object.keys()` for area count. Falls back to `plan.areas` for backwards compat.

---

## HIGH Issues

### H1. ~~Three new niches missing from `NICHE_PRICING`~~ ✅ FIXED

**File:** `prototype/pricing/suppliers.py`

**Fix:** Added `cottagecore`, `vintage_floral`, and `whimsigoth` to `NICHE_PRICING` with full dress/blazer product type coverage. Pricing modeled after similar aesthetic niches (cottagecore≈mushroom_cottagecore, vintage_floral≈dark_floral, whimsigoth≈gothic).

### H2. ~~Blazer YAML composition roles may not be `full_coverage_pattern`~~ ❌ NOT A BUG

**Files:** `prototype/rules/pp_blazer_casual.yaml` and variants

Investigation showed blazers use `front_right`/`front_left` (not `front`), and both DO have `full_coverage_pattern` role. False alarm from cross-reference check that looked for wrong area key.

### H3. ~~Cost logging wrong provider for non-Printify products~~ ✅ FIXED

**File:** `prototype/tool_server/services/production_service.py`

**Fix:** 3-way cost logging: non-Printify→`gemini/$0.03`, AOP→`vertex_vton/$0.06`, non-AOP→`gemini/$0.10`.

### H4. ~~`force_provider` enum missing `"kie"` — primary provider~~ ✅ FIXED

**Files:** `dashboard/src/lib/agent-tools.ts:278`, `prototype/tool_server/schemas/artwork.py:10`

**Fix:** Added `"kie"` to both Zod enum and Pydantic Literal.

### H5. ~~`PlanStage` canvas edit writes directly to Supabase, bypassing lock~~ ✅ FIXED

**File:** `dashboard/src/components/studio/stages/plan-stage.tsx`

**Fix:** Added `worker_claimed_at` check before save — if product is locked by worker, shows message and aborts edit.

### H6. ~~`base_price` column stores `listed_price`, not base cost~~ ✅ FIXED

**Files:** `pipeline_adapter.py:956`, `production_service.py:128`

**Fix:** Added `base_cost` column via migration `20260305000002`. Now both `base_price` (listed price) and `base_cost` (manufacturing cost) are stored. Updated `pipeline_adapter.py`, `production_service.py`, `sync_to_supabase.py`, and TypeScript types.

### H7. ~~`NicheGuide.difficulty` type mismatch: `integer` in DB, `string | null` in TypeScript~~ ✅ FIXED

**File:** `dashboard/src/lib/database.types.ts:79`

**Fix:** Changed `difficulty: string | null` → `difficulty: number`.

### H8. ~~`artwork_service.generate_all()` return shape doesn't match docstring~~ ✅ FIXED

**File:** `prototype/tool_server/services/artwork_service.py`

**Fix:** Return shape now matches docstring: `{"printify_product_id", "status", "area_count", "mockup_count"}`. No longer leaks `output_dir` filesystem path.

---

## MEDIUM Issues

### M1. ~~Dynamic slot map inherits C1 key mismatch~~ ✅ RESOLVED

Auto-resolved when C1 was fixed. `_get_slot_map(product_type)` now reads correct keys from `COMPOSITING_SLOTS_BY_TYPE`.

### M2. ~~`pp_blazer_casual_hero` and `_sleeves` variants — unclear purpose~~ ❌ NOT A BUG

**Investigation:** These are legitimate product type variants with distinct design strategies:
- `pp_blazer_casual_hero`: Back panel uses hero_scene (focal motif) instead of full_coverage_pattern
- `pp_blazer_casual_sleeves`: Only sleeves are patterned, body panels are solid color (fashion-forward contrast)
Both have complete YAML rules with proper generation orders and composition guidance.

### M3. ~~New niches may not be seeded in `niche_guides` DB table~~ ✅ FIXED

**Fix:** Migration `20260305000002` seeds 6 missing niches (`dark_floral`, `boho_floral`, `cottagecore`, `vintage_floral`, `whimsigoth`, `art_nouveau`) with display_name, difficulty, motifs, etsy_tags from their YAML files.

### M4. ~~`supabase_client.py` falls back to local Supabase URL~~ ✅ FIXED

**File:** `prototype/supabase_client.py:22`

**Fix:** Removed local fallback URL. Now raises `ValueError` if `SUPABASE_URL` env var is missing, with message "Local Supabase is no longer used."

### M5. ~~`SupplierProduct` TypeScript interface missing `printify_provider_id`~~ ✅ FIXED

**File:** `dashboard/src/lib/database.types.ts:65-72`

**Fix:** Added `printify_provider_id`, `supplier_type`, and `model_number` to SupplierProduct interface.

### M6. ~~SSE progress events defined but never sent~~ ✅ FIXED (misleading text removed)

`schemas/common.py` defines `ProgressEvent` but no endpoint sends it. All long-running ops block and return single JSON.

**Fix:** Removed misleading "canvas will update in real-time" from Asset Producer agent config. SSE streaming remains as future enhancement.

### M7. ~~`os.environ` mutation for `force_provider` is not thread-safe~~ ✅ FIXED

**File:** `artwork_service.py:66-82`

**Fix:** Wrapped `os.environ["IMAGE_PROVIDER"]` read/write in `threading.Lock()` to prevent race conditions between concurrent artwork calls.

---

## LOW Issues

### L1. ~~No agent handles `"failed"` status — falls back to Concierge~~ ✅ FIXED

**Fix:** Added `"failed"` to Concierge's `statusTriggers`. Added guidance in system prompt for handling failed products (check worker_error, offer reset or new creation).

### L2. `workflow_runs` table is never written to — dead schema

**Status:** DEFERRED. Table exists in migrations and is referenced by Edge Functions (`trigger-agent`, `printify-webhook`, `cron-cleanup`). Python worker doesn't use it. `SCHEMA_RESTRUCTURING_PLAN.md` already identifies it for dropping. Leaving in place until Edge Functions are refactored.

### L3. `design_templates` types are hoodie-centric (`pocket_crop_params`)

**Status:** DEFERRED. The `pocket_crop_params` field stores `{}` for non-hoodie products. Not actively causing errors — just a naming issue that could confuse future developers.

### L4. `sync_to_supabase.py` sets `shop_id: None` for all synced products

**Status:** ACCEPTED. `shop_id` is nullable in the schema. CLI sync path has no shop context. Personal use phase doesn't need multi-shop support. Will be addressed when multi-tenant is implemented.

---

## Summary Table

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| C1 | **CRITICAL** | 5 product types wrong compositing slot keys | ✅ FIXED |
| C2 | **CRITICAL** | `_find_dress_base()` only strips `aop_dress_` | ✅ FIXED |
| C3 | **CRITICAL** | `publish()` crashes for non-Printify | ✅ FIXED |
| C4 | **CRITICAL** | `"approved"` status not in DB enum | ✅ FIXED |
| C5 | **CRITICAL** | `printify_id` typo in query endpoint | ✅ FIXED |
| C6 | **CRITICAL** | `"kie"` provider rejected by DB constraint | ✅ FIXED |
| C7 | **CRITICAL** | Handoff reads `plan.areas` array, Python writes `area_prompts` dict | ✅ FIXED |
| H1 | **HIGH** | 3 niches missing from NICHE_PRICING | ✅ FIXED |
| H2 | **HIGH** | Blazer YAML composition roles may be wrong | ❌ NOT A BUG |
| H3 | **HIGH** | Cost logging wrong provider for non-Printify | ✅ FIXED |
| H4 | **HIGH** | `force_provider` enum missing `"kie"` | ✅ FIXED |
| H5 | **HIGH** | PlanStage edit bypasses lock | ✅ FIXED |
| H6 | **HIGH** | `base_price` stores listed_price semantically | ✅ FIXED |
| H7 | **HIGH** | `difficulty` type mismatch integer vs string | ✅ FIXED |
| H8 | **HIGH** | `generate_all` return shape wrong | ✅ FIXED |
| M1 | **MEDIUM** | Dynamic slot map inherits C1 | ✅ RESOLVED (C1 fixed) |
| M2 | **MEDIUM** | Blazer hero/sleeves variants unclear | ❌ NOT A BUG |
| M3 | **MEDIUM** | New niches not seeded in DB | ✅ FIXED |
| M4 | **MEDIUM** | Local Supabase URL fallback | ✅ FIXED |
| M5 | **MEDIUM** | Missing `printify_provider_id` in TS | ✅ FIXED |
| M6 | **MEDIUM** | SSE events defined but never sent | ✅ FIXED (text) |
| M7 | **MEDIUM** | `os.environ` mutation not thread-safe | ✅ FIXED |
| L1 | **LOW** | No agent for "failed" status | ✅ FIXED |
| L2 | **LOW** | `workflow_runs` table dead schema | DEFERRED |
| L3 | **LOW** | Template types hoodie-centric | DEFERRED |
| L4 | **LOW** | `shop_id: None` in sync tool | ACCEPTED |
