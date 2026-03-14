 Vercel as the Agent Runtime, Supabase as Data Layer
Since your frontend is already on Vercel, use Vercel serverless functions (or Vercel AI SDK's streaming) as the agent runtime instead of Edge Functions. 
Vercel Pro plan gives you 300-second function timeout, and their AI SDK is designed for long-running AI operations with streaming.
Chat UI → Vercel API Route (agent logic, up to 300 sec) → Supabase DB
                         ↓
              Claude API / Image Gen / Printify API calls
                         ↓
              Stream progress back to chat via AI SDK
Supabase still handles the database, auth, storage, and realtime subscriptions. But the orchestration logic lives in Vercel.
Pros: Vercel AI SDK is purpose-built for this — streaming responses, tool calling, long-running AI operations. 300-second timeout handles most agent steps. 
Single deployment target (Vercel) for all logic. You're already using Vercel for the frontend. Great DX with Next.js API routes.
Cons: 300 seconds still isn't infinite — image generation + processing could still timeout on complex operations. Vercel serverless has cold starts. 
Costs scale with execution time. You lose the "everything in Supabase" simplicity. Edge Functions still useful for webhooks and Printify callbacks.
My take: This is probably your sweet spot for the MVP. You get the long timeouts, the AI SDK integration, and you don't need to manage a separate worker process. 
Use Supabase Edge Functions only for things they're good at: webhooks, cron jobs, and lightweight data operations.