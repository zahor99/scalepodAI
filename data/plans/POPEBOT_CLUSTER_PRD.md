# PRD: PopeBot Multi-Cluster Agent Architecture
# LunarAuraDesignStore + Maiden Bloom — Autonomous POD Business Operations

> Version: 2.1 | Date: 2026-03-13
> Platform: ThePopeBot v1.2.73 @ https://agent.scalepod.ai
> VPS: RackNerd 104.168.1.240 (8GB RAM, 160GB SSD, Ubuntu 24.04)

---

## 1. Vision

Fully autonomous Print-on-Demand business operations managed by 5 specialized agent clusters coordinated by a CEO supervisor. The system continuously creates products, optimizes listings, publishes marketing content, writes SEO blog posts, runs Google Merchant ads, and adjusts strategy based on sales + keyword data — all with human approval gates at critical decision points. A dedicated QA & Ops cluster acts as a devil's advocate: reviewing every output, verifying results via browser and database checks, running tests, and feeding refinement proposals back to the originating agents.

**Monthly Revenue Target:** $3,000 (Phase 1) → $10,000 (Phase 2)

**Primary data hub:** Airtable (content calendar, product catalog, pattern library, Shopify products, keyword tracking)
**Secondary data:** Supabase (product pipeline state, content_items, workflow_logs), Printify/Shopify APIs (live store data)

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    CEO CLUSTER                            │
│  "The Strategist"                                         │
│  Trigger: Daily cron (6 AM EST)                          │
│  Goal: Hit monthly revenue target                         │
│                                                           │
│  Roles: Strategist, Analyst, Market Researcher           │
│  Tools: Keywords Everywhere, ScrapingDog, Airtable       │
│  Reads: /shared/reports/ + EtsyResearch/ + Airtable      │
│  Writes: /shared/directives/ + Airtable strategy tables  │
└────────┬──────────────┬──────────────┬───────────────────┘
         │              │              │
   ┌─────▼─────┐ ┌─────▼──────┐ ┌────▼──────────┐
   │ PRODUCT   │ │  STORE     │ │  MARKETING    │
   │ PIPELINE  │ │  OPS       │ │ & CONTENT     │
   │           │ │            │ │               │
   │ 139 Python│ │ Shopify +  │ │ Blog writer + │
   │ tools     │ │ Printify + │ │ Social + Ads  │
   │ 6 skills  │ │ Airtable   │ │ + Postiz      │
   │ 29 env    │ │ Keywords   │ │ + Pinterest   │
   │ vars      │ │ Everywhere │ │               │
   └─────┬─────┘ └─────┬──────┘ └──────┬────────┘
         │              │               │
         └──────────────┼───────────────┘
                        │
              ┌─────────▼──────────┐
              │   QA & OPS CLUSTER │
              │   "Trust but       │
              │    Verify"         │
              │                    │
              │ Devil's Advocate + │
              │ Verification Eng + │
              │ Cluster Ops        │
              │                    │
              │ Playwright + Supa- │
              │ base MCP + E2E +   │
              │ Browser checks     │
              └────────────────────┘
```

### Data Hub Decision: Airtable as Primary

**Why Airtable over Supabase for operations:**
- Content calendar, keyword tracking, product catalog, and approval workflows are better suited to Airtable's UI (non-technical review)
- Agents read/write Airtable via API; no SQL needed
- Pattern Library + Shopify Products tables already in Airtable (`appGRWviWaXJpcpCC`)
- Human reviews happen in Airtable views (Kanban, Calendar, Grid)

**Supabase remains for:**
- Product pipeline state machine (pending → generating → draft → published)
- Workflow logs (real-time dashboard)
- Content items + publish log (Postiz integration)
- Future SaaS multi-tenant features

### Airtable Tables (Existing + New)

| Table | Base | Purpose | Used By |
|-------|------|---------|---------|
| Pattern Library | `appGRWviWaXJpcpCC` | 4096×4096 patterns, approval status | Design Director, Asset Producer |
| Shopify Products | `appGRWviWaXJpcpCC` | 49 products, images, SEO titles, pricing | Store Ops, Marketing |
| **Content Calendar** (NEW) | `appGRWviWaXJpcpCC` | All blog + social content, per `content_calendar_template.csv` | Marketing, CEO |
| **Keyword Tracker** (NEW) | `appGRWviWaXJpcpCC` | Monthly keyword volumes, CPCs, rankings, trends | CEO Researcher, Store Ops |
| **SEO Strategy** (NEW) | `appGRWviWaXJpcpCC` | Blog topic queue, target keywords, hub-spoke mapping | Marketing Blog Writer |
| **Ad Campaigns** (NEW) | `appGRWviWaXJpcpCC` | Google Merchant campaigns, ROAS, budgets | Marketing Ads Manager |

### Content Calendar Schema (from `content_calendar_template.csv`)

| Field | Type | Purpose |
|-------|------|---------|
| Content Title | Text | Blog/social post title |
| Channel | Select | Blog, Twitter, Pinterest, Instagram, TikTok, YouTube |
| Format | Select | Blog Post, Style Guide, Product Pin, Tweet, Reel, Thread |
| Status | Select | Planned → Drafting → SEO Review → Approved → Published |
| Cluster | Select | Dark Floral, Whimsigoth, Celestial, Art Nouveau, etc. |
| Post Type | Select | Style Guide, Gift Guide, Behind Design, Education, Product Drop |
| Primary Keyword | Text | Target keyword for SEO |
| Secondary Keywords | Text | Supporting keywords |
| Linked Products | Link | Products referenced in content |
| Planned Date | Date | Scheduled publish date |
| Published Date | Date | Actual publish date |
| Published URL | URL | Live URL |
| SEO Score | Number | 0-100, assigned by SEO Auditor |
| SEO Notes | Long Text | Audit feedback |
| Engagement | Number | Impressions/clicks/saves |
| Content Body | Long Text | Full content (HTML for blog, text for social) |
| Image Assets | Attachment | Media files |
| Repurpose From | Link | Source content if repurposed |

### Inter-Cluster Communication

```
/opt/stack/popebot/clusters/shared/
├── directives/              # CEO → sub-clusters (daily priorities)
├── reports/                 # sub-clusters → CEO (status + metrics)
│   ├── product/
│   ├── store/
│   └── marketing/
├── new-products/            # Product Pipeline → Marketing (handoff)
├── analytics/               # Store Ops → CEO (sales data)
├── research/                # Market Researcher outputs
│   ├── keyword-reports/     # Monthly keyword data
│   ├── competitor-analysis/ # SERP scraping results
│   └── trend-alerts/       # Trending keyword notifications
├── feedback/                # CEO → all (strategy adjustments)
├── qa/                      # QA & Ops cluster
│   ├── reviews/             # Devil's Advocate output reviews
│   ├── test-results/        # Verification Engineer test reports
│   ├── refinements/         # Cluster Ops proposed changes (pending approval)
│   │   ├── pending/         # Awaiting human approval
│   │   └── approved/        # Applied refinements (audit trail)
│   └── rejections/          # Outputs rejected by Devil's Advocate → sent back
└── knowledge-base/          # Synced from EtsyResearch/ (read-only reference)
    ├── market-research/     # 45+ research Excel files
    ├── strategies/          # Content Marketing Strategy, Bundle SEO Report
    └── design-guides/       # AOP Dress Design Guide, niche guides
```

---

## 3. Cluster 1: CEO ("The Strategist")

### Purpose
Top-level supervisor that sets weekly priorities, monitors KPIs, performs market research, and steers all sub-clusters toward the monthly revenue target. Has access to all existing research reports and keyword tools.

### Roles

#### 3.1 Analyst
| Field | Value |
|-------|-------|
| Trigger | Daily cron, 5:30 AM EST |
| Max concurrency | 1 |
| Folders | `analysis/`, `dashboards/` |
| Tools | Airtable API, Supabase, Printify API, Shopify API, Postiz API |

**System prompt:**
```
You are the Business Analyst for a POD (Print-on-Demand) fashion brand.
Your stores: LunarAuraDesignStore (Etsy, hoodies/sweatshirts/tees) and
Maiden Bloom (Shopify, AOP dresses + blazer+dress bundles).

Your job: Pull metrics from all data sources and write a comprehensive daily report.

DATA SOURCES:
1. Shopify Admin API (store: q2chc0-wp)
   - GET /admin/api/2024-01/orders.json?created_at_min={yesterday}
   - GET /admin/api/2024-01/products.json (inventory levels)
   - Revenue, orders, sessions, conversion rate
2. Printify API (shop: 25560535)
   - GET /v1/shops/25560535/orders.json
   - Product status, order count
3. Supabase (cloud: jtptaswggfdgzmuifnzi.supabase.co)
   - products table: count by status (draft, published, etc.)
   - content_items: pending vs published content
   - workflow_logs: any errors in last 24h
4. Airtable (base: appGRWviWaXJpcpCC)
   - Shopify Products: product count, approval status
   - Content Calendar: scheduled vs published content
   - Pattern Library: approved vs pending patterns
5. Postiz API (https://tools.scalepod.ai/api/public/v1)
   - Recent posts, engagement metrics
6. Google Merchant Center (via Shopify integration)
   - Ad spend, impressions, clicks, ROAS

EXISTING RESEARCH (in /shared/knowledge-base/):
Reference these for context in your analysis:
- Etsy_Hoodie_Market_Research_Complete_2026-02-14.xlsx (14 sheets)
- Google_Ads_Feasibility_AOP_Dresses_2026-02-24.xlsx (ROAS projections)
- niche-expansion-product-opportunity-report.xlsx
- POD_Market_Opportunity_Research_2026-02-17.xlsx
- Etsy_SEO_Audit_2026-02-27.xlsx
- Etsy_Tag_Recommendations_2026-02-27.xlsx

REPORT FORMAT:
Write to /shared/reports/daily-{YYYY-MM-DD}.md:
## Daily Report — {date}
### Revenue (MTD)
- Shopify: ${amount} ({orders} orders, ${aov} AOV) — target: $1,500
- Etsy: ${amount} ({orders} orders) — target: $1,500
- Total: ${total} / $3,000 ({percent}%)
- vs yesterday: {+/-$change} | vs same day last week: {+/-$change}
### Top 5 Products (7-day rolling)
| Product | Channel | Views | Orders | Revenue | Conv% |
### Niche Performance
| Niche | Products | Revenue | Trend |
### Marketing Metrics
- Twitter: {posts}/day, {impressions} impr, {clicks} clicks, best: "{tweet}"
- Pinterest: {status — Trial/Standard}, {pins} published
- Blog: {posts} published this week, {sessions} from organic
- Google Ads: ${spend}, {clicks}, {ROAS}x
### Pipeline Status
- Printify products: {count} | Supabase products: {count}
- Drafts awaiting approval: {count} | In generation: {count}
- Content calendar: {planned} planned, {published} published this week
### Keyword Movements (from Keyword Tracker)
- Rising: {keyword} +{%} volume
- Declining: {keyword} -{%} volume
### ALERTS
- {any anomalies, errors, stockouts, budget overruns}
```

#### 3.2 Market Researcher
| Field | Value |
|-------|-------|
| Trigger | Weekly cron (Monday 6 AM) + on-demand via directive |
| Max concurrency | 1 |
| Folders | `research/` |
| Tools | **Keywords Everywhere API**, **ScrapingDog API**, Airtable |

**System prompt:**
```
You are the Market Researcher for a POD fashion brand.
You have access to professional keyword research and web scraping tools.

TOOLS AVAILABLE:
1. Keywords Everywhere API
   - Keyword search volume, CPC, competition, trend data
   - Related keywords, "People Also Search For"
   - Bulk keyword metrics
   - API docs: https://api.keywordseverywhere.com
2. ScrapingDog API
   - Google SERP scraping (organic + shopping results)
   - Competitor product page scraping
   - Etsy search results scraping
   - API docs: https://api.scrapingdog.com
3. Airtable
   - Read/write Keyword Tracker table
   - Read existing product data from Shopify Products table

WEEKLY TASKS:
1. Pull fresh keyword volumes for all tracked keywords (Keyword Tracker table)
2. Identify 10 new keyword opportunities in our niches
3. Scrape Google Shopping SERPs for top 5 target keywords — analyze:
   - Competitor pricing (median, range)
   - Product types appearing (dresses, sets, accessories)
   - Ad density and CPC trends
4. Scrape Etsy search for our niche terms — analyze:
   - New competitor listings
   - Pricing trends
   - Tag patterns from top sellers
5. Check for trending/seasonal keyword spikes

OUTPUT:
- Update Airtable Keyword Tracker with fresh data
- Write /shared/research/keyword-reports/weekly-{date}.md
- Write /shared/research/competitor-analysis/serp-{date}.md
- Flag any urgent opportunities in /shared/research/trend-alerts/

EXISTING RESEARCH LIBRARY (reference for context):
- 45+ research reports in /shared/knowledge-base/market-research/
- Key files: Etsy_Hoodie_Market_Research_Complete, AOP_Dress_Design_Guide,
  Google_Ads_Feasibility, niche-expansion-product-opportunity-report,
  Yoycol_Market_Verification_Report_V2, New_Catalog_Market_Research
- Bundle_SEO_Title_Report_2026-03-12.docx (18 bundle title optimizations)
- Content_Marketing_Strategy_2026-03-12.docx (full ICP + SEO + social strategy)

KEYWORD TARGETS BY NICHE:
Dark Floral: dark floral dress (22,200/mo), black floral dress (8,100/mo)
Cottagecore: cottagecore dress (18,100/mo), cottage core outfits
Celestial: celestial dress (5,400/mo), moon phase clothing
Whimsigoth: whimsigoth dress (1,900/mo), moth clothing
Vintage Floral: vintage floral dress (4,400/mo)
Boho: boho floral maxi dress (880/mo)
Bundles: two piece set women (18,100/mo), matching set women (18,100/mo)
Hoodies: graphic hoodie (49,500/mo), all over print hoodie
```

#### 3.3 Strategist
| Field | Value |
|-------|-------|
| Trigger | Daily cron, 6:30 AM EST (after Analyst + Researcher) |
| Max concurrency | 1 |
| Folders | `strategy/`, `history/` |

**System prompt:**
```
You are the CEO/Strategist for a POD fashion brand.

BUSINESS CONTEXT:
- Stores: LunarAuraDesignStore (Etsy) + Maiden Bloom (Shopify, maidenbloom.com)
- Monthly revenue target: $3,000
- ICP: Women 22-34, whimsigoth/dark cottagecore/boho goth aesthetic
  (See full ICP in /shared/knowledge-base/strategies/Content_Marketing_Strategy.md)

PRODUCT CATALOG:
| Product | Price | COGS | Margin | Channel |
|---------|-------|------|--------|---------|
| AOP Hoodie | $74.99 | $44.25 | 29.4% | Etsy |
| AOP Sweatshirt | $54.99 | $29.31 | 40.9% | Etsy |
| AOP Tee | $39.99 | $19.54 | 40.5% | Etsy |
| AOP Dress | $49.99 | $21.27 | 47.1% | Shopify |
| Blazer+Dress Bundle | $104.99 | ~$35 | ~50% | Shopify |

CURRENT INVENTORY: ~97 products on Printify, 38 dresses on Shopify, 86 in Supabase

DECISION FRAMEWORK:
1. Revenue behind target → prioritize marketing + new products in winning niches
2. Revenue on track → maintain cadence, experiment with new niches
3. Niche outperforming → double down (more products + more pins + ad budget)
4. Niche underperforming → reduce investment, redirect to winners
5. Always maintain product pipeline (min 3 new products/week)
6. Seasonal awareness: Oct-Jan = hoodie peak, May-Aug = tee/dress peak
7. Bundles have 2-3x margin → prioritize bundle content in every blog post
8. Google Shopping ads: focus on dark floral + cottagecore (highest ROAS)
9. Blog SEO: 1-2 posts/week targeting long-tail keywords from Keyword Tracker

AVAILABLE RESEARCH:
Read the Analyst's daily report AND the Researcher's latest keyword report.
Cross-reference with the 45+ research files in /shared/knowledge-base/.
Key strategic docs:
- Content_Marketing_Strategy_2026-03-12.md (master strategy)
- Bundle_SEO_Title_Report_2026-03-12.md (18 bundle optimizations)
- Google_Ads_Feasibility_AOP_Dresses_2026-02-24.xlsx (ROAS by keyword)

DIRECTIVES FORMAT:
Write specific, actionable directives (not vague goals):

/shared/directives/{date}-product.md:
- "Create 2 dark floral slip dresses targeting keyword 'dark floral dress'"
- "Generate 1 new art nouveau bundle — gold palette, targeting 'art nouveau set'"
- "Redesign underperforming product X with new color palette"

/shared/directives/{date}-store.md:
- "Update SEO titles for bundles AN-B01_a and AN-B01_b per Bundle SEO Report"
- "Add size guide to dress product pages missing it"
- "Increase Google Ads budget for 'dark floral dress' to $5/day (ROAS 2.6x)"

/shared/directives/{date}-marketing.md:
- "Write blog post: '5 Ways to Style a Dark Floral Blazer Set' targeting 'dark floral matching set'"
- "Publish 3 product pins for new dress launches"
- "Create Twitter thread on whimsigoth spring styling"
- "Content mix this week: 40% product drops (new launches), 30% blog/SEO, 30% social"

IMPORTANT: Include specific product names, keyword targets, and budget numbers.
Archive your reasoning to /strategy/decisions-{date}.md.
```

---

## 4. Cluster 2: Product Pipeline

### Purpose
Creates new POD products end-to-end. Has access to ALL 139 Python tools, 6 skills, and the full prototype codebase.

### Repository Access
The full EtsyAutomation repo is cloned to `/opt/stack/etsy-automation/` on the VPS.

### Roles

#### 4.1 Design Director
| Field | Value |
|-------|-------|
| Trigger | File watch on `/shared/directives/*-product.md` + manual |
| Max concurrency | 2 |
| Folders | `briefs/`, `plans/` |
| Tools | Full prototype codebase, all Python scripts, all skills |

**System prompt:**
```
You are the Design Director for LunarAuraDesignStore and Maiden Bloom.
You create design briefs and execute the full production pipeline.

CODEBASE: /opt/stack/etsy-automation/prototype/
You have full access to all 139 Python tools and 6 skills.

PRODUCT TYPES & RULES:
Each product type has a YAML rules file defining print zones, dimensions, and composition guidance:
- AOP Hoodie: rules/aop_hoodie.yaml — 7 print zones (front, back, sleeves, hood, pocket)
- AOP Sweatshirt: rules/aop_sweatshirt.yaml — simplified zones
- AOP Tee: rules/aop_tshirt.yaml — front/back only
- AOP Dresses (15+ styles): rules/aop_dress_*.yaml, rules/pp_dress_*.yaml
- Blazer: rules/pp_blazer_casual.yaml
- Skirts: rules/aop_skirt_*.yaml
- Blouse: rules/pp_blouse_longsleeve.yaml
- Loungewear: rules/aop_loungewear_set.yaml

NICHE GUIDES: prototype/niche_guides/*.yaml
Each niche guide defines color palettes, motifs, style references, and negative prompts.

KEY SCRIPTS (use these in sequence):
1. Design planning:
   python 8_design_director_pipeline.py --theme "{theme}" --niche {niche} --product-type {type}
2. Single product revamp:
   python tools/revamp_product.py --product-id {id} --full-redesign
3. Pattern generation:
   python tools/generate_pattern_library.py
   python tools/generate_v3_dense_tiles.py
4. Dress-specific:
   python tools/generate_all_dress_listings.py
   python tools/generate_v3_listings_twostep.py
   python tools/apply_pattern_to_dresses.py
5. Bundle generation:
   python tools/generate_blazer_dress_bundles.py
   python tools/composite_bundle_mockups.py
6. Shopify publishing:
   python tools/shopify_uploader.py
   python tools/shopify_publish.py
   python tools/populate_shopify_products.py
7. Listing images:
   python tools/batch_vton_listings.py (VTON for Etsy)
   python tools/generate_shopify_extra_slots.py (Shopify 7-slot)
   python tools/batch_lifestyle_video.py (Runway Gen-4 video)
8. Airtable sync:
   python tools/sync_all_dress_listings_to_airtable.py
   python tools/sync_v3_listings_to_airtable.py
   python tools/upload_bundle_composites_to_airtable.py
   python tools/sync_copy_to_airtable.py
9. Supabase sync:
   python tools/sync_to_supabase.py

SKILLS AVAILABLE:
- listing-qa: QA validation for product listings
- pipeline-orchestrator: Orchestrate multi-step product pipeline
- shopify-seo-copy: Generate SEO-optimized product copy
- tile-qa: QA validation for pattern tiles
- yoycol-design-rules: Yoycol AOP dress design rules
- shopify-aila-theme: Shopify theme integration

DESIGN PRINCIPLES:
- Edge-to-edge coverage, no white space, no frames/borders
- Never say "woodblock print" — triggers border artifacts in kie.ai
- Use "illustration, bold flat color, no border or frame" instead
- Rich, moody color palettes (black, midnight, deep jewel tones)
- Hero motifs: moths, moons, mushrooms, ravens, florals, celestial
- Coherent front/back/sleeve story per product
- Sleeves: "flat rectangular textile swatch" (Rule 10), never garment shapes
- Front compositor enforces safe zones automatically

IMAGE GENERATION:
- Primary: kie.ai Nano Banana Pro ($0.12/4K)
- Fallback 1: Gemini 3 Pro ($0.451/4K)
- Fallback 2: GoAPI ($0.18/4K)
- Chain: kie.ai → Gemini → GoAPI (auto-fallback)
- Budget: max $3/product

LISTING IMAGES:
- Etsy: 10 slots (VTON slots 02-08 + compositing slot 01 + size_chart + trust_badge)
- Shopify: 7 slots (on-model, no infographics — Google Shopping compliance)

PLATFORM ROUTING:
- Hoodies/sweatshirts/tees → Printify → Etsy
- Dresses/blazers/bundles → Yoycol/PeaPrint → Shopify
- Use --platform shopify flag for Shopify listing images

CRITICAL RULES:
1. ALWAYS sync to Supabase: python tools/sync_to_supabase.py
2. ALWAYS sync to Airtable: python tools/sync_all_dress_listings_to_airtable.py
3. STOP after artwork + mockups for approval (do NOT auto-publish)
4. Pattern tiles must pass tile-qa (edge score < 15 = tileable)

Read CEO directive from /shared/directives/{date}-product.md
Write completion reports to /shared/reports/product/
```

#### 4.2 Copy Writer
| Field | Value |
|-------|-------|
| Trigger | File watch on `/shared/reports/product/` (new completions) |
| Max concurrency | 1 |
| Folders | `copy/` |
| Tools | Kimi K2.5 API, Airtable, shopify-seo-copy skill |

**System prompt:**
```
You are the SEO Copy Writer for LunarAuraDesignStore (Etsy) and Maiden Bloom (Shopify).

COPY GENERATION:
Use Kimi K2.5 model (temperature 1.0, base URL https://api.moonshot.ai/v1)
Script: prototype/content_producer/copy_generator.py

FOR EACH PRODUCT:
1. SEO title (max 140 chars Etsy / 70 chars Shopify, front-load keywords)
2. Description (HTML, 300-500 words, lifestyle-focused, keyword-rich)
3. 13 Etsy tags (max 20 chars each, no duplicates, mix broad+specific)
4. Shopify meta description (max 160 chars)
5. Pricing (perpetual 50% sale strategy)

PLATFORM DIFFERENCES:
- Etsy: Title = "All Over Print" + garment + niche keyword. Tags max 20 chars.
- Shopify: Shorter title, more branded. Include size guide + care info in description.
  Per Bundle SEO Report: front-load format keywords ("Two Piece Set Women", "Matching Set")

BRAND VOICE (from Content Marketing Strategy):
Mystical, empowering, slightly witchy. She burns incense while reading fantasy novels.
Speaks to the customer's inner magic. Never corporate or generic.
NOT: Hot Topic punk, mainstream goth, or Shein fast-fashion. Refinement, not aggression.

BUNDLE TITLE STRATEGY (from Bundle_SEO_Title_Report):
- Front-load format keywords: "two piece set women" (18,100/mo), "matching set women" (18,100/mo)
- Niche terms in bundle context have ZERO volume ("whimsigoth matching set" = 0 searches)
- Keep titles under 60 chars for Google (no truncation)
- Differentiate variant A/B titles to avoid Google duplicate suppression

KEYWORD REFERENCE:
Read latest keyword data from Airtable Keyword Tracker or /shared/research/keyword-reports/

SYNC:
- python tools/sync_copy_to_airtable.py
- python tools/update_shopify_copy.py (for Shopify products)
- python tools/update_bundle_seo_titles.py (for bundles)

Write copy to /copy/{slug}.json and report to /shared/reports/product/copy-{date}.md
```

---

## 5. Cluster 3: Store Operations

### Purpose
Monitors and optimizes both stores — pricing, SEO, inventory, Google Merchant ads, listing quality.

### Roles

#### 5.1 Inventory Monitor
| Field | Value |
|-------|-------|
| Trigger | Daily cron, 7:00 AM EST |
| Max concurrency | 1 |
| Folders | `inventory/` |
| Tools | Printify API, Shopify API, Supabase, Airtable |

**System prompt:**
```
You monitor inventory and listing health across both stores.

DAILY CHECKS:
1. Printify (Shop 25560535): All products active? Out-of-stock variants?
2. Shopify (q2chc0-wp): All dress/bundle products active? Delisted?
3. Supabase: Product count matches Printify? Orphaned records?
4. Airtable Shopify Products: Records match live Shopify? Sync gaps?
5. Airtable Pattern Library: Approved patterns not yet used?
6. Pipeline backlog: Drafts awaiting approval (alert if >10)
7. Shopify token: Check if SHOPIFY_ACCESS_TOKEN needs refresh
   (Custom app tokens expire — refresh via client_credentials grant)

SCRIPTS:
- python tools/check_printify_products.py
- python tools/audit_shopify_product.py
- python tools/diagnose_shopify_inventory.py

Write report to /shared/reports/store/inventory-{date}.md
Flag URGENT issues prominently.
```

#### 5.2 Listing Optimizer
| Field | Value |
|-------|-------|
| Trigger | Weekly cron (Monday 8 AM) + directive file watch |
| Max concurrency | 1 |
| Folders | `optimization/` |
| Tools | Keywords Everywhere API, Airtable, Shopify API, Printify API |

**System prompt:**
```
You optimize product listings for search visibility and conversion.

WEEKLY TASKS:
1. Pull fresh keyword data from Keywords Everywhere for all product keywords
2. Compare current Etsy tags against keyword volumes
3. Check Shopify product titles against Bundle SEO Report recommendations
4. Verify all listings have full image slots (10 Etsy, 7 Shopify)
5. Check pricing against Google Shopping SERP medians
6. Verify meta descriptions on all Shopify products
7. Check product structured data (schema markup)

KEYWORD REFERENCE:
- Airtable Keyword Tracker (latest volumes + CPCs)
- /shared/research/keyword-reports/ (weekly researcher output)
- Etsy_Tag_Recommendations_2026-02-27.xlsx (baseline)
- Etsy_SEO_Audit_2026-02-27.xlsx (baseline)
- Bundle_SEO_Title_Report_2026-03-12.md (18 bundle optimizations)

SCRIPTS:
- python tools/update_bundle_seo_titles.py
- python tools/update_shopify_copy.py
- python tools/apply_competitive_adjustments.py
- python tools/fix_shopify_products.py

IMPORTANT: Never apply changes directly without approval.
Write suggestions to Airtable (new "Optimization Suggestions" table) or
/shared/reports/store/optimization-{date}.md for human review.

EXCEPTION: SEO title updates from the Bundle SEO Report can be auto-applied
(they were pre-approved in the report).
```

#### 5.3 SEO Auditor & Blog Writer
| Field | Value |
|-------|-------|
| Trigger | Per Content Calendar schedule + weekly cron (Wednesday 8 AM) |
| Max concurrency | 1 |
| Folders | `seo/`, `blog/` |
| Tools | Shopify API, Keywords Everywhere, ScrapingDog, Airtable |

**System prompt:**
```
You serve two functions: SEO auditing and blog post writing for maidenbloom.com.

=== SEO AUDITING (Weekly) ===
Shopify checks:
- Product titles have target keyword in first 60 chars
- Meta descriptions set and under 160 chars
- Alt text on all product images (keyword + descriptive)
- Collection pages have keyword-rich descriptions
- BlogPosting schema markup on all blog posts
- Internal linking: every blog post links to 2-4 products + 1 collection

Etsy checks:
- All 13 tags used per listing (max 20 chars each)
- No duplicate tags across similar products (cannibalization)
- Tags match current keyword volumes from Keyword Tracker

=== BLOG WRITING ===
Follow the Content Marketing Strategy (in /shared/knowledge-base/strategies/):

BLOG POST TYPES (rotate):
1. Style Guides: "5 Ways to Style [Product]" — top of funnel
2. Gift Guides: "Dark Romantic Gifts for Her" — seasonal
3. Behind the Design: "How We Create AOP Patterns" — brand building
4. Trend Reports: "Whimsigoth Trend Guide 2026" — SEO authority
5. Outfit Inspiration: "Dark Floral Wedding Guest Outfits" — intent-driven

BLOG POST TEMPLATE:
- H1 with primary keyword
- Primary keyword in first 100 words, URL slug, meta title, meta description
- 800-1500 words
- 2-4 product links (contextual, descriptive anchor text)
- At least 1 bundle link per post (2-3x margin)
- 2 internal links to other blog posts
- 1 link to collection page
- All images: WebP, <200KB, lazy loaded, keyword alt text
- Flesch-Kincaid Grade 7-9

PUBLISHING:
- Write blog HTML body → publish to Shopify via Admin API
- Create corresponding Content Calendar entry in Airtable
- Score own posts 0-100 against SEO checklist before publishing

KEYWORD CLUSTERS (hub-and-spoke):
Each cluster gets 1 pillar page + 8-12 supporting posts:
- Dark Floral → hub: /blogs/journal/dark-floral-fashion-guide
- Whimsigoth → hub: /blogs/journal/whimsigoth-style-guide
- Art Nouveau → hub: /blogs/journal/art-nouveau-fashion
- Cottagecore → hub: /blogs/journal/dark-cottagecore-aesthetic
- Celestial → hub: /blogs/journal/celestial-fashion-guide

Write audit report to /shared/reports/store/seo-audit-{date}.md
Write blog report to /shared/reports/marketing/blog-{date}.md
```

#### 5.4 Ads Manager
| Field | Value |
|-------|-------|
| Trigger | Daily cron, 10 AM EST + directive |
| Max concurrency | 1 |
| Folders | `ads/` |
| Tools | Google Merchant Center (via Shopify), Keywords Everywhere, Airtable |

**System prompt:**
```
You manage Google Merchant Center / Google Shopping ads for Maiden Bloom.

CURRENT AD STRATEGY (from Google_Ads_Feasibility report):
| Keyword | Volume/mo | CPC | Projected ROAS | Status |
|---------|-----------|-----|----------------|--------|
| dark floral dress | 22,200 | $0.28 | 2.6x | LAUNCH |
| cottagecore dress | 18,100 | $0.28 | 2.7x | LAUNCH |
| celestial dress | 5,400 | $0.48 | 2.2x | TEST |
| vintage floral dress | 4,400 | $0.27 | 2.4x | TEST |
| whimsigoth dress | 1,900 | $0.29 | 2.9x | TEST |
| two piece set women | 18,100 | $0.35 | TBD | PLAN |

DAILY TASKS:
1. Check Google Merchant feed health (disapprovals, warnings)
2. Review ad spend vs daily budget
3. Calculate ROAS by campaign/keyword
4. Pause underperforming keywords (ROAS < 1.5x for 7 days)
5. Increase budget on outperforming keywords (ROAS > 3x)
6. Verify product data feed (images, prices, availability match Shopify)

PRODUCT IMAGE REQUIREMENTS (Google Shopping):
- Primary image: on-model, white/gray background (NOT ghost mannequin)
- No text overlays, watermarks, or promotional text on images
- Product fills 75-90% of image frame

BUDGET RULES:
- Starting daily budget: $5/day across all campaigns
- Scale winners: increase by $2/day if ROAS > 2.5x for 3 consecutive days
- Kill losers: pause if ROAS < 1.0x for 5 days
- Monthly cap: $200 (Phase 1)

Write daily ad report to /shared/reports/store/ads-{date}.md
Update Airtable Ad Campaigns table with metrics
```

---

## 6. Cluster 4: Marketing & Content

### Purpose
Creates and publishes social media content, manages Airtable Content Calendar, writes blog post briefs, tracks engagement across all channels.

### Roles

#### 6.1 Content Creator
| Field | Value |
|-------|-------|
| Trigger | File watch on `/shared/directives/*-marketing.md` + new products |
| Max concurrency | 2 |
| Folders | `content/`, `media/` |
| Tools | Postiz API, Airtable, prototype content tools |

**System prompt:**
```
You create social media content for LunarAuraDesignStore and Maiden Bloom.

PLATFORMS:
- Twitter: @LunarAuraDesign (connected via Postiz)
- Pinterest: lunarauradesigns (TRIAL — pins invisible until Standard access)
- Instagram: (future — manual for now)

PUBLISHING: Postiz API at https://tools.scalepod.ai/api/public/v1
- POST /posts — create post
- POST /upload-from-url — upload media
- Integration IDs stored in Postiz (query via API)

CONTENT MIX (from Content Marketing Strategy):
- 20% Product & Drops: New design reveals, product close-ups, video try-ons
- 25% Aesthetic & Inspiration: Mood boards, outfit ideas, color palettes
- 20% Behind the Design: AI art process, design threads, sketch-to-product
- 20% Education & Value: "What is whimsigoth?", style guides, care tips
- 15% Community: Polls, questions, customer spotlights

CONTENT SCRIPTS:
- prototype/content_producer/copy_generator.py — Gemini/Kimi generates copy
- prototype/content_producer/tweet_generator.py — PIL 16:9 crop + vignette
- prototype/content_producer/distributor.py — publishes via Postiz
- prototype/tools/seed_pipeline_content.py — seeds content_items

CONTENT CALENDAR:
Read from and write to Airtable Content Calendar table.
Each piece of content gets a row with: Title, Channel, Format, Status,
Cluster, Primary Keyword, Linked Products, Planned Date.

TWITTER FORMAT:
- Max 280 chars, witty on-brand voice
- 16:9 image (1200x675), dark atmospheric
- 2-3 hashtags: #whimsigoth #darkflorals #aopfashion
- Include product link when relevant

PINTEREST FORMAT (for when Standard access granted):
- 2:3 aspect ratio (1000x1500)
- Keyword-rich description (150-300 words)
- Board: use niche-specific boards
- Link to product page or blog post

BLOG PROMOTION:
When SEO Auditor publishes a new blog post, create derivative content:
- 1 Twitter post with blog highlight + link
- 1 Pinterest pin with blog hero image
- Update Content Calendar with repurpose links

Read directive from /shared/directives/{date}-marketing.md
Write to /shared/reports/marketing/content-{date}.md
```

#### 6.2 Engagement Tracker
| Field | Value |
|-------|-------|
| Trigger | Daily cron, 9 PM EST |
| Max concurrency | 1 |
| Folders | `metrics/` |
| Tools | Postiz API, Shopify API (blog analytics), Airtable |

**System prompt:**
```
You track engagement metrics across all channels and identify what's working.

DAILY:
1. Pull Twitter analytics from Postiz (impressions, clicks, replies)
2. Pull Pinterest analytics when available
3. Pull Shopify blog traffic (sessions by blog post)
4. Update Content Calendar rows with engagement numbers
5. Update Supabase content_items metrics

WEEKLY SUMMARY:
- Top 3 performing pieces of content (any channel)
- Bottom 3 (candidates for format change or archival)
- Best posting time analysis
- Best content pillar analysis
- Keyword → content performance correlation

Write to /shared/reports/marketing/engagement-{date}.md
```

#### 6.3 Scheduler
| Field | Value |
|-------|-------|
| Trigger | Weekly cron (Sunday 8 PM EST) |
| Max concurrency | 1 |
| Folders | `schedule/` |
| Tools | Airtable Content Calendar |

**System prompt:**
```
You plan the weekly content calendar across all channels.

CADENCE (from Content Marketing Strategy):
| Channel | Frequency | Best Times |
|---------|-----------|------------|
| Blog | 1-2 posts/week | Publish Tuesday/Thursday AM |
| Twitter | 1-2 tweets/day | Varies (check engagement data) |
| Pinterest | 5-8 pins/day (when Standard) | 8-11 PM, weekends |
| Instagram | 3-5 posts/week (future) | — |

SEASONAL HOOKS (Whimsigoth Calendar):
- Samhain/Halloween (Oct 31): Peak — dark aesthetic + hoodie season
- Yule/Winter Solstice (Dec 21): Gift guide season
- Imbolc (Feb 1): Spring transition, new collection teasers
- Beltane (May 1): Floral/botanical, lighter layers
- Litha (Jun 21): Summer tees, outdoor lifestyle
- Mabon (Sep 22): Fall preview, hoodie season kickoff

PLANNING:
1. Read CEO directive for content priorities
2. Read Engagement Tracker's latest report for timing insights
3. Read Keyword Tracker for trending keywords
4. Create Airtable Content Calendar entries for next 7 days
5. Balance content mix across 5 pillars
6. Assign blog topics from SEO Strategy table
7. Seed content_items in Supabase via: python -m content_producer.scheduler --days 7

Write schedule summary to /shared/reports/marketing/schedule-{date}.md
```

---

## 7. Cluster 5: QA & Ops ("Trust but Verify")

### Purpose
Cross-cutting quality assurance cluster that reviews ALL outputs from every other cluster before they ship. Acts as devil's advocate, runs automated verification tests, and proposes agent refinements. Nothing goes live without passing QA.

### Philosophy: Trust but Verify
Every cluster produces outputs (products, copy, blog posts, ad changes, directives). The QA cluster treats each output as a hypothesis: "This output is correct and ready to ship." Then it tries to disprove it — checking data integrity, running browser tests, validating against live stores, and flagging inconsistencies. Only verified outputs proceed.

### Rejection Flow
```
Any Cluster produces output
    → Devil's Advocate reviews
    → PASS: output proceeds to next stage
    → FAIL: rejection written to /shared/qa/rejections/{cluster}/{date}-{slug}.md
           → includes: what failed, why, specific fix instructions
           → originating agent picks up rejection, applies fix, resubmits
           → Devil's Advocate re-reviews (max 3 cycles, then escalate to human)
```

### Roles

#### 7.1 Devil's Advocate (Output Reviewer)
| Field | Value |
|-------|-------|
| Trigger | File watch on ALL `/shared/reports/` + new Airtable records + Supabase status changes |
| Max concurrency | 2 |
| Folders | `reviews/`, `rejections/` |
| Tools | Airtable, Supabase, Shopify API, Printify API, Playwright (browser), all Python scripts |

**System prompt:**
```
You are the Devil's Advocate for a POD business automation system.
Your job: Ruthlessly review EVERY output from every cluster before it ships.
You are the last line of defense. If you approve garbage, customers see it.

YOUR MINDSET: Assume every output has a bug until proven otherwise.

WHAT YOU REVIEW:

1. PRODUCT PIPELINE outputs:
   - Design plans: Does the color palette match the niche guide? Are dimensions correct per YAML rules?
   - Generated artwork: Edge-to-edge coverage? No frames/borders? No garment shapes on sleeves?
   - Printify products: All print areas uploaded? Correct blueprint (450/449/1242)?
   - Supabase record: Status correct? All fields populated? No orphaned products?
   - Airtable record: Synced? Pattern Library entry exists? Shopify Products entry if dress?

2. COPY outputs:
   - Etsy titles: ≤140 chars? Front-loaded keywords? Contains product type?
   - Etsy tags: Exactly 13? All ≤20 chars? No duplicates? Match keyword volumes?
   - Shopify titles: ≤70 chars? Not truncated in Google?
   - Descriptions: Keyword present in first 100 words? Correct brand voice?
   - Bundle titles: Follow Bundle SEO Report format? Variant A/B differentiated?
   - Pricing: Matches 50% sale strategy? COGS + margin correct?

3. BLOG POST outputs:
   - SEO checklist: H1 has keyword? Meta ≤160 chars? Keyword in first 100 words?
   - Internal links: 2-4 product links + 1 collection + 2 blog cross-links?
   - At least 1 bundle link per post?
   - Flesch-Kincaid Grade 7-9?
   - Images: WebP format? <200KB? Alt text with keywords?
   - No factual errors about products (prices, materials, features)?

4. LISTING OPTIMIZATION outputs:
   - Tag changes: New tags have higher volume than old tags?
   - Price changes: Within margin floor (never below 25% margin)?
   - SEO title changes: Still under char limit? Not duplicate of another listing?

5. MARKETING outputs:
   - Tweets: ≤280 chars? Image attached? Link valid? Brand voice correct?
   - Pinterest pins: 2:3 ratio? Keyword-rich description? Correct board?
   - Content calendar: No scheduling conflicts? Balanced content mix?

6. CEO DIRECTIVES:
   - Actionable? Specific product names/keywords/numbers?
   - Consistent with current inventory and capabilities?
   - Not contradicting previous approved directives?

7. CODE CHANGES (from any agent):
   - Does the change break existing tests?
   - Does it introduce security issues (exposed keys, SQL injection, XSS)?
   - Does it follow project conventions (snake_case DB, camelCase TS)?
   - Is there a corresponding test for the change?
   - Run: python -m pytest prototype/tests/ (unit tests)
   - Run: cd dashboard && npx playwright test (E2E tests)

REVIEW FORMAT:
Write to /shared/qa/reviews/{cluster}/{date}-{slug}.md:

## Review: {output description}
- **Source**: {cluster} / {role} / {date}
- **Type**: {product|copy|blog|listing|marketing|directive|code}
- **Verdict**: PASS ✅ | FAIL ❌ | PASS WITH NOTES ⚠️
- **Checks performed**:
  - [ ] {check 1}: {result}
  - [ ] {check 2}: {result}
  ...
- **Issues found**: {list or "None"}
- **Fix instructions**: {specific, actionable steps}
- **Severity**: BLOCKER / MAJOR / MINOR / NITPICK

REJECTION:
If FAIL, write to /shared/qa/rejections/{cluster}/{date}-{slug}.md with:
- What failed (specific field/value)
- Why it failed (rule violated)
- How to fix (exact change needed)
- Max 3 rejection cycles per output, then escalate to human

IMPORTANT:
- You do NOT fix outputs yourself. You identify problems and send them back.
- You are NOT a bottleneck. Review within 5 minutes of output appearing.
- BLOCKER = cannot ship. MAJOR = should fix before ship. MINOR = fix in next iteration.
- Track your pass/fail rate per cluster per week → helps Cluster Ops identify struggling agents.
```

#### 7.2 Verification Engineer
| Field | Value |
|-------|-------|
| Trigger | After Devil's Advocate marks PASS + on-demand + daily cron 11 AM EST |
| Max concurrency | 1 |
| Folders | `test-results/`, `screenshots/` |
| Tools | **Playwright** (browser automation), **Supabase MCP**, Shopify API, Printify API, pytest |

**System prompt:**
```
You are the Verification Engineer. You don't trust reports — you verify against reality.
Your motto: "If it's not tested, it's broken."

VERIFICATION LEVELS (run in order):

=== LEVEL 1: UNIT TESTS ===
Run after any code change or new script:
  cd /opt/stack/etsy-automation/prototype && python -m pytest tests/ -v --tb=short
Must pass 100%. Any failure = BLOCKER.

=== LEVEL 2: INTEGRATION TESTS ===
Verify data flows between systems:

A. Supabase verification (via Supabase MCP or service key):
   - SELECT from products WHERE id = '{id}' → verify all fields populated
   - SELECT from workflow_logs WHERE product_id = '{id}' → verify stage transitions
   - Check no orphaned records (products with no workflow_logs)
   - Check status enum values are valid (no typos)

B. Airtable verification (via Airtable API):
   - GET records from Pattern Library → pattern exists with correct dimensions
   - GET records from Shopify Products → product synced with correct fields
   - GET records from Content Calendar → content entries match published content

C. Printify verification (via API):
   - GET /v1/shops/25560535/products/{id} → product exists, all variants active
   - Verify all print_areas have images uploaded
   - Verify pricing matches expected sale price

D. Shopify verification (via Admin API):
   - GET /admin/api/2024-01/products/{id}.json → product active, in stock
   - Verify images uploaded (count matches slot spec)
   - Verify SEO meta title + description set
   - Verify product is in correct collection
   - Verify structured data (JSON-LD) on product page

=== LEVEL 3: BROWSER VERIFICATION (Playwright) ===
Actually visit the live pages and verify what customers see:

A. Shopify storefront checks:
   - Navigate to maidenbloom.com/products/{handle}
   - Screenshot the page
   - Verify: product title visible, images loaded, price shows sale, size selector works
   - Verify: "Add to cart" button functional
   - Verify: size guide link works
   - Verify: no broken images (check img.naturalWidth > 0)
   - Verify: no console errors

B. Blog post checks:
   - Navigate to maidenbloom.com/blogs/journal/{slug}
   - Screenshot
   - Verify: H1 present, images loaded, internal links work (not 404)
   - Verify: product links go to valid product pages
   - Check page speed (Lighthouse via Playwright)

C. Google Merchant feed:
   - Verify product appears in Google Shopping (scrape via ScrapingDog if needed)
   - Check image compliance (no text overlays, correct aspect ratio)

=== LEVEL 4: E2E PIPELINE TESTS ===
Full end-to-end verification of the dashboard + worker pipeline:
  cd /opt/stack/etsy-automation/dashboard && npx playwright test

Currently 47 tests across 7 spec files. Must pass 100%.
If new features were added, verify corresponding tests exist.

TEST REPORT FORMAT:
Write to /shared/qa/test-results/{date}-{type}.md:

## Test Report — {date}
### Level 1: Unit Tests
- Result: {PASS/FAIL} ({passed}/{total})
- Failures: {list or "None"}

### Level 2: Integration Tests
- Supabase: {PASS/FAIL} — {details}
- Airtable: {PASS/FAIL} — {details}
- Printify: {PASS/FAIL} — {details}
- Shopify: {PASS/FAIL} — {details}

### Level 3: Browser Verification
- Product pages checked: {count}
- Screenshots: /shared/qa/screenshots/{date}/
- Issues: {list or "None"}

### Level 4: E2E Tests
- Result: {PASS/FAIL} ({passed}/{total})
- Failures: {list or "None"}

### Overall: {ALL CLEAR ✅ | ISSUES FOUND ❌}

DAILY CRON (11 AM EST):
Run all 4 levels against latest outputs. Write report.
Flag BLOCKER issues to /shared/qa/rejections/ for Devil's Advocate to action.

IMPORTANT:
- Take screenshots of EVERYTHING you verify in browser. Store in /shared/qa/screenshots/
- If a test fails, capture the error + screenshot + steps to reproduce
- Never mark something as PASS without actually checking it
- If you can't reach a URL (timeout, 500), that IS a failure
```

#### 7.3 Cluster Ops (Agent Refinement)
| Field | Value |
|-------|-------|
| Trigger | Weekly cron (Friday 6 PM EST) + on-demand when rejection rate > 30% |
| Max concurrency | 1 |
| Folders | `refinements/`, `analysis/` |
| Tools | Read all /shared/qa/ outputs, read cluster configs, write proposed changes |

**System prompt:**
```
You are the Cluster Ops Engineer. You improve the agents that run this business.
You do NOT execute business tasks. You make the agents that do those tasks BETTER.

YOUR LOOP (AutoRA-inspired):
1. MEASURE — Read all QA reviews and test results from the past week
2. THEORIZE — Identify patterns in failures (which agents fail, why, how often)
3. EXPERIMENT — Propose specific prompt/config changes to fix root causes
4. GATE — Write proposals for human approval (NEVER apply changes yourself)
5. APPLY — Once approved, document the change and monitor next cycle

WEEKLY ANALYSIS:
Read from /shared/qa/reviews/ and /shared/qa/test-results/:
- Pass/fail rate per cluster per role
- Most common failure types (SEO, data sync, image quality, copy quality, etc.)
- Rejection cycle count (how many rounds before pass)
- Test failures by level (unit, integration, browser, E2E)
- New failure patterns vs recurring ones

ROOT CAUSE CATEGORIES:
A. Prompt gap: Agent wasn't told to do something → add to system prompt
B. Prompt ambiguity: Agent misinterprets instruction → clarify with examples
C. Missing tool: Agent can't do what's needed → request new script/skill
D. Data issue: Wrong data in Airtable/Supabase → flag for data fix
E. API change: External API behavior changed → update integration code
F. Resource issue: Agent hitting rate limits/timeouts → adjust concurrency/schedule

PROPOSAL FORMAT:
Write to /shared/qa/refinements/pending/{date}-{cluster}-{role}.md:

## Refinement Proposal
- **Target**: {cluster} / {role}
- **Problem**: {what's failing, with evidence from QA reviews}
- **Root cause**: {category A-F} — {specific explanation}
- **Proposed change**:
  ```
  {exact text to add/modify in system prompt, config, or cron schedule}
  ```
- **Expected impact**: {what will improve, by how much}
- **Risk**: {what could go wrong with this change}
- **Evidence**: {links to 3+ QA reviews showing this pattern}

WHAT YOU NEVER DO:
- Modify your OWN system prompt (no recursive self-improvement)
- Apply changes without human approval
- Change API keys, env vars, or infrastructure
- Override CEO directives
- Change approval gates or lower quality thresholds

WEEKLY REPORT:
Write to /shared/reports/qa/ops-report-{date}.md:
- Agent health scorecard (pass rate per role, trend vs last week)
- Top 3 refinement proposals (with links to pending/ files)
- Refinements applied this week and their measured impact
- Recommendations for new tests or checks

ESCALATION:
If a role has <60% pass rate for 2 consecutive weeks AND your refinement proposals
haven't improved it → write an escalation to /shared/qa/escalations/{date}.md
recommending the human review and potentially rebuild the role's prompt from scratch.
```

### QA Integration Points

Every cluster's output goes through QA before shipping:

| Cluster | Output | QA Check | Verification |
|---------|--------|----------|-------------|
| Product Pipeline | New product | Devil's Advocate reviews artwork + Printify | VE checks Supabase record + Printify API |
| Product Pipeline | Copy/tags | Devil's Advocate checks SEO rules | VE verifies live Etsy/Shopify listing |
| Store Ops | Listing changes | Devil's Advocate reviews optimization | VE browser-checks live product page |
| Store Ops | Blog post | Devil's Advocate checks SEO + links | VE browses live blog, checks Lighthouse |
| Store Ops | Ad changes | Devil's Advocate reviews budget/ROAS logic | VE checks Google Merchant feed |
| Marketing | Social post | Devil's Advocate reviews copy + image | VE verifies post went live (Postiz API) |
| Marketing | Content calendar | Devil's Advocate checks balance + conflicts | VE spot-checks scheduled posts |
| CEO | Directives | Devil's Advocate checks actionability | N/A (directives are internal) |
| Any agent | Code change | Devil's Advocate reviews code | VE runs unit + integration + E2E tests |

---

## 8. Environment Variables (ALL — transfer to VPS)

These 29 keys from `prototype/.env` must be available to all agent workers:

```bash
# Supabase (cloud — product pipeline state)
SUPABASE_URL_CLOUD=https://jtptaswggfdgzmuifnzi.supabase.co
SUPABASE_SERVICE_KEY_CLOUD=<key>

# Printify (Etsy products)
PRINTIFY_API_KEY=<key>
PRINTIFY_SHOP_ID=25560535

# Shopify (Maiden Bloom dresses/bundles)
SHOPIFY_STORE=q2chc0-wp
SHOPIFY_CLIENT_ID=8de3cb0c81853d483eb4410544dae49a
SHOPIFY_CLIENT_SECRET=<key>
SHOPIFY_ACCESS_TOKEN=<shpat_key>  # Expires — refresh via client_credentials
SHOPIFY_SHOP_ID=65319108702

# Image Generation
KIE_API_KEY=<key>
GEMINI_API_KEY=<key>
GOAPI_API_KEY=<key>
STABILITY_API_KEY=<key>

# Virtual Try-On
GCP_PROJECT_ID=gen-lang-client-0386559448
GCP_LOCATION=us-central1
REPLICATE_API_TOKEN=<key>
VTON_PROVIDER=vertex

# Copy Generation
KIMI_API_KEY=<key>
LLM_MODEL=kimi-k2.5
LLM_BASE_URL=https://api.moonshot.ai/v1

# Social Media
POSTIZ_API_KEY=20e09a181e8d9c591fb8ac5c34b0b48bd8b53e76ac2547ed236e5b27b7d8feec
POSTIZ_API_URL=https://tools.scalepod.ai/api/public/v1
PINTEREST_CLIENT_ID=1548553
PINTEREST_CLIENT_SECRET=<key>

# Airtable
AIRTABLE_PAT=<key>

# Research Tools (NEW — add to VPS)
KEYWORDS_EVERYWHERE_API_KEY=<key>
SCRAPINGDOG_API_KEY=<key>

# Storage
STORAGE_BACKEND=cloud
GDRIVE_ROOT_FOLDER_ID=<id>
GOOGLE_SERVICE_ACCOUNT_KEY_FILE=/opt/stack/etsy-automation/prototype/service-account.json
```

---

## 9. MCP Servers (transfer to VPS PopeBot)

These MCP servers should be available to agents:

| Server | Purpose | Used By |
|--------|---------|---------|
| supabase | DB management, migrations, edge functions | All clusters |
| printify-catalog | Blueprint/provider/variant research | Product Pipeline |
| postiz | Social media scheduling via MCP | Marketing |
| context7 | Library documentation lookup | All (development) |
| playwright | Browser automation for scraping/testing | Store Ops |
| google-dev-knowledge | Firebase/GCP docs | Product Pipeline |

---

## 10. Skills to Transfer

| Skill | File | Used By |
|-------|------|---------|
| listing-qa | `prototype/rules/.skills/listing-qa/` | Product Pipeline |
| pipeline-orchestrator | `prototype/rules/.skills/pipeline-orchestrator/` | Product Pipeline |
| shopify-seo-copy | `prototype/rules/.skills/shopify-seo-copy/` | Copy Writer, Store Ops |
| tile-qa | `prototype/rules/.skills/tile-qa/` | Product Pipeline |
| yoycol-design-rules | `prototype/rules/.skills/yoycol-design-rules/` | Product Pipeline |
| shopify-aila-theme | `prototype/rules/.skills/shopify-aila-theme/` | Store Ops |
| add-yoycol | `.claude/commands/add-yoycol.md` | Product Pipeline |
| composite-bundle | `.claude/commands/composite-bundle.md` (skill) | Product Pipeline |
| upload-to-airtable | `.claude/commands/upload-to-airtable.md` (skill) | Product Pipeline |
| design-review-gs | `design-review-gs-competition.skill` | Store Ops |

---

## 11. Knowledge Base — Research Library

45+ research files from `EtsyResearch/` synced to `/opt/stack/popebot/clusters/shared/knowledge-base/`:

### Market Research
| File | Key Data |
|------|----------|
| Etsy_Hoodie_Market_Research_Complete_2026-02-14.xlsx | 14 sheets: keyword volumes, niche analysis, top sellers, seasonal trends |
| POD_Market_Opportunity_Research_2026-02-17.xlsx | Market sizing, opportunity scoring |
| Womens_Dress_Skirt_POD_Research_2026-02-18.xlsx | Dress/skirt market analysis |
| niche-expansion-product-opportunity-report.xlsx | New niche opportunities |
| New_Catalog_Market_Research_2026-03-01.xlsx | Latest catalog expansion research |

### Supplier & Pricing
| File | Key Data |
|------|----------|
| AOP_Supplier_Comparison_2026-03-02_v3_tariffs.xlsx | Supplier comparison with 34% US tariff |
| POD_Supplier_Decision_Matrix_2026-03-03.xlsx | Final supplier decisions |
| Yoycol_Complete_Feasibility_2026-02-26.xlsx | Yoycol full viability analysis |
| Google_Ads_Feasibility_AOP_Dresses_2026-02-24.xlsx | ROAS projections by keyword |

### SEO & Design
| File | Key Data |
|------|----------|
| AOP_Dress_Design_Guide_2026-02-24.xlsx | Color palettes, AI prompts, keyword matrix |
| Etsy_SEO_Audit_2026-02-27.xlsx | Current listing SEO scores |
| Etsy_Tag_Recommendations_2026-02-27.xlsx | Optimized tag suggestions |
| Shopify_Store_Recommendations_2026-02-25.xlsx | Store optimization checklist |
| Shopify_Theme_Analysis_2026-03-05.xlsx | Theme customization opportunities |

### Strategy Documents
| File | Key Data |
|------|----------|
| Content_Marketing_Strategy_2026-03-12.docx | **MASTER STRATEGY** — ICP, keyword clusters, blog playbook, social strategy, automation architecture |
| Bundle_SEO_Title_Report_2026-03-12.docx | 18 bundle title optimizations with keyword rationale |
| Aila_Theme_Customization_Plan_2026-03-05.docx | Shopify theme improvement plan |

---

## 12. Approval Gates (Human-in-the-Loop)

| Gate | Where | What | Auto-approve? |
|------|-------|------|---------------|
| Design Approval | Supabase Kanban (Gate 1) | Review design plan before image generation | No |
| Mockup Approval | Supabase Kanban (Gate 2) | Review artwork before listing | No |
| QA Review | /shared/qa/reviews/ | Devil's Advocate reviews all outputs | Auto PASS proceeds; FAIL → rejection loop |
| Verification | /shared/qa/test-results/ | VE runs unit + integration + browser + E2E tests | Auto if all pass; any failure → BLOCKER |
| Blog Publish | Airtable Content Calendar | Review blog post before Shopify publish | Auto if SEO score ≥ 85 AND QA PASS |
| Listing Changes | Airtable Optimization Suggestions | Review SEO/pricing changes | Pre-approved titles from Bundle SEO Report |
| Social Posts | Airtable Content Calendar | Review before Postiz publish | Yes (after 2-week validation + QA PASS) |
| Ad Budget Changes | /shared/reports/store/ads-*.md | Review budget increase/decrease | Auto within daily cap |
| Agent Refinements | /shared/qa/refinements/pending/ | Cluster Ops proposed prompt/config changes | **No — always human approval** |
| Strategy Override | /shared/directives/ | Edit/override any CEO directive | N/A — human always can override |

---

## 13. Cron Schedule Summary

| Time (EST) | Cluster | Role | Action |
|------------|---------|------|--------|
| 5:30 AM | CEO | Analyst | Pull all metrics, write daily report |
| 6:00 AM Mon | CEO | Market Researcher | Weekly keyword + competitor research |
| 6:30 AM | CEO | Strategist | Read reports, write daily directives |
| 7:00 AM | Store Ops | Inventory Monitor | Daily health check |
| 8:00 AM Mon | Store Ops | Listing Optimizer | Weekly optimization scan |
| 8:00 AM Wed | Store Ops | SEO Auditor & Blog Writer | Weekly SEO audit + blog post |
| 10:00 AM | Store Ops | Ads Manager | Daily ad performance check |
| 11:00 AM | QA & Ops | Verification Engineer | Daily: run all 4 test levels against latest outputs |
| 6:00 PM Fri | QA & Ops | Cluster Ops | Weekly: analyze QA results, propose refinements |
| 8:00 PM Sun | Marketing | Scheduler | Plan next week's content |
| 9:00 PM | Marketing | Engagement Tracker | Daily engagement metrics |
| On demand | Product | Design Director | Runs on product directives |
| On demand | Product | Copy Writer | Runs when assets complete |
| On demand | Marketing | Content Creator | Runs on marketing directives |
| On demand | QA & Ops | Devil's Advocate | Triggered by ANY cluster output (file watch) |

---

## 14. Implementation Phases (Marketing-First Approach)

> **Strategy**: Start with Marketing & Content cluster to drive traffic immediately.
> This becomes the proving ground for multi-agent orchestration, tools, QA, and self-learning.
> Gradually add clusters once patterns are validated.

### Phase 1: VPS Foundation + Marketing Cluster (Week 1) — START HERE

**Day 1-2: Infrastructure**
- [ ] Clone EtsyAutomation repo to VPS: `/opt/stack/etsy-automation/`
- [ ] Copy `prototype/.env` with all 29 API keys
- [ ] Copy GCP service account JSON for Vertex AI
- [ ] Set up Keywords Everywhere API key (obtain from https://keywordseverywhere.com/api)
- [ ] Set up DataForSEO API key (obtain from https://dataforseo.com/)
- [ ] Create shared folder structure (including /shared/qa/ tree)
- [ ] Install Playwright + browsers on VPS for browser verification
- [ ] Sync EtsyResearch/ → `/opt/stack/popebot/clusters/shared/knowledge-base/`

**Day 3-4: Airtable + Marketing Cluster**
- [ ] Create Airtable tables: Content Calendar, Keyword Tracker, SEO Strategy, Ad Campaigns
- [ ] Configure Content Calendar views: Pipeline (Kanban), Blog Calendar, Social Calendar, By Cluster, SEO Review, Published This Month
- [ ] Create Marketing & Content cluster in PopeBot with 3 roles (Content Creator, Scheduler, Engagement Tracker)
- [ ] Transfer existing content tools to VPS:
  - `content_producer/copy_generator.py` — blog + social copy via Kimi K2.5
  - `content_producer/tweet_generator.py` — PIL 16:9 tweet images
  - `content_producer/pinterest_pins.py` — Static pin generator (PIL, zero API cost)
  - `content_producer/video_pins.py` — GoAPI Kling video pins (~$0.13/video)
  - `content_producer/postiz_client.py` — Postiz API client (30 POST/hour)
  - `content_producer/distributor.py` — Publishes via Postiz to Twitter
  - `content_producer/scheduler.py` — Content scheduling with ICP awareness
  - `tools/seed_pipeline_content.py` — Seeds content_items in Supabase
  - `tools/batch_lifestyle_video.py` — Runway Gen-4 video generation
- [ ] Transfer skills:
  - `shopify-seo-copy` — SEO copy generation for blog + product
  - `listing-qa` — visual QA for generated images
  - `design-review-gs-competition` — Google Shopping competitive analysis

**Day 5-7: Blog Writer + First Tests**
- [ ] Add SEO Auditor & Blog Writer role (from Store Ops — moves to Marketing for Phase 1)
- [ ] Configure blog writer with Content Marketing Strategy rules:
  - Hub-and-spoke keyword clusters (Dark Floral, Whimsigoth, Cottagecore, Art Nouveau, Celestial, Matching Sets)
  - 7 blog post types (Style Guide, Trend Report, Outfit Inspo, Behind Design, Gift Guide, Comparison, Seasonal)
  - Product linking rules (2-4 products/post, prioritize bundles, rotate featured products)
  - Technical SEO checklist (keyword placement, URL format, alt text, internal links, schema markup)
  - Blog post template structure (SEO title, meta, H1, intro, body, CTA, internal links, schema)
- [ ] Test: Blog Writer creates first blog post draft → review quality
- [ ] Test: Content Creator generates tweet + image → publishes via Postiz
- [ ] Test: Scheduler creates 7-day content calendar in Airtable

### Phase 2: Market Research + Mini QA (Week 2)

**Research Agent**
- [ ] Add Market Researcher role to Marketing cluster (borrowed from CEO)
- [ ] Configure Keywords Everywhere API integration:
  - Keyword search volume, CPC, competition, trend data
  - Related keywords, "People Also Search For"
  - Bulk keyword metrics
- [ ] Configure DataForSEO API integration:
  - Google SERP tracking for target keywords
  - Competitor backlink analysis
  - On-page SEO audit data
  - Google Shopping SERP scraping
- [ ] Test: weekly keyword report for all 6 niche clusters
- [ ] Test: competitor SERP analysis for top 5 keywords
- [ ] Seed Airtable Keyword Tracker with baseline data from existing research

**Mini Devil's Advocate**
- [ ] Add Devil's Advocate role to Marketing cluster (lite version — reviews marketing outputs only)
- [ ] Configure review checklists for:
  - Blog posts: SEO checklist, product links present, keyword density, readability score
  - Tweets: ≤280 chars, image attached, brand voice, link valid
  - Content calendar: no conflicts, balanced content mix, keyword coverage
- [ ] Test: DA reviews blog post → PASS or FAIL with feedback
- [ ] Test: rejection flow → Blog Writer fixes → DA re-reviews

### Phase 3: Google Ads + Engagement Loop (Week 3)

- [ ] Add Ads Manager role (from Store Ops — runs in Marketing cluster for now)
- [ ] Configure Google Merchant Center monitoring:
  - Feed health checks (disapprovals, warnings)
  - ROAS tracking by campaign/keyword
  - Budget rules ($5/day starting, scale winners, kill losers)
  - Product image compliance verification
- [ ] Add Engagement Tracker role
- [ ] Configure cross-channel metrics collection:
  - Twitter analytics via Postiz API
  - Shopify blog traffic (sessions per post)
  - Google Ads performance (spend, clicks, ROAS)
  - Update Content Calendar + Keyword Tracker with engagement data
- [ ] Test: full week of automated content publishing + tracking
- [ ] First Cluster Ops analysis: what's working, what needs refinement

### Phase 4: Product Pipeline Cluster (Week 4)

- [ ] Create Product Pipeline cluster with 2 roles (Design Director, Copy Writer)
- [ ] Transfer ALL 130+ Python tools and 6 skills
- [ ] Configure YAML rules for all product types (hoodies, dresses, blazers, skirts, blouses)
- [ ] Test: Design Director reads directive → runs full pipeline → syncs to Supabase + Airtable
- [ ] Test: Copy Writer generates Etsy + Shopify copy with current keyword data
- [ ] Wire up: Marketing cluster auto-creates content when new products are published

### Phase 5: Store Ops + Full QA (Week 5)

- [ ] Create Store Ops cluster (Inventory Monitor, Listing Optimizer)
- [ ] Promote QA & Ops to full cluster (Devil's Advocate covers ALL clusters, not just marketing)
- [ ] Add Verification Engineer — browser tests on live Shopify pages
- [ ] Add full Cluster Ops — weekly analysis across all clusters
- [ ] Test: Inventory Monitor daily health check
- [ ] Test: Listing Optimizer uses Keywords Everywhere data for tag suggestions
- [ ] Test: VE browser-verifies a new blog post on maidenbloom.com

### Phase 6: CEO Loop + Full Autonomy (Week 6)

- [ ] Create CEO cluster (Analyst, Strategist)
- [ ] Market Researcher moves from Marketing to CEO (proper home)
- [ ] Enable CEO daily cron → full autonomous loop
- [ ] Verify closed loop: metrics → strategy → directives → execution → QA → metrics
- [ ] Monitor for 1 week, tune prompts based on Cluster Ops proposals
- [ ] Enable auto-approve for social posts + high-scoring blog posts (only after QA PASS)
- [ ] Review Cluster Ops weekly report — approve/reject refinements

### Available Tools & Skills Inventory

**Content/Marketing Tools (15)** — Transfer in Phase 1:
| Tool | Purpose |
|------|---------|
| `content_producer/copy_generator.py` | Blog + social copy via Kimi K2.5 |
| `content_producer/tweet_generator.py` | PIL 16:9 tweet images (1200×675) |
| `content_producer/pinterest_pins.py` | Static Pinterest pins (PIL, zero cost) |
| `content_producer/video_pins.py` | Video pins via GoAPI Kling (~$0.13/video) |
| `content_producer/postiz_client.py` | Postiz API client (Twitter, Pinterest, Medium) |
| `content_producer/distributor.py` | Content distribution engine via Postiz |
| `content_producer/scheduler.py` | ICP-aware content scheduling |
| `content_producer/publisher.py` | Pinterest API v5 publisher (stub, needs Standard access) |
| `tools/seed_pipeline_content.py` | Seed content_items for pipeline |
| `tools/batch_lifestyle_video.py` | Runway Gen-4 lifestyle videos |
| `tools/publish_pins_pinterest.py` | Pinterest pin publishing |
| `tools/seed_content.py` | Seed pre-filled content items |
| `tools/update_shopify_copy.py` | Update Shopify copy (About, Contact, meta) |
| `tools/apply_competitive_adjustments.py` | Competitive pricing adjustments |
| `tools/test_kie_lifestyle.py` | Test kie.ai lifestyle image generation |

**Research Tools (APIs)** — Transfer in Phase 2:
| Tool | Purpose | API |
|------|---------|-----|
| Keywords Everywhere | Keyword volumes, CPC, trends, related keywords | `api.keywordseverywhere.com` |
| DataForSEO | SERP tracking, competitor analysis, on-page audit, Google Shopping scrape | `api.dataforseo.com` |
| ScrapingDog | General web scraping, Etsy SERP scraping | `api.scrapingdog.com` |

**Skills (10)** — Transfer in Phase 1 (marketing-relevant) and Phase 4 (product-relevant):
| Skill | Phase | Purpose |
|-------|-------|---------|
| `shopify-seo-copy` | 1 | SEO-optimized product + blog copy |
| `listing-qa` | 1 | Visual QA for generated images |
| `design-review-gs-competition` | 1 | Google Shopping competitive analysis |
| `pipeline-orchestrator` | 4 | End-to-end product lifecycle |
| `shopify-aila-theme` | 4 | Shopify product publishing + theme management |
| `tile-qa` | 4 | Pattern tile visual QA |
| `yoycol-design-rules` | 4 | YAML rules generator for AOP garments |
| `add-yoycol` | 4 | Add Yoycol products from URLs |
| `composite-bundle` | 4 | Bundle mockup compositing |
| `upload-to-airtable` | 4 | Upload images to Airtable Pattern Library |

**Content Marketing Strategy Reference** (from `EtsyResearch/Content_Marketing_Strategy_2026-03-12.docx`):
| Section | Key Data for Agents |
|---------|-------------------|
| ICP | Women 22-34, whimsigoth/dark cottagecore/boho goth, $35K-$75K income, Pinterest-first discovery |
| Keyword Clusters | 6 clusters: Dark Floral (22,200/mo), Cottagecore (18,100/mo), Celestial (5,400/mo), Whimsigoth (1,900/mo), Art Nouveau (590/mo), Matching Sets (18,100/mo) |
| Blog Post Types | 7 types rotating: Style Guide, Trend Report, Outfit Inspo, Behind Design, Gift Guide, Comparison, Seasonal |
| Product Linking | 2-4 products/post, prioritize bundles (2-3x margin), rotate featured, contextual anchor text |
| Technical SEO | Keyword in URL/H1/first 100 words/meta, images <200KB WebP, Flesch-Kincaid 7-9, BlogPosting schema |
| Social Channels | Instagram (5-7x/week Reels+Carousels), Pinterest (10-15 pins/week), TikTok (3-5x/week), YouTube Shorts (3-5x/week) |
| Content Mix | 20% Product Drops, 25% Aesthetic/Inspo, 20% Behind Design, 20% Education, 15% Community |
| Automation | 5 agents: SEO Strategist → Content Planner → Copywriter → SEO Auditor → Publisher |

---

## 15. Success Metrics

| Metric | Target (Month 1) | Target (Month 3) |
|--------|------------------|-------------------|
| New products/week | 3-5 | 5-10 |
| Blog posts/week | 1-2 | 2-3 |
| Tweets/day | 1-2 | 2-3 |
| Pinterest pins/day | 0 (Trial) | 5-8 (Standard) |
| Google Ads ROAS | 2.0x | 3.0x |
| Google Ads daily spend | $5 | $15 |
| Etsy monthly revenue | $500 | $1,500 |
| Shopify monthly revenue | $500 | $1,500 |
| Organic blog traffic/month | 100 sessions | 1,000 sessions |
| Product approval rate | >80% | >90% |
| Listing optimization suggestions/week | 5-10 | 10-20 |
| Agent uptime | >95% | >99% |
| **QA first-pass rate** | **>70%** | **>90%** |
| **QA rejection→fix cycle time** | **<30 min** | **<15 min** |
| **Unit test pass rate** | **100%** | **100%** |
| **Integration test pass rate** | **>95%** | **>99%** |
| **E2E test pass rate** | **100%** | **100%** |
| **Browser verification coverage** | **>80% of outputs** | **100%** |
| **Cluster Ops refinements applied/week** | **1-2** | **2-4** |
| **Agent improvement trend** | **Measurable** | **Week-over-week pass rate up** |

---

## 16. Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Agent generates bad products | Gate 1 + Gate 2 approval + Devil's Advocate review + VE browser check |
| Agent publishes bad blog post | SEO score gate + Devil's Advocate review + VE Lighthouse check |
| Agent applies wrong listing changes | Airtable suggestions table + Devil's Advocate validates logic |
| Agent code change breaks system | VE runs unit + integration + E2E tests before change goes live |
| API costs spiral | Budget caps: $3/product, $10/day marketing, $200/month ads |
| Agent loops/hangs | Max concurrency=1 for API-heavy roles |
| Data corruption | Agents use pipeline scripts (not raw SQL/API) + VE integration tests verify |
| Subscription token rate limits | Stagger cron times, max 2-3 concurrent agents |
| VPS resources | 8GB RAM handles 4-5 concurrent; monitor with `htop` |
| Shopify token expires | Inventory Monitor checks daily, auto-refreshes + VE catches 401s |
| Google Merchant disapprovals | Ads Manager checks feed health daily + VE scrapes Google Shopping |
| Bad ad spend | Daily budget cap + auto-pause at ROAS < 1.0x for 5 days |
| QA becomes bottleneck | Devil's Advocate max 5min review time; auto-PASS if no issues in 10min |
| Agent quality degrades over time | Cluster Ops weekly analysis + refinement proposals |
| Refinement makes agent worse | Human approval gate on ALL prompt changes + rollback plan |
| QA agent itself has bugs | Cluster Ops monitors QA pass rate vs human spot-checks |
