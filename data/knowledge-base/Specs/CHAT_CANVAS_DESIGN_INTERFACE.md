# Chat + Canvas Design Interface — Specification

**Status:** Finalized
**Created:** 2026-02-20
**Last Updated:** 2026-02-20
**Decisions Locked:** 2026-02-20 (D1-D9 all resolved)

---

## 1. Vision

Replace the current form-based product creation and approval flow with a **conversational design assistant** paired with a **dynamic canvas panel**. The user chats with an AI design assistant using natural language; the canvas beside the chat updates in real-time to show stage-appropriate content — editable prompts, generated artwork, mockup images, listing copy, and pricing.

Think: Claude Desktop's "canvas" or Cursor's side panel — but purpose-built for the POD design workflow.

### Core Principles

1. **Chat is the primary control surface** — every action (create, approve, regenerate, edit) is initiated via natural language
2. **Canvas is the primary display surface** — shows the current artifact(s) for the active pipeline stage
3. **Everything persists to Supabase** — chat history, generation parameters, prompts used, rules applied, asset versions
4. **Full lineage tracking** — for every generated asset, store: which prompt, which model, which rules version, which parameters produced it
5. **Multi-agent with shared memory** — specialized agents per stage, all reading/writing to the same Supabase state, seamless handoffs via context briefings
6. **Direct orchestration** — agents call Python pipeline functions as tools directly (not a polling worker)

---

## 2. Architecture: Multi-Agent with Shared Memory (RECOMMENDED)

### The Problem with Single-Agent Approaches

A single LLM handling all stages needs 15+ tools and a massive system prompt covering design rules, image generation parameters, SEO copy rules, pricing math, and Etsy constraints. Tool selection accuracy degrades as the tool count grows, and the system prompt becomes too long for reliable instruction following.

### The Solution: Specialized Agents, Shared State

```
┌──────────────────────────────────────────────────────────────────┐
│                    SHARED MEMORY (Supabase)                      │
│  ┌──────────┐ ┌────────────────┐ ┌──────────────┐ ┌──────────┐ │
│  │ products │ │ generation_log │ │ chat_messages │ │ Storage  │ │
│  │ (state)  │ │ (lineage)      │ │ (all agents) │ │ (assets) │ │
│  └──────────┘ └────────────────┘ └──────────────┘ └──────────┘ │
└──────────────────────┬───────────────────────────────────────────┘
                       │ read/write
         ┌─────────────┼─────────────┐
         │             │             │
┌────────▼───┐ ┌──────▼──────┐ ┌────▼──────────┐
│  DESIGN    │ │  ASSET      │ │  LISTING      │
│  DIRECTOR  │ │  PRODUCER   │ │  PRODUCER     │
│            │ │             │ │               │
│  5 tools   │ │  6 tools    │ │  8 tools      │
│  Focused   │ │  Focused    │ │  Focused      │
│  sys prompt│ │  sys prompt │ │  sys prompt   │
└────────────┘ └─────────────┘ └───────────────┘
     Stage 1        Stage 2         Stage 3
```

Each agent is a **separate LLM call** with:
- Its own focused system prompt (design vocabulary OR image gen params OR SEO rules)
- Its own small tool set (4-6 tools — high selection accuracy)
- Read/write access to the same Supabase tables
- Access to the full chat history (all agents' messages in one thread)

### Why the Conversation Doesn't Break

The user sees **one continuous chat thread**. The agents share it.

```
[User]  Create a dark cottagecore mushroom hoodie
[DD]    I'll design that! Here's the concept...        ← Design Director
[User]  Make the front more mystical, add fireflies
[DD]    Updated the front prompt. Ready to approve?     ← Design Director
[User]  Approved, generate the artwork
[DD→AP] Handing off to asset generation...              ← Handoff message
[AP]    Generating front panel now...                    ← Asset Producer
[AP]    Front done! Working on back with front as ref...
[User]  The back is too dark
[AP]    Regenerating back with lighter tones...          ← Asset Producer
[User]  Perfect, approve mockups
[AP→LP] Moving to listing production...                  ← Handoff message
[LP]    Here's the SEO title and description...          ← Listing Producer
```

The handoff is seamless because:

1. **All messages go to the same `chat_messages` table** — the next agent reads them all
2. **Product state is in Supabase** — not in any agent's context window
3. **A handoff briefing** is compiled and injected into the new agent's first system prompt turn
4. **The user never sees "agent switching"** — they just see the assistant continuing the conversation

### The Handoff Briefing

When the orchestrator (Next.js frontend) detects a stage transition, it compiles a briefing for the incoming agent:

```
HANDOFF BRIEFING (compiled from shared memory):
─────────────────────────────────────────────
Product: Dark Cottagecore Mushroom Forest Hoodie
Product ID: abc-123
Previous stage: Plan (completed)
Current stage: Asset Generation

Design Plan Summary:
- Theme: "Enchanted mushroom forest at twilight"
- Style: "Dark cottagecore with bioluminescent accents"
- Palette: #1A1A2E (background), #8B5E3C (earth), #7FFF7F (bioluminescence)
- Trim: black
- Front: Hero scene — glowing mushroom cluster on forest floor
- Back: Complementary — owl perched on branch overlooking forest
- Sleeve: Accent pattern — trailing vines with tiny glowing mushrooms

User preferences observed in conversation:
- Wants "mystical" feel — added fireflies to front in v2 of plan
- Prefers compact single subject (not sprawling scenes)
- Approved plan after 1 revision

Generation log:
- Plan v1: generated, user feedback "needs more mystery"
- Plan v2: generated with fireflies, approved
```

This briefing is built automatically from:
- `products` row (theme, plan, status)
- `generation_log` rows (what was generated, what feedback was given)
- Last N `chat_messages` (summarized — not the full history, just key decisions)

### Agent Definitions

#### Agent 0: Concierge (pre-creation)
```
Persona:  Friendly creative partner, helps brainstorm
Tools:    suggest_niches, create_product, browse_inspiration
Sys prompt focus: Niche knowledge, trending themes, ICP (women 22-34 whimsigoth/boho)
Model:    Cheap/fast (Gemini Flash or Haiku-class)
Triggers: No active product in session
```

#### Agent 1: Design Director
```
Persona:  Expert textile designer, knows AOP print constraints
Tools:    generate_plan, edit_area_prompt, edit_palette, edit_theme,
          regenerate_plan, approve_plan
Sys prompt focus:
  - Full AOP rules from YAML (front two-region layout, pocket crop zone,
    sleeve = flat swatch, seam allowances)
  - Niche guide (motifs, palette, audience)
  - Hex palette discipline (exact codes in prompts)
  - Composition guidance (single compact subject, horizontal boundaries)
Model:    Mid-tier (Gemini 2.5 Pro or Sonnet-class) — needs design reasoning
Triggers: product.status IN (pending, planning, plan_ready)
Active until: User calls approve_plan → status = concept_approved
```

#### Agent 2: Asset Producer
```
Persona:  Technical image production specialist
Tools:    generate_all_artwork, regenerate_area, view_artwork,
          compare_versions, upload_to_printify, approve_mockups, reject_area
Sys prompt focus:
  - Gemini/GoAPI generation parameters (4K, aspect ratios, reference chaining)
  - Quality assessment (similarity threshold 0.85, edge-fill for sleeves)
  - Cost awareness ($0.18/image GoAPI, 250 RPD Gemini free tier)
  - Printify upload flow (print_areas with placeholders)
  - Crop/mirror pipeline (pocket from front, hood from back, sleeve mirror)
Model:    Mid-tier with vision (needs to discuss image quality)
Triggers: product.status IN (concept_approved, generating, uploading, mockups_ready)
Active until: User calls approve_mockups → status = production_approved
```

#### Agent 3: Listing Producer
```
Persona:  Etsy SEO and marketing specialist
Tools:    generate_copy, edit_title, edit_description, edit_tags,
          calculate_pricing, adjust_pricing, generate_listing_images,
          regenerate_listing_image, publish
Sys prompt focus:
  - Etsy SEO rules (140 char title, pipe-separated, front-loaded keywords)
  - Tag constraints (13 tags, max 20 chars, 3 broad + 5 mid + 5 long-tail)
  - Pricing strategy (perpetual 50% sale, margin targets per niche)
  - Listing image templates (T1-T9 + T5B descriptions)
  - Fee stack (6.5% transaction + 3% + $0.25 payment + 15% offsite ads)
Model:    Mid-tier (good at structured content generation)
Triggers: product.status IN (production_approved, copy_pricing, listing_images, draft)
Active until: User calls publish → status = published
```

### Routing Logic (Orchestrator)

The Next.js frontend acts as a thin orchestrator:

```typescript
function getActiveAgent(productStatus: string): AgentConfig {
  switch (productStatus) {
    case null:
    case undefined:
      return CONCIERGE_AGENT;

    case 'pending':
    case 'planning':
    case 'plan_ready':
      return DESIGN_DIRECTOR_AGENT;

    case 'concept_approved':
    case 'generating':
    case 'uploading':
    case 'mockups_ready':
      return ASSET_PRODUCER_AGENT;

    case 'production_approved':
    case 'copy_pricing':
    case 'listing_images':
    case 'draft':
      return LISTING_PRODUCER_AGENT;

    case 'published':
      return CONCIERGE_AGENT; // Post-publish conversation

    default:
      return CONCIERGE_AGENT;
  }
}
```

When the user sends a message:
1. Frontend reads `product.status` from Supabase
2. Selects the active agent config (system prompt + tools + model)
3. Loads full `chat_messages` history for this product
4. Compiles handoff briefing if agent changed since last message
5. Calls LLM with: `[system_prompt, ...chat_history, user_message]`
6. Streams response back to chat + canvas

### Why This Beats the Alternatives

| Concern | Hardcoded (1 agent) | Hybrid (1 agent + overlay) | Multi-Agent + Shared Memory |
|---------|--------------------|--------------------------|-----------------------------|
| Tool count per call | 15+ (unreliable) | 6-8 (ok) | 4-6 (reliable) |
| System prompt size | Large (all stages) | Medium (base + overlay) | Small (focused) |
| Instruction following | Degrades with size | Ok | Best |
| Conversation continuity | Perfect | Perfect | Seamless (shared chat history) |
| Agent personality | Blurred | Slightly blurred | Distinct but consistent |
| Different models per stage | No | No | Yes |
| Debugging | Easy (1 thread) | Easy (1 thread) | Easy (1 thread, tagged by agent) |
| Iterate one stage | Risky (breaks others) | Medium risk | Zero risk |
| System prompt can embed rules | No (too big) | Partially | Yes (each agent gets its own rules) |

### Message Attribution

Each `chat_messages` row includes an `agent_id` field so we can track which agent produced each response. The UI can optionally show subtle labels ("Design Director", "Asset Producer") or hide them entirely — the conversation reads naturally either way.

```sql
-- chat_messages table
agent_id TEXT,  -- 'concierge', 'design_director', 'asset_producer', 'listing_producer'
```

### Cross-Stage Recall

When the user references something from a previous stage ("remember when I said I wanted fireflies?"), the current agent can find it because:
1. It has the full `chat_messages` history in its context
2. The handoff briefing summarizes key decisions
3. The `generation_log` records all feedback text

If the conversation gets very long (50+ messages), the orchestrator summarizes older messages before injecting them, keeping the context window manageable.

---

## 3. Shared Memory Architecture

The shared memory is **user-scoped** — every piece of state belongs to a user and their products. Agents don't have their own memory; they read from and write to the user's shared state in Supabase.

### Memory Layers

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: User Memory (persists across ALL products)        │
│  ─────────────────────────────────────────────────────────  │
│  user_preferences table                                     │
│  ├── style preferences    "I always want dark backgrounds"  │
│  ├── niche affinity       celestial_boho, mushroom_cottage  │
│  ├── quality standards    "I like high contrast"            │
│  ├── rejected patterns    "never use radial mandalas"       │
│  ├── approved patterns    "shelf/branch compositions work"  │
│  ├── pricing overrides    "always target 50%+ margin"       │
│  └── process preferences  "always ask before generating"    │
│                                                             │
│  Populated by: any agent, from conversation + explicit asks │
│  Read by: all agents in system prompt injection             │
├─────────────────────────────────────────────────────────────┤
│  LAYER 2: Product Memory (persists across stages)           │
│  ─────────────────────────────────────────────────────────  │
│  products table + generation_log + chat_messages            │
│  ├── design_plan          the approved plan (JSON)          │
│  ├── generation_log       every prompt, model, rules, cost  │
│  ├── chat_messages        full conversation (all agents)    │
│  ├── workflow_logs        activity timeline                 │
│  └── Storage              artwork, mockups, listing images  │
│                                                             │
│  Populated by: agent tool calls (generate, edit, approve)   │
│  Read by: next agent on handoff via briefing compilation    │
├─────────────────────────────────────────────────────────────┤
│  LAYER 3: Session Memory (current conversation context)     │
│  ─────────────────────────────────────────────────────────  │
│  LLM context window (ephemeral, per API call)               │
│  ├── system prompt        agent-specific + injected context │
│  ├── chat history         recent messages (or summarized)   │
│  ├── handoff briefing     compiled from Layer 2             │
│  └── tool results         from current turn                 │
│                                                             │
│  Built by: orchestrator before each LLM call                │
│  Dies: when LLM call completes (but outputs saved to L2)   │
└─────────────────────────────────────────────────────────────┘
```

### Schema: `user_preferences` Table

```sql
CREATE TABLE user_preferences (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL,  -- Phase 1: single user, Phase 2+: auth user ID
  category    TEXT NOT NULL,   -- 'style', 'quality', 'process', 'pricing', 'niche', 'rejected_patterns'
  key         TEXT NOT NULL,   -- 'default_background', 'always_ask_before_gen', etc.
  value       TEXT NOT NULL,   -- the preference value
  source      TEXT,            -- 'explicit' (user said "remember this") or 'inferred' (agent observed pattern)
  confidence  FLOAT DEFAULT 1.0,  -- 1.0 for explicit, lower for inferred
  product_id  UUID REFERENCES products(id),  -- NULL = global, set = product-specific override
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, category, key, product_id)
);
```

### How Agents Use Memory

**On every LLM call, the orchestrator injects user preferences into the system prompt:**

```
USER PREFERENCES (learned from previous sessions):
- Style: Prefers dark backgrounds (#1A1A2E range), high contrast
- Composition: Likes shelf/branch/fog compositions. NEVER radial mandalas.
- Quality: Wants at least 0.75 similarity score between front and back
- Process: Always confirm before generating images (cost-conscious)
- Pricing: Target 50%+ margin minimum
- Niche affinity: celestial_boho (5 products), mushroom_cottagecore (3 products)
```

**Agents can write to user memory via a tool:**

| Tool | Description |
|------|------------|
| `remember_preference` | Save an explicit user preference ("always use dark backgrounds") |
| `forget_preference` | Remove a preference the user no longer wants |
| `get_preferences` | Read all preferences for context (read-only, also injected in sys prompt) |

**Inference from behavior:**

When a user consistently rejects artwork with light backgrounds across 3+ products, Agent 2 (Asset Producer) can call `remember_preference({ category: "style", key: "background_tone", value: "dark, avoid light/pastel backgrounds", source: "inferred", confidence: 0.7 })`. Inferred preferences are surfaced with lower priority and the agent can ask: "I've noticed you prefer dark backgrounds — should I remember that for future designs?"

### Memory Scoping for Multi-Tenant (Phase 2+)

All memory tables include `user_id`. In Phase 1 (single user), this is a fixed UUID. When auth is added:
- `user_preferences` filters by authenticated user
- `products`, `generation_log`, `chat_messages` all have a `user_id` FK
- RLS policies enforce: `auth.uid() = user_id`
- Each user has their own preference profile, generation history, and chat threads

---

## 4. Lineage Tracking — Generation Metadata

### Problem

We're actively iterating on design rules (YAML), prompts (system prompts in prompts.py), and generation parameters. When we look at a product's artwork later, we need to know exactly what configuration produced it.

### Schema: `generation_log` Table

```sql
CREATE TABLE generation_log (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id    UUID REFERENCES products(id) ON DELETE CASCADE,
  asset_type    TEXT NOT NULL,  -- 'plan', 'artwork_front', 'artwork_back', 'artwork_right_sleeve', 'listing_image_01', 'copy', 'pricing'
  version       INT NOT NULL DEFAULT 1,  -- increments on regeneration

  -- What was used to generate this
  model_id          TEXT,        -- 'gemini-3-pro-image-preview', 'kimi-k2.5', 'goapi-nano-banana-pro'
  model_provider    TEXT,        -- 'google', 'moonshot', 'goapi'
  prompt_text       TEXT,        -- the exact prompt sent to the model
  negative_prompt   TEXT,
  system_prompt     TEXT,        -- for LLM calls (plan generation, copy writing)
  parameters        JSONB,       -- model-specific: {image_size, aspect_ratio, temperature, reference_image_used, ...}

  -- What rules were active
  rules_snapshot    JSONB,       -- snapshot of the YAML rules used (or hash + version)
  rules_file        TEXT,        -- 'aop_hoodie.yaml'
  rules_hash        TEXT,        -- SHA256 of the rules file at generation time
  niche_guide_slug  TEXT,        -- 'celestial_boho', 'mushroom_cottagecore'
  niche_guide_hash  TEXT,        -- SHA256 of niche guide YAML

  -- What came out
  storage_path      TEXT,        -- Supabase Storage path to the generated asset
  storage_bucket    TEXT,        -- 'artwork', 'listing-images', 'mockups'
  file_size_bytes   BIGINT,
  dimensions        JSONB,       -- {width, height} for images

  -- Quality / feedback
  similarity_score  FLOAT,       -- structural similarity to reference (if applicable)
  user_feedback     TEXT,        -- "too dark", "love it", etc.
  was_approved      BOOLEAN,     -- did user keep this version?
  replaced_by       UUID REFERENCES generation_log(id),  -- points to next version if regenerated

  -- Timing
  started_at        TIMESTAMPTZ DEFAULT now(),
  completed_at      TIMESTAMPTZ,
  duration_ms       INT,
  cost_usd          FLOAT,       -- estimated cost of this generation

  created_at        TIMESTAMPTZ DEFAULT now()
);

-- Indexes for common queries
CREATE INDEX idx_generation_log_product ON generation_log(product_id);
CREATE INDEX idx_generation_log_asset ON generation_log(product_id, asset_type, version);
```

### What Gets Logged

| Asset Type | Logged Fields |
|-----------|--------------|
| `plan` | model_id, system_prompt (PLAN_SYSTEM_PROMPT), prompt_text (build_plan_user_prompt output), rules_snapshot, niche_guide |
| `artwork_front` | model_id, prompt_text (area prompt), parameters (image_size, aspect_ratio), reference_image_used=false, rules_hash |
| `artwork_back` | Same + reference_image_used=true (front image path), similarity_score |
| `artwork_right_sleeve` | Same + reference_image_used=true |
| `copy` | model_id, system_prompt (copy writer prompt), prompt_text, parameters (temperature) |
| `listing_image_01..10` | model_id, prompt_text (template prompt e.g. T1), parameters (template_id, custom_prompt) |
| `pricing` | parameters (niche, product_type, supplier costs snapshot) |

### Version Chain

When a user regenerates an asset:
1. Create new `generation_log` row with `version = previous.version + 1`
2. Set `replaced_by` on the previous row to point to the new one
3. Store user feedback on the previous row ("too dark, needs more contrast")

This gives us a complete regeneration chain: v1 → v2 → v3, with feedback at each step.

---

## 5. Chat Session Model

### Schema: Extend Existing `chat_sessions` Table

```sql
-- Add product binding to existing chat_sessions table
ALTER TABLE chat_sessions ADD COLUMN product_id UUID REFERENCES products(id);
ALTER TABLE chat_sessions ADD COLUMN active_stage TEXT; -- current pipeline stage overlay

-- Chat messages already exist — extend with tool tracking
ALTER TABLE chat_messages ADD COLUMN tool_calls JSONB;      -- [{tool_name, args, result_summary}]
ALTER TABLE chat_messages ADD COLUMN generation_log_ids UUID[];  -- links to generation_log entries created by this message
```

### Session Lifecycle

```
1. User opens product page → load or create chat_session for this product
2. Chat loads full message history from chat_messages
3. System prompt = BASE_PROMPT + stage_overlay(product.status)
4. User chats → LLM responds with text or tool calls
5. Tool calls → invoke Python process → log to generation_log → stream result to canvas
6. On stage transition → update active_stage → swap overlay → inform user
```

---

## 6. Canvas Specification

The canvas is the right panel of the split-pane layout. It is a **scrollable, reactive display surface** that renders different component compositions based on `product.status`. All data flows from Supabase via Realtime subscriptions — the canvas never holds authoritative state.

### 6.1 Canvas Shell (always present)

Every canvas view is wrapped in a persistent shell:

```
┌──────────────────────────────────────────────────┐
│  ┌─ Progress Bar ──────────────────────────────┐ │
│  │ ● Concept ─── ◐ Assets ─── ○ Listing ─── ○ │ │
│  │               ▲ generating                   │ │
│  └──────────────────────────────────────────────┘ │
│  ┌─ Agent Badge ───────────────────────────────┐ │
│  │ 🎨 Design Director         Session: $0.00   │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
│  ┌─────────────────────────────────────────────┐  │
│  │                                             │  │
│  │         STAGE CONTENT AREA                  │  │
│  │         (scrollable)                        │  │
│  │                                             │  │
│  │         Components swap per stage           │  │
│  │                                             │  │
│  └─────────────────────────────────────────────┘  │
│                                                    │
│  ┌─ Generation Info Bar (collapsible) ─────────┐  │
│  │ Model: gemini-3.1-pro | Rules: aop_hoodie   │  │
│  │ SHA: a1b2c3 | Cost this session: $0.54       │  │
│  └──────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

**Shell Components:**

| Component | Position | Data Source | Behavior |
|-----------|----------|-------------|----------|
| Progress Bar | Top, fixed | `product.status` | 4 nodes: Concept, Assets, Listing, Published. Active node pulses when agent is processing. Sub-status text below (e.g., "generating", "uploading") |
| Agent Badge | Below progress | Orchestrator routing | Shows active agent name + icon. Updates on stage transition. Also shows running session cost total |
| Stage Content | Middle, scrollable | Stage-dependent | Swaps entire component tree on status change. Smooth transition animation |
| Generation Info Bar | Bottom, collapsible | `generation_log` latest entry | Shows model, rules file, hash, cumulative session cost. Collapsed by default, click to expand |

### 6.2 Stage 0: Inspiration (no product yet)

**Trigger:** No product_id bound to session, or product just created with status `pending`.

```
┌──────────────────────────────────────────────┐
│                                              │
│  Describe your design idea in the chat →     │
│                                              │
│  ── or pick a starting point ──              │
│                                              │
│  ┌─ NICHES ───────────────────────────────┐  │
│  │ ┌──────────┐ ┌──────────┐ ┌─────────┐ │  │
│  │ │Celestial │ │Mushroom  │ │Japanese │ │  │
│  │ │Boho      │ │Cottage   │ │Art      │ │  │
│  │ │ ☾ ✧ ◌   │ │ 🍄 🌿 🦋│ │ 🎋 🐉 🌊│ │  │
│  │ └──────────┘ └──────────┘ └─────────┘ │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ┌─ RECENT DESIGNS ──────────────────────┐   │
│  │ ┌────┐ ┌────┐ ┌────┐ ┌────┐          │   │
│  │ │    │ │    │ │    │ │    │ (thumbs)  │   │
│  │ └────┘ └────┘ └────┘ └────┘          │   │
│  │ Koi Dragon  Mushroom  Celtic  Moth    │   │
│  └───────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

| Element | Interaction | Data Source |
|---------|------------|-------------|
| Niche cards | Click → sends chat message "I want to explore {niche}" | `niche_guides` table |
| Recent designs | Click → opens that product's chat session | `products` table, last 8, ordered by updated_at |
| Recent design thumbnails | Hover → show theme + status | Supabase Storage front artwork |

### 6.3 Stage 1: Design Plan (Gate 1)

**Trigger:** `product.status IN (planning, plan_ready)`
**During `planning`:** Show skeleton/spinner with live log feed from `workflow_logs`.
**At `plan_ready`:** Full plan viewer with editable fields.

```
┌──────────────────────────────────────────────┐
│                                              │
│  DESIGN PLAN                                 │
│  ──────────                                  │
│                                              │
│  Theme ────────────────────────────────────  │
│  ┌────────────────────────────────────────┐  │
│  │ Dark cottagecore mushroom forest       │← editable │
│  └────────────────────────────────────────┘  │
│                                              │
│  Style ────────────────────────────────────  │
│  ┌────────────────────────────────────────┐  │
│  │ Bioluminescent dark fantasy            │← editable │
│  └────────────────────────────────────────┘  │
│                                              │
│  Palette ──────────────────────────────────  │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐                  │
│  │██│ │██│ │██│ │██│ │██│  [+ Add]          │
│  └──┘ └──┘ └──┘ └──┘ └──┘                  │
│  #1A1A2E #8B5E3C #7FFF7F #2D1B4E #F5F0E1   │
│  bg      primary second  accent  highlight   │
│                                              │
│  Trim ─────── [▼ Black     ]                 │
│                                              │
│  ┌─ AREA PROMPTS ────────────────────────┐   │
│  │                                       │   │
│  │  ▾ Front (hero scene)           [v1]  │   │
│  │  ┌─────────────────────────────────┐  │   │
│  │  │ LAYOUT RULE (MUST FOLLOW):      │  │   │
│  │  │ This image has exactly TWO      │  │   │
│  │  │ regions. REGION 1 (upper half): │  │   │
│  │  │ a glowing mushroom cluster...   │← editable textarea │
│  │  │                            ···  │  │   │
│  │  └─────────────────────────────────┘  │   │
│  │  Negative: text, watermarks, labels   │   │
│  │  Role: hero_scene                     │   │
│  │                                       │   │
│  │  ▸ Back (complementary)         [v1]  │   │
│  │  (collapsed — click to expand)        │   │
│  │                                       │   │
│  │  ▸ Sleeve (accent pattern)      [v1]  │   │
│  │  (collapsed — click to expand)        │   │
│  │                                       │   │
│  └───────────────────────────────────────┘   │
│                                              │
│  Rationale ────────────────────────────────  │
│  "The mushroom cluster creates a natural     │
│   focal point while the bioluminescent..."   │
│                                              │
│  ┌─ RULES INFO ──────────────────────────┐   │
│  │ File: aop_hoodie.yaml                 │   │
│  │ SHA: a1b2c3d4 | Applied: just now     │   │
│  │ [View full rules]                     │   │
│  └───────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

**Editable Field Behavior:**

| Field | Component | On Edit | Sync |
|-------|-----------|---------|------|
| Theme | `<input>` single line | Debounce 500ms → save to `products.theme` | System message: `[Canvas] User updated theme` |
| Style | `<input>` single line | Debounce 500ms → save to `products.style_hint` | System message |
| Palette swatches | Color picker popover on click | Save to `products.design_plan.hex_palette` | System message: `[Canvas] User changed {role} color to {hex}` |
| Trim | `<select>` dropdown | Immediate save to `products.design_plan.trim_color` | System message |
| Area prompt textarea | Auto-expanding `<textarea>` | Debounce 1000ms → save to `products.design_plan.area_prompts.{area}.prompt` | System message: `[Canvas] User edited {area} prompt directly` |
| Negative prompt | `<input>` below textarea | Debounce 500ms → save | System message |

**Accordion behavior:** Front prompt expanded by default. Back and Sleeve collapsed. Click header to toggle. Version badge `[v1]` shows current generation_log version for that area.

### 6.4 Stage 2: Assets (Gate 2)

**Trigger:** `product.status IN (concept_approved, generating, uploading, mockups_ready)`

**Sub-states within Stage 2:**

| Status | Canvas Shows |
|--------|-------------|
| `concept_approved` | "Waiting for generation to start..." + spinner |
| `generating` | Progressive artwork grid — images appear as each area completes. Live log feed below. |
| `uploading` | All artwork shown + "Uploading to Printify..." spinner |
| `mockups_ready` | Full artwork grid + mockup grid + generation details. Gate 2 actions available. |

```
┌──────────────────────────────────────────────┐
│                                              │
│  ARTWORK ──────────────────────────────────  │
│                                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │          │ │          │ │          │    │
│  │  Front   │ │  Back    │ │  Sleeve  │    │
│  │          │ │          │ │          │    │
│  │          │ │          │ │          │    │
│  └──────────┘ └──────────┘ └──────────┘    │
│   v2 ↺ $0.18  v1 ✓ $0.18  v1 ✓ $0.18     │
│                                              │
│  ┌── Derived Areas (auto-generated) ─────┐   │
│  │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐  │   │
│  │ │L.Slv │ │R.Hood│ │L.Hood│ │Pocket│  │   │
│  │ └──────┘ └──────┘ └──────┘ └──────┘  │   │
│  │ mirror    crop     mirror   crop      │   │
│  └───────────────────────────────────────┘   │
│                                              │
│  MOCKUPS ──────────────────────────────────  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │          │ │          │ │          │    │
│  │  Black   │ │  Navy    │ │  Charcoal│    │
│  │          │ │          │ │          │    │
│  └──────────┘ └──────────┘ └──────────┘    │
│  (Printify mockups — trim color variants)    │
│                                              │
│  ┌── SELECTED AREA DETAILS ──────────────┐   │
│  │ (appears when an artwork is clicked)  │   │
│  │                                       │   │
│  │ Area: front | Version: 2 of 2         │   │
│  │ Model: gemini-3.1-pro                 │   │
│  │ Provider: google                      │   │
│  │ Prompt: "LAYOUT RULE (MUST FOLL..."   │   │
│  │ [Show full prompt]                    │   │
│  │ Reference image: none (anchor)        │   │
│  │ Similarity to ref: n/a               │   │
│  │ Resolution: 4500x5400 (4K 4:5)       │   │
│  │ Cost: $0.18                           │   │
│  │ Generated: 2 min ago                  │   │
│  │                                       │   │
│  │ v1: [thumb] "too dark" (rejected)     │   │
│  │ v2: [thumb] (current) ←              │   │
│  │                                       │   │
│  │ [↺ Regenerate] [Compare v1↔v2]       │   │
│  └───────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

**Artwork Grid Interactions:**

| Action | Behavior | Side Effect |
|--------|----------|-------------|
| Click artwork thumbnail | Expand "Selected Area Details" panel below grid. Shows generation metadata, version history, prompt used | None (read-only) |
| Double-click artwork | Open lightbox (see 6.7) | None |
| Click `↺ Regenerate` | Agent receives message: "User wants to regenerate {area}" | Agent calls `regenerate_area` tool |
| Click `Compare v1↔v2` | Open lightbox in split-compare mode (see 6.7) | None |
| Hover artwork | Overlay with area name + version badge | None |

**Progressive Loading:**
During `generating` status, each area slot starts as a skeleton with a spinner. As `workflow_logs` INSERTs arrive (via Realtime), the spinner updates with live text ("Generating front panel..."). When the artwork file appears in Storage, the skeleton replaces with the actual image. This gives a progressive reveal effect — front appears first, then back, then sleeve.

**Derived Areas:**
The 4 derived areas (left sleeve mirror, right hood crop, left hood mirror, pocket crop) appear in a smaller secondary row. These are not interactive (no regeneration) — they're auto-generated from the primary 3 areas.

### 6.5 Stage 3: Listing Production

**Trigger:** `product.status IN (production_approved, copy_pricing, listing_images, draft)`

**Sub-states:**

| Status | Canvas Shows |
|--------|-------------|
| `production_approved` | "Generating copy and pricing..." + spinner |
| `copy_pricing` | Copy fields appear (editable), pricing card appears. "Generating listing images..." |
| `listing_images` | Copy + pricing + listing image grid (progressive loading) |
| `draft` | Everything complete, all fields editable. Publish button available |

```
┌──────────────────────────────────────────────┐
│                                              │
│  LISTING PREVIEW ──────────────────────────  │
│                                              │
│  Title ────────────────────────────────────  │
│  ┌────────────────────────────────────────┐  │
│  │ Dark Cottagecore Mushroom Hoodie |     │← editable │
│  │ Enchanted Forest Sweatshirt | Gift    │  │
│  └────────────────────────────────────────┘  │
│  128/140 chars                               │
│                                              │
│  Description ──────────────────────────────  │
│  ┌────────────────────────────────────────┐  │
│  │ Step into an enchanted twilight forest │← editable │
│  │ with this stunning all-over-print...   │  │
│  │                                   ···  │  │
│  └────────────────────────────────────────┘  │
│  [Preview as Etsy listing]                   │
│                                              │
│  Tags (13/13) ─────────────────────────────  │
│  ┌──────────────────────────────────────┐    │
│  │ [mushroom hoodie ×] [cottagecore ×]  │    │
│  │ [forest hoodie ×] [dark aesthetic ×] │    │
│  │ [enchanted ×] [nature lover ×] ...   │← click × to remove, │
│  │                      [+ Add tag]     │   type to add │
│  └──────────────────────────────────────┘    │
│  All tags ≤ 20 chars ✓                       │
│                                              │
│  ┌─ PRICING ─────────────────────────────┐   │
│  │                                       │   │
│  │  Sale Price   Listed Price   Margin   │   │
│  │  [$69.99  ]   $139.98       49.9%    │   │
│  │                                       │   │
│  │  Base Cost    Net Profit    Fees      │   │
│  │  $35.10       $34.89        $12.41   │   │
│  │                                       │   │
│  │  [View fee breakdown]                 │   │
│  └───────────────────────────────────────┘   │
│                                              │
│  LISTING IMAGES (10 slots) ────────────────  │
│                                              │
│  ┌────────┐ ┌────────┐ ┌────────┐           │
│  │ 01     │ │ 02     │ │ 03     │           │
│  │ T1     │ │ T2     │ │ T5     │           │
│  │ Hero   │ │ Back   │ │ Life   │           │
│  └────────┘ └────────┘ └────────┘           │
│  ┌────────┐ ┌────────┐ ┌────────┐           │
│  │ 04     │ │ 05     │ │ 06     │           │
│  │ T3     │ │ T6     │ │ T7     │           │
│  │ HoodUp │ │ Detail │ │ Gift   │           │
│  └────────┘ └────────┘ └────────┘           │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────┐ │
│  │ 07     │ │ 08     │ │ 09     │ │ 10   │ │
│  │ T5B    │ │ T8     │ │ T9     │ │ T4   │ │
│  │ LifeBk │ │ Seam   │ │ Close  │ │ Back │ │
│  └────────┘ └────────┘ └────────┘ └──────┘ │
│                                              │
│  Click image → regen dialog with template    │
│  picker                                      │
│                                              │
│  ┌─ PUBLISH ─────────────────────────────┐   │
│  │ [Publish to Etsy]  (status=draft only) │  │
│  └───────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

**Listing Field Interactions:**

| Field | Component | Validation | On Edit |
|-------|-----------|-----------|---------|
| Title | `<textarea>` 2 rows | Max 140 chars, live counter | Debounce 500ms → `products.title` + system message |
| Description | `<textarea>` auto-expanding | None (free-form) | Debounce 1000ms → `products.description` + system message |
| Tags | Tag chips with `×` delete + add input | Max 13 tags, each max 20 chars, no truncation mid-word | Immediate save → `products.tags` + system message |
| Sale Price | `<input type="number">` | Min $1, max $999. Auto-calculates listed price (2x) and margin | Debounce 500ms → `products.sale_price` + recalc |
| Listed Price | Read-only (computed: sale_price × 2) | — | — |
| Margin/Net/Fees | Read-only | — | Recalculated when sale_price changes |

**Listing Image Interactions:**

| Action | Behavior |
|--------|----------|
| Click image | Opens regen dialog (see 6.8) |
| Double-click | Opens lightbox at full resolution |
| Hover | Shows template ID (T1-T9) + slot name overlay |
| Drag (future) | Reorder slots — deferred to Phase 2 |

### 6.6 Stage 4: Published

**Trigger:** `product.status = published`

```
┌──────────────────────────────────────────────┐
│                                              │
│  ✓ PUBLISHED                                 │
│  ──────────                                  │
│                                              │
│  ┌─ LINKS ───────────────────────────────┐   │
│  │ [View on Etsy →]                      │   │
│  │ [View on Printify →]                  │   │
│  │ [View listing images →]               │   │
│  └───────────────────────────────────────┘   │
│                                              │
│  ┌─ LISTING SUMMARY ────────────────────┐    │
│  │ Title: Dark Cottagecore Mushroom...   │    │
│  │ Sale: $69.99 | Margin: 49.9%         │    │
│  │ Tags: 13 | Images: 10/10             │    │
│  │ Published: Feb 20, 2026 3:45 PM      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌─ GENERATION SUMMARY ─────────────────┐    │
│  │ Total generations: 8                  │    │
│  │ Regenerations: 2 (front v2, back v2)  │    │
│  │ Total cost: $1.44                     │    │
│  │ Models used: gemini-3.1-pro, kimi     │    │
│  │ Rules: aop_hoodie.yaml (SHA: a1b2c3)  │   │
│  │ [View full generation timeline]       │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌─ PERFORMANCE (Phase 2) ──────────────┐    │
│  │ Views: --  | Favorites: --           │    │
│  │ Sales: --  | Revenue: --             │    │
│  │ (Etsy API integration coming soon)   │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  [Start new design]                          │
│                                              │
└──────────────────────────────────────────────┘
```

### 6.7 Lightbox — Full-Resolution Image Viewer

Opens as a **modal overlay** covering both chat and canvas panels. Triggered by double-clicking any image.

```
┌──────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────┐  [×]   │
│  │                                             │        │
│  │                                             │        │
│  │              FULL-RES IMAGE                 │        │
│  │              (pan + zoom)                   │        │
│  │                                             │        │
│  │                                             │        │
│  │                                             │        │
│  └─────────────────────────────────────────────┘        │
│                                                          │
│  ┌─ VERSION SIDEBAR ─────────────────────────────────┐   │
│  │                                                   │   │
│  │  ● v2 (current) — Feb 20, 3:12 PM                │   │
│  │    Model: gemini-3.1-pro | Cost: $0.18            │   │
│  │    [Show prompt]                                  │   │
│  │                                                   │   │
│  │  ○ v1 (replaced) — Feb 20, 3:05 PM               │   │
│  │    Model: gemini-3.1-pro | Cost: $0.18            │   │
│  │    Feedback: "too dark, needs more contrast"      │   │
│  │    [Show prompt] [View image]                     │   │
│  │                                                   │   │
│  └───────────────────────────────────────────────────┘   │
│                                                          │
│  [← Prev area]  front (2 of 3)  [Next area →]           │
│  [Compare versions side-by-side]                         │
└──────────────────────────────────────────────────────────┘
```

**Compare Mode** (toggled by "Compare versions" button):

```
┌──────────────────────────────────────────────────────────┐
│   v1                          v2                   [×]   │
│  ┌────────────────────┐  ┌────────────────────┐         │
│  │                    │  │                    │         │
│  │   (rejected)       │  │   (current)        │         │
│  │                    │  │                    │         │
│  └────────────────────┘  └────────────────────┘         │
│                                                          │
│  Feedback on v1: "too dark, needs more contrast"         │
│  Similarity v1→v2: 0.62                                  │
│                                                          │
│  [Use v1 instead]  [Keep v2]  [Regenerate new v3]        │
└──────────────────────────────────────────────────────────┘
```

**Lightbox Features:**

| Feature | Behavior |
|---------|----------|
| Zoom | Scroll wheel or pinch to zoom. Important for 4500x5400 artwork — need to inspect print quality |
| Pan | Click-drag when zoomed in |
| Version sidebar | Lists all versions from `generation_log` for this area. Click version to view. Shows prompt, model, cost, feedback |
| Arrow navigation | Navigate between areas (front → back → sleeve) |
| Compare toggle | Splits view into side-by-side with version selector |
| "Use v1 instead" | Reverts to a previous version. Creates system message: "[Canvas] User reverted {area} to v1" |
| "Regenerate new v3" | Sends chat message to agent: "regenerate {area}" |
| Escape / click outside | Closes lightbox |

### 6.8 Listing Image Regen Dialog

Opens as a **popover or small modal** when clicking a listing image slot. Allows template selection before regeneration.

```
┌─────────────────────────────────────────┐
│  Regenerate Slot 01 (Hero Front)        │
│  ───────────────────────────────────    │
│                                         │
│  Current template: T1                   │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│  │ T1 │ │ T2 │ │ T3 │ │ T4 │ │ T5 │   │
│  │ ●  │ │    │ │    │ │    │ │    │   │
│  └────┘ └────┘ └────┘ └────┘ └────┘   │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│  │T5B │ │ T6 │ │ T7 │ │ T8 │ │ T9 │   │
│  │    │ │    │ │    │ │    │ │    │   │
│  └────┘ └────┘ └────┘ └────┘ └────┘   │
│                                         │
│  Custom instructions (optional):        │
│  ┌─────────────────────────────────┐    │
│  │ Make the lighting warmer...     │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Cost: ~$0.18                           │
│  [Cancel]  [Regenerate]                 │
└─────────────────────────────────────────┘
```

Template thumbnails show a **visual icon/description** for each template type (ghost mannequin, lifestyle, close-up, etc.). Selecting a different template changes what gets generated. Custom instructions are passed to the image producer as additional context.

### 6.9 Canvas State Transitions

When `product.status` changes (detected via `useRealtimeProduct`), the canvas transitions smoothly:

```
status change detected
    │
    ▼
┌─────────────────┐     ┌─────────────┐     ┌──────────────┐
│ Fade out current│────→│ Update       │────→│ Fade in new  │
│ stage content   │     │ progress bar │     │ stage content│
│ (200ms)         │     │ + agent badge│     │ (300ms)      │
└─────────────────┘     └─────────────┘     └──────────────┘
```

**Within a stage**, sub-status changes (e.g., `generating` → `uploading`) update in-place without full transitions — just swap spinners and text.

### 6.10 Responsive Behavior

| Breakpoint | Layout | Behavior |
|-----------|--------|----------|
| >= 1280px | 40/60 split | Chat left, canvas right. Both fully visible |
| 1024-1279px | 35/65 split | Slightly narrower chat, wider canvas for images |
| 768-1023px | Tab toggle | `[Chat] [Canvas]` tabs at top. Show one at a time. Badge on Canvas tab when content updates while viewing Chat |
| < 768px | Tab toggle + compact | Same tabs. Canvas images in single column. Listing images 2-up instead of 3-up |

**Tab notification:** When viewing the Chat tab and the canvas content updates (new image generated, status change), a subtle badge/dot appears on the Canvas tab to draw attention.

### 6.11 Canvas Design System

#### Color Palette — Dark Whimsigoth

The ICP is women 22-34 into whimsigoth/dark cottagecore/boho goth. The UI should feel like a **moonlit creative studio** — deep, moody, with warm gold accents. Not cyberpunk-neon. Not corporate-dark.

```
Background layers:
  --bg-deep:      #0C0A12    (deepest — page background, near-black with purple undertone)
  --bg-surface:   #161224    (canvas panel background)
  --bg-card:      #1E1832    (cards, panels, elevated surfaces)
  --bg-hover:     #2A2442    (hover state on cards)

Text:
  --text-primary:   #F0ECF5  (high contrast — headings, primary content)
  --text-secondary: #A99FBF  (muted — labels, metadata, timestamps)
  --text-muted:     #6B6080  (very muted — disabled, placeholder)

Accents:
  --accent-gold:    #CA8A04  (CTAs, approve buttons, active states, selected items)
  --accent-gold-hover: #EAB308
  --accent-purple:  #7C3AED  (links, interactive elements, agent badge)
  --accent-purple-muted: #4C1D95  (subtle highlights)
  --accent-green:   #22C55E  (success, published, approved states)
  --accent-red:     #EF4444  (errors, rejected, destructive actions)
  --accent-amber:   #F59E0B  (warnings, cost indicators)

Borders:
  --border-subtle:  #2A2442  (card borders, dividers — barely visible)
  --border-focus:   #7C3AED  (focus rings, active inputs)

Gradients:
  --gradient-surface: linear-gradient(180deg, #1E1832 0%, #161224 100%)
  --gradient-glow:    radial-gradient(ellipse at center, #7C3AED15 0%, transparent 70%)
```

**Contrast ratios:** All text meets WCAG AA (4.5:1 minimum). `--text-primary` on `--bg-surface` = 12.8:1. `--text-secondary` on `--bg-surface` = 5.2:1.

#### Typography

```
Heading:  Playfair Display (serif) — elegant, editorial feel
Body:     Inter (sans-serif) — clean, readable for prompts and metadata
Mono:     Fira Code (monospace) — for hex codes, SHA hashes, technical metadata

Tailwind config:
  fontFamily: {
    serif: ['Playfair Display', 'Georgia', 'serif'],
    sans: ['Inter', 'system-ui', 'sans-serif'],
    mono: ['Fira Code', 'monospace'],
  }

Scale:
  Canvas section headings:  text-lg font-serif font-semibold (18px)
  Card headers:             text-sm font-sans font-medium uppercase tracking-wide (14px)
  Body text:                text-sm font-sans (14px)
  Metadata/labels:          text-xs font-sans text-secondary (12px)
  Hex codes/hashes:         text-xs font-mono (12px)
  Editable textareas:       text-sm font-sans (14px, comfortable for prompt editing)
```

#### shadcn/ui Component Mapping

| Canvas Element | shadcn Component | Notes |
|---------------|-----------------|-------|
| **Canvas shell** | Custom `<div>` with flex column | No shadcn wrapper needed |
| **Progress bar** | Custom (not shadcn Progress — need 4 discrete nodes, not continuous) | Custom component with node circles + connecting lines |
| **Agent badge** | `<Badge variant="outline">` | With Lucide icon prefix |
| **Stage content area** | `<ScrollArea>` | shadcn ScrollArea for styled scrollbar |
| **Generation info bar** | `<Collapsible>` | Collapsed by default, expand to show metadata |
| **Niche cards (Stage 0)** | `<Card>` + `<CardHeader>` + `<CardContent>` | Hover effect with `--bg-hover` |
| **Recent designs (Stage 0)** | `<Card>` with image thumbnail | Grid layout, 4 columns |
| **Theme/Style inputs (Stage 1)** | `<Input>` | With debounced onChange |
| **Palette swatches (Stage 1)** | `<Popover>` + color picker | Click swatch → popover with hex input |
| **Trim dropdown (Stage 1)** | `<Select>` | With color dot preview |
| **Area prompts accordion (Stage 1)** | `<Accordion type="multiple">` | `<AccordionItem>` per area, first expanded |
| **Prompt textarea (Stage 1)** | `<Textarea>` | Auto-expanding, debounced save |
| **Artwork grid (Stage 2)** | CSS Grid (custom) | Not a shadcn component — custom 3-col grid |
| **Version badge on artwork** | `<Badge variant="secondary">` | e.g., "v2" with version number |
| **Selected area details (Stage 2)** | `<Card>` + `<Collapsible>` | Expandable metadata panel |
| **Lightbox (Stage 2/3)** | `<Dialog>` (full screen) | `<DialogContent className="max-w-[95vw] max-h-[95vh]">` |
| **Version sidebar in lightbox** | `<ScrollArea>` inside `<Dialog>` | Right side panel within the dialog |
| **Compare mode** | `<Tabs>` inside `<Dialog>` | Tab between "Single" and "Compare" views |
| **Title input (Stage 3)** | `<Textarea>` + char counter | 2-row, 140 char max |
| **Description (Stage 3)** | `<Textarea>` auto-expanding | No max, free-form |
| **Tags (Stage 3)** | Custom tag input (no shadcn equiv) | Chips with `x` delete + add input. Use `<Badge>` for chips |
| **Pricing card (Stage 3)** | `<Card>` with `<Input type="number">` | Sale price editable, rest computed |
| **Fee breakdown (Stage 3)** | `<Collapsible>` | "View fee breakdown" toggle |
| **Listing image grid (Stage 3)** | CSS Grid (custom) | 5x2 or 3-col responsive |
| **Regen dialog (Stage 3)** | `<Popover>` or `<Dialog>` | Template picker grid + custom prompt textarea |
| **Template picker thumbnails** | `<ToggleGroup type="single">` | Visual toggle for T1-T9 |
| **Publish button (Stage 3)** | `<Button variant="default">` | Gold accent bg (`--accent-gold`) |
| **Links (Stage 4)** | `<Button variant="link">` | External link arrows |
| **Mobile tab toggle** | `<Tabs>` | `<TabsList>` at top of viewport |

#### Animation & Transition Specs

```
Stage transition (status change):
  1. Fade out current content:   200ms ease-out, opacity 1 → 0
  2. Update progress bar:        300ms ease-in-out, node fill + connecting line
  3. Fade in new content:        300ms ease-in, opacity 0 → 1
  Total: ~500ms perceived

Sub-status update (within stage):
  Content swap:                  150ms cross-fade (no full transition)

Progressive image loading:
  Skeleton:                      animate-pulse with --bg-card color
  Image reveal:                  300ms fade-in from 0 → 1 opacity when loaded
  Stagger:                       Each area delays 100ms after previous (front, then back+100ms, then sleeve+200ms)

Accordion expand/collapse:
  shadcn Accordion default:      200ms ease (built-in, don't override)

Lightbox open:
  Overlay fade:                  200ms ease, bg opacity 0 → 0.8
  Content scale:                 300ms ease, scale 0.95 → 1.0 + opacity

Editable field save indicator:
  On save:                       Brief green flash on border (--accent-green at 30% opacity)
  Duration:                      400ms fade out

Cost confirmation pulse:
  Session cost badge update:     Scale 1.0 → 1.1 → 1.0 (300ms) when cost changes

prefers-reduced-motion:
  ALL of the above reduce to instant (0ms) or simple opacity changes (150ms max)
  No scale transforms, no stagger delays
```

#### Accessibility Requirements

| Requirement | Implementation |
|-------------|---------------|
| Focus management | All interactive canvas elements reachable via Tab. Focus ring = 2px `--border-focus` (purple) |
| Lightbox focus trap | When Dialog opens, focus trapped inside. Escape closes. Return focus to trigger element |
| Image alt text | Every artwork: `alt="Front panel artwork, version 2"`. Mockups: `alt="Black colorway mockup"` |
| Screen reader for progress | Progress bar nodes: `aria-label="Stage 2: Assets, in progress"` |
| Editable fields | All inputs/textareas have visible labels (not just placeholders). Use `<Label>` from shadcn |
| Color not sole indicator | Version badges show number ("v2"), not just color. Status uses icon + text, not just color |
| Keyboard image navigation | Arrow keys navigate between artwork in lightbox. Enter opens lightbox from grid |
| Tag management | Tags removable via keyboard (Delete/Backspace on focused tag). Add via Enter in input |
| Cost announcements | `aria-live="polite"` region for cost updates so screen readers announce changes |
| Zoom support | Lightbox image zoom works via keyboard (+/- keys, not just scroll wheel) |

#### Key Interaction Patterns Missing from Initial Spec

1. **Undo on editable fields** — Ctrl+Z in any canvas textarea reverts the last local change (before save). After save, the previous value is gone from the input but still in `generation_log`.

2. **Dirty state indicator** — When a canvas field is edited but not yet saved (during debounce window), show a small unsaved dot next to the field. Clears on successful save.

3. **Canvas-to-chat quick action** — Each canvas section has a small "Ask about this" link icon that pre-fills the chat input with context. E.g., clicking it on the front prompt pre-fills: "About the front panel prompt: "

4. **Skeleton → Error state** — If image generation fails, the skeleton replaces with an error card (red border, error message, "Retry" button) instead of staying as a spinner forever.

5. **Drag handle on lightbox** — Lightbox can be dragged to resize (useful when wanting to see chat and lightbox simultaneously). Or: allow lightbox to dock to the canvas panel instead of overlaying everything.

6. **Session cost running total** — Visible in the agent badge bar. Updates in real-time as tools execute. Format: `$1.26 this session`. Pulls from `generation_log.cost_usd` SUM for this session.

---

## 7. Tool Definitions

Each tool maps to a Python function invoked via a Next.js API route. Tools are grouped by stage and only exposed to the LLM when that stage is active.

### Always Available

| Tool | Description | Python Function |
|------|------------|----------------|
| `get_product_status` | Get current product state | `supabase_client.fetch_product()` |
| `get_generation_history` | Get version chain for an asset | SQL query on `generation_log` |
| `get_rules_summary` | Summarize active YAML rules | `rules_loader.load_rules()` |

### Stage 1: Design Planning

| Tool | Description | Python Function | Side Effects |
|------|------------|----------------|-------------|
| `create_product` | Create a new product record | `supabase_client.create_product()` | Creates DB row, returns product_id |
| `generate_plan` | Generate design plan from theme | `director.generate_plan()` | Calls LLM, saves plan to DB, logs to generation_log |
| `edit_area_prompt` | Update a specific area's prompt text | Direct DB update | Writes to products.design_plan |
| `edit_palette` | Update hex palette colors | Direct DB update | Writes to products.design_plan |
| `edit_theme` | Update theme/style text | Direct DB update | Writes to products.theme/style_hint |
| `regenerate_plan` | Regenerate entire plan with feedback | `director.generate_plan()` + feedback context | New generation_log entry, version++ |
| `approve_plan` | Approve concept → trigger Stage 2 | `update_status('concept_approved')` | Status transition |

### Stage 2: Asset Generation

| Tool | Description | Python Function | Side Effects |
|------|------------|----------------|-------------|
| `generate_all_artwork` | Generate images for all areas | `pipeline.generate_all_images()` | Gemini/GoAPI calls, uploads to Storage, logs each area |
| `regenerate_area` | Regenerate a single area with feedback | `generator.generate_design()` | One image gen call, version++, logs to generation_log |
| `view_artwork` | Get artwork URLs for display | Storage query | Read-only |
| `compare_versions` | Get side-by-side URLs for asset versions | `generation_log` query | Read-only |
| `upload_to_printify` | Create Printify product from artwork | `uploader.create_printify_product()` | Printify API call |
| `approve_mockups` | Approve mockups → trigger Stage 3 | `update_status('production_approved')` | Status transition |
| `reject_area` | Flag a specific area for regeneration | DB update + log | Sets user_feedback on generation_log |

### Stage 3: Production

| Tool | Description | Python Function | Side Effects |
|------|------------|----------------|-------------|
| `generate_copy` | Generate title, description, tags | `writer.generate_listing_copy()` | LLM call, logs to generation_log |
| `edit_title` | Edit listing title | Direct DB update | Writes to products.title |
| `edit_description` | Edit listing description | Direct DB update | Writes to products.description |
| `edit_tags` | Add/remove/replace tags | Direct DB update | Writes to products.tags |
| `calculate_pricing` | Run pricing calculator | `calculator.calculate_pricing()` | Computes pricing, logs |
| `adjust_pricing` | Override sale/list price | Direct DB update | Writes to products.sale_price |
| `generate_listing_images` | Produce all 10 listing images | `producer.produce_listing_images()` | Gemini calls, logs each slot |
| `regenerate_listing_image` | Regen one slot with template choice | `producer.produce_single_listing_image()` | One Gemini call, version++ |
| `publish` | Publish to Etsy via Printify | `uploader.publish_product()` | Printify publish API call |

---

## 8. System Prompt Architecture (Per Agent)

Each agent gets a system prompt assembled from 3 parts:

```
SYSTEM PROMPT = BASE_CONTEXT + USER_MEMORY + AGENT_INSTRUCTIONS
```

### Part 1: Base Context (shared across all agents)

Injected by the orchestrator into every agent call. Contains product state and handoff context.

```
PRODUCT CONTEXT:
Product ID: {product_id}
Theme: {theme}
Product Type: {product_type}
Niche: {niche_slug}
Current Status: {status}

CONVERSATION HISTORY:
You are continuing a design conversation with the user. Previous messages
from other assistants in this thread are part of the same collaborative
session — refer to them naturally, do not re-introduce yourself.

{handoff_briefing if stage just changed, otherwise empty}
```

### Part 2: User Memory (injected from `user_preferences`)

Compiled by the orchestrator from the `user_preferences` table. Gives every agent awareness of the user's learned preferences.

```
USER PREFERENCES (learned across sessions):
- Style: Prefers dark backgrounds (#1A1A2E range), high contrast artwork
- Composition: Likes shelf/branch/fog layouts. NEVER radial mandalas.
- Quality: Expects 0.75+ similarity between front and back panels
- Process: Always confirm before generating images (cost-conscious)
- Pricing: Target 50%+ margin minimum
- Rejected: Light/pastel backgrounds, busy patterns, text in artwork
- Niche affinity: celestial_boho (5 products), mushroom_cottagecore (3 products)

You may update these preferences if the user explicitly asks you to remember
something, or if you observe a strong pattern (ask for confirmation first).
Tool: remember_preference, forget_preference
```

### Part 3: Agent-Specific Instructions

#### Agent 0: Concierge

```
You are a friendly creative partner helping brainstorm POD (print-on-demand)
design ideas. You know the Etsy market, trending aesthetics, and what sells
for the whimsigoth/dark cottagecore/boho goth audience (women 22-34).

Help the user explore themes, suggest niches, and refine ideas before
committing to a product. When they're ready, call create_product to start.

YOUR TOOLS: suggest_niches, create_product, browse_inspiration, get_preferences
```

#### Agent 1: Design Director

```
You are an expert textile designer specializing in all-over-print (AOP)
garment design. You translate creative themes into production-ready image
generation prompts for each print area of a hoodie.

ACTIVE RULES FILE: {rules_file} (hash: {rules_hash})
{full relevant sections of aop_hoodie.yaml — front layout, pocket crop,
 sleeve swatch rules, seam allowances, trim config}

NICHE GUIDE: {niche_display_name}
Style: {niche_style}
Motifs: {niche_motifs}
Palette direction: {niche_palette}

KEY CONSTRAINTS (from rules):
- Front panel: TWO-REGION LAYOUT — hero in upper half, solid bg lower half
- Pocket crops from front at 59-83% from top — elements in that zone appear TWICE
- Sleeves: flat rectangular textile swatch, NO garment shapes
- Hood panels: cropped from back upper portion
- Seam allowance: {seam_px}px keep-out zone on all edges
- Single compact hero subject (wider than tall) on uniform background
- No atmosphere/fog/mist outside the hero subject

PROMPT ENGINEERING:
- Hex palette codes MUST be identical across all area prompts (copy-paste)
- Layout constraints go BEFORE creative content in every prompt
- Add "no text, no watermarks, no signatures, no labels" to all prompts
- Sleeves: "flat rectangular textile swatch" — never garment shapes

YOUR TOOLS: generate_plan, edit_area_prompt, edit_palette, edit_theme,
            regenerate_plan, approve_plan, remember_preference, get_generation_history

When the user approves the plan, call approve_plan to advance to asset generation.
```

#### Agent 2: Asset Producer

```
You are a technical image production specialist. You oversee artwork generation
for AOP hoodies using AI image models, manage quality, and handle Printify uploads.

IMAGE GENERATION PIPELINE:
- Primary: Gemini ({model_id}), 4K resolution
- Fallback: GoAPI Nano Banana Pro ($0.18/image, no daily limit)
- Auto-fallback: Gemini 429 → GoAPI for remainder of session
- Force GoAPI: when user requests or Gemini quota low

REFERENCE IMAGE CHAINING:
1. Front → generated from text only (anchor)
2. Back → front as visual reference
3. Right sleeve → front as visual reference
4. Left sleeve = horizontal mirror of right
5. Right hood = crop from back upper portion
6. Left hood = mirror of right hood
7. Pocket = content-aware crop from front lower portion

QUALITY THRESHOLDS:
- Similarity between reference-chained areas: ≥ 0.85
- Edge-fill validation for sleeves (no garment shapes)
- Pocket zone: front must have solid bg below 55% from top

CURRENT DESIGN PLAN:
{serialized_design_plan with area prompts}

COST AWARENESS: Each image = ~$0.18 (GoAPI) or 1 of 250 free RPD (Gemini).
ALWAYS tell the user the estimated cost before generating.

YOUR TOOLS: generate_all_artwork, regenerate_area, view_artwork,
            compare_versions, upload_to_printify, approve_mockups,
            reject_area, remember_preference, get_generation_history
```

#### Agent 3: Listing Producer

```
You are an Etsy SEO and marketing specialist. You create optimized listing
content, calculate pricing, and produce professional listing images.

COPY RULES (Etsy requirements):
- Title: max 140 chars, front-loaded keywords, pipe-separated segments
  Pattern: "Theme Hoodie | Style Description | Gift Occasion"
- Description: keyword-rich opening paragraph, then sections:
  How to Order, Product Details, Shipping Info, Care Instructions, Returns
- Tags: EXACTLY 13, each MAX 20 chars, no truncation mid-word
  Mix: 3 broad + 5 medium-tail + 5 long-tail
- No ALL CAPS in tags

PRICING STRATEGY:
- Perpetual 50% sale (listed_price = sale_price × 2)
- Target margin: {target_margin_range}
- Base cost: ${base_cost} ({blank_model})
- Fee stack: 6.5% transaction + 3% + $0.25 payment + $0.20 listing + 15% offsite ads

LISTING IMAGE TEMPLATES (10 slots):
T1: Ghost mannequin front, dark bg, hood down
T2: Ghost mannequin back, dark bg, hood down
T3: Ghost mannequin front, hood UP dramatic
T4: Ghost mannequin back, hood UP dramatic
T5: On-model lifestyle front (editorial)
T5B: On-model lifestyle back (editorial)
T6: Fabric texture close-up (macro detail)
T7: Folded & styled (gift-ready presentation)
T8: Sleeve/hood detail (print continuity)
T9: On-model close-up (chest-up, print focus)

YOUR TOOLS: generate_copy, edit_title, edit_description, edit_tags,
            calculate_pricing, adjust_pricing, generate_listing_images,
            regenerate_listing_image, publish, remember_preference,
            get_generation_history
```

---

## 9. Tool Execution Architecture

### How Chat LLM Calls Python Processes

```
┌──────────┐     ┌──────────────┐     ┌──────────────────┐     ┌──────────┐
│  Chat UI │────→│ Next.js API  │────→│ Python Tool       │────→│ Supabase │
│  (React) │     │ /api/tools/  │     │ Server (FastAPI    │     │ Storage  │
│          │←────│ {tool_name}  │←────│ or subprocess)    │←────│ + DB     │
└──────────┘     └──────────────┘     └──────────────────┘     └──────────┘
     ↑                  ↑                      ↑
     │            ai SDK tool          HTTP endpoint
     │            streaming            or subprocess
     │
  Canvas updates
  via Supabase Realtime
```

### Option A: FastAPI Sidecar (RECOMMENDED for Phase 1)

Run a lightweight FastAPI server alongside the Next.js dashboard. Each tool = one endpoint.

```python
# prototype/tool_server.py
from fastapi import FastAPI
from design_director.director import generate_plan
from asset_pipeline.generator import generate_design
# ...

app = FastAPI()

@app.post("/tools/generate_plan")
async def tool_generate_plan(request: GeneratePlanRequest):
    """Generate a design plan — called by the chat LLM as a tool."""
    # 1. Load rules + niche
    # 2. Call generate_plan()
    # 3. Log to generation_log
    # 4. Save to Supabase
    # 5. Return plan JSON
    ...

@app.post("/tools/generate_artwork")
async def tool_generate_artwork(request: GenerateArtworkRequest):
    """Generate artwork for one area — streams progress via SSE."""
    ...
```

**Why FastAPI:**
- Python processes stay in Python (no subprocess overhead)
- SSE streaming for long-running ops (image gen takes 30-60s)
- Already have all pipeline code as importable Python modules
- FastAPI's async model handles concurrent requests well
- Simple deployment alongside worker.py

**FastAPI Lifecycle Management:**

```python
# Start: via root package.json (alongside dashboard)
# "dev": "concurrently \"cd dashboard && npm run dev\" \"cd prototype && uvicorn tool_server:app --port 8100 --host 127.0.0.1\""

# Health check: GET /health → { "status": "ok", "uptime": 123 }
# Dashboard checks health on startup and shows warning banner if tool server is unreachable

# Graceful shutdown:
# - FastAPI lifespan event cancels in-flight generation tasks
# - Running tool calls have 30s to complete before force-kill
# - Advisory locks are auto-cleared by PostgreSQL on connection close

# Process management:
# - Phase 1: Manual start via npm run dev (concurrently)
# - Phase 2: Supervisor or Docker Compose for production
# - Dashboard /api/health endpoint proxies to tool server health check
```

**Startup dependency:** Dashboard must not render the chat interface until tool server health check passes. Show a "Connecting to design engine..." loading state if health check fails, with auto-retry every 5s.

### Option B: Next.js API Routes with Python Subprocesses

Each Next.js API route spawns a Python subprocess. Simpler routing but higher overhead and harder to stream progress.

### Streaming Long Operations

Image generation takes 30-60s. The tool execution must stream progress:

```
User: "Generate the artwork"
LLM: [calls generate_all_artwork tool]
     ↓
Canvas: "Generating front panel..." (progress from tool)
Canvas: [front image appears] "Front generated (v1)"
Canvas: "Generating back panel (using front as reference)..."
Canvas: [back image appears] "Back generated (v1), similarity: 0.78"
Canvas: "Generating sleeve..."
Canvas: [sleeve image appears] "Sleeve generated (v1)"
Canvas: "Creating Printify product..."
Canvas: [mockup images appear] "3 mockups downloaded"
     ↓
LLM: "All artwork is generated! The front panel shows [description].
      The back has [description]. Take a look at the mockups on the
      right — what do you think? Any areas you'd like to regenerate?"
```

This is achieved via:
1. Tool server sends SSE events as each step completes
2. Each SSE event triggers a Supabase `workflow_logs` INSERT
3. `useRealtimeLogs` hook in the dashboard picks up the log
4. Canvas components re-render with new data
5. When tool completes, final result returns to the LLM for its response

### Preventing Stale Status Reads

**Problem:** The orchestrator reads `product.status` to select the active agent at each user message. During long-running tool execution (e.g., 3-minute artwork generation), the status changes in Supabase via the tool server — but the orchestrator may read a stale value if it queries at the wrong time.

**Solution: Event-driven status with optimistic lock**

```
1. Orchestrator reads product.status → selects agent → sends to LLM
2. LLM calls tool → Next.js API route forwards to tool server
3. Tool server acquires advisory lock: UPDATE products SET worker_claimed_at = now()
   WHERE id = ? AND worker_claimed_at IS NULL
4. Tool server updates status as it progresses (pending → generating → uploading)
5. Canvas receives status updates via Supabase Realtime subscription
6. Tool server clears lock on completion: SET worker_claimed_at = NULL
7. When tool returns, orchestrator re-reads fresh status before next LLM call
```

**Key rules:**
- The orchestrator **always re-reads product.status** before each LLM invocation — never caches it
- The tool server is the **only writer** of status during active execution (advisory lock prevents races)
- Canvas status display comes from **Supabase Realtime**, not from the orchestrator's read
- If the advisory lock is already held (another request in flight), the tool returns a 409 Conflict and the agent tells the user "Generation is already in progress"

---

## 10. UX Layout

### Desktop (>= 1024px): Split Pane

```
┌────────────────────────────────────────────────────────────────┐
│  Header: Product Theme | StatusBadge | Stage Indicator         │
├────────────────────────┬───────────────────────────────────────┤
│                        │                                       │
│  CHAT PANEL (40%)      │  CANVAS PANEL (60%)                  │
│  ────────────          │  ─────────────                       │
│                        │                                       │
│  [message history      │  [Stage-dependent content             │
│   scrollable]          │   as defined in Section 5]            │
│                        │                                       │
│                        │  ┌─ Pipeline Progress ──────────┐    │
│                        │  │ ● Plan ─── ● Assets ─── ○ List │  │
│                        │  └──────────────────────────────┘    │
│                        │                                       │
│                        │  ┌─ Generation Log ─────────────┐    │
│                        │  │ Area: front | v2 | 0.78 sim  │    │
│                        │  │ Prompt: [expandable]          │    │
│                        │  │ Model: gemini-3-pro | $0.18   │    │
│                        │  │ Rules: aop_hoodie v2.3        │    │
│                        │  └──────────────────────────────┘    │
│                        │                                       │
├────────────────────────┤                                       │
│  [ChatInput]           │                                       │
│  Shift+Enter: newline  │                                       │
└────────────────────────┴───────────────────────────────────────┘
```

### Mobile (< 1024px): Tab Toggle

```
┌──────────────────────────┐
│  [Chat] [Canvas] tabs    │
├──────────────────────────┤
│                          │
│  (shows one at a time)   │
│                          │
└──────────────────────────┘
```

### Canvas Panel Behavior

| Event | Canvas Reaction |
|-------|----------------|
| Product created | Switches to Stage 0 (inspiration) |
| Plan generated | Switches to Stage 1 (plan viewer with editable prompts) |
| User edits prompt in canvas | Syncs to DB, LLM acknowledges |
| User edits prompt via chat | Canvas updates in real-time |
| Artwork generating | Progressive loading — images appear as each area completes |
| Artwork complete | Full gallery with version badges and generation metadata |
| Image clicked | Lightbox opens with zoom + version history sidebar |
| Mockups ready | Mockup row appears below artwork |
| Copy generated | Listing preview with editable fields |
| Listing image clicked | Regen dialog with template picker (T1-T9) |

---

## 11. Data Flow Diagram

```
                    ┌─────────────────┐
                    │    User Chat    │
                    │    Message      │
                    └────────┬────────┘
                             │
                    ┌────────▼──────────────┐
                    │   ORCHESTRATOR        │
                    │   (Next.js API route) │
                    │                       │
                    │  1. Read product.status│
                    │  2. Select agent       │
                    │  3. Compile:           │
                    │     - base context     │
                    │     - user_preferences │
                    │     - agent sys prompt │
                    │     - handoff briefing │
                    │     - chat_messages    │
                    │  4. Filter tools       │
                    │  5. Call LLM           │
                    └────────┬──────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──┐  ┌───────▼──┐  ┌───────▼───────┐
     │ Agent 1:  │  │ Agent 2: │  │ Agent 3:      │
     │ Design    │  │ Asset    │  │ Listing       │
     │ Director  │  │ Producer │  │ Producer      │
     │ 5 tools   │  │ 6 tools  │  │ 8 tools       │
     └─────┬─────┘  └────┬─────┘  └───────┬───────┘
           │              │                │
           └──────────────┼────────────────┘
                          │ (tool calls)
                 ┌────────▼────────┐
                 │  Tool Router    │
                 │  /api/tools/    │
                 └────────┬────────┘
                          │
                 ┌────────▼────────┐
                 │  FastAPI Tool   │
                 │  Server (Python)│
                 └──┬──────────┬───┘
                    │          │
           ┌────────▼──┐  ┌───▼──────────┐
           │ Supabase  │  │ External API │
           │ DB +      │  │ (Gemini,     │
           │ Storage   │  │  Printify,   │
           │           │  │  GoAPI)      │
           │ ● products│  └──────────────┘
           │ ● gen_log │
           │ ● chat_msg│
           │ ● user_pref│
           └─────┬─────┘
                 │
        ┌────────▼────────┐
        │ Supabase        │
        │ Realtime        │
        │ (subscriptions) │
        └────────┬────────┘
                 │
        ┌────────▼────────┐
        │  Canvas Panel   │
        │  (React)        │
        │  re-renders     │
        └─────────────────┘
```

### Orchestrator Detail

The orchestrator is the critical piece — it's a Next.js API route (`/api/chat/design`) that:

```typescript
// Pseudocode for orchestrator
async function handleChatMessage(productId: string, userMessage: string) {
  // 1. Get current state
  const product = await supabase.from('products').select('*').eq('id', productId).single();
  const preferences = await supabase.from('user_preferences').select('*').eq('user_id', userId);
  const chatHistory = await supabase.from('chat_messages').select('*').eq('product_id', productId).order('created_at');

  // 2. Select agent
  const agent = getActiveAgent(product.status);

  // 3. Compile handoff briefing (only if agent changed)
  const lastAgent = chatHistory.at(-1)?.agent_id;
  const briefing = lastAgent !== agent.id
    ? await compileHandoffBriefing(product, chatHistory)
    : '';

  // 4. Build system prompt
  const systemPrompt = [
    buildBaseContext(product, briefing),
    buildUserMemory(preferences),
    agent.instructions,  // agent-specific system prompt
  ].join('\n\n');

  // 5. Call LLM with agent's tool set
  const response = await streamText({
    model: agent.model,
    system: systemPrompt,
    messages: chatHistory,
    tools: agent.tools,
  });

  // 6. Save assistant message to chat_messages with agent_id
  // 7. Stream response to client
  // 8. Execute tool calls, log to generation_log
}
```

---

## 12. Migration Path from Current System

### What Changes

| Component | Current | New |
|-----------|---------|-----|
| Product creation | Form at `/products/new` | Chat message: "Create a dark cottagecore mushroom hoodie" |
| Plan review | PlanViewer card on product detail page | Canvas panel + chat approval |
| Asset review | ArtworkGallery on product detail page | Canvas panel with version history + lightbox |
| Copy editing | Inline edit form fields | Canvas editable fields + chat commands |
| Worker polling | `worker.py` polls Supabase every 10s | FastAPI tool server invoked by chat LLM directly |
| Status transitions | Worker detects status + routes to stage | Chat LLM calls approve tool → direct status update |

### What Stays the Same

- All Python pipeline code (director, generator, uploader, writer, producer, pricing)
- Supabase schema (products, workflow_logs, niche_guides tables)
- Supabase Storage structure (artwork, mockups, listing-images buckets)
- Printify API integration
- Gemini/GoAPI image generation
- Listing image template system (T1-T9)
- YAML rules files

### Migration Strategy

1. **Phase A**: Build FastAPI tool server wrapping existing pipeline functions
2. **Phase B**: Build split-pane chat+canvas layout, wire to ai SDK
3. **Phase C**: Implement stage-specific system prompts + tool filtering
4. **Phase D**: Add generation_log table + lineage tracking in tool server
5. **Phase E**: Build canvas components (lightbox, version compare, inline editing)
6. **Phase F**: Wire Supabase Realtime for progressive canvas updates
7. **Phase G**: Deprecate worker.py polling loop (keep as fallback)

### Coexistence

During migration, both systems work simultaneously:
- Old: `/products/new` form → worker.py → approval cards
- New: `/products/{id}/design` chat → tool server → canvas
- Same Supabase DB, same Storage, same Printify products

---

## 13. Finalized Decisions

All architectural questions resolved. These are binding for implementation.

### D1: LLM Models — Configurable per agent via settings page

| Agent | Default Model | Default Temp | Notes |
|-------|--------------|-------------|-------|
| Concierge | Kimi K2.5 | 1.0 (fixed) | Cheap, good for brainstorming |
| Design Director | Gemini 3.1 Pro | 0.7 | Strong structured output + design reasoning |
| Asset Producer | Gemini 3.1 Pro | 0.7 | Technical image quality discussion |
| Listing Producer | Kimi K2.5 | 1.0 (fixed) | Good at structured content (titles, tags) |

**Kimi K2.5 temperature constraint:** Kimi K2.5 API rejects any temperature other than 1.0 — the API returns an error for any other value. The settings page must:
1. Show temperature as read-only "1.0 (fixed by provider)" when Kimi K2.5 is selected
2. Make temperature editable only for models that support it (Gemini, Claude)
3. Store a `model_constraints` config map: `{ "kimi-k2.5": { "temperature": { "fixed": 1.0 } } }`
4. If user switches from Gemini (temp 0.7) to Kimi, auto-reset temp to 1.0 with toast: "Kimi K2.5 requires temperature 1.0 — adjusted automatically"

**Settings page required**: Dashboard `/settings` page where user can change model + temperature per agent. Stored in `user_preferences` table with `category='agent_config'`.

### D2: Image Preview — Canvas only

Generated images appear **only in the canvas panel**. Chat shows text descriptions and directs attention to the canvas ("Front panel generated — take a look at the canvas"). Keeps the chat stream clean and text-focused.

### D3: Session Scope — 1:1 product per session

Each product gets its own chat thread. No multi-product sessions in Phase 1. To create a variant, start a new session (Concierge can pre-fill from an existing product).

### D4: Canvas Edit Sync — System message + agent acknowledges

When the user edits a field directly in the canvas:
1. Change writes to Supabase immediately
2. System message injected into chat: `"[Canvas edit] User updated front prompt directly"`
3. On next user message, the agent acknowledges the change naturally

Full lineage — every change visible in both generation_log and chat_messages.

### D5: Cost Guardrails — Ask first time, auto after

- First image generation in a session requires explicit confirmation with cost estimate
- Subsequent regenerations in same session are automatic
- `session_cost_confirmed` flag resets when session is reopened
- Running session spend shown in canvas footer

### D6: Rules Versioning — Hash + relevant fields only

- `rules_hash`: SHA256 of full YAML file at generation time
- `rules_file`: filename (e.g., `aop_hoodie.yaml`)
- `rules_snapshot`: JSONB with **only the fields relevant to that area** (~500B, not full 5KB)
- Full YAML reconstructable from git using hash

### D7: Agent Personality — Unified + subtle UI label + progress indicator

- **Chat**: All agents share same tone ("your design assistant"). Domain vocabulary shifts naturally. Agents never announce themselves.
- **UI label**: Small badge/chip shows active agent (e.g., "Design Director")
- **Progress bar**: Pipeline progress indicator above the canvas:
  ```
  ● Concept ──── ● Assets ──── ○ Listing ──── ○ Published
       ▲
  ```

### D8: Preference Inference — Moderate (2 signals + ask)

- After same pattern observed across 2+ products, agent asks: "Should I remember this for future designs?"
- Saves only on user confirmation, with `source: 'inferred'`, `confidence: 0.8`
- Explicit "remember this" saves immediately at `confidence: 1.0`
- Never silently infers — always asks

### D9: Batch Operations — Deferred to Phase 2

Chat = one product at a time. Batch stays in CLI (`batch_revamp.py`). Phase 2 adds batch agent to Concierge.

---

## 14. Dependencies & Prerequisites

| Dependency | Status | Notes |
|-----------|--------|-------|
| ai SDK (`@ai-sdk/react`, `ai`) | Installed | v3.0.88 / v6.0.86 |
| Supabase Realtime | Working | useRealtimeProduct, useRealtimeLogs |
| Chat components | Partial | ChatInput, MessageBubble exist; need canvas integration |
| PlanViewer | Working | Needs editable mode + DB sync |
| ArtworkGallery | Working | Needs lightbox + version badges |
| FastAPI | Not installed | Need to add to prototype/requirements.txt |
| Python pipeline | Working | All functions importable, tested |
| generation_log table | Not created | New migration needed |
| user_preferences table | Not created | New migration needed |
| Split-pane layout | Not built | New component (resizable panels) |
| Lightbox viewer | Not built | react-medium-image-zoom or custom |
| Settings page | Not built | Model/temperature config per agent |
| Agent orchestrator | Not built | Next.js API route with routing logic |
| Handoff briefing compiler | Not built | Summarizes product state for agent transitions |
| Progress indicator | Partial | PipelineProgress exists, needs chat+canvas adaptation |
| Gemini 3.1 Pro API key | Needed | For Design Director + Asset Producer agents |
| Google AI SDK for JS | Not installed | `@google/generative-ai` or OpenAI-compatible endpoint |

---

## 15. Success Metrics

1. **Full product creation via chat** — theme description → published listing, entirely through conversation
2. **Lineage query** — for any asset, can retrieve: exact prompt, model, rules version, parameters, cost, and all previous versions
3. **Regeneration via chat** — "regenerate the front panel, make it darker" → new version appears in canvas with version badge
4. **Sub-60s stage transitions** — plan approval to first artwork appearing in canvas < 60s
5. **Rules change tracking** — when we modify aop_hoodie.yaml, can compare which products used which rules version
6. **Graceful agent transitions** — agent switches are subtle (small badge change, no jarring UI reset). User may notice domain-specific vocabulary shifts but the conversation feels continuous
7. **Preference recall** — after 2+ products, agent references learned preferences without being told
8. **Settings-driven model swap** — change Design Director from Gemini to Claude in settings, next message uses new model

---

## 16. Implementation Phases

### Phase A: Foundation (database + tool server)
- `generation_log` and `user_preferences` migrations
- FastAPI tool server wrapping existing pipeline functions
- Pydantic request/response models for every tool endpoint
- Error handling middleware (retry logic, structured error responses)
- Advisory lock mechanism for concurrent request prevention
- Stale lock watchdog query
- Settings page with per-agent model/temperature config (with Kimi constraint)
- **Tests:** Unit tests for all Pydantic models, lock logic, watchdog. Integration tests for each tool endpoint with mocked LLM.

### Phase B: Chat + Canvas Layout
- Split-pane layout component (resizable, responsive)
- Agent orchestrator API route with routing logic
- Wire ai SDK to orchestrator with dynamic system prompts + tool sets
- Zod schemas for tool call parameter validation
- In-memory rate limiting on `/api/chat` and `/api/tools/*`
- Origin header check on API routes
- **Tests:** Unit tests for agent routing, Zod schemas. Integration test for orchestrator → tool server round-trip.

### Phase C: Agent System
- 4 agent configs (system prompts, tool definitions, model selection)
- Handoff briefing compiler (Section 20.2)
- Canvas edit → system message sync
- Progress indicator in canvas header
- Post-publish edit tools for Concierge (Section 20.1)
- **Tests:** Handoff briefing tests (H-1 through H-5). System prompt snapshot tests.

### Phase D: Canvas Components
- Stage-specific canvas renderers (plan viewer, artwork gallery, listing preview)
- Lightbox with zoom + version history sidebar
- Editable fields in canvas with DB sync
- Generation metadata panel (prompt, model, rules, cost)
- Error state cards (red border, retry button) for failed generations
- Partial Stage 2 display (completed areas + failed area + pending areas)
- **Tests:** Component unit tests (vitest). E2E tests CC-1 through CC-10.

### Phase E: Memory + Polish
- User preference read/write tools for agents
- Moderate inference (2-signal + ask pattern)
- Cost tracking per session
- First-time cost confirmation flow

---

## 17. Error Recovery & Failure Handling

Every tool call can fail. This section defines what happens for each failure class and how the system recovers.

### 17.1 Failure Taxonomy

| Failure Class | Examples | Recovery Strategy |
|--------------|---------|-------------------|
| **Transient** | Network timeout, 429 rate limit, Gemini 503 | Auto-retry with backoff (3 attempts, 5s/15s/45s) |
| **Partial** | Front artwork succeeds, back fails | Resume from last success (per-area status tracking) |
| **Permanent** | Invalid API key, model not found, YAML parse error | Fail fast, surface error to user in chat, no auto-retry |
| **Cost-related** | GoAPI balance depleted, Gemini quota exceeded | Notify user with cost info, suggest alternative (switch provider) |
| **State corruption** | Status stuck at "generating" with no lock | Watchdog detects stale locks (>15 min), auto-resets to previous gate status |

### 17.2 Tool Call Error Flow

When any tool call fails:

```
Tool server returns error
    ↓
Next.js API route receives { error: true, error_type, message, retriable }
    ↓
If retriable AND attempt < 3:
    → Auto-retry with exponential backoff
    → Log retry to workflow_logs (action: "tool_retry")
    ↓
If NOT retriable OR retries exhausted:
    → Log failure to workflow_logs (action: "tool_error")
    → Return structured error to LLM as tool result
    → LLM explains failure to user in natural language
    → Canvas shows error state (red border card with message + retry button)
    ↓
Product status rolls back to last stable gate:
    generating/uploading → concept_approved (user can re-trigger)
    copy_pricing/listing_images → production_approved (user can re-trigger)
    planning → pending (user can re-trigger)
```

### 17.3 Partial Stage 2 Failure (CRITICAL)

Stage 2 generates artwork for 3 areas sequentially (front → back → sleeve). Each area takes 30-60s. If the back fails after the front succeeds, we must NOT re-generate the front.

**Per-area status tracking in `generation_log`:**

```sql
-- Each area's generation is a separate generation_log row
-- The tool server checks which areas already have a successful entry
-- and skips them on resume

SELECT asset_type, version, was_approved
FROM generation_log
WHERE product_id = $1
  AND asset_type IN ('artwork_front', 'artwork_back', 'artwork_right_sleeve')
  AND was_approved IS NOT FALSE  -- NULL = pending, TRUE = approved
ORDER BY asset_type, version DESC;
```

**Resume logic in tool server:**

```python
async def generate_all_artwork(product_id: str, plan: dict):
    areas = ["front", "back", "right_sleeve"]

    for area in areas:
        # Check if this area already has a successful generation
        existing = get_latest_generation(product_id, f"artwork_{area}")
        if existing and existing.storage_path:
            log(f"Skipping {area} — already generated (v{existing.version})")
            continue

        try:
            result = generate_single_area(area, plan, reference_images)
            log_generation(product_id, area, result)
        except Exception as e:
            log_error(product_id, area, e)
            # Update product with partial progress info
            update_product(product_id,
                error_message=f"{area} generation failed: {str(e)}",
                error_area=area,
                status="concept_approved"  # Roll back to gate
            )
            raise  # Propagate to tool caller
```

**Canvas shows partial state:**
- Completed areas show their artwork with green check
- Failed area shows error card with red border and retry button
- Remaining areas show "Waiting" placeholder
- Chat message: "The front panel generated successfully, but the back panel failed: [error]. Say 'retry' to resume — I'll pick up from the back panel."

### 17.4 Network Disconnection During Generation

If the user's browser disconnects while a tool is executing:

1. **Tool server continues running** — it writes to Supabase regardless of frontend connection
2. **On reconnect**, the dashboard re-fetches product state and generation_log
3. **Canvas hydrates** from current DB state (artwork that appeared while offline now shows)
4. **Chat receives a system message**: "[Reconnected] Generation completed while you were away. The canvas shows the latest state."

### 17.5 Stale Lock Watchdog

A background timer (checked on each orchestrator invocation) detects stuck products:

```sql
-- Products stuck in transitional status with a stale lock
SELECT id FROM products
WHERE worker_claimed_at IS NOT NULL
  AND worker_claimed_at < now() - interval '15 minutes'
  AND status IN ('planning', 'generating', 'uploading', 'copy_pricing', 'listing_images');
```

For stale locks:
1. Clear `worker_claimed_at = NULL`
2. Roll back status to the previous gate (`generating` → `concept_approved`)
3. Log a `stale_lock_reset` entry in `workflow_logs`
4. On next user message, the agent notices the rollback and explains: "It looks like the previous generation was interrupted. Would you like me to try again?"

### 17.6 LLM Refuses to Call Tools

If the LLM responds with text instead of calling a tool when one is clearly needed:

1. The orchestrator does **not** auto-retry or force tool calls
2. The response is delivered to the user as-is
3. The user can rephrase or explicitly ask (e.g., "please generate the artwork now")
4. If this happens > 3 times consecutively, log a `tool_refusal` warning for debugging

This avoids infinite retry loops while keeping the user in control.

---

## 18. Security Considerations

### 18.1 Route Authentication

**Phase 1 (personal use):** No auth — dashboard runs locally, FastAPI tool server listens on localhost only.

**Phase 2 (multi-tenant SaaS):** Full auth required:

| Layer | Mechanism |
|-------|-----------|
| Dashboard routes | Supabase Auth (session cookies via `@supabase/ssr`) |
| API routes (`/api/chat`, `/api/tools/*`) | Verify Supabase JWT from request header |
| Tool server (FastAPI) | API key in `X-Tool-Server-Key` header, validated against env var |
| Supabase RLS | All tables get `user_id` column + RLS policies in Phase 2 |

**Phase 1 safeguards (even without auth):**
- Tool server binds to `127.0.0.1` only (not `0.0.0.0`)
- Next.js API routes check `Origin` header to prevent CSRF from other local apps
- `.env` files excluded from git (already in `.gitignore`)

### 18.2 API Key Protection

| Key | Storage | Access Pattern |
|-----|---------|---------------|
| Gemini API key | `prototype/.env` (server-side only) | Tool server reads from env, never sent to browser |
| GoAPI API key | `prototype/.env` (server-side only) | Tool server reads from env, never sent to browser |
| Kimi API key | `prototype/.env` (server-side only) | Tool server reads from env, never sent to browser |
| Printify API key | `prototype/.env` (server-side only) | Tool server reads from env, never sent to browser |
| Supabase anon key | `dashboard/.env.local` | Public key, OK for browser (RLS enforced in Phase 2) |
| Supabase service role key | `dashboard/.env.local` | Server-side only, used in API routes, never exposed to client |

**Rule:** No API keys appear in:
- Chat messages (agent responses are sanitized)
- generation_log entries (store model name, not key)
- Browser console or network tab (keys stay server-side)
- Git history (env files gitignored)

### 18.3 Input Sanitization

| Input Source | Sanitization |
|-------------|-------------|
| User chat messages | Stored as-is in DB (text). Rendered in React (auto-escaped by JSX). No `dangerouslySetInnerHTML`. |
| Canvas inline edits (prompts, title, description, tags) | Trimmed, max-length enforced (title: 140 chars, description: 5000 chars, tags: 20 chars each, 13 max). Stored as text. |
| LLM tool call parameters | Validated by Zod schemas in Next.js API routes before forwarding to tool server. Unknown fields stripped. |
| Tool server request bodies | Validated by Pydantic models in FastAPI endpoints. Type mismatches return 422. |
| File uploads (none in Phase 1) | Phase 2: validate MIME type, max size 50MB, virus scan via Supabase Storage policies |

**Prompt injection defense:**
- User messages are passed to the LLM as `role: "user"` — never injected into system prompts
- Canvas edits are stored in Supabase and read by the tool server as data — never interpolated into LLM prompts without proper quoting
- The `build_plan_user_prompt()` function in `prompts.py` already uses string formatting (not raw concatenation) for user-provided theme/style inputs

### 18.4 Rate Limiting

| Endpoint | Limit | Rationale |
|----------|-------|-----------|
| `/api/chat` | 30 messages/minute | Prevents LLM cost runaway from rapid-fire messages |
| `/api/tools/generate_*` | 5 calls/minute | Image generation is expensive ($0.18/image) |
| `/api/tools/publish` | 1 call/5 minutes | Publishing is irreversible, prevent accidental double-publish |
| Tool server (FastAPI) | 60 requests/minute global | Backstop for all tool calls |

**Phase 1 implementation:** Simple in-memory counter per route (reset on server restart). No need for Redis until Phase 2.

### 18.5 Cost Caps

| Cap | Default | Configurable |
|-----|---------|-------------|
| Per-session image generation spend | $5.00 | Yes, in settings |
| Per-product total spend | $15.00 | Yes, in settings |
| Daily total spend | $50.00 | Yes, in settings |

When a cap is reached:
1. Tool server refuses the generation request with `{ error_type: "cost_cap_exceeded" }`
2. Agent tells user: "You've reached the $5.00 session limit. You can adjust this in Settings or start a new session."
3. Canvas shows cost badge in warning state (amber)

Cost tracked in `generation_log.cost_usd` — SUM queries per session/product/day.

---

## 19. Testing Strategy

### 19.1 Testing Layers

```
┌──────────────────────────────────────────────────┐
│ E2E Tests (Playwright)                            │
│ Full chat → canvas → tool → pipeline flow         │
├──────────────────────────────────────────────────┤
│ Integration Tests (pytest + httpx)                │
│ Tool server endpoints, DB operations, pipeline    │
├──────────────────────────────────────────────────┤
│ Unit Tests (vitest + pytest)                      │
│ Components, routing logic, Zod schemas, Pydantic  │
└──────────────────────────────────────────────────┘
```

### 19.2 Unit Tests

**Frontend (vitest):**

| Test Target | What to Test |
|------------|-------------|
| Agent routing (`getActiveAgent`) | Every product status maps to correct agent config |
| Handoff briefing compiler | Generates correct briefing from product state + recent messages |
| Canvas stage renderer selection | Each status renders the correct canvas component |
| Zod tool schemas | Invalid params rejected, valid params pass, edge cases handled |
| Cost cap calculation | SUM queries return correct values, cap enforcement logic |
| Model constraint validation | Kimi temp locked to 1.0, Gemini temp accepts 0.0-2.0 |

**Backend (pytest):**

| Test Target | What to Test |
|------------|-------------|
| FastAPI endpoints | Request validation, error responses, Pydantic models |
| Pipeline adapter functions | `run_plan_stage`, `run_asset_stage`, `run_production_stage` |
| Generation log writer | Correct fields populated, version chains, replaced_by FK |
| Resume logic | Partial Stage 2: skips completed areas, retries failed areas |
| Stale lock detection | Watchdog query returns correct stale products |
| Rules hash computation | Same YAML = same hash, changed YAML = different hash |

### 19.3 Integration Tests

**Tool server integration (pytest + httpx):**

```python
# Test with real Supabase (local), mocked LLM + image providers
async def test_generate_plan_tool():
    # Setup: create product in DB
    product_id = create_test_product(theme="test mushroom forest")

    # Act: call tool endpoint with mocked LLM response
    with mock_llm(return_value=SAMPLE_PLAN_JSON):
        resp = await client.post("/tools/generate_plan", json={
            "product_id": product_id,
            "theme": "test mushroom forest"
        })

    # Assert: product status updated, generation_log entry created
    assert resp.status_code == 200
    product = fetch_product(product_id)
    assert product["status"] == "plan_ready"
    assert product["design_plan"] is not None

    log_entry = fetch_latest_generation(product_id, "design_plan")
    assert log_entry["model_id"] == "mock-model"
    assert log_entry["rules_hash"] is not None
```

**Critical integration test cases:**
1. Full Stage 1 flow: create product → generate plan → approve → status = concept_approved
2. Full Stage 2 flow: generate artwork (3 areas) → upload to Printify → status = mockups_ready
3. Partial failure resume: front succeeds → back fails → resume → back retries, front skipped
4. Canvas edit sync: edit prompt in DB → system message appears in chat_messages
5. Cost tracking: 3 generations → cost_usd SUM matches expected total
6. Stale lock reset: set old lock → run watchdog → verify status rollback

### 19.4 E2E Tests (Playwright)

**Adapting the existing 27-test suite:**

The current E2E suite (`dashboard/e2e/full-pipeline.spec.ts`) tests the form-based flow. For the chat+canvas interface, we create a **parallel test file** rather than replacing the existing one (both flows coexist during migration).

```
dashboard/e2e/
  full-pipeline.spec.ts          ← existing form-based tests (keep)
  chat-canvas-pipeline.spec.ts   ← new chat+canvas tests
```

**Key chat+canvas E2E scenarios:**

| Test | Description | Timeout |
|------|------------|---------|
| CC-1 | Type theme in chat → product created → canvas shows plan | 120s |
| CC-2 | Edit prompt in canvas → DB updated → chat shows system message | 30s |
| CC-3 | Approve plan via chat → Stage 2 begins → artwork appears progressively in canvas | 600s |
| CC-4 | Reject area via chat → regen → new version badge appears in canvas | 120s |
| CC-5 | Full pipeline: chat theme → approve plan → approve mockups → publish | 900s |
| CC-6 | Stage progress bar reflects correct active stage | 30s |
| CC-7 | Lightbox opens on artwork click → zoom works → close returns focus | 15s |
| CC-8 | Canvas edit + chat message race: edit field, send message simultaneously → no data loss | 30s |
| CC-9 | Network disconnect simulation → reconnect → canvas hydrates from DB | 30s |
| CC-10 | Cost cap reached → agent refuses generation → canvas shows warning | 30s |

### 19.5 Handling Non-Deterministic LLM Output

LLMs don't produce identical output across runs. Testing strategies:

1. **Mock LLM responses in unit/integration tests** — use canned JSON responses for tool calls. Test the pipeline logic, not the LLM output quality.

2. **Schema validation over content matching** — assert that the LLM's tool call parameters match the Zod/Pydantic schema, not that specific text appears.

3. **Snapshot tests for system prompts** — capture system prompt assembly output and snapshot it. Catches unintended prompt changes.

4. **Golden path recording** — record one successful E2E run with real LLMs, save the tool call sequence as a "golden path". Future runs can replay this sequence with mocked LLM to verify pipeline logic at full speed.

5. **Smoke tests with real LLMs** — separate test suite that runs against real APIs (Gemini, Kimi) but only checks structure:
   - Plan JSON has all required fields
   - Generated image is a valid PNG/JPEG with expected dimensions
   - Copy output has title, description, 13 tags

These smoke tests run on-demand (not in CI), because they cost money and are non-deterministic.

### 19.6 Agent Handoff Testing

Handoff correctness is critical. Dedicated test cases:

| Test | Description |
|------|------------|
| H-1 | Design Director → Asset Producer: briefing contains plan, palette, all area prompts |
| H-2 | Asset Producer → Listing Producer: briefing contains artwork URLs, mockup URLs, Printify product ID |
| H-3 | Status rollback during handoff: if new agent's first tool call fails, status returns to previous gate |
| H-4 | Chat history continuity: messages from Agent A are visible to Agent B (verified by checking injected messages array) |
| H-5 | Memory injection: user_preferences are included in both agents' system prompts |

---

## 20. Published Product Management

### 20.1 Post-Publish Actions

When a product reaches `published` status, the Concierge agent resumes control. However, it needs limited edit capabilities for post-publish corrections:

| Tool | Description | Available Post-Publish |
|------|------------|----------------------|
| `edit_title` | Update Etsy listing title | Yes — via Printify API PUT |
| `edit_description` | Update Etsy listing description | Yes — via Printify API PUT |
| `edit_tags` | Update Etsy tags | Yes — via Printify API PUT |
| `adjust_pricing` | Change sale/list price | Yes — via Printify API PUT |
| `unpublish` | Remove from Etsy (keep on Printify) | Yes — requires confirmation |
| `regenerate_*` | Any regeneration | No — create new product instead |

The Concierge agent's system prompt includes:
```
POST-PUBLISH MODE:
This product is live on Etsy. You can make text and pricing edits
(these update via Printify API). For design changes, suggest creating
a new product based on this one.
```

### 20.2 Handoff Briefing Compiler

The handoff briefing is assembled by the orchestrator from Supabase queries:

```typescript
async function compileHandoffBriefing(productId: string, newAgent: AgentConfig): string {
  const product = await fetchProduct(productId);
  const recentLogs = await fetchRecentLogs(productId, limit: 10);
  const recentMessages = await fetchRecentMessages(productId, limit: 20);
  const generations = await fetchGenerationSummary(productId);

  let briefing = `HANDOFF BRIEFING:\n`;
  briefing += `Product: ${product.theme} (${product.product_type})\n`;
  briefing += `Status: ${product.status}\n`;
  briefing += `Niche: ${product.niche_slug}\n`;

  // Include stage-specific context
  if (newAgent.stage === 'asset_generation') {
    briefing += `\nDESIGN PLAN:\n${JSON.stringify(product.design_plan, null, 2)}\n`;
    briefing += `Palette: ${product.design_plan?.palette?.join(', ')}\n`;
  }

  if (newAgent.stage === 'listing_production') {
    briefing += `\nARTWORK: ${generations.artwork.length} areas generated\n`;
    briefing += `Printify Product: ${product.printify_product_id}\n`;
    briefing += `Mockups: ${generations.mockups.length} available\n`;
  }

  // Recent activity (what happened leading to this handoff)
  briefing += `\nRECENT ACTIVITY:\n`;
  for (const log of recentLogs) {
    briefing += `- ${log.action}: ${log.details}\n`;
  }

  return briefing;
}
```
