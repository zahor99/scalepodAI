  Verification Guide

  Connection Setup

  - Dashboard: http://localhost:3000 (Next.js dev server)
  - Supabase Studio: http://127.0.0.1:54323 (DB admin UI)
  - Supabase API: http://127.0.0.1:54321 (REST + Realtime)
  - All LOCAL — no cloud dependency

  Step 1: Products Dashboard (empty state)

  URL: http://localhost:3000/products
  - Page loads with "Products" header
  - Shows "0 total products"
  - 8 tabs visible: All, Needs Review, In Progress, Ideas, Concepts, Draft, Published, Failed
  - Empty state message: "No products found" with "Create Product" button
  - "New Product" button in top-right

  Step 2: Create Product Form

  URL: http://localhost:3000/products/new
  - Page loads with "New Product" header and "Design Brief" form
  - Theme textarea with placeholder text (min 5 chars validation)
  - Product Type dropdown shows 2 active products (AOP Hoodie, Gildan Tee)
  - Niche dropdown shows 15 niches with recommendation badges (STRONG_BUY, BUY, WATCH)
  - Style Hint optional text field
  - Try submitting empty form — should show validation errors
  - Fill in: Theme = "Japanese koi fish transforming into dragon", Product Type = AOP Hoodie, Niche = Japanese Art
  - Click "Create Product" — should redirect to product detail page

  Step 3: Product Detail (pending state)

  URL: http://localhost:3000/products/[id] (auto-redirected after creation)
  - Shows spinner with "Waiting for worker to pick up..."
  - Status badge shows "Pending" (gray)
  - Pipeline Progress shows 3 stages (Stage 1 highlighted)
  - Back link to "/products" works

  Step 4: Verify in Supabase Studio

  URL: http://127.0.0.1:54323
  - Navigate to Table Editor > products
  - New row exists with status = "pending", theme filled in, supplier_product_id and niche_guide_id set
  - worker_claimed_at is NULL

  Step 5: Dashboard Updates (back to list)

  URL: http://localhost:3000/products
  - Product appears in the list with status badge "Pending"
  - Appears in "All" and "Ideas" tabs
  - Card shows theme (truncated), niche name, relative time

  Step 6: Realtime Test (via Supabase Studio)

  - In Supabase Studio, manually update the product's status to plan_ready
  - Dashboard list updates WITHOUT page refresh (realtime)
  - Status badge changes to "Plan Ready" (yellow)
  - Product now appears in "Needs Review" tab

  Step 7: Gate 1 — Plan Approval (detail page)

  - Click the product card to go to detail page
  - Yellow card: "Review Design Plan" with "Approve Concept" and "Regenerate" buttons
  - If design_plan is NULL, no plan viewer shown (expected since worker didn't run)
  - Click "Approve Concept" — status changes to concept_approved
  - UI switches to spinner: "Queued for artwork generation..."

  Step 8: Simulate Gate 2 (via Studio)

  - In Studio, set status = mockups_ready
  - Detail page shows yellow card: "Review Artwork & Mockups"
  - "Approve for Production" and "Reject" buttons visible
  - Artwork galleries show "No images available yet" (expected — no actual images)

  Step 9: Test Failed State

  - In Studio, set status = failed, worker_error = "Test error message"
  - Detail page shows red card: "Pipeline Failed"
  - Error message "Test error message" displayed
  - "Retry" button works — sets status back to appropriate stage

  Step 10: Full Worker Integration (optional — costs API credits)

  # Terminal 2: Start the Python worker
  cd C:\Users\Owner\Documents\EtsyAutomation\prototype
  python worker.py
  - Worker picks up the pending product
  - Dashboard shows live status transitions via realtime
  - Activity log feed updates with worker progress messages

  ---
  What's NOT tested yet (requires worker running with API keys):

  - Actual design plan generation (needs Kimi API key)
  - Real artwork in galleries (needs Gemini API key)
  - Printify mockup display (needs Printify API key)
  - Supabase Storage image URLs in galleries
