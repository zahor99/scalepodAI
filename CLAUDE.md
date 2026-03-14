# My Agent

## Overview

This is an autonomous AI agent powered by [thepopebot](https://github.com/stephengpope/thepopebot). It uses a **two-layer architecture**:

1. **Event Handler** — A Next.js server that orchestrates everything: web UI, Telegram chat, cron scheduling, webhook triggers, and job creation.
2. **Docker Agent** — A container that runs the Pi coding agent for autonomous task execution. Each job gets its own branch, container, and PR.

All core logic lives in the `thepopebot` npm package. This project is a scaffolded shell — thin Next.js wiring, user-editable configuration, GitHub Actions workflows, and Docker files.

## Directory Structure

```
project-root/
├── CLAUDE.md                          # This file (project documentation)
├── next.config.mjs                    # Next.js config (wraps withThepopebot())
├── instrumentation.js                 # Server startup hook (re-exports from package)
├── middleware.js                       # Auth middleware (re-exports from package)
├── .env                               # API keys and tokens (gitignored)
├── package.json
│
├── app/                               # Next.js app directory (MANAGED — do not edit, auto-synced)
│   ├── api/[...thepopebot]/route.js   # Catch-all API route (re-exports from package)
│   └── stream/chat/route.js           # Chat streaming endpoint (session auth)
│
├── config/                            # Agent configuration (user-editable)
│   ├── SOUL.md                        # Personality, identity, and values
│   ├── JOB_PLANNING.md                # Event handler LLM system prompt
│   ├── JOB_AGENT.md                   # Agent runtime environment docs
│   ├── JOB_SUMMARY.md                 # Prompt for summarizing completed jobs
│   ├── HEARTBEAT.md                   # Self-monitoring / heartbeat behavior
│   ├── SKILL_BUILDING_GUIDE.md             # Guide for building agent skills
│   ├── CRONS.json                     # Scheduled job definitions
│   └── TRIGGERS.json                  # Webhook trigger definitions
│
├── .github/workflows/                 # GitHub Actions
├── docker/                            # Docker files (job agent + event handler)
├── skills/                            # All available agent skills
│   └── active/                        # Symlinks to active skills (shared by Pi + Claude Code)
├── .pi/skills → skills/active         # Pi reads skills from here
├── .claude/skills → skills/active     # Claude Code reads skills from here
├── cron/                              # Scripts for command-type cron actions
├── triggers/                          # Scripts for command-type trigger actions
├── logs/                              # Per-job output (logs/<JOB_ID>/job.md + session .jsonl)
└── data/                              # SQLite database (data/thepopebot.sqlite)
```

## Two-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ┌──────────────────┐         ┌──────────────────┐                     │
│  │  Event Handler   │ ──1──►  │     GitHub       │                     │
│  │  (creates job)   │         │ (job/* branch)   │                     │
│  └────────▲─────────┘         └────────┬─────────┘                     │
│           │                            │                               │
│           │                            2 (triggers run-job.yml)        │
│           │                            │                               │
│           │                            ▼                               │
│           │                   ┌──────────────────┐                     │
│           │                   │  Docker Agent    │                     │
│           │                   │  (runs Pi, PRs)  │                     │
│           │                   └────────┬─────────┘                     │
│           │                            │                               │
│           │                            3 (creates PR)                  │
│           │                            │                               │
│           │                            ▼                               │
│           │                   ┌──────────────────┐                     │
│           │                   │     GitHub       │                     │
│           │                   │   (PR opened)    │                     │
│           │                   └────────┬─────────┘                     │
│           │                            │                               │
│           │                            4a (auto-merge.yml)             │
│           │                            4b (notify-pr-complete.yml)     │
│           │                            │                               │
│           5 (notification → web UI     │                               │
│              and Telegram)             │                               │
│           └────────────────────────────┘                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Event Handler** (this Next.js server): Receives requests (web UI, Telegram, webhooks, cron timers), creates jobs by pushing a `job/<uuid>` branch to GitHub, and manages the web interface.

**Docker Agent**: A container spun up by GitHub Actions (`run-job.yml`) that clones the job branch, runs the Pi coding agent with the job prompt, commits results, and opens a PR.

## Job Lifecycle

1. **Job created** — Event handler calls `createJob()` (via chat, cron, trigger, or API)
2. **Branch pushed** — A `job/<uuid>` branch is created with `logs/<uuid>/job.md` containing the task prompt
3. **Workflow triggers** — `run-job.yml` fires on `job/*` branch creation
4. **Container runs** — Docker agent clones the branch, builds `SYSTEM.md` from `config/SOUL.md` + `config/AGENT.md`, runs Pi with the job prompt, and logs the session to `logs/<uuid>/`
5. **PR created** — Agent commits results and opens a pull request
6. **Auto-merge** — `auto-merge.yml` squash-merges the PR if all changed files fall within `ALLOWED_PATHS` prefixes (default: `/logs`)
7. **Notification** — `notify-pr-complete.yml` sends job results back to the event handler, which creates a notification in the web UI and sends a Telegram message

## Action Types

Both cron jobs and webhook triggers use the same dispatch system. Every action has a `type` field:

| | `agent` (default) | `command` | `webhook` |
|---|---|---|---|
| **Uses LLM** | Yes — spins up Pi in Docker | No | No |
| **Runtime** | Minutes to hours | Milliseconds to seconds | Milliseconds to seconds |
| **Cost** | LLM API calls + GitHub Actions | Free (runs on event handler) | Free (runs on event handler) |
| **Use case** | Tasks that need to think, reason, write code | Shell scripts, file operations | Call external APIs, forward webhooks |

If the task needs to *think*, use `agent`. If it just needs to *do*, use `command`. If it needs to *call an external service*, use `webhook`.

### Agent action
```json
{ "type": "agent", "job": "Analyze the logs and write a summary report" }
```
Creates a Docker Agent job. The `job` string is passed as-is to the LLM as its task prompt.

### Command action
```json
{ "type": "command", "command": "node cleanup.js --older-than 7d" }
```
Runs a shell command on the event handler. Working directory: `cron/` for crons, `triggers/` for triggers.

### Webhook action
```json
{
  "type": "webhook",
  "url": "https://api.example.com/notify",
  "method": "POST",
  "headers": { "Authorization": "Bearer token" },
  "vars": { "source": "my-agent" }
}
```
Makes an HTTP request. `GET` skips the body. `POST` (default) sends `{ ...vars }` or `{ ...vars, data: <incoming payload> }` when triggered by a webhook.

## Cron Jobs

Defined in `config/CRONS.json`, loaded at server startup by `node-cron`.

```json
[
  {
    "name": "Daily Check",
    "schedule": "0 9 * * *",
    "type": "agent",
    "job": "Review recent activity and summarize findings",
    "enabled": true
  }
]
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name |
| `schedule` | Yes | Cron expression (e.g., `0 9 * * *` = daily at 9am) |
| `type` | No | `agent` (default), `command`, or `webhook` |
| `job` | For agent | Task prompt passed to the LLM |
| `command` | For command | Shell command (runs in `cron/` directory) |
| `url` | For webhook | Target URL |
| `method` | For webhook | `GET` or `POST` (default: `POST`) |
| `headers` | For webhook | Custom request headers |
| `vars` | For webhook | Key-value pairs merged into request body |
| `enabled` | No | Set `false` to disable (default: `true`) |
| `llm_provider` | No | Override LLM provider for this cron (agent type only) |
| `llm_model` | No | Override LLM model for this cron (agent type only) |

## Webhook Triggers

Defined in `config/TRIGGERS.json`, loaded at server startup. Triggers fire on POST requests to watched paths (after auth, before route handler, fire-and-forget).

```json
[
  {
    "name": "GitHub Push",
    "watch_path": "/webhook/github-push",
    "enabled": true,
    "actions": [
      {
        "type": "agent",
        "job": "Review the push to {{body.ref}}: {{body.head_commit.message}}"
      }
    ]
  }
]
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name |
| `watch_path` | Yes | URL path to watch (e.g., `/webhook/github-push`) |
| `actions` | Yes | Array of actions to fire (same fields as cron actions) |
| `enabled` | No | Set `false` to disable (default: `true`) |

**Template tokens** for `job` and `command` strings:

| Token | Resolves to |
|-------|-------------|
| `{{body}}` | Entire request body as JSON |
| `{{body.field}}` | Nested field from request body |
| `{{query}}` | All query parameters as JSON |
| `{{query.field}}` | Specific query parameter |
| `{{headers}}` | All request headers as JSON |
| `{{headers.field}}` | Specific request header |

## API Endpoints

All API routes are under `/api/`, handled by the catch-all route.

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/create-job` | POST | `x-api-key` | Create a new autonomous agent job |
| `/api/telegram/webhook` | POST | `TELEGRAM_WEBHOOK_SECRET` | Telegram bot webhook |
| `/api/telegram/register` | POST | `x-api-key` | Register Telegram webhook URL |
| `/api/github/webhook` | POST | `GH_WEBHOOK_SECRET` | Receive notifications from GitHub Actions |
| `/api/jobs/status` | GET | `x-api-key` | Check status of running/queued jobs |
| `/api/ping` | GET | Public | Health check |

**`x-api-key`**: Database-backed API keys generated through the web UI (Settings > Secrets). Keys are SHA-256 hashed, verified with timing-safe comparison. Format: `tpb_` prefix + 64 hex characters.

## Web Interface

Accessible after login at `APP_URL`. Routes: `/` (chat), `/chats` (history), `/chat/[chatId]` (resume chat), `/settings/crons`, `/settings/triggers`, `/settings/secrets` (API keys), `/runners` (job monitor), `/notifications`, `/login` (auth / first-time admin setup).

## Authentication

NextAuth v5 with Credentials provider (email/password), JWT in httpOnly cookies. First visit creates admin account. Browser UI uses Server Actions with `requireAuth()`. API routes use `x-api-key` header. Chat streaming uses a dedicated route at `/stream/chat` with `auth()` session check.

## Database

SQLite via Drizzle ORM at `data/thepopebot.sqlite`. Auto-initialized and auto-migrated on server startup. Tables: `users`, `chats`, `messages`, `notifications`, `subscriptions`, `settings` (key-value store, also stores API keys). Column naming: camelCase in JS → snake_case in SQL.

## GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `run-job.yml` | `job/*` branch created | Runs the Docker agent container |
| `rebuild-event-handler.yml` | Push to `main` | Rebuilds server (fast path or Docker restart) |
| `upgrade-event-handler.yml` | Manual `workflow_dispatch` | Creates PR to upgrade thepopebot package |
| `build-image.yml` | `docker/pi-coding-agent-job/**` changes | Builds Pi coding agent Docker image to GHCR |
| `auto-merge.yml` | Job PR opened | Squash-merges if changes are within `ALLOWED_PATHS` |
| `notify-pr-complete.yml` | After `auto-merge.yml` | Sends job completion notification |
| `notify-job-failed.yml` | `run-job.yml` fails | Sends failure notification |

## GitHub Secrets & Variables

### Secrets (prefix-based naming)

| Prefix | Purpose | Visible to LLM? | Example |
|--------|---------|------------------|---------|
| `AGENT_` | Protected credentials for Docker agent | No (filtered by env-sanitizer) | `AGENT_GH_TOKEN`, `AGENT_ANTHROPIC_API_KEY` |
| `AGENT_LLM_` | LLM-accessible credentials for Docker agent | Yes | `AGENT_LLM_BRAVE_API_KEY` |
| *(none)* | Workflow-only secrets (never passed to container) | N/A | `GH_WEBHOOK_SECRET` |

`AGENT_*` secrets are collected into a `SECRETS` JSON object by `run-job.yml` (prefix stripped) and exported as env vars in the container. `AGENT_LLM_*` go into `LLM_SECRETS` and are not filtered from the LLM's bash environment.

### Repository Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_URL` | Public URL for the event handler | Required |
| `AUTO_MERGE` | Set to `"false"` to disable auto-merge | Enabled |
| `ALLOWED_PATHS` | Comma-separated path prefixes for auto-merge | `/logs` |
| `JOB_IMAGE_URL` | Docker image for job agent (GHCR URLs trigger auto-builds) | Default thepopebot image |
| `EVENT_HANDLER_IMAGE_URL` | Docker image for event handler | Default thepopebot image |
| `RUNS_ON` | GitHub Actions runner label | `ubuntu-latest` |
| `LLM_PROVIDER` | LLM provider for Docker agent | `anthropic` |
| `LLM_MODEL` | LLM model name for Docker agent | Provider default |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `APP_URL` | Public URL for webhooks and Telegram | Yes |
| `AUTH_SECRET` | NextAuth session encryption (auto-generated) | Yes |
| `GH_TOKEN` | GitHub PAT for creating branches/files | Yes |
| `GH_OWNER` | GitHub repository owner | Yes |
| `GH_REPO` | GitHub repository name | Yes |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | For Telegram |
| `TELEGRAM_WEBHOOK_SECRET` | Telegram webhook validation secret | No |
| `TELEGRAM_CHAT_ID` | Default chat ID for notifications | For Telegram |
| `GH_WEBHOOK_SECRET` | GitHub Actions webhook auth | For notifications |
| `LLM_PROVIDER` | `anthropic`, `openai`, `google`, or `custom` | No (default: `anthropic`) |
| `LLM_MODEL` | Model name override | No |
| `LLM_MAX_TOKENS` | Max tokens for LLM responses | No (default: 4096) |
| `ANTHROPIC_API_KEY` | Anthropic API key | For anthropic provider |
| `OPENAI_API_KEY` | OpenAI API key / Whisper | For openai provider |
| `OPENAI_BASE_URL` | Custom OpenAI-compatible base URL | For custom provider |
| `GOOGLE_API_KEY` | Google API key | For google provider |
| `CUSTOM_API_KEY` | Custom provider API key | For custom provider |
| `DATABASE_PATH` | Override SQLite DB location | No |

## Managed Files

The following directories are auto-synced by `thepopebot init` and `thepopebot upgrade`. **Do not edit them** — changes will be overwritten on package updates: `.github/workflows/`, `docker/event-handler/`, `docker-compose.yml`, `.dockerignore`, `CLAUDE.md`, `app/`.

All UI components live in the npm package — `app/` only contains thin page shells that import from `thepopebot/chat`, `thepopebot/auth/components`, etc.

## Customization

User-editable config files in `config/`: `SOUL.md` (personality), `JOB_PLANNING.md` (LLM system prompt), `JOB_AGENT.md` (runtime docs), `JOB_SUMMARY.md` (job summaries), `HEARTBEAT.md` (self-monitoring), `SKILL_BUILDING_GUIDE.md` (skill guide), `CRONS.json` (scheduled jobs), `TRIGGERS.json` (webhook triggers).

To customize appearance, edit `theme.css` in the project root (loaded after `globals.css`, user-owned, not managed).

Skills in `skills/` are activated by symlinking into `skills/active/`. Both `.pi/skills` and `.claude/skills` point to `skills/active/`. Scripts for command-type actions go in `cron/` and `triggers/`.

### Markdown includes and variables

Config markdown files support includes and built-in variables (processed by the package's `render-md.js`):

| Syntax | Description |
|--------|-------------|
| `{{ filepath.md }}` | Include another file (relative to project root, recursive with circular detection) |
| `{{datetime}}` | Current ISO timestamp |
| `{{skills}}` | Dynamic bullet list of active skill descriptions from `skills/active/*/SKILL.md` frontmatter — never hardcode skill names, this is resolved at runtime |
