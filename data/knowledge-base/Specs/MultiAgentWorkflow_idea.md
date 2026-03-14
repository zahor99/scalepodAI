## Agent 1 — Design Analyst (analyze-design)
This is your entry point. It accepts either a text idea ("celestial moon hoodie with mystical vibes") or a competitor image URL/upload, and produces a structured design brief.
What it does: extracts or defines the color palette (hex codes), art style (e.g. vintage Japanese, gothic, minimalist), motifs and elements (moon, stars, skulls), mood/aesthetic, target audience, and the niche category. If given a competitor image, it uses vision to deconstruct the composition — what's working visually, what makes it sell — without copying. If given text, it expands the concept into a detailed creative brief.
Output stored in Supabase designs table: design_brief JSON with all the structured attributes. Status: brief_ready.

Agent 2 — Design Generator (generate-design)
Takes the design brief and produces print-ready artwork. This is where your image generation API lives (Ideogram, Flux, or DALL-E 3).
What it does: converts the design brief into an optimized image generation prompt (this is where your prompt templates from the Tags Reference Library sheet come in), calls the image API, validates the output dimensions meet Printify's requirements (minimum 3000×4000px at 300 DPI for most hoodies), runs multiple generations if needed (typically 3-4 variations), and stores all variants. For front+back designs, it runs two generation passes with coordinated style consistency.
Output: image files stored in Supabase Storage, URLs written to designs table. Status: artwork_ready. The user can review variants at this stage through the dashboard before proceeding — this is your human-in-the-loop checkpoint.

Agent 3 — Copy Writer (generate-copy)
Takes the design brief + selected artwork and generates all the listing text content.
What it does: generates an SEO-optimized title (140 characters, front-loaded with keywords following the pattern we saw from ISHIRTLAB: "Celestial Moon Sweatshirt | Mystical Night Sky Hoodie | Boho Celestial Gift"), a structured description (keyword-rich opening paragraph, How to Order section, Product Details, Shipping Info, Care Instructions, Returns — mirroring the top sellers' format), and exactly 13 tags (3 broad + 5 medium-tail + 5 long-tail, each under 20 characters). It uses the keyword research data from your Supabase prompts table to pick high-volume, low-competition terms.
Output: products table gets title, description, tags JSON array. Status: copy_ready.

Agent 4 — Pricing Calculator (calculate-pricing)
Takes the product type, niche, and supplier costs to determine optimal pricing.
What it does: pulls the supplier base cost from your suppliers table (e.g. Gildan 18500 at $15.64), applies the Etsy fee stack (6.5% transaction + 3% + $0.25 payment + $0.20 listing + potential 15% offsite ads), calculates shipping costs, applies your margin target from pricing_rules, and implements the perpetual 50% sale strategy (list at 2× target, run permanent "sale"). It also does a competitive price check against the niche average from your market research data.
Output: products table gets base_price, sale_price, margin_pct, fee_breakdown JSON. Status: priced.

Agent 5 — Printify Product Creator (printify-create)
This is your first external API agent. It creates the actual product on Printify.
What it does: selects the blueprint ID (e.g. Gildan 18500 = blueprint 77) and print provider from your suppliers table, uploads the design image to Printify, maps it to the correct print area (front, back, or both), sets up all color variants (the top sellers offer 15+ colors — you'd configure which colors per niche), sets the pricing per variant, and creates the product via Printify's REST API. Rate limit: stay under 200 requests per 30 minutes.
Output: products table gets printify_product_id, printify_blueprint_id. Status: printify_created.

Agent 6 — Mockup Generator (generate-mockups)
Uses Printify's built-in mockup generation for quick prototype images.
What it does: calls Printify's mockup endpoint for the created product, generates flat-lay and basic lifestyle mockups across 3-4 key colors, downloads and stores these in Supabase Storage. These are your "prototype" images — good enough for internal review and the basic listing, but not the final product photos.
Output: mockup URLs stored in designs table mockup_urls JSON array. Status: mockups_ready. This is another natural review checkpoint in your dashboard.

Agent 7 — Image Producer (produce-images)
This is your NanoBanan Pro integration for professional product photography.
What it does: takes the design artwork and feeds it into NanoBanan Pro to generate the full 10-image set we defined in the Image Strategy sheet — hero flat lay with styled background, lifestyle scene (person wearing it or styled on furniture), alternative colorways, design detail closeup, size chart overlay, color grid showing all variants, model/mannequin shot, back view, gift-wrapped context, and trust/quality infographic. Each image type gets a specific NanoBanan Pro prompt optimized for that shot type. This replaces the Printify mockups as the primary listing images.
Output: professional image URLs stored in Supabase Storage, linked in products table image_urls JSON. Status: images_ready.

Agent 8 — Publisher (publish-to-etsy)
The final agent that pushes everything live.
What it does: calls Printify's publish endpoint to push the product to your connected Etsy shop, then makes direct Etsy API calls (OAuth 2.0) to update the tags (Printify's tag support is limited), set the correct Etsy taxonomy/category, upload the NanoBanan Pro images (replacing Printify's default mockups), set shipping profiles, and apply the sale pricing. It also logs the final listing URL and all metadata to workflow_logs.
Output: products table gets etsy_listing_id, etsy_url, published_at. Status: published.

Data Flow Through Supabase
Each agent reads from and writes to the same products row (plus related tables). The status field acts as the state machine:
brief_ready → artwork_ready → copy_ready → priced → printify_created → mockups_ready → images_ready → published
Your Edge Function orchestrator checks the current status and triggers the next agent. If any agent fails, the status stays put and the error goes into workflow_logs for debugging.
Vercel AI SDK Integration
On the frontend side, your chat interface uses the Vercel AI SDK's useChat hook talking to a route handler that calls the chat-orchestrator Edge Function. The orchestrator parses user intent ("create a celestial hoodie in the gothic niche") and kicks off Agent 1, then each subsequent agent is triggered either automatically (for the full pipeline) or on user approval at the checkpoint stages (after Agents 2 and 6).
What I'd Build First
For your MVP, I'd suggest agents 1, 3, 4, 5, and 8 — skipping NanoBanan Pro initially and using Printify mockups as your images. That gets products live fastest. Then layer in Agent 2 (AI design generation), Agent 6 (Printify mockups as separate step), and Agent 7 (NanoBanan Pro) as upgrades.
Want me to start building any of these agents, or should I spec out the Supabase schema and Edge Function signatures first?