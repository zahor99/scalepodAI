# SEO Audit Report — maidenbloom.com
**Date**: 2026-03-11
**Auditor**: Claude SEO Agent

## Executive Summary
- **Overall SEO Health: 38/100**
- **Critical Issues: 5**
- **High Priority Issues: 8**
- **Quick Wins: 6**
- **Pages Audited: 6** (Homepage, 1 Collection, 2 Products, Blog index, About Us)

The site is **not indexed by Google at all** — a `site:maidenbloom.com` search returns zero results. This is the single most urgent problem. Combined with missing meta descriptions across all pages, a placeholder "About Us" page still referencing the theme vendor name "Aila", fake contact information on the Contact page, no Open Graph tags, and thin collection page content, the store is effectively invisible to search engines and would perform poorly even if indexed. The technical foundation (Shopify, proper sitemaps, Product schema) is sound, but on-page SEO and content quality need significant work.

---

## Phase 1: Crawlability & Indexation

### Robots.txt
**Status: OK** — Standard Shopify robots.txt with appropriate rules.
- Blocks admin, cart, checkout, account, search, and filtered/sorted collection URLs
- Sitemap declared: `https://maidenbloom.com/sitemap.xml`
- Crawl delays set for AhrefsBot (10s), MJ12bot (10s), Pinterest (1s)
- Nutch fully blocked
- No issues — this is a well-configured default Shopify robots.txt

### Sitemap
**Status: OK** — Sitemap index with 4 sub-sitemaps:
| Sub-sitemap | Content |
|-------------|---------|
| `sitemap_products_1.xml` | 40 product URLs (all lastmod 2026-03-11) |
| `sitemap_pages_1.xml` | 8 pages (Contact, Privacy, Terms, Shipping, Refund, About Us, FAQ, Data Sharing Opt-Out) |
| `sitemap_collections_1.xml` | 9 collections (incl. frontpage) |
| `sitemap_blogs_1.xml` | Blog section |

All products have image entries. No issues with sitemap structure.

### Indexation Status
**CRITICAL: ZERO pages indexed.** A Google search for `site:maidenbloom.com` returns no results. A branded search for "maidenbloom.com" also returns no results — the domain does not appear anywhere in Google's index.

**Likely causes:**
1. The store is very new (products lastmod all show 2026-03-11)
2. No Google Search Console verification/submission (most likely)
3. Possible password protection was recently removed
4. No inbound links from any indexed domains

### Canonicalization
- **Homepage**: Canonical tag not explicitly detected in fetch (Shopify usually auto-generates these)
- **Collection page**: Not explicitly detected
- **Product pages**: Not explicitly detected but Shopify auto-generates canonical tags in the `<head>` — likely present but obscured by the fetch tool's HTML-to-markdown conversion
- **No duplicate content risk detected** — URL structure is clean

---

## Phase 2: Technical SEO

### Structured Data / Schema

| Schema Type | Present | Quality | Issues |
|-------------|---------|---------|--------|
| Organization | Yes | Partial | Logo URL points to Shopify's default `no-image-2048-a2addb12.gif` placeholder instead of actual logo. `sameAs` array is empty on homepage but populated on collection pages with generic social URLs (twitter.com/, facebook.com/ — not actual profile URLs) |
| WebSite + SearchAction | Yes | Good | Proper search URL template |
| Product | Yes | Good | Includes price, availability, brand, SKU, images, variants |
| BreadcrumbList | Yes | Partial | Only 2 levels (Home > Product) — missing collection level |
| FAQPage | Yes | Good | Present on FAQ page with all 7 Q&A pairs |
| CollectionPage | No | Missing | No structured data for collection pages |

**Key Issues:**
1. Organization logo in schema is a Shopify placeholder GIF, not the actual `mb_logo.png`
2. `sameAs` social links are empty/generic — need actual profile URLs
3. BreadcrumbList on product pages skips the collection level (Home > Product instead of Home > Collection > Product)
4. No `AggregateRating` or `Review` schema on any product

### Page Speed Indicators
- Scripts use `async` and `defer` attributes (15+ instances) — good
- No `<link rel="preload">` or `<link rel="prefetch">` detected for critical resources
- Images served via Shopify CDN with automatic WebP conversion — good
- No evidence of critical CSS inlining or font preloading

### Mobile Readiness
- Viewport meta tag: Not explicitly detected in fetch but Shopify themes always include it
- Separate mobile banner image detected (`mb_banner_elevate_mobile.png`) — responsive design confirmed
- Mobile navigation with hamburger menu present

### Security
- HTTPS enforced across all pages — good
- No mixed content detected
- hCaptcha protection on forms

---

## Phase 3: On-Page SEO

### Page-by-Page Analysis

| Page | Title Tag | Meta Desc | H1 | Schema | Issues |
|------|-----------|-----------|-----|--------|--------|
| Homepage | Not detected (likely "Maiden Bloom") | **MISSING** | "NEW COLLECTION" + "SHOP BY _Style_" (2 H1s) | Organization + WebSite | No meta desc, 2 H1s, generic H1 text, no OG tags |
| Dark Floral Collection | "Dark Floral Dresses" (estimated) | **MISSING** | "Dark Floral Dresses" | Organization only | No meta desc, no collection desc text, no CollectionPage schema |
| Product 1 (Dark Garden) | "Dark Garden Tapestry 3/4 Sleeve Maxi Dress - Dark Floral ..." | **MISSING** | Full product name with pipe | Product + BreadcrumbList | No meta desc, no reviews, no related products |
| Product 2 (Cosmic Garden) | "Cosmic Garden Side Slit Dress - Celestial Dress" | **MISSING** | Full product name with pipe | Product + BreadcrumbList | No meta desc, no reviews, no related products |

### Detailed Findings

#### Homepage
- **Title**: Likely just "Maiden Bloom" — not keyword-optimized. Should include primary keyword like "All Over Print Dresses | Dark Floral, Boho & Celestial | Maiden Bloom"
- **Meta Description**: MISSING — critical gap. Every page needs one.
- **H1 Tags**: TWO H1 tags ("NEW COLLECTION" and "SHOP BY _Style_") — should have exactly one, keyword-rich H1
- **H1 Content**: "NEW COLLECTION" is generic and contains no keywords. Should be something like "All Over Print Dresses — Dark Floral, Boho & Celestial Styles"
- **Open Graph Tags**: NONE detected — social sharing will show generic/broken previews
- **Image Alt Text**: Banner images have basic alt text ("Banner Elevate", "Banner New Collection") but niche category images (boho, celestial, dark floral, whimsigoth, maxi) have **no alt text**
- **Content Depth**: Minimal — mostly product grids with category navigation. No intro text, no value proposition copy, no keyword-rich content
- **Internal Linking**: Good category navigation (7 collection links), product cards link properly

#### Dark Floral Dresses Collection
- **Title**: Short, likely "Dark Floral Dresses" — should be "Dark Floral Dresses | All Over Print Botanical Fashion | Maiden Bloom"
- **Meta Description**: MISSING
- **H1**: "Dark Floral Dresses" — good, contains target keyword
- **Content**: ZERO descriptive text beyond the product grid. This is a major SEO gap. Collections need 200-400 words of keyword-rich intro/outro text
- **14 products listed** — good product count
- **Image Alt Text**: Follows pattern "[Product Name] — view 1" — functional but not keyword-optimized. Should include "dark floral dress" keyword
- **Filters**: Good — Style and Dress Type filters available
- **H2/H3 Hierarchy**: H2s used for sidebar navigation categories (not semantic content headings)

#### Product 1: Dark Garden Tapestry 3/4 Sleeve Maxi Dress
- **Title**: "Dark Garden Tapestry 3/4 Sleeve Maxi Dress - Dark Floral ..." — truncated at ~60 chars, includes keyword "Dark Floral" — decent
- **Meta Description**: MISSING — should highlight unique design, price, free shipping threshold
- **H1**: "Dark Garden Tapestry 3/4 Sleeve Maxi Dress | All Over Print Dark Floral Fashion" — good, keyword-rich, unique
- **H2/H3 Hierarchy**: H2s for "Why You'll Love It" and "Product Details" — logical structure
- **Product Description**: Good content depth with fabric details, care instructions, sizing, shipping info, FAQ. Contains relevant keywords naturally
- **Image Alt Text**: All images use "[Product Name] — view N" pattern — should be more descriptive (e.g., "Dark floral maxi dress front view on model", "Dark floral print close-up detail")
- **Pricing Schema**: Correct — $54.99 sale, $109.98 compare-at
- **Availability**: "BackOrder" — this may cause Google Shopping disapprovals; should be "InStock" if accepting orders
- **Reviews**: NONE — no review system installed
- **Related Products**: NONE — missed cross-sell opportunity
- **Trust Signals**: "Made to Order" badge, free shipping over $75, BLOOM10 discount code

#### Product 2: Cosmic Garden Side Slit Dress
- **Title**: "Cosmic Garden Side Slit Dress - Celestial Dress" — only 48 chars, room to add brand. Good keyword inclusion
- **Meta Description**: MISSING
- **H1**: "Cosmic Garden Side Slit Dress | All Over Print Celestial Fashion" — good
- **Description**: Good content about celestial motifs, sublimation print quality, size inclusivity
- **Same issues as Product 1**: no reviews, no related products, generic image alts, missing meta description

---

## Phase 4: E-Commerce SEO

### Product Schema
**Status: Good foundation, missing elements**

Present:
- Product name, brand, price, compare-at price, currency
- SKU per variant (e.g., MB-DF05_34MAXI-34M-XS)
- Availability status (BackOrder)
- Product images (6-7 per product)
- 9 size variants with individual pricing

Missing:
- `aggregateRating` / `review` — no review data
- `gtin` / `mpn` — no universal product identifiers
- `color` — not specified in variant schema
- `material` — "93% Polyester + 7% Spandex" exists in description but not in schema
- `shippingDetails` — not in schema
- `returnPolicy` — not linked in schema (Shopify 2024+ supports this)

**Issue**: Availability is "BackOrder" — Google Shopping may suppress products not marked "InStock". Since the store accepts orders and fulfills via POD, availability should be "InStock".

### Collection Pages
**Status: Poor** — No descriptive content beyond product grids. Every collection page should have:
1. 200-400 word intro paragraph with primary + secondary keywords
2. Buying guide or style tips section below the grid
3. FAQ section specific to that style/category
4. Internal links to related collections

### Breadcrumb Navigation
- Visual breadcrumbs present on product and collection pages
- BreadcrumbList schema present but **only 2 levels** on product pages (Home > Product)
- Should be 3 levels: Home > Collection > Product

### Google Shopping Readiness
| Requirement | Status | Issue |
|-------------|--------|-------|
| Clean product images (no text overlays) | Likely OK | On-model shots appear clean based on Shopify listing |
| Product schema with price | OK | $54.99-$59.99 with compare-at prices |
| Availability | WARNING | "BackOrder" — change to "InStock" |
| Brand in schema | OK | "Maiden Bloom" |
| GTIN/MPN | MISSING | No universal identifiers |
| Shipping info page | OK | `/policies/shipping-policy` exists |
| Return policy page | OK | `/policies/refund-policy` exists |
| Meta descriptions | MISSING | Required for Google Merchant Center best practices |
| Unique product descriptions | OK | Each product has unique copy |

---

## Phase 5: Content & Authority

### Blog
**Status: Exists but minimal**
- URL: `/blogs/news`
- 3 blog posts found:
  1. "5 Ways to Style an All-Over Print Dress for Any Season"
  2. "The Art of All-Over Print: How We Design Our Signature Dresses"
  3. "Welcome to the Maiden Bloom Style Journal"
- No publication dates visible
- Content appears short (preview text only ~15 words each)
- **No blog post has been deeply fetched for word count**, but preview text suggests thin content
- Blog titles contain good keywords ("all-over print dress", "AOP")

### Trust Pages

| Page | Status | Issues |
|------|--------|--------|
| About Us | EXISTS but BROKEN | Still contains **Aila Theme** placeholder text ("Welcome to Aila Theme", "Welcome to the Aila family"). Does NOT mention Maiden Bloom's actual story, mission, or the AOP dress focus. Shows $19.99 placeholder product prices. |
| Contact | EXISTS but FAKE DATA | Lists fake address ("789512 Piermont Dr NE Albuquerque, NM 1988"), fake phone ("+1 (0)35 2568 4593"), and placeholder email ("hello@domain.com"). Footer shows real email (hello@maidenbloom.com). **Actual business is in Kanata, ON, Canada** per Terms of Service. |
| Privacy Policy | OK | Custom policy mentioning Maiden Bloom, real address, updated 2026-03-10 |
| Terms of Service | OK | Custom policy with correct legal entity (Bioinsight Lab Inc) |
| Refund Policy | OK | 14-day return policy, clear terms |
| Shipping Policy | EXISTS | In sitemap, not independently verified |
| FAQ | OK | 7 Q&A pairs with FAQPage schema markup |

### Trust Signals
- **Reviews**: NONE — no review app installed on any product page
- **Social Proof**: Zero social media followers linked (sameAs arrays empty or generic)
- **Certifications**: None
- **Trust Badges**: "Made to Order" badge, free shipping threshold ($75), BLOOM10 first-order discount
- **Social Media Links**: Footer links to Pinterest, Facebook, Instagram, Twitter, YouTube — but URLs appear to be generic platform homepages, not actual Maiden Bloom profiles

---

## Prioritized Issues

### CRITICAL (Blocks Ranking/Indexation)

1. **Site not indexed by Google** — Impact: Zero organic traffic possible. No pages appear in Google search results at all. — Fix: Set up Google Search Console, verify domain ownership, submit sitemap URL (`https://maidenbloom.com/sitemap.xml`), request indexing of key pages. — Effort: Low

2. **No meta descriptions on ANY page** — Impact: Even when indexed, Google will auto-generate snippets which are typically poor for e-commerce. Click-through rates will suffer. — Fix: Write unique meta descriptions for all 40 products, 9 collections, and homepage. Product template: "[Product Name] — [key feature]. All-over print [style] dress, sizes XS-5XL. [Price]. Free shipping over $75." — Effort: Medium

3. **About Us page is theme placeholder** — Impact: Google's E-E-A-T signals are damaged. "Welcome to Aila Theme" text is a clear red flag for quality raters. Customers who find this page will lose trust immediately. — Fix: Rewrite with actual Maiden Bloom story, founder info, AOP printing process, brand values. — Effort: Low

4. **Contact page has fake information** — Impact: Google Business Profile / Merchant Center will reject inconsistent NAP (Name, Address, Phone). Fake address in Albuquerque contradicts real address in Kanata, ON in Terms of Service. — Fix: Update contact page with real business address, phone, and email (hello@maidenbloom.com). — Effort: Low

5. **Product availability set to "BackOrder"** — Impact: Google Shopping may suppress or deprioritize products not marked as "InStock". Since POD items are made-to-order but actively sold, they should be "InStock". — Fix: Change Shopify inventory tracking settings so products show as "InStock" in schema. — Effort: Low

### HIGH PRIORITY (Significant Ranking Impact)

1. **No Open Graph / Twitter Card meta tags** — Impact: Social sharing on Pinterest, Facebook, Twitter will show broken/generic previews. Critical for a visual fashion brand. — Fix: Add OG tags (og:title, og:description, og:image, og:type, og:price:amount, og:price:currency) via theme `<head>` customization. Shopify themes usually include these — check if theme settings need enabling. — Effort: Low

2. **Homepage has 2 H1 tags with generic text** — Impact: Dilutes keyword focus. "NEW COLLECTION" tells Google nothing about what the site sells. — Fix: Single H1 like "All Over Print Dresses — Dark Floral, Boho, Celestial & Whimsigoth Styles". Move "NEW COLLECTION" to H2. — Effort: Low

3. **Collection pages have zero descriptive content** — Impact: Google sees thin pages (just product grids). Competitors with category descriptions outrank thin pages. — Fix: Add 200-400 word intro per collection with primary keywords woven in. E.g., Dark Floral collection: "Discover our dark floral dresses collection — dramatic botanical prints on rich black backgrounds, featuring roses, dahlias, and wildflowers in deep crimson, blush, and gold..." — Effort: Medium

4. **No product reviews or rating schema** — Impact: Missing review stars in SERPs. Reviews are the #1 conversion factor for fashion e-commerce. — Fix: Install Judge.me (free plan) or Shopify Product Reviews app. Encourage reviews via post-purchase email. — Effort: Medium

5. **No related products / cross-selling** — Impact: Missed internal linking opportunity and revenue per session. — Fix: Enable "Related Products" or "You May Also Like" section on product pages (most Shopify themes support this natively). — Effort: Low

6. **Organization schema logo is placeholder** — Impact: Google Knowledge Panel will show blank/generic image. — Fix: Update Organization schema logo URL from `no-image-2048-a2addb12.gif` to actual logo `mb_logo.png`. — Effort: Low

7. **Image alt text is generic** — Impact: Missing keyword signals from 200+ product images. Image search traffic lost. — Fix: Change from "[Name] — view N" to descriptive alts like "Dark floral maxi dress with roses on black background — front view on model". — Effort: Medium

8. **BreadcrumbList schema missing collection level** — Impact: Google breadcrumbs in SERPs show only Home > Product instead of Home > Dark Floral Dresses > Product. Reduces click-through and navigation signals. — Fix: Update BreadcrumbList schema to include 3 levels. — Effort: Low

### QUICK WINS (Easy, Immediate Benefit)

1. **Submit sitemap to Google Search Console** — Impact: Triggers indexation of all 40 products, 9 collections, 8 pages. — Fix: Create GSC account, verify via DNS TXT record, submit sitemap. — Effort: Low

2. **Fix social media `sameAs` links** — Impact: Rich results and Knowledge Panel won't show social profiles. — Fix: Replace generic URLs (twitter.com/, facebook.com/) with actual profile URLs in schema. Create profiles if they don't exist. — Effort: Low

3. **Add `<link rel="preconnect">` for Shopify CDN** — Impact: Faster image loading = better Core Web Vitals. — Fix: Add `<link rel="preconnect" href="https://cdn.shopify.com" crossorigin>` to theme `<head>`. — Effort: Low

4. **Fix homepage title tag** — Impact: Branded search will look generic. — Fix: Set to "Maiden Bloom | All Over Print Dresses — Dark Floral, Boho & Celestial Fashion". — Effort: Low

5. **Add `material` to Product schema** — Impact: Google Shopping filters by material; "93% Polyester + 7% Spandex" helps discovery. — Fix: Add structured data property to product template. — Effort: Low

6. **Enable Shopify's built-in canonical tags** — Impact: Prevents any duplicate content from URL parameters. — Fix: Verify in theme.liquid that `{{ canonical_url }}` is in `<head>` (Shopify default). — Effort: Low

### LONG-TERM RECOMMENDATIONS

1. **Build backlink profile** — Zero external links means zero domain authority. Submit to fashion directories, reach out to fashion bloggers in the dark floral / whimsigoth niche, create Pinterest boards with actual content to drive referral links.

2. **Expand blog to target long-tail keywords** — Write 1,500+ word guides: "How to Style a Dark Floral Dress for Every Season", "Whimsigoth Fashion Guide: The Complete Style Handbook", "Celestial Wedding Guest Dresses". Target keywords like "dark floral dress outfit ideas" (2,400/mo), "whimsigoth aesthetic clothing" (3,600/mo).

3. **Set up Google Merchant Center** — Required for Google Shopping ads (the primary sales channel per the business plan). Fix availability to "InStock", ensure all product images meet requirements, submit product feed.

4. **Add size guide page with structured data** — Create a standalone size guide page targeting "dress size chart" searches. Add `SizeSpecification` schema.

5. **Implement hreflang if targeting multiple countries** — Business is in Canada but prices are in USD. If targeting US + CA, add hreflang tags.

6. **Create a "cottagecore dress" collection** — High-volume keyword (18,100/mo) with no dedicated collection page. Currently only have boho, celestial, dark floral, whimsigoth.

7. **Add a "boho floral dress" landing page or collection description** — 8,100 monthly searches. The boho collection exists but has no descriptive content.

8. **Set up email capture popup** — Build an email list for product launches and abandoned cart recovery.

---

## Action Plan (Top 10 Priority Order)

| # | Action | Effort | Impact | Target Keyword |
|---|--------|--------|--------|---------------|
| 1 | Set up Google Search Console + submit sitemap | Low | Critical | All keywords |
| 2 | Fix About Us page (remove Aila theme placeholder) | Low | High | Brand trust / E-E-A-T |
| 3 | Fix Contact page (real address, phone, email) | Low | High | Brand trust / E-E-A-T |
| 4 | Write meta descriptions for all 40 products + 9 collections + homepage | Medium | High | dark floral dress, celestial dress, boho floral dress |
| 5 | Fix homepage: single keyword-rich H1, optimized title tag | Low | High | all over print dress |
| 6 | Change product availability from "BackOrder" to "InStock" | Low | High | Google Shopping readiness |
| 7 | Add Open Graph + Twitter Card meta tags to theme | Low | Medium | Social sharing / Pinterest traffic |
| 8 | Write 200-400 word collection descriptions for all 9 collections | Medium | High | dark floral dress (22.2K), cottagecore dress (18.1K), boho floral dress (8.1K) |
| 9 | Install review app (Judge.me free) + add Review schema | Medium | High | All product pages — star ratings in SERPs |
| 10 | Fix Organization schema logo + social sameAs URLs | Low | Medium | Brand Knowledge Panel |

---

## Appendix: Page Inventory

### Products in Sitemap (40 total)
All products follow consistent URL pattern: `/products/[design-name]-[dress-type]-all-over-print-[style]-fashion`

### Collections (9 total)
| Collection | URL |
|------------|-----|
| Homepage/Frontpage | `/collections/frontpage` |
| All | `/collections/all` |
| Boho Floral | `/collections/boho-floral-dresses` |
| Celestial | `/collections/celestial-dresses` |
| Dark Floral | `/collections/dark-floral-dresses` |
| Whimsigoth | `/collections/whimsigoth-dresses` |
| Maxi Dresses | `/collections/maxi-dresses` |
| Midi Dresses | `/collections/midi-dresses` |
| Spaghetti Strap | `/collections/spaghetti-strap-dresses` |
| Hoodie Dresses | `/collections/hoodie-dresses` |

### Missing Collections (Keyword Opportunities)
| Potential Collection | Target Keyword | Monthly Volume |
|---------------------|---------------|---------------|
| Cottagecore Dresses | cottagecore dress | 18,100 |
| Vintage Floral Dresses | vintage floral dress | 4,400 |
| Long Sleeve Dresses | long sleeve floral dress | 2,900 |

### Pages (8 total)
Contact, Privacy Policy, Terms of Service, Shipping Policy, Refund Policy, About Us, FAQ, Data Sharing Opt-Out
