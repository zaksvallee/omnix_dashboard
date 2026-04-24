import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const NEWS_API_KEY = Deno.env.get("NEWSAPI_AI_KEY");

serve(async () => {
  try {
    if (!NEWS_API_KEY) {
      return new Response("Missing NEWSAPI_AI_KEY secret", { status: 500 });
    }

    const response = await fetch("https://eventregistry.org/api/v1/article/getArticles", {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        query: {
          $query: {
            lang: "eng",
            dateStart: "2026-01-01",
            keyword: "violence"
          }
        },
        resultType: "articles",
        articlesCount: 50,
        apiKey: NEWS_API_KEY
      })
    });

    if (!response.ok) {
      return new Response(`NewsAPI fetch failed: ${response.status}`, { status: 500 });
    }

    const data = await response.json();

    if (!data.articles?.results) {
      return new Response("No articles returned", { status: 200 });
    }

    let inserted = 0;

    for (const article of data.articles.results) {
      const lat = article.location?.lat ?? 0;
      const lon = article.location?.long ?? 0;

      const { error } = await supabase
        .from("global_events")
        .upsert({
          id: article.uri,
          source_id: "newsapi_ai",
          source_trust_score: 85,
          country: article.source?.location?.country ?? null,
          continent: null,
          subregion: null,
          latitude: lat,
          longitude: lon,
          category: "media",
          cameo_code: null,
          goldstein_scale: null,
          event_tone: null,
          global_severity: 50,
          confidence_score: 85,
          correlation_group: article.uri,
          occurred_at: article.dateTime,
          ingested_at: new Date().toISOString(),
          raw_payload: article
        });

      if (error) {
        return new Response(`Insert error: ${error.message}`, { status: 500 });
      }

      inserted++;
    }

    return new Response(`Inserted ${inserted} articles`, { status: 200 });

  } catch (err) {
    return new Response(`Fatal error: ${err}`, { status: 500 });
  }
});