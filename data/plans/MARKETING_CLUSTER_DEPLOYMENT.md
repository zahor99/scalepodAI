# Marketing & Content Cluster — Deployment Plan & Status

**VPS:** 104.168.1.240 (RackNerd)
**Platform:** PopeBot v1.2.73 (Docker + Claude Code CLI)
**Cluster ID:** `14e768ed-9d75-40c7-b3f4-edf2dff63c04`
**Workspace:** `/opt/stack/popebot/data/clusters/cluster-14e768ed/`
**Date:** 2026-03-14

---

## Architecture

PopeBot runs a Next.js event handler in Docker that manages "clusters" — groups of AI agent roles stored in SQLite. Each role is triggered (cron/manual/webhook) and runs as an ephemeral Docker container using the Claude Code CLI (`claude -p`).

```
PopeBot Event Handler (Docker, port 4100)
  └── SQLite DB: clusters + cluster_roles tables
  └── Triggers role → spawns Docker container
        └── stephengpope/thepopebot:claude-code-cluster-worker-1.2.73
        └── Mounts: workspace dir → /home/claude-code/workspace/
        └── Runs: claude -p "$PROMPT" --dangerously-skip-permissions
        └── Auth: CLAUDE_CODE_OAUTH_TOKEN env var
        └── Logs: stdout.jsonl + stderr.txt in timestamped log dirs
```

### Workspace Layout (inside container)
```
/home/claude-code/workspace/
├── .env                          # API keys (Supabase, Airtable, Postiz, Shopify, etc.)
├── prototype/                    # Python content producer scripts
│   ├── content_producer/         # postiz_client.py, tweet_generator.py, scheduler.py, etc.
│   └── supabase_client.py
├── docs/                         # Strategy docs, PRD, project context
│   ├── POPEBOT_CLUSTER_PRD.md    # Full 5-cluster architecture spec
│   ├── CLAUDE.md                 # Master project context (pipeline, products, stack)
│   ├── CONTENT_AUTOMATION_REMAINING.md
│   ├── SEO_AUDIT_REPORT.md
│   ├── SOCIAL_MARKETING_STATUS.md
│   ├── GOOGLE_SHOPPING_VIABILITY_ASSESSMENT.md
│   ├── POD_SKILLS_AND_LESSONS_LEARNED.md
│   └── POSTIZ_INTEGRATION_PLAN.md
├── shared/                       # Inter-cluster communication
│   ├── directives/               # CEO/ops directives (input)
│   ├── reports/                  # Agent output reports
│   ├── knowledge-base/           # 8 research files (market data, suppliers, specs)
│   ├── qa/                       # Quality review artifacts
│   └── research/                 # Agent research output
└── logs/                         # Per-role execution logs
    ├── role-1e3d07ec/            # Content Creator logs
    ├── role-6838206c/            # Scheduler logs
    ├── role-e966ba41/            # Engagement Tracker logs
    └── role-0442ad24/            # SEO Auditor logs
```

---

## Roles

| # | Role | ID | Trigger | Purpose |
|---|---|---|---|---|
| 1 | Content Creator | `1e3d07ec` | manual / webhook | Create tweets, pins, social content. Publish via Postiz. Update Airtable Content Calendar. |
| 2 | Scheduler | `6838206c` | cron `0 1 * * 0` (Sun 1am) | Build 7-day content calendar. Assign post types per content mix ratios. Write to Airtable. |
| 3 | Engagement Tracker | `e966ba41` | cron `0 2 * * *` (daily 2am) | Pull metrics from Postiz/Shopify. Update Airtable. Write performance reports. |
| 4 | SEO Auditor & Blog Writer | `0442ad24` | cron `0 13 * * 3` (Wed 1pm) | Keyword research, SEO audits, blog post drafts. Update Keyword Tracker + SEO Strategy tables. |

---

## Airtable Tables (base `appGRWviWaXJpcpCC`)

| Table | ID | Fields | Status |
|---|---|---|---|
| Content Calendar | `tbloKzWEyUxDxExNV` | 15 fields (Title, Channel, Format, Status, Cluster, Post Type, Keywords, Dates, Content Body, etc.) | **3 records created** |
| Keyword Tracker | `tblushsnd2AsXhDlK` | 13 fields (Keyword, Volume, CPC, Difficulty, Rank, etc.) | Empty — needs seeding |
| SEO Strategy | `tbl9Gq9ztstxrOKm0` | 14 fields (Strategy Name, Target Keywords, Content Type, Status, etc.) | Empty |
| Ad Campaigns | `tblAlNG65eCAtW0fE` | 16 fields (Campaign Name, Platform, Budget, CPC, ROAS, etc.) | Empty |

---

## What Has Been Done

### Infrastructure (2026-03-13/14)
- [x] SSH access to VPS confirmed
- [x] PopeBot event handler running (Docker, port 4100, healthy)
- [x] Claude Code OAuth token configured in `.env`
- [x] Marketing & Content cluster inserted into PopeBot SQLite DB
- [x] 4 roles inserted with full system prompts, cron configs, folder assignments
- [x] Cluster workspace created at `/opt/stack/popebot/data/clusters/cluster-14e768ed/`
- [x] **Symlink bug discovered and fixed** — Docker containers can't resolve host-path symlinks; replaced with real file copies
- [x] Shared directory structure created with correct permissions (chmod 777)
- [x] `.env` copied (real file, not symlink) with all 31 API keys
- [x] `prototype/content_producer/` scripts copied (postiz_client, tweet_gen, scheduler, etc.)
- [x] `docs/` populated with 9 strategy/spec documents
- [x] `shared/knowledge-base/` populated with 8 research files
- [x] Postiz URL fixed from `localhost:4007` to `https://tools.scalepod.ai`
- [x] 4 Airtable tables created with full field schemas via REST API

### Content Creator — First Successful Run (2026-03-14 04:22 UTC)
- [x] Container launched and ran for **6 minutes 35 seconds**
- [x] Cost: **$0.86** (46 turns, Claude Sonnet)
- [x] Read directive from `shared/directives/2026-03-13-marketing.md`
- [x] Sourced API keys from `.env`
- [x] Crafted 1 tweet for Dark Floral Dress Drop
- [x] **Created 3 Content Calendar records in Airtable** (Product Drop Mar 15, Education Mar 16, Style Guide Mar 17)
- [x] Each record has: title, channel, format, status, cluster, post type, primary keyword, planned date, full content body
- [x] Generated marketing execution report
- [x] Tweet NOT published — Postiz API key invalid (separate issue)

---

## What Is Left

### Blockers (must fix before next runs)
- [ ] **API token strategy** — OAuth tokens (`sk-ant-oat01-*`) can only be used by one session at a time. When user is active on PopeBot, cluster workers get 401. Need a dedicated token or standard API key for cluster workers.
- [ ] **Postiz API key** — Current key returns "Invalid API key". Regenerate in Postiz dashboard at `tools.scalepod.ai`.
- [ ] **Shopify token** — Expired. Refresh via client_credentials grant (see `prototype/suppliers/shopify_auth.py`).

### Remaining Role Tests
- [ ] **Scheduler** — Run with valid token. Should create 7-day content calendar (Mar 17-23) in Airtable.
- [ ] **SEO Auditor & Blog Writer** — Run with valid token. Keyword research for dark floral/whimsigoth/cottagecore clusters.
- [ ] **Engagement Tracker** — Run after content is published. Needs live posts to pull metrics from.

### Airtable Seeding
- [ ] **Keyword Tracker** — Seed with baseline data from `shared/knowledge-base/market-research-2026-02-14.md` (volumes, CPCs for top 20 keywords)
- [ ] **SEO Strategy** — Initial entries for 3 keyword clusters (dark floral, whimsigoth, cottagecore)

### Cron Automation
- [ ] **Verify cron triggers** — Roles have cron schedules in DB but haven't tested the event handler actually firing them. Need to confirm PopeBot's cron system reads `trigger_config` from `cluster_roles`.
- [ ] **Test webhook triggers** — Content Creator should be triggerable via webhook for on-demand content.

### Phase 2: Other Clusters (from PRD)
- [ ] Product & Design cluster (Design Director, QA Reviewer, Listing Optimizer)
- [ ] Operations & Fulfillment cluster (Inventory Monitor, Order Tracker, Supplier Liaison)
- [ ] Analytics & Intelligence cluster (Market Researcher, Performance Analyst, Competitor Monitor)
- [ ] CEO / Orchestrator cluster (Strategy Planner, Cross-Cluster Coordinator)

---

## Key Lessons Learned

1. **Symlinks break in Docker** — Container only sees bind-mounted paths. Host symlinks (`/opt/stack/...`) don't resolve. Use real file copies or additional bind mounts.
2. **OAuth tokens are single-session** — `sk-ant-oat01-*` tokens get rejected when used concurrently. Server deployments need dedicated tokens.
3. **Container is ephemeral** — AutoRemove=true. No way to inspect after exit. All output must go to mounted log dirs.
4. **Agent is resourceful** — Even with broken symlinks, the Content Creator found workarounds, sourced keys from `.env`, called Airtable API directly via curl, and wrote a detailed report. Cost was reasonable at $0.86/run.
5. **Content quality is good** — On-brand tweets with correct hashtags, seasonal relevance, proper content mix ratios. Ready for production once Postiz key is fixed.
