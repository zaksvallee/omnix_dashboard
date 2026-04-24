import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const DECAY_START_MINUTES = 0   // FORCE IMMEDIATE DECAY
const DECAY_RATE = 5
const CLOSE_THRESHOLD = 30

serve(async () => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    const { data: watches, error } = await supabase
      .from("watch_current_state")
      .select("*")

    if (error) throw error
    if (!watches || watches.length === 0) {
      return new Response(JSON.stringify({ processed: 0 }))
    }

    let processed = 0

    for (const watch of watches) {

      const now = new Date()
      const lastUpdate = new Date(watch.updated_at)
      const minutesInactive =
        (now.getTime() - lastUpdate.getTime()) / 60000

      if (minutesInactive < DECAY_START_MINUTES) continue

      const newRisk = Math.max(
        Number(watch.risk_score) - DECAY_RATE,
        0
      )

      const newConfidence = Math.max(
        Number(watch.confidence) - 0.05,
        0
      )

      if (newRisk <= CLOSE_THRESHOLD) {

        // Emit WATCH_CLOSED
        await supabase.from("dispatch_actions").insert({
          id: crypto.randomUUID(),
          action_type: "WATCH_CLOSED",
          status: "DECIDED",
          risk_score: newRisk,
          confidence: newConfidence,
          geo_lat: watch.geo_lat,
          geo_lng: watch.geo_lng,
          source: "decay_engine",
          decision_trace: {
            reason: "Risk fell below threshold",
            minutes_inactive: minutesInactive
          },
          dcw_seconds: 0,
          decided_at: new Date().toISOString()
        })

        const lifecycleMinutes =
          (now.getTime() - new Date(watch.updated_at).getTime()) / 60000

        // Archive
        await supabase.from("watch_archive").insert({
          id: watch.id,
          geo_lat: watch.geo_lat,
          geo_lng: watch.geo_lng,
          peak_cluster_size: watch.peak_cluster_size || watch.cluster_size,
          peak_risk_score: watch.peak_risk_score || watch.risk_score,
          peak_confidence: watch.peak_confidence || watch.confidence,
          total_lifecycle_minutes: Math.round(lifecycleMinutes),
          closed_at: new Date().toISOString()
        })

        // Remove projection
        await supabase
          .from("watch_current_state")
          .delete()
          .eq("id", watch.id)

      } else {

        // Emit WATCH_DECAYED
        await supabase.from("dispatch_actions").insert({
          id: crypto.randomUUID(),
          action_type: "WATCH_DECAYED",
          status: "DECIDED",
          risk_score: newRisk,
          confidence: newConfidence,
          geo_lat: watch.geo_lat,
          geo_lng: watch.geo_lng,
          source: "decay_engine",
          decision_trace: {
            reason: "Gradual inactivity decay",
            minutes_inactive: minutesInactive
          },
          dcw_seconds: 0,
          decided_at: new Date().toISOString()
        })

        await supabase
          .from("watch_current_state")
          .update({
            risk_score: newRisk,
            confidence: newConfidence,
            last_event_type: "WATCH_DECAYED",
            updated_at: new Date().toISOString()
          })
          .eq("id", watch.id)
      }

      processed++
    }

    return new Response(JSON.stringify({ processed }))

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})