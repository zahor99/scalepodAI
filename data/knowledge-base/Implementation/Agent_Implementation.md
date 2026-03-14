# Design Studio — Agent Implementation Status

## Last Updated: 2026-03-02

## Overview

The Design Studio is a chat + canvas interface for the POD product creation workflow. Users describe a design idea in chat, and a multi-agent system guides them through the full lifecycle: ideation → design plan → artwork generation → listing copy/pricing → publish to Etsy.

**Spec**: `Specs/CHAT_CANVAS_DESIGN_INTERFACE.md` (~1,550 lines)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    /studio (Next.js)                     │
│  ┌──────────────┐  ┌──────────────────────────────────┐ │
│  │  Chat Panel   │  │       Canvas Panel               │ │
│  │  (useChat)    │  │  Progress bar + Agent badge      │ │
│  │  Session list │  │  Stage-based rendering:           │ │
│  │  Shop select  │  │   - InspirationStage             │ │
│  │               │  │   - PlanStage (editable)         │ │
│  │               │  │   - AssetStage (lightbox)        │ │
│  │               │  │   - ListingStage (carousel)      │ │
│  │               │  │   - PublishedStage               │ │
│  └──────┬───────┘  └──────────────────────────────────┘ │
│         │ POST /api/chat/design                          │
│         ▼                                                │
│  ┌──────────────────────────────────────────────────────┐│
│  │  Chat API Route (route.ts)                           ││
│  │  1. Fetch product → get status                       ││
│  │  2. getActiveAgent(status) → agent config            ││
│  │  3. getToolsForAgent(toolNames) → tool set           ││
│  │  4. Inject handoff briefing for non-Concierge agents ││
│  │  5. streamText → Kimi K2.5 + tools                  ││
│  └──────────────┬───────────────────────────────────────┘│
│                 │ HTTP bridge (agent-tools.ts)            │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐│
│  │  FastAPI Tool Server (:8100)                         ││
│  │  /tools/generate_plan, /tools/generate_artwork, etc. ││
│  │  → calls Python pipeline functions                   ││
│  └──────────────────────────────────────────────────────┘│
│                 │                                         │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐│
│  │  Supabase (products, workflow_logs, chat_sessions)   ││
│  │  Realtime → studio-context.tsx → canvas auto-updates ││
│  └──────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## Multi-Agent System

### 5 Agents (status-driven routing)

| Agent | ID | Status Triggers | Tools |
|-------|----|----------------|-------|
| **Concierge** | `concierge` | null, pending, published | suggest_niches, create_product |
| **Design Director** | `design_director` | planning, plan_ready | generate_plan, edit_area_prompt, edit_palette |
| **Asset Producer** | `asset_producer` | concept_approved, generating, uploading, mockups_ready | generate_all_artwork, regenerate_area |
| **Listing Producer** | `listing_producer` | production_approved, copy_pricing, listing_images, draft | generate_copy, calculate_pricing, generate_listing_images, regenerate_listing_slot, publish |
| **Published** | `published` | approved, publishing | (none) |

**All agents** also get query tools: `get_product_status`, `get_design_plan`

### Agent Routing Flow (route.ts)

```
Request { messages, shopId, productId }
  │
  ├─ productId? → fetch product.status from Supabase
  │
  ├─ getActiveAgent(status) → AgentConfig { id, systemPrompt, toolNames }
  │
  ├─ getToolsForAgent(toolNames ∪ queryToolNames, niches, shopId)
  │   → resolves tool definitions from agent-tools.ts
  │
  ├─ Build system prompt = agent.systemPrompt + context block (niches, products, current product)
  │
  ├─ If non-Concierge agent + product exists:
  │   → Prepend handoff briefing as system message
  │
  └─ streamText(kimi-k2.5, temperature=1.0, tools, messages)
```

### Handoff Briefings

Two layers of handoff briefings:

1. **Server-side (route.ts)**: System message prepended to model messages with product ID, status, theme, niche, product type. Gives the LLM context without relying on conversation history.

2. **Client-side (studio-context.tsx)**: Detects agent transitions via `useRef` tracking. When `getActiveAgent()` returns a different agent than the previous one, injects a contextual briefing via `appendSystemMessage()`:
   - concierge → design_director: theme, niche, product type, style hint
   - design_director → asset_producer: area count, palette colors
   - asset_producer → listing_producer: artwork area names
   - listing_producer → published: Etsy title

---

## File Inventory

### Frontend (dashboard/src/)

| File | Purpose | Status |
|------|---------|--------|
| `app/studio/page.tsx` | Studio page (SSR, fetches niches) | Complete |
| `app/studio/design-studio.tsx` | ResizablePanelGroup (40/60 split) | Complete |
| `components/studio/chat-panel.tsx` | Chat UI: sessions, shops, useChat, auto-save | Complete |
| `components/studio/canvas-panel.tsx` | Canvas: progress bar, agent badge, stage router | Complete |
| `components/studio/studio-context.tsx` | Shared state, Realtime sub, handoff briefings | Complete |
| `components/studio/stages/inspiration-stage.tsx` | Niche cards grid, click-to-explore | Complete |
| `components/studio/stages/plan-stage.tsx` | Plan viewer + inline edit (textarea, save to DB) | Complete |
| `components/studio/stages/asset-stage.tsx` | Artwork grid, lightbox, regenerate buttons, logs | Complete |
| `components/studio/stages/listing-stage.tsx` | Copy preview, pricing, image carousel, publish btn | Complete |
| `components/studio/stages/published-stage.tsx` | Success card, Etsy/Printify links, "Create Another" | Complete |
| `lib/agent-configs.ts` | 5 AgentConfig objects, getActiveAgent() | Complete |
| `lib/agent-tools.ts` | Tool definitions, callToolServer(), getToolsForAgent() | Complete |
| `app/api/chat/design/route.ts` | Multi-agent routing, handoff briefing, Kimi K2.5 | Complete |
| `app/api/chat/sessions/route.ts` | GET list / POST create sessions | Complete |
| `app/api/chat/sessions/[id]/route.ts` | GET one / PUT update session | Complete |
| `components/ui/resizable.tsx` | shadcn resizable panels | Complete |

### Backend (prototype/)

| File | Purpose | Status |
|------|---------|--------|
| `tool_server.py` | FastAPI entry point (:8100) | Complete |
| `tool_server/endpoints/plan.py` | /tools/generate_plan, edit_area_prompt, edit_palette | Complete |
| `tool_server/endpoints/artwork.py` | /tools/generate_all_artwork, regenerate_area | Complete |
| `tool_server/endpoints/production.py` | /tools/generate_copy, calculate_pricing, listing_images | Complete |
| `tool_server/endpoints/publish.py` | /tools/publish | Complete |
| `tool_server/endpoints/query.py` | /tools/product_status/{id} | Complete |
| `tool_server/endpoints/health.py` | /health | Complete |
| `tool_server/services/*.py` | Service layer (plan, artwork, production, lock, cost, db) | Complete |
| `tool_server/schemas/*.py` | Pydantic models for request/response | Complete |
| `tool_server/tests/*.py` | Unit tests (schemas, services, endpoints) | Complete |

### Database

| Migration | Purpose | Status |
|-----------|---------|--------|
| `20260216000002_chat_sessions.sql` | Base chat_sessions table | Applied |
| `20260222000003_phase_a_foundation.sql` | Adds product_id FK to chat_sessions | Applied |

---

## Build Status

- **TypeScript**: `tsc --noEmit` — 0 errors
- **Next.js build**: `npx next build` — 34 routes compiled, 0 errors
- **E2E tests**: Pending verification (27 existing tests + studio tests needed)

### Type Fixes Applied (2026-03-02)

1. `design-studio.tsx:29` — `direction="horizontal"` → `orientation="horizontal"` (react-resizable-panels API)
2. `agent-tools.ts:348` — `Record<string, ReturnType<typeof tool>>` → `ToolSet` (AI SDK v6 type)
3. `e2e/12-cross-cutting.spec.ts` — `base.test(...)` → `base(...)` (Playwright TestType is callable)

---

## Remaining Gaps (Spec vs Implementation)

| Spec Requirement | Status | Priority |
|-----------------|--------|----------|
| Multi-agent routing (status → agent switch) | **Done** (2026-03-02) | — |
| Handoff briefings between agents | **Done** (2026-03-02) | — |
| chat_sessions table | **Done** (verified) | — |
| Canvas inline editing (plan-stage) | **Done** (edit prompts + palette) | — |
| Lightbox for artwork/listing images | **Done** (asset + listing stages) | — |
| generation_log lineage table | Not built | Medium |
| user_preferences active use by agents | Not built | Low |
| Reference image chaining in generator | Not built | Medium |
| Lightbox with version comparison | Not built | Low |
| SSE progress streaming from tool server | Not built | Medium |
| E2E test coverage for studio | Not built | **High** |
| Dark whimsigoth design system (theme) | Not applied | Low |

---

## How to Run

```bash
# Terminal 1: Supabase
supabase start

# Terminal 2: Dashboard
cd dashboard && npm run dev

# Terminal 3: Python tool server
cd prototype && python tool_server.py

# Terminal 4: Python worker (processes pipeline stages)
cd prototype && python worker.py
```

Studio URL: http://localhost:3000/studio

---

## Session Log

### 2026-03-02: Multi-Agent Wiring Sprint

**Team**: 4 agents (route-wirer, db-checker, handoff-builder, build-verifier)

**Completed**:
1. Rewrote `route.ts` — multi-agent routing via `getActiveAgent()` + `getToolsForAgent()`
2. Verified `chat_sessions` migration — schema aligned with API routes
3. Added handoff briefing system to `studio-context.tsx` — agent transition detection + contextual briefings
4. Build verification — 3 type fixes, 34 routes compiled clean

**Prior session (2026-03-01)**: Built all UI components (chat panel, canvas panel, 5 stages, studio context, agent configs, agent tools, sessions API). Session froze during plan mode before wiring could start.
