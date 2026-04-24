import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const RADIUS_METERS = 500
const MIN_CLUSTER_SIZE = 2
const WINDOW_MINUTES = 30

function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371000
  const toRad = (deg: number) => deg * (Math.PI / 180)

  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const cutoff = new Date(Date.now() - WINDOW_MINUTES * 60000).toISOString()

    const { data: signals, error } = await supabase
      .from("external_signals")
      .select("*")
      .gte("created_at", cutoff)

    if (error) throw error
    if (!signals || signals.length < MIN_CLUSTER_SIZE) {
      return new Response(JSON.stringify({ clustered: false }))
    }

    for (let i = 0; i < signals.length; i++) {
      const cluster = [signals[i]]

      for (let j = 0; j < signals.length; j++) {
        if (i === j) continue

        const dist = haversineDistance(
          signals[i].geo_lat,
          signals[i].geo_lng,
          signals[j].geo_lat,
          signals[j].geo_lng
        )

        if (dist <= RADIUS_METERS) {
          cluster.push(signals[j])
        }
      }

      if (cluster.length >= MIN_CLUSTER_SIZE) {

        const { data: activeWatches } = await supabase
          .from("watch_current_state")
          .select("*")

        let existingWatch = null

        if (activeWatches) {
          for (const watch of activeWatches) {
            const dist = haversineDistance(
              watch.geo_lat,
              watch.geo_lng,
              signals[i].geo_lat,
              signals[i].geo_lng
            )
            if (dist <= RADIUS_METERS) {
              existingWatch = watch
              break
            }
          }
        }

        const riskScore = 40 + cluster.length * 5
        const confidence = Math.min(0.5 + cluster.length * 0.1, 0.95)

        if (!existingWatch) {

          const newId = crypto.randomUUID()

          await supabase.from("dispatch_actions").insert({
            id: newId,
            action_type: "WATCH_PROMOTION",
            status: "DECIDED",
            risk_score: riskScore,
            confidence: confidence,
            geo_lat: signals[i].geo_lat,
            geo_lng: signals[i].geo_lng,
            source: "correlation_engine",
            decision_trace: {
              reason: "Initial geo-density cluster detected",
              cluster_size: cluster.length
            },
            metadata: {
              signal_ids: cluster.map(s => s.id)
            },
            dcw_seconds: 15,
            decided_at: new Date().toISOString()
          })

          await supabase.from("watch_current_state").insert({
            id: newId,
            geo_lat: signals[i].geo_lat,
            geo_lng: signals[i].geo_lng,
            cluster_size: cluster.length,
            risk_score: riskScore,
            confidence: confidence,
            last_event_type: "WATCH_PROMOTION",
            updated_at: new Date().toISOString()
          })

        } else {

          await supabase.from("dispatch_actions").insert({
            id: crypto.randomUUID(),
            action_type: "WATCH_STRENGTHENED",
            status: "DECIDED",
            risk_score: riskScore,
            confidence: confidence,
            geo_lat: existingWatch.geo_lat,
            geo_lng: existingWatch.geo_lng,
            source: "correlation_engine",
            decision_trace: {
              reason: "Cluster strengthened",
              cluster_size: cluster.length
            },
            metadata: {
              signal_ids: cluster.map(s => s.id)
            },
            dcw_seconds: 10,
            decided_at: new Date().toISOString()
          })

          await supabase
            .from("watch_current_state")
            .update({
              cluster_size: cluster.length,
              risk_score: riskScore,
              confidence: confidence,
              last_event_type: "WATCH_STRENGTHENED",
              updated_at: new Date().toISOString()
            })
            .eq("id", existingWatch.id)
        }

        return new Response(JSON.stringify({ clustered: true }))
      }
    }

    return new Response(JSON.stringify({ clustered: false }))

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})