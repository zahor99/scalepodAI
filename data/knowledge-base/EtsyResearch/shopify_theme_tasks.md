# Aila Theme Customization — Task Tracker

**Store:** q2chc0-wp.myshopify.com (Maiden Bloom)
**Theme:** ailatheme (ID: 137859661918)
**Company:** Maiden Bloom, owned by Bioinsight Lab Inc
**Address:** 226 Halyard Way, K2T 0L3, Kanata, Ontario, Canada
**Started:** 2026-03-08

## Compliance Notes
- **Google Shopping**: Requires clear return/refund policy, shipping info, business contact, privacy policy, accurate pricing (compare-at must be genuine), no misleading claims
- **Meta Ads**: Requires privacy policy, terms of service, functional checkout, no deceptive content, landing pages must match ad content
- **Both require**: SSL (Shopify provides), working contact info, clear pricing, product availability accuracy

## Deviations from Plan
| # | Deviation | Reason |
|---|-----------|--------|
| 1 | Editing theme via Admin API instead of Shopify CLI local dev | Store is live, no local dev server needed per user request |
| 2 | Policy pages use real Bioinsight Lab Inc legal entity | Google Shopping requires legitimate business info |
| 3 | Added Google Shopping compliance checks | User needs smooth approval tomorrow |
| 4 | Skipping product upload tasks | Another agent is handling product loading |
| 5 | Color palette applied via `custom-style.css` not `custom.css` | `custom.css` is a compiled Shopify asset; `custom-style.css` is the writable override file in Aila |
| 6 | Image zoom: added hover lens alongside existing PhotoSwipe lightbox | Plan said "add zoom" but theme already had click-to-lightbox; added hover magnifier for AOP detail inspection |
| 7 | Collection filters: CSS-only (no Liquid changes) | Aila already has a full dual-mode filter system built in; just needed enabling + styling |
| 8 | Blog template: fixed existing schema bug | Plan said "create blog template" but Aila already had a full blog; fixed `@type` from Article→BlogPosting and broken `page.url` reference |

---

## Priority 1: Critical (Must-Have for Launch) — ALL DONE ✅

- [x] **T1. Product Schema (JSON-LD)** — `snippets/structured-data-product.liquid`
- [x] **T2. Organization Schema (JSON-LD)** — `snippets/structured-data-org.liquid`
- [x] **T3. SEO Meta Templates** — `snippets/seo-meta-enhanced.liquid`
- [x] **T4. Fabric & Care Tabs** — `snippets/product-tabs-custom.liquid`
- [x] **T5. Size Chart Modal** — `snippets/size-chart-modal.liquid`
- [x] **T6. Color Palette Override** — `assets/custom-style.css`
- [x] **T7. Typography Update** — `layout/theme.liquid` + `assets/custom-style.css`

## Priority 2: High (Pre-Launch) — ALL DONE ✅

- [x] **T8. Privacy Policy Page** — Page ID: 105088221278, handle: `privacy-policy`
- [x] **T9. Terms of Service Page** — Page ID: 105088254046, handle: `terms-of-service`
- [x] **T10. Shipping Policy Page** — Page ID: 105088286814, handle: `shipping-policy`
- [x] **T11. Return/Refund Policy Page** — Page ID: 105088319582, handle: `refund-policy`
- [x] **T12. Contact Information Page** — Page ID: 105034285150, handle: `contact`
- [x] **T13. Image Zoom on Hover** — `snippets/image-zoom-hover.liquid` (cursor-following 2.5x lens, desktop only)
- [x] **T14. Collection Page Filters** — CSS skin in `custom-style.css` (Aila has built-in filter system, needs enabling)
- [x] **T15. FAQ Page with Schema** — `snippets/faq-schema.liquid` + `sections/page-faqs.liquid` + Page ID: 105090580574
- [x] **T16. About Page** — `sections/page-about-us.liquid` + Page ID: 105090547806
- [x] **T17. Blog Template** — `snippets/article-schema.liquid` (fixed BlogPosting schema, blog was already functional)

## Priority 3: Nice-to-Have (Post-Launch)

- [ ] **T18. Lookbook Section** — `sections/lookbook.liquid`
- [ ] **T19. "Complete the Look" Cross-sell** — `sections/main-product.liquid`
- [ ] **T20. Announcement Bar Rotation** — `sections/announcement.liquid`
- [ ] **T21. Email Capture Popup** — `snippets/email-popup.liquid`
- [ ] **T22. Performance Optimization** — lazy-load, defer JS, preload fonts

## Manual Steps Required (User Action)

- [x] **M1. Policy pages in footer** — DONE via footer-group.json update
  - "Policies" column with 7 links: Privacy, Terms, Shipping, Refund, Contact, About, FAQ
  - Address added under logo: "226 Halyard Way, Kanata, Ontario K2T 0L3, Canada"
- [ ] **M2. Update contact email** — Currently `support@maidenbloom.com` (confirm or update)
- [ ] **M3. Verify checkout flow** — Place a test order to confirm payment + shipping
- [ ] **M4. Submit sitemap to Google Search Console** — `q2chc0-wp.myshopify.com/sitemap.xml`
- [ ] **M5. Enable collection filters**
  - Online Store > Customize > Collection page > "Product listing" section
  - Toggle "Enable filtering" ON, set to "Storefront filters", position "Left sidebar"
  - Go to Navigation > "Collection and search filters" and add: Product Type, Size, Price
- [ ] **M6. Add social links** — Theme editor > Footer > add Instagram, Pinterest, TikTok URLs

## Google Shopping Readiness Checklist

- [x] SSL certificate (Shopify auto-provides)
- [ ] Accurate product data — *products loading via another agent*
- [ ] Compare-at pricing reflects genuine previous price
- [x] Product structured data (JSON-LD) on all product pages
- [x] Organization structured data on homepage
- [x] Privacy policy page created — **needs footer link (M1)**
- [x] Return/refund policy page created — **needs footer link (M1)**
- [x] Shipping info page created — **needs footer link (M1)**
- [x] Contact info page created — **needs footer link (M1)**
- [x] Terms of service page created — **needs footer link (M1)**
- [x] Business name and address on site
- [ ] Working checkout flow — **user to verify (M3)**
- [x] No prohibited content
- [ ] Product images meet Google specs — *products loading*
- [x] FAQ page with structured data
- [x] BlogPosting schema for content marketing

## Meta Ads Readiness Checklist

- [x] Privacy policy page
- [x] Terms of service page
- [ ] Functional website with working links — **user to verify**
- [ ] Clear product pricing — *products loading*
- [x] Contact information
- [x] No deceptive or misleading content
- [x] Meta/Open Graph tags on all pages
- [x] Twitter Card tags on product/collection pages

## Theme Assets Pushed (Summary)

| Asset Key | Type | Purpose |
|-----------|------|---------|
| `snippets/structured-data-product.liquid` | New | Product + Offer + BreadcrumbList JSON-LD |
| `snippets/structured-data-org.liquid` | New | Organization JSON-LD (homepage) |
| `snippets/seo-meta-enhanced.liquid` | New | Enhanced OG/Twitter/canonical meta tags |
| `snippets/product-tabs-custom.liquid` | New | Fabric/Care/Sizing/Shipping accordion |
| `snippets/size-chart-modal.liquid` | New | Size chart popup with cm/inch toggle |
| `snippets/image-zoom-hover.liquid` | New | Cursor-following hover magnifier |
| `snippets/faq-schema.liquid` | New | FAQPage JSON-LD structured data |
| `snippets/article-schema.liquid` | New | BlogPosting JSON-LD structured data |
| `assets/custom-style.css` | Modified | Boho palette + typography + filter styling |
| `layout/theme.liquid` | Modified | Google Fonts + render calls for new snippets |
| `sections/main-product.liquid` | Modified | Added tabs, size chart, zoom renders |
| `sections/page-faqs.liquid` | Modified | Added schema + default FAQ content |
| `sections/page-about-us.liquid` | Modified | Full brand story section |
| `sections/article.liquid` | Modified | Replaced inline schema with snippet |

## Shopify Pages Created

| Page | ID | Handle | URL |
|------|-----|--------|-----|
| Privacy Policy | 105088221278 | privacy-policy | `/pages/privacy-policy` |
| Terms of Service | 105088254046 | terms-of-service | `/pages/terms-of-service` |
| Shipping Policy | 105088286814 | shipping-policy | `/pages/shipping-policy` |
| Return & Refund Policy | 105088319582 | refund-policy | `/pages/refund-policy` |
| Contact Us | 105034285150 | contact | `/pages/contact` |
| About Us | 105090547806 | about-us | `/pages/about-us` |
| FAQ | 105090580574 | faq | `/pages/faq` |
