# ONYX Guard Pilot Daily Ops Sheet

Use this sheet every pilot day for consistent operations.

Related:
- [guard_operator_launch_checklist.md](/Users/zaks/omnix_dashboard/docs/guard_operator_launch_checklist.md)
- [guard_app_android_deployment_blueprint_v2.md](/Users/zaks/omnix_dashboard/docs/guard_app_android_deployment_blueprint_v2.md)

Date: __________  
Site: __________  
Shift Window: __________  
Operations Lead: __________  
Control Lead: __________

## 1. Morning Preflight (Before First Shift)

- [ ] ONYX app opens on all assigned guard devices.
- [ ] Supabase sync path is active (not local-only unless planned fallback).
- [ ] Pending event/media backlog checked and noted.
- [ ] NFC checkpoints physically present and readable at site.
- [ ] Wearables paired and reporting baseline signals.
- [ ] Device battery levels acceptable for shift.
- [ ] Patrol route map and checkpoint order confirmed with guards.

Notes:
______________________________________________________________________

## 2. Shift Start Compliance

Per guard:
- [ ] Shift verification image captured.
- [ ] `SHIFT_START` event created after verification.
- [ ] Initial status set correctly.
- [ ] Control room confirms guard appears in live shift list.

Non-compliance exceptions:
______________________________________________________________________

## 3. In-Shift Operational Monitoring

Every 60-90 minutes:
- [ ] Check pending queue counts by guard/site.
- [ ] Check failed event/media counts.
- [ ] Check panic channel health.
- [ ] Check checkpoint scan cadence vs route expectation.
- [ ] Check patrol image completion and quality.
- [ ] Check wearable disconnect/fatigue alerts.

If issues found:
- [ ] Retry failed events
- [ ] Retry failed media
- [ ] Escalate to controller if unresolved > 10 minutes

Issue log:
______________________________________________________________________

## 4. Dispatch Handling Quality

- [ ] Dispatch acknowledgements within target SLA.
- [ ] Status transitions (`EN_ROUTE`, `ON_SITE`, `CLEAR`) captured correctly.
- [ ] Panic triggers (if any) had complete event chain and closure.

Dispatch anomalies:
______________________________________________________________________

## 5. Midday or Mid-Shift Handover (if applicable)

- [ ] Outgoing team confirms no hidden local backlog.
- [ ] Incoming team verifies sync dashboard state.
- [ ] Device condition and battery handover complete.
- [ ] Outstanding incidents and patrol gaps briefed.

Handover notes:
______________________________________________________________________

## 6. End-of-Day Wrap

- [ ] All shifts closed (`SHIFT_END` where applicable).
- [ ] Pending queue near zero or explained.
- [ ] Failed queue reviewed and actioned.
- [ ] Key incidents labeled for learning loop.
- [ ] Patrol compliance summary captured.
- [ ] Device health issues logged for support.

## 7. End-of-Day KPI Snapshot

Target values can be adjusted per pilot plan.

- Patrol verification compliance: ____ % (target > 95%)
- Duplicate sync rate: ____ % (target < 0.1%)
- Median dispatch ack time: ____ (target site SLA)
- Panic response chain complete: ____ / ____ incidents
- Queue drain success after reconnect: ____ / ____ cases
- Unusable patrol images: ____ % (target trend down daily)

## 8. Daily Pilot Report (Template)

Summary:
______________________________________________________________________

Top 3 wins:
1. _________________________________________________________________
2. _________________________________________________________________
3. _________________________________________________________________

Top 3 problems:
1. _________________________________________________________________
2. _________________________________________________________________
3. _________________________________________________________________

Required next actions (owner + due):
1. _________________________________________________________________
2. _________________________________________________________________
3. _________________________________________________________________

## 9. Sign-Off

Operations Lead: ____________________ Time: __________  
Control Lead: _______________________ Time: __________  
Pilot Site Representative: ___________ Time: __________
