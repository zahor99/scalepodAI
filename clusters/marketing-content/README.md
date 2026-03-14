# Marketing & Content Cluster

Autonomous marketing system for the POD business (LunarAuraDesignStore / Maiden Bloom), targeting women 22-34 interested in whimsigoth, dark cottagecore, and boho goth aesthetics.

## Roles

| Role | Trigger | Schedule | Purpose |
|------|---------|----------|---------|
| **Content Creator** | Webhook | On demand | Creates and publishes social media content via Postiz |
| **Scheduler** | Cron | Sundays 1am UTC | Plans weekly content calendar in Airtable |
| **Engagement Tracker** | Cron | Daily 2am UTC | Pulls metrics and updates Airtable |
| **SEO Auditor** | Cron | Wednesdays 1pm UTC | Keyword research and blog drafting |

## Directory Structure

```
clusters/marketing-content/
├── CLUSTER_SYSTEM.md          # Shared system context for all roles
├── README.md                  # This file
├── shared/
│   ├── directives/            # Instructions for agents (read at runtime)
│   ├── reports/               # Status reports written by agents
│   └── knowledge-base/        # Reference materials
├── content-creator/
│   ├── content/               # Drafted content
│   └── media/                 # Media assets
├── scheduler/
│   └── schedule/              # Generated schedule files
├── engagement-tracker/
│   └── metrics/               # Saved metrics snapshots
└── seo-auditor/
    ├── seo/                   # SEO research outputs
    └── blog/                  # Blog post drafts
```

## Webhook: Content Creator

**Endpoint**: `POST /webhook/marketing-content-create`

Triggers an agent job to create and publish social content. Include a directive in the request body to guide the agent.

**Example payloads:**

```bash
# Create a product highlight post
curl -X POST https://your-app.com/webhook/marketing-content-create \
  -H "Content-Type: application/json" \
  -d '{"directive": "Create 3 Pinterest pins showcasing our dark floral tote bags"}'

# Create aesthetic content
curl -X POST https://your-app.com/webhook/marketing-content-create \
  -H "Content-Type: application/json" \
  -d '{"directive": "Write 5 tweets with whimsigoth aesthetic vibes for this week"}'
```

## Cron Jobs

### Marketing Content Scheduler
- **Schedule**: `0 1 * * 0` (Sundays 1am UTC)
- **Action**: Creates a 7-day content calendar in Airtable following the content mix (25% Aesthetic, 20% Product, 20% Behind Design, 20% Education, 15% Community)
- **Output**: Airtable Content Calendar + report in `shared/reports/`

### Marketing Engagement Tracker
- **Schedule**: `0 2 * * *` (Daily 2am UTC)
- **Action**: Pulls engagement metrics from all platforms, updates Airtable
- **Output**: Airtable Content Calendar (engagement fields) + report in `shared/reports/`

### Marketing SEO Auditor
- **Schedule**: `0 13 * * 3` (Wednesdays 1pm UTC)
- **Action**: Researches trending keywords, updates Airtable, drafts blog posts
- **Output**: Airtable Keyword Tracker + SEO Strategy + blog draft in `seo-auditor/blog/` + report in `shared/reports/`

## Airtable Integration

**Base ID**: `appGRWviWaXJpcpCC`

| Table | ID | Purpose |
|-------|----|---------|
| Content Calendar | tbloKzWEyUxDxExNV | Content planning and tracking |
| Keyword Tracker | tblushsnd2AsXhDlK | SEO keyword research |
| SEO Strategy | tbl9Gq9ztstxrOKm0 | SEO strategy and goals |
| Ad Campaigns | *(see Airtable)* | Paid ad management |
| Shopify Products | *(see Airtable)* | Product catalog sync |
| Pattern Library | *(see Airtable)* | Design pattern reference |

**Auth**: `AIRTABLE_API_KEY` environment variable

## External APIs

| Service | URL | Auth |
|---------|-----|------|
| Postiz | https://tools.scalepod.ai/api/public/v1 | `Authorization: POSTIZ_API_KEY` (no Bearer prefix) |
| Supabase | jtptaswggfdgzmuifnzi.supabase.co | `SUPABASE_SERVICE_KEY_CLOUD` |
| Shopify | q2chc0-wp.myshopify.com | `SHOPIFY_ACCESS_TOKEN` |
| NCA Toolkit | http://nca-toolkit:8080 | `fc64b209f9f2928b6f12eae67945c358bae5b2b38ae26fb3` |

## Adding Directives

Drop a markdown file into `shared/directives/` to give agents standing instructions. Agents read the latest directives at runtime before executing their tasks.

Example directive files:
- `shared/directives/tone-guide.md` - Brand voice and tone guidelines
- `shared/directives/campaign-brief.md` - Active campaign details
- `shared/directives/content-themes.md` - Current content themes and priorities

## Monitoring

- **Reports**: Check `shared/reports/` for agent-generated status updates
- **Job logs**: View job history in the web UI at `/runners`
- **Notifications**: Completion alerts sent via web UI and Telegram

## Content Strategy

Full content strategy reference: `data/docs/Social_Media_Content_Strategy_MaidenBloom_2026.html`
