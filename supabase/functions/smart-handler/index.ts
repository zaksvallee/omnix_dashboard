import { serve } from "https://deno.land/std/http/server.ts"

serve(async () => {
  const NEWS_API_KEY = Deno.env.get("NEWS_API_KEY")
  const NEWSDATA_KEY = Deno.env.get("NEWSDATA_KEY")

  const results: any[] = []

  // --- NEWSAPI.ORG ---
  if (NEWS_API_KEY) {
    const res = await fetch(
      `https://newsapi.org/v2/everything?q=war OR protest OR attack OR unrest&language=en&sortBy=publishedAt&pageSize=50&apiKey=${NEWS_API_KEY}`
    )

    if (res.ok) {
      const data = await res.json()
      for (const article of data.articles ?? []) {
        results.push({
          id: article.url,
          source: "newsapi",
          category: "conflict",
          description: article.title,
          latitude: 0,
          longitude: 0,
          severity: 5,
          event_timestamp: article.publishedAt,
        })
      }
    }
  }

  return new Response(
    JSON.stringify(results),
    { headers: { "Content-Type": "application/json" } }
  )
})