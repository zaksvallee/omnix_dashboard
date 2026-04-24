import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js"

serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const now = new Date()

  const { data: patrols, error: patrolError } = await supabase
    .from("patrols")
    .select("*")
    .eq("is_active", true)

  if (patrolError || !patrols) {
    console.error("Failed to load patrols", patrolError)
    return new Response("Error loading patrols", { status: 500 })
  }

  for (const patrol of patrols) {
    // Find an active guard on site
    const { data: dutyState } = await supabase
      .from("duty_states")
      .select("guard_id")
      .eq("site_id", patrol.site_id)
      .is("exited_at", null)
      .in("state", ["ON_POST", "PATROLLING"])
      .limit(1)
      .single()

    if (!dutyState) continue

    // Last check-in
    const { data: lastCheckin } = await supabase
      .from("checkins")
      .select("created_at")
      .eq("guard_id", dutyState.guard_id)
      .order("created_at", { ascending: false })
      .limit(1)
      .single()

    const lastTime = lastCheckin
      ? new Date(lastCheckin.created_at)
      : new Date(0)

    const idleMinutes =
      (now.getTime() - lastTime.getTime()) / 60000

    if (idleMinutes < patrol.max_idle_minutes) continue

    // Random offset
    const offsetMinutes =
      patrol.min_interval_minutes +
      Math.random() *
        (patrol.max_interval_minutes - patrol.min_interval_minutes)

    const triggerTime = new Date(
      now.getTime() + offsetMinutes * 60000
    )

    await supabase.from("patrol_triggers").insert({
      patrol_id: patrol.id,
      guard_id: dutyState.guard_id,
      site_id: patrol.site_id,
      trigger_time: triggerTime,
      window_start: new Date(triggerTime.getTime() - 5 * 60000),
      window_end: new Date(triggerTime.getTime() + 5 * 60000),
      expires_at: new Date(triggerTime.getTime() + 10 * 60000),
      status: "PENDING",
    })
  }

  return new Response("Patrol triggers evaluated", { status: 200 })
})
