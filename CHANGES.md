# Landing uplift: ScalePOD AI for merch agencies (2026-10-14)

Branch `agency-uplift`, based on `origin/main`. Repositions scalepod.ai from "POD command center for Etsy sellers" to ScalePOD AI for merch agencies, per `vault/projects/scalepod-prospects-2026/PRODUCT-SPEC-2026-10-14.md` §1, §3, §7, §8 and `design-2026-10/DESIGN.md`.

## Deployment note (read before merging)

- GitHub Pages serves **`gh-pages`**, not `main` (`gh api repos/zahor99/scalepodAI/pages` → `source.branch: gh-pages`). The live page today is the pre-compliance copy; the Etsy-compliance rewrite on `main` (commits d03d2f2 … 8178fc9) has never been deployed. Merging this PR to `main` will not change the live site until Pages is switched to `main` / root (the legacy `main` branch has `CNAME` + `.nojekyll` in place) or the three HTML files are pushed to `gh-pages`.
- The local `EtsyAutomation/scalepod-ai/website-deploy/` copy is identical to `origin/main` apart from line endings; nothing needed carrying over.
- `app.scalepod.ai` (login + `/sp/api/register/request`) is not live yet. Until it is, "Log in" 404s/does not resolve and the request-access form falls back to a prefilled `mailto:`.

## Section by section (old → new)

| Section | Live page (gh-pages) / main | New |
|---|---|---|
| `<title>` / meta / OG | "ScalePod AI — Your AI-Powered POD Command Center" (live) · "ScalePOD — Print-on-Demand Product Studio & Seller Tools" (main); `og:image` pointed at a missing `images/og-banner.webp` | "ScalePOD AI — from brief to print-ready, for merch agencies"; description = the §1 one-liner; `og:image` = new `images/og.jpg` (rendered from the hero, 1200×630) |
| Fonts | Plus Jakarta Sans | Inter + JetBrains Mono per DESIGN.md (same Google Fonts origin, no new third party) |
| Tokens | ad-hoc cyan/green/amber set, green gradient buttons | DESIGN.md dark token set (`bg`, `surface`, `surface-2`, `border`, `text`, `text-muted`, `accent`, `accent-2`, `cta`, `success`, `danger`, violet for "waiting on client"); accent gradient only on logo square and primary buttons; radii 10/8/6/999; no drop shadows |
| Wordmark | `Scale`+`Pod` | `Scale`+`POD` (POD in accent) + small "AI" suffix; favicon = mark on the gradient square |
| Nav | How It Works · Results · Features · Join Waitlist | How it works · Client review · Demo · Pricing · **Log in** (→ app.scalepod.ai/login) · **Request access** (→ on-page form) |
| Hero | "Stop Designing. Start Scaling." / "Your POD Command Center." + AOP hoodie render + waitlist CTA | "From brief to print-ready in hours, not days." + the §1 one-liner (mirrored verbatim) + Request access / Watch the 2-minute demo + "Already have a workspace? Log in". Visual = HTML/CSS brief-journey mock from DEMO-BRAND.md (Kessel & Pine Merch → Aldervane Analytics: 3-direction board, W2/W4/W6/W7 rail, credits) with a "fictional, synthetic" caption |
| Stats | 7 print zones · 10 listing images · 3 product tiers · 2 platform connections | 3–5 directions per board · 300 dpi print file per position · 1 link for client decisions · ≈ 48 cr a typical full brief |
| How it works (6 Etsy steps: design studio → artwork → mockups → listing SEO → pricing → publish) | removed | **Eight jobs** (§1 jobs to be done, 8 cards) |
| — | new | **Two modes**: Pitch (≈ 6 cr, no gates, capped per month) vs Client (≈ 48 cr, full path) |
| — | new | **Seven steps, each with a named gate** = W1–W7 from §3 with the gate per step, plus W8 status/usage and "start from an approved design"; four agent rules (cost before go, nothing leaves the workspace, reproducible assets, catalogue is the truth) |
| Showcase "Designs That Sell" (fox / serpent / owl AOP renders, Etsy-seller framing) | removed; `images/hero-mirror.jpg` and `images/showcase/*` deleted (AOP is explicitly not in v1) | **What the client sees**: phone mock of the review page (accept / reject / regenerate per item) + a demo quote table (50 / 100 / 250 pcs, landed to DK, marked synthetic) |
| — | new | **Demo**: embedded `<video>` (poster + mp4 from tools.scalepod.ai, `preload="none"`) + link to open in a new tab |
| Features (AOP, 10-slot images, SEO tags, niche templates, multi-tier listings, analytics) | removed | **Print files only on verified blanks**: verified vs candidate tiers (§7) + the "not in the catalogue yet" line; **Not in v1** chips (§1) |
| Comparison "Without / With ScalePOD" | removed | — |
| — | new | **Pricing, credits not seats**: 100 cr €49 · 300 cr €129 · 1,000 cr €349, per-credit price, "indicative until launch"; "Included credits with every workspace" (no number); pitch ≈ 6 cr, full brief ≈ 48 cr; "No subscription". No monthly plans anywhere |
| Waitlist (email → Supabase `waitlist` table with an embedded anon key) | removed, anon key gone from the page | **Request access** form: work email + agency + honeypot `website`; POSTs `{email, company, source:"website", website:""}` as JSON to `https://app.scalepod.ai/sp/api/register/request` (8 s timeout, 200/409 = success); on any failure opens `mailto:wellnesspresso@gmail.com` with subject/body prefilled and shows the address as a link |
| Footer | Privacy · Terms · Contact (live: `wellnesspresso@gmail.com`; main: `hello@scalepod.ai`, not set up) · "© ScalePOD" | Log in · Request access · Privacy policy · Terms of service · Contact (`wellnesspresso@gmail.com`, the live page's working address) · "© 2026 ScalePOD AI" |
| Scripts | inline waitlist JS + Supabase | inline JS only (menu toggle + form); no external scripts |

## privacy.html and terms.html

- Product name `ScalePod AI` → `ScalePOD AI` (title, meta, body, footer) and the nav wordmark `Scale`+`POD`.
- Contact address: `main` had replaced the live `wellnesspresso@gmail.com` with `hello@scalepod.ai` (4 places in privacy, 0 in terms). `hello@scalepod.ai` is not set up, so the live address is restored. Flagged for the operator; swap once a scalepod.ai mailbox exists.
- Etsy API terms link `https://www.etsy.com/developers/terms-of-use` returns 404; updated to `https://www.etsy.com/legal/api` (both occurrences; Etsy answers 403 to every automated client, so this one needs a human click to confirm). Wording untouched.
- **Kept intact for Etsy API compliance**: privacy §6 "Etsy API Data Handling" (data accessed, use, protection, retention, Sections 3 and 5 compliance statement), the Printify/Etsy third-party clauses, and terms §2/§7 describing the Etsy/Printify integration. The Etsy integration still exists in the codebase; the landing page simply no longer markets it.

## Checks

- Playwright: desktop 1440 and phone 390 full-page screenshots in `vault/projects/scalepod-prospects-2026/design-2026-10/website/` (`before.png` from the live page, `after-desktop.png`, `after-phone.png`). No element wider than the viewport at 390 / 768 / 1440 (only the clipped decorative glow).
- Link check (script in the session scratchpad): all local files and anchors resolve; external links 200 except `app.scalepod.ai` (pending, expected) and `optout.aboutads.info` (429 rate-limit on a pre-existing privacy link).
- Page weight: `index.html` 63 KB + `images/og.jpg` 85 KB (only fetched by link previews); the demo video is `preload="none"`, so first paint loads HTML + two font files only. Previously the page shipped ~1.2 MB of showcase JPEGs.
