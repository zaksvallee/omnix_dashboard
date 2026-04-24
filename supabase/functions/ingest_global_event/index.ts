import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const NEWSAPI_KEY = Deno.env.get("NEWSAPI_KEY")!
    const NEWSDATA_KEY = Deno.env.get("NEWSDATA_KEY")!
    const NEWSAPI_AI_KEY = Deno.env.get("NEWSAPI_AI_KEY")!

    const events: any[] = []

    // =========================================================
    // FETCH SOURCES
    // =========================================================

    await fetchNewsApiOrg()
    await fetchNewsData()
    await fetchNewsApiAi()

    async function fetchNewsApiOrg() {
      const res = await fetch(
        `https://newsapi.org/v2/everything?q=war OR protest OR riot OR attack OR explosion OR unrest&language=en&sortBy=publishedAt&pageSize=50&apiKey=${NEWSAPI_KEY}`
      )
      if (!res.ok) return
      const json = await res.json()
      for (const a of json.articles ?? []) {
        const n = normalize(a)
        if (n) events.push(n)
      }
    }

    async function fetchNewsData() {
      const res = await fetch(
        `https://newsdata.io/api/1/news?apikey=${NEWSDATA_KEY}&language=en&category=top`
      )
      if (!res.ok) return
      const json = await res.json()
      for (const a of json.results ?? []) {
        const n = normalize(a)
        if (n) events.push(n)
      }
    }

    async function fetchNewsApiAi() {
      const res = await fetch(
        `https://eventregistry.org/api/v1/article/getArticles`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            apiKey: NEWSAPI_AI_KEY,
            query: {
              $query: {
                keyword:
                  "war OR protest OR riot OR attack OR explosion OR unrest"
              }
            },
            articlesPage: 1,
            articlesCount: 50,
            articlesSortBy: "date"
          })
        }
      )
      if (!res.ok) return
      const json = await res.json()
      const articles = json.articles?.results ?? []
      for (const a of articles) {
        const n = normalize(a)
        if (n) events.push(n)
      }
    }

    // =========================================================
    // DEDUP
    // =========================================================

    const unique = new Map()
    for (const e of events) {
      unique.set(e.source_id, e)
    }
    const finalEvents = Array.from(unique.values())

    if (finalEvents.length > 0) {
      const { error } = await supabase
        .from("global_events")
        .upsert(finalEvents, { onConflict: "source_id" })

      if (error) throw error
    }

    // =========================================================
    // REBUILD CLUSTERS
    // =========================================================

    const { data: allEvents } = await supabase
      .from("global_events")
      .select("latitude, longitude, severity")

    if (!allEvents) throw new Error("No events found")

    await supabase.from("global_clusters").delete().neq("id", "")

    const buckets = new Map()

    for (const e of allEvents) {
      if (!e.latitude || !e.longitude) continue

      const latBucket = Math.round(e.latitude / 5) * 5
      const lngBucket = Math.round(e.longitude / 5) * 5
      const key = `${latBucket}_${lngBucket}`

      if (!buckets.has(key)) {
        buckets.set(key, {
          centroid_lat: latBucket,
          centroid_lng: lngBucket,
          events: []
        })
      }

      buckets.get(key).events.push(e)
    }

    const clusters: any[] = []

    for (const bucket of buckets.values()) {
      const count = bucket.events.length
      if (count < 5) continue

      const avgSeverity =
        bucket.events.reduce((sum: number, e: any) => sum + (e.severity || 0), 0) / count

      const clusterScore = count * avgSeverity

      clusters.push({
        centroid_lat: bucket.centroid_lat,
        centroid_lng: bucket.centroid_lng,
        event_count: count,
        avg_severity: avgSeverity,
        cluster_score: clusterScore
      })
    }

    if (clusters.length > 0) {
      const { error } = await supabase
        .from("global_clusters")
        .insert(clusters)

      if (error) throw error
    }

    return new Response(
      JSON.stringify({
        success: true,
        inserted_events: finalEvents.length,
        clusters_created: clusters.length
      }),
      { status: 200 }
    )

  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500 }
    )
  }
})


// =========================================================
// NORMALIZER
// =========================================================

function normalize(article: any) {
  const title =
    article.title?.eng ||
    article.title ||
    ""

  if (!title) return null

  const published =
    article.publishedAt ||
    article.pubDate ||
    article.date ||
    new Date().toISOString()

  const sourceId =
    article.url ||
    article.link ||
    crypto.randomUUID()

  const geo = resolveGeo(title)

  return {
    source_id: sourceId,
    title,
    description: article.description ?? "",
    latitude: geo?.lat ?? null,
    longitude: geo?.lng ?? null,
    severity: estimateSeverity(title),
    published_at: new Date(published).toISOString(),
    created_at: new Date().toISOString()
  }
}


// =========================================================
// EXPANDED GEO RESOLVER
// =========================================================

function resolveGeo(text: string) {
  const lower = text.toLowerCase()

  const locationMap: Record<string, { lat: number, lng: number }> = {
    "israel": { lat: 31.5, lng: 34.8 },
    "gaza": { lat: 31.4, lng: 34.3 },
    "ukraine": { lat: 48.3, lng: 31.2 },
    "kyiv": { lat: 50.4, lng: 30.5 },
    "russia": { lat: 61.5, lng: 105 },
    "moscow": { lat: 55.7, lng: 37.6 },
    "china": { lat: 35.8, lng: 104.1 },
    "beijing": { lat: 39.9, lng: 116.4 },
    "germany": { lat: 51.1, lng: 10.4 },
    "france": { lat: 46.2, lng: 2.2 },
    "italy": { lat: 41.9, lng: 12.5 },
    "usa": { lat: 39.8, lng: -98.5 },
    "united states": { lat: 39.8, lng: -98.5 },
    "india": { lat: 20.6, lng: 78.9 },
    "south africa": { lat: -30.6, lng: 22.9 },
    "johannesburg": { lat: -26.2, lng: 28.0 }
  }

  for (const key in locationMap) {
    if (lower.includes(key)) {
      return locationMap[key]
    }
  }

  return null
}


// =========================================================
// SEVERITY
// =========================================================

function estimateSeverity(text: string) {
  const lower = text.toLowerCase()

  if (lower.includes("war")) return 7
  if (lower.includes("coup")) return 7.5
  if (lower.includes("attack")) return 6
  if (lower.includes("riot")) return 5
  if (lower.includes("explosion")) return 5.5
  if (lower.includes("protest")) return 4
  if (lower.includes("unrest")) return 4.5

  return 3
}