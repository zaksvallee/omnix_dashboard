// ONYX — Dispatches (truth rail)
// Every dispatch: Zara's proposal, operator decision, outcome, evidence.
// Built around the idea that Zara's accuracy is earned and visible.

const { Shell, StatusChip } = window;
const Icon = window.Icon;

// ---- Dispatch records ----
// Each record: t (time), id, site, type, zaraRec, operatorAct, outcome, duration, concur (bool)
// Rich enough to populate a truth rail with lineage, evidence, and lessons.

const DISPATCHES_FULL = [
  {
    id: "DSP-4821", day: "TONIGHT", t: "22:41:18", site: "MS Vallee", zone: "Zone 3 N",
    type: "Motion at north fence line", category: "Perimeter",
    zaraRec: "DISPATCH", zaraConf: 94, operatorAct: "CONCUR", override: false,
    outcome: "in-progress", outcomeText: "Echo-3 on scene · verifying",
    duration: "00:42",
    evidence: { camera: "VAL-N-03", confidence: "0.94", priorAlerts: "0 / 14d", detection: "Human silhouette · 68 cm profile" },
    reasoning: [
      "Perimeter beam · zone 3 broken at 22:40:36.",
      "YOLO v8 classified silhouette as human (0.94 conf). Profile height ≈ 170 cm.",
      "No scheduled maintenance. Wildlife ruled out: too tall + upright gait.",
      "Echo-3 closest unit (2.4 km, on-duty). Client VoIP parallel-call for verification.",
    ],
    humanNote: "Concurred within 4s. No second-guess.",
    learned: null, // still in progress
  },
  {
    id: "DSP-4819", day: "TONIGHT", t: "22:08:04", site: "Waterfall", zone: "Gate A",
    type: "Gate anomaly · manual code retry",
    category: "Access",
    zaraRec: "VERIFY", zaraConf: 88, operatorAct: "CONCUR", override: false,
    outcome: "verified", outcomeText: "Homeowner · forgotten code",
    duration: "02:14",
    evidence: { camera: "WF-G-01", confidence: "0.88", priorAlerts: "2 / 30d", detection: "3 retries + vehicle" },
    reasoning: [
      "Keypad: 3 failed entries within 40s. Vehicle matched homeowner register (plate ANW-4821).",
      "Face match against homeowner DB: 0.91.",
      "Recommended VERIFY (VoIP call) not DISPATCH — signal was high on 'mistake', low on 'intrusion'.",
    ],
    humanNote: "Operator approved VoIP. Homeowner confirmed, gate opened remotely.",
    learned: { text: "Added homeowner's backup code to primary list. Reduced retry count for this plate before escalation." },
  },
  {
    id: "DSP-4817", day: "TONIGHT", t: "21:52:31", site: "Blue Ridge", zone: "Perimeter E",
    type: "Motion · east fence",
    category: "Perimeter",
    zaraRec: "VERIFY", zaraConf: 42, operatorAct: "AUTO-CLEARED", override: false,
    outcome: "false-pos", outcomeText: "Wildlife · kudu, classified in 600ms",
    duration: "00:09",
    evidence: { camera: "BR-E-02", confidence: "0.42", priorAlerts: "4 / 7d", detection: "Quadruped · kudu profile" },
    reasoning: [
      "Secondary classifier confirmed quadruped in 0.6s. Gait + mass inconsistent with human.",
      "Kudu signature present in false-positive cluster for this camera (4 this week).",
      "Auto-suppressed. Operator was not interrupted.",
    ],
    humanNote: "No operator attention required. Logged to the cluster.",
    learned: { text: "Camera BR-E-02 sensitivity auto-tuned −12%. Kudu recognizer weight ↑ for this zone." },
  },
  {
    id: "DSP-4815", day: "TONIGHT", t: "21:14:02", site: "Hilbrook", zone: "Street",
    type: "Vehicle loitering report · community",
    category: "Community",
    zaraRec: "VERIFY", zaraConf: 71, operatorAct: "OVERRIDE → DISPATCH", override: true,
    outcome: "verified", outcomeText: "Legitimate Uber waiting",
    duration: "08:22",
    evidence: { camera: "HB-ST-04", confidence: "0.71", priorAlerts: "0 / 30d", detection: "Sedan · 12+ min stationary" },
    reasoning: [
      "Community WhatsApp report: white sedan, 40 min. ANPR match: 12 min on camera.",
      "Vehicle registered to Uber fleet. Recommended VERIFY (VoIP call to owner of destination address).",
      "Operator escalated to DISPATCH based on recent area priors (3 scouting reports in 14d).",
    ],
    humanNote: "Zaks overrode to DISPATCH — 'area is jumpy this week, better safe'. RX-03 made contact.",
    learned: { text: "Operator override logged. Weighting for recent-area-priors ↑ in Hilbrook for next 7d." },
  },
  {
    id: "DSP-4812", day: "TONIGHT", t: "20:41:50", site: "Sandton Estate N", zone: "Pool House",
    type: "Panic button · armed",
    category: "Panic",
    zaraRec: "DISPATCH", zaraConf: 99, operatorAct: "AUTO-DISPATCHED", override: false,
    outcome: "verified", outcomeText: "Medical · resolved on-scene",
    duration: "04:12",
    evidence: { camera: "SE-PH-01", confidence: "0.99", priorAlerts: "0 / 60d", detection: "Panic device #PD-1142" },
    reasoning: [
      "Panic device #PD-1142 triggered. Policy = auto-dispatch regardless of AI confidence.",
      "Nearest unit Tango-1 (1.1 km) notified in 300ms. Operator briefed.",
      "Medical pre-alerted in parallel (sub-threshold, based on device owner's profile).",
    ],
    humanNote: "Auto-dispatched per policy. Operator reviewed and confirmed.",
    learned: { text: "Medical pre-alert saved ~90s on arrival. Policy candidate: always pre-alert for pool-house panics." },
  },
  {
    id: "DSP-4811", day: "TONIGHT", t: "20:14:03", site: "Oakley", zone: "Camera 07",
    type: "False-positive cluster · auto-tuned",
    category: "Maintenance",
    zaraRec: "NO-ACTION", zaraConf: 0, operatorAct: "AUTO", override: false,
    outcome: "false-pos", outcomeText: "Sensitivity tuned · 6 → 0 / hr",
    duration: "—",
    evidence: { camera: "OK-07", confidence: "—", priorAlerts: "18 / 7d", detection: "Sensitivity profile update" },
    reasoning: [
      "Oakley-07 producing 6+ false positives per hour (tree branch + streetlight interaction).",
      "Auto-tuned HSV thresholds + motion-grid exclusion zone.",
      "Change is reversible; flagged for ops review in morning.",
    ],
    humanNote: "No interrupt required. Ops rail shows change for morning review.",
    learned: { text: "Exclusion zone saved 42 false-positive alerts overnight. Up for permanence-check tomorrow." },
  },
  {
    id: "DSP-4809", day: "TONIGHT", t: "19:58:22", site: "MS Vallee", zone: "East Gate",
    type: "Vehicle entry · homeowner",
    category: "Access",
    zaraRec: "LOG", zaraConf: 97, operatorAct: "AUTO", override: false,
    outcome: "verified", outcomeText: "Routine entry",
    duration: "00:02",
    evidence: { camera: "VAL-E-01", confidence: "0.97", priorAlerts: "—", detection: "ANPR · ANW-4821" },
    reasoning: ["Plate match + face match. Logged only. No operator interrupt."],
    humanNote: "—",
    learned: null,
  },
  {
    id: "DSP-4805", day: "TONIGHT", t: "18:42:16", site: "Hilbrook", zone: "Guard House",
    type: "Shift change · handover",
    category: "Admin",
    zaraRec: "LOG", zaraConf: 100, operatorAct: "AUTO", override: false,
    outcome: "verified", outcomeText: "Clean handover",
    duration: "00:14",
    evidence: { camera: "HB-GH-01", confidence: "1.00", priorAlerts: "—", detection: "RFID · day→night" },
    reasoning: ["RFID day→night shift transition acknowledged."],
    humanNote: "—",
    learned: null,
  },
  // Yesterday
  {
    id: "DSP-4790", day: "LAST NIGHT", t: "03:22:08", site: "Sandton Estate N", zone: "North Wall",
    type: "Scaling attempt · 2 individuals",
    category: "Perimeter",
    zaraRec: "DISPATCH", zaraConf: 96, operatorAct: "CONCUR", override: false,
    outcome: "confirmed", outcomeText: "Attempted breach · SAPS called",
    duration: "12:44",
    evidence: { camera: "SE-N-02", confidence: "0.96", priorAlerts: "1 / 30d", detection: "2 humans · ladder" },
    reasoning: [
      "Two humans climbing with ladder. IR + visible confirmed, 0.96 conf.",
      "Auto-dispatched RX-03 (1.8 km) + Echo-3 (3.2 km, backup). SAPS pre-briefed.",
      "Subjects fled on arrival. One suspect on camera, face-matched to prior-offender DB.",
    ],
    humanNote: "Zaks concurred in 2s. Good call.",
    learned: { text: "Face-match to prior-offender DB triggered SAPS pre-brief — saved 4 min on SAPS arrival vs baseline." },
  },
  {
    id: "DSP-4788", day: "LAST NIGHT", t: "01:48:22", site: "Waterfall", zone: "Gate B",
    type: "Stranger at gate · delivery",
    category: "Access",
    zaraRec: "VERIFY", zaraConf: 64, operatorAct: "CONCUR", override: false,
    outcome: "verified", outcomeText: "Legit · late delivery driver",
    duration: "01:08",
    evidence: { camera: "WF-G-02", confidence: "0.64", priorAlerts: "0 / 30d", detection: "Unknown face · delivery uniform" },
    reasoning: ["Uniform + package matched delivery co. DB. VoIP to homeowner resolved in 60s."],
    humanNote: "—",
    learned: null,
  },
  {
    id: "DSP-4786", day: "LAST NIGHT", t: "00:14:02", site: "Blue Ridge", zone: "Street",
    type: "Slow-rolling vehicle · 3 passes",
    category: "Community",
    zaraRec: "DISPATCH", zaraConf: 81, operatorAct: "OVERRIDE → VERIFY", override: true,
    outcome: "false-pos", outcomeText: "Lost driver · Google Maps",
    duration: "02:31",
    evidence: { camera: "BR-ST-01", confidence: "0.81", priorAlerts: "2 / 14d", detection: "Vehicle · 3 passes in 6 min" },
    reasoning: [
      "Pattern matched 'scouting' profile. Recommended DISPATCH.",
      "Operator downgraded to VERIFY — driver had phone-up-to-ear behavior consistent with 'lost'.",
      "VoIP on loudspeaker confirmed. Driver was given directions.",
    ],
    humanNote: "Zaks caught the phone behavior. Zara missed it.",
    learned: { text: "Added phone-to-ear pose as a de-weighting signal for 'scouting' classifier. Re-trained on 14 examples." },
  },
];

// Live/in-progress first; then by recency
const TODAY = DISPATCHES_FULL.filter(d => d.day === "TONIGHT");
const YESTERDAY = DISPATCHES_FULL.filter(d => d.day === "LAST NIGHT");

// ---- Filter chips ----
const TIME_FILTERS = ["Tonight · active", "Last 24h", "Last 7d", "Last 30d"];
const CATEGORY_FILTERS = ["All", "Perimeter", "Access", "Panic", "Community", "Maintenance", "Admin"];

// ---- Row ----
function DispatchRow({ d, selected, onClick }) {
  const recKind = d.zaraRec === "DISPATCH" ? "dispatch" : d.zaraRec === "VERIFY" ? "verify" : "ignore";
  const actClass = d.override ? "override" : d.operatorAct === "CONCUR" ? "concur" : d.operatorAct.startsWith("AUTO") ? "auto" : "pending";
  return (
    <div className={"dsp-row" + (selected ? " selected" : "")} onClick={onClick}>
      <div className="dsp-t">
        <span>{d.t}</span>
      </div>
      <div className="dsp-id">{d.id}</div>
      <div className="dsp-incident">
        <div className="dsp-incident-type">{d.type}</div>
        <div className="dsp-incident-sub">
          <span className="dsp-site-badge">{d.site}</span>
          <span>·</span>
          <span>{d.zone}</span>
        </div>
      </div>
      <div className="dsp-concur">
        <span className={"dsp-rec " + recKind}>{d.zaraRec}</span>
        <span className={"dsp-arrow" + (d.override ? " override" : "")}>
          {d.override ? "⤳" : "→"}
        </span>
        <span className={"dsp-act " + actClass}>
          {d.operatorAct === "OVERRIDE → DISPATCH" ? "OVERRIDE" : d.operatorAct === "OVERRIDE → VERIFY" ? "OVERRIDE" : d.operatorAct === "AUTO-DISPATCHED" ? "AUTO" : d.operatorAct === "AUTO-CLEARED" ? "AUTO" : d.operatorAct}
        </span>
      </div>
      <div className="dsp-outcome">
        <span className={"dsp-outcome-dot " + d.outcome}/>
        <span className="dsp-outcome-text">{d.outcomeText}</span>
      </div>
      <div className="dsp-duration">{d.duration}</div>
      <div className="dsp-duration" style={{color: "var(--text-3)", textAlign: "right"}}>{d.zaraConf > 0 ? d.zaraConf : "—"}</div>
    </div>
  );
}

function DayHeader({ label, count, concur }) {
  return (
    <div className="dsp-sep">
      <span>{label}</span>
      <span className="dsp-sep-count">{count} events</span>
      <span className="dsp-sep-concur">Zara concurrence · <span className="mono">{concur}%</span></span>
    </div>
  );
}

// ---- Truth Rail ----
function TruthRail({ d }) {
  if (!d) {
    return (
      <div className="dsp-truth">
        <div className="tr-empty">
          <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4">
            <circle cx="12" cy="12" r="9"/>
            <path d="M12 7v5l3 3"/>
          </svg>
          <div className="tr-empty-h">Truth rail</div>
          <div className="tr-empty-s">Select a dispatch to inspect the evidence chain, Zara's reasoning, operator decision, and what was learned.</div>
        </div>
      </div>
    );
  }

  const outcomeLabel = d.outcome === "verified" ? "Verified" : d.outcome === "confirmed" ? "Confirmed incident" : d.outcome === "false-pos" ? "False positive" : "In progress";
  const outcomeMeta = d.outcome === "in-progress" ? "elapsed" : "resolved";

  return (
    <div className="dsp-truth">
      <div className="tr-head">
        <div className="tr-eyebrow">
          <span>Dispatch record</span>
          <span className="mono">{d.id}</span>
        </div>
        <div className="tr-title">{d.type}</div>
        <div className="tr-meta">
          <span><span className="mono">{d.site}</span> · {d.zone}</span>
          <span>{outcomeMeta} <span className="mono">{d.duration}</span></span>
          <span>category <span className="mono">{d.category}</span></span>
        </div>
      </div>

      <div className="tr-body">
        {/* Evidence */}
        <div className="tr-section">
          <div className="tr-sh">Evidence</div>
          <div className="tr-evidence">
            <div className="tr-evidence-item">
              <div className="tr-evidence-k">Camera</div>
              <div className="tr-evidence-v">{d.evidence.camera}</div>
            </div>
            <div className="tr-evidence-item">
              <div className="tr-evidence-k">Confidence</div>
              <div className="tr-evidence-v">{d.evidence.confidence}</div>
            </div>
            <div className="tr-evidence-item">
              <div className="tr-evidence-k">Prior alerts</div>
              <div className="tr-evidence-v">{d.evidence.priorAlerts}</div>
            </div>
            <div className="tr-evidence-item">
              <div className="tr-evidence-k">Detection</div>
              <div className="tr-evidence-v" style={{fontSize: 11.5, fontWeight: 400}}>{d.evidence.detection}</div>
            </div>
          </div>
        </div>

        {/* Chain — Zara proposes → Human acts → Outcome */}
        <div className="tr-section">
          <div className="tr-sh">Decision chain</div>
          <div className="tr-chain">
            <div className="tr-step zara">
              <div className="tr-step-head">
                <span className="tr-step-actor">Zara proposed</span>
                <span className="tr-step-time">{d.t}</span>
              </div>
              <div className="tr-step-body">
                Recommend <span className="mono">{d.zaraRec}</span>
                {d.zaraConf > 0 && <span className="tr-step-note" style={{display: "inline", marginLeft: 8}}>conf {d.zaraConf}%</span>}
              </div>
              <div className="tr-step-note">
                {d.reasoning.map((r, i) => (<div key={i}>· {r}</div>))}
              </div>
            </div>

            <div className={"tr-step human"}>
              <div className="tr-step-head">
                <span className="tr-step-actor">{d.operatorAct.startsWith("AUTO") ? "Auto-executed" : "Operator Zaks M."}</span>
                <span className="tr-step-time">+{d.duration === "—" ? "0s" : "4s"}</span>
              </div>
              <div className="tr-step-body" style={{marginTop: 2}}>
                {d.override
                  ? <>Override: <span className="mono">{d.operatorAct.replace("OVERRIDE → ", "")}</span> instead of <span className="mono">{d.zaraRec}</span>.</>
                  : <>{d.operatorAct.startsWith("AUTO") ? "Policy auto-execute." : <>Concurred with <span className="mono">{d.zaraRec}</span>.</>}</>
                }
              </div>
              {d.humanNote !== "—" && <div className="tr-step-note">{d.humanNote}</div>}
            </div>

            <div className={"tr-step outcome " + d.outcome}>
              <div className="tr-step-head">
                <span className="tr-step-actor">{outcomeLabel}</span>
                <span className="tr-step-time">{d.duration}</span>
              </div>
              <div className="tr-step-body">{d.outcomeText}</div>
            </div>
          </div>
        </div>

        {/* Learned */}
        {d.learned && (
          <div className="tr-section">
            <div className="tr-sh">Zara learned</div>
            <div className="tr-learned">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" style={{color: "var(--brand-2)", flexShrink: 0, marginTop: 1}}>
                <path d="M12 2L14.5 8.5L21 9.5L16.5 14L17.5 21L12 17.5L6.5 21L7.5 14L3 9.5L9.5 8.5Z"/>
              </svg>
              <div className="tr-learned-body">{d.learned.text}</div>
            </div>
          </div>
        )}

        {/* Timeline sparks for the incident */}
        <div className="tr-section">
          <div className="tr-sh">Related activity · ± 2h</div>
          <div style={{fontSize: 11.5, color: "var(--text-3)", lineHeight: 1.6}}>
            <div>· <span style={{color:"var(--text-2)", fontFamily:"var(--font-mono)", fontSize:10.5}}>{d.t.slice(0,5)}</span> — no neighboring alerts at <span style={{color:"var(--text-2)"}}>{d.site}</span></div>
            <div>· <span style={{color:"var(--text-2)", fontFamily:"var(--font-mono)", fontSize:10.5}}>{"−12m"}</span> — <span style={{color:"var(--text-2)"}}>{d.evidence.camera}</span> sensitivity nominal</div>
            <div>· <span style={{color:"var(--text-2)", fontFamily:"var(--font-mono)", fontSize:10.5}}>{"+01h"}</span> — scheduled sweep for {d.site}</div>
          </div>
        </div>
      </div>

      <div className="tr-actions">
        <button className="btn btn-ghost btn-sm">
          <span style={{display:"inline-flex", alignItems:"center", gap: 4}}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 12h18M3 6h18M3 18h12"/></svg>
            Full log
          </span>
        </button>
        <button className="btn btn-ghost btn-sm">
          <span style={{display:"inline-flex", alignItems:"center", gap: 4}}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M8 12l3 3 5-6"/></svg>
            Add to report
          </span>
        </button>
        <div className="spacer"/>
        <button className="btn btn-ghost btn-sm" style={{color:"var(--text-3)"}}>⋯</button>
      </div>
    </div>
  );
}

// ---- Page ----
function DispatchesPage() {
  const [selected, setSelected] = React.useState("DSP-4821"); // currently-active one
  const [timeFilter, setTimeFilter] = React.useState("Tonight · active");
  const [categoryFilter, setCategoryFilter] = React.useState("All");

  const selectedDispatch = DISPATCHES_FULL.find(d => d.id === selected);

  const filtered = DISPATCHES_FULL.filter(d => categoryFilter === "All" || d.category === categoryFilter);
  const today = filtered.filter(d => d.day === "TONIGHT");
  const yesterday = filtered.filter(d => d.day === "LAST NIGHT");

  // stats
  // Concurrence: of operator-reviewed decisions, how many agreed with Zara's rec
  const reviewed = today.filter(d => !d.operatorAct.startsWith("AUTO"));
  const concurred = reviewed.filter(d => !d.override);
  const todayConcur = reviewed.length > 0 ? Math.round(concurred.length / reviewed.length * 100) : 97;
  const yesterdayConcur = 94;

  return (
    <Shell active="dispatches" title="Dispatches" crumb="Truth rail · Tonight" showHeartbeat={false}>
      <div className="dsp-page">
        {/* Header */}
        <div className="dsp-header">
          <div className="dsp-h-title">
            <div className="dsp-eyebrow">Dispatches · Truth rail</div>
            <h1 className="dsp-h1">Every decision, every override, every outcome.</h1>
            <div className="dsp-h-sub">
              <span className="mono">142</span> dispatches tonight · <span className="mono">{todayConcur}%</span> Zara concurrence · <span className="mono">0</span> missed incidents · audit-ready
            </div>
          </div>
          <div className="dsp-h-controls">
            <div className="dsp-search">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.5-4.5"/></svg>
              <input placeholder="Search site, unit, dispatch ID…" />
              <span className="mono m-xs" style={{color:"var(--text-3)", letterSpacing:"0.04em"}}>⌘K</span>
            </div>
          </div>
        </div>

        {/* KPI strip */}
        <div className="dsp-kpis">
          <div className="dsp-kpi">
            <div className="dsp-kpi-k">Tonight</div>
            <div className="dsp-kpi-v">142</div>
            <div className="dsp-kpi-sub"><span className="pos">▲ 12%</span> vs 7d avg</div>
          </div>
          <div className="dsp-kpi accent">
            <div className="dsp-kpi-k">Zara concurrence</div>
            <div className="dsp-kpi-v">{todayConcur}<span className="unit">%</span></div>
            <div className="dsp-kpi-sub">operator agreed <span className="mono">137/142</span></div>
          </div>
          <div className="dsp-kpi">
            <div className="dsp-kpi-k">Median response</div>
            <div className="dsp-kpi-v">6.2<span className="unit">s</span></div>
            <div className="dsp-kpi-sub"><span className="pos">▼ 1.4s</span> vs baseline</div>
          </div>
          <div className="dsp-kpi">
            <div className="dsp-kpi-k">Overrides</div>
            <div className="dsp-kpi-v">5</div>
            <div className="dsp-kpi-sub">3 upgrades · 2 downgrades</div>
          </div>
          <div className="dsp-kpi">
            <div className="dsp-kpi-k">False positives suppressed</div>
            <div className="dsp-kpi-v">218</div>
            <div className="dsp-kpi-sub">auto-cleared · 0 interrupts</div>
          </div>
          <div className="dsp-kpi">
            <div className="dsp-kpi-k">Confirmed incidents</div>
            <div className="dsp-kpi-v">3</div>
            <div className="dsp-kpi-sub">1 SAPS · 2 medical</div>
          </div>
        </div>

        {/* Filter row */}
        <div className="dsp-filters">
          <div className="dsp-filter-group">
            <span className="dsp-filter-label">Window</span>
            {TIME_FILTERS.map(f => (
              <button key={f} className={"dsp-chip" + (f === timeFilter ? " active" : "")} onClick={() => setTimeFilter(f)}>
                {f === timeFilter && <span className="dot"/>}
                {f}
              </button>
            ))}
          </div>
          <div style={{width: 1, height: 20, background: "var(--border)"}}/>
          <div className="dsp-filter-group">
            <span className="dsp-filter-label">Category</span>
            {CATEGORY_FILTERS.map(f => (
              <button key={f} className={"dsp-chip" + (f === categoryFilter ? " active" : "")} onClick={() => setCategoryFilter(f)}>{f}</button>
            ))}
          </div>
          <div className="dsp-filter-count">
            showing <span className="mono">{filtered.length}</span> of <span className="mono">{DISPATCHES_FULL.length}</span>
          </div>
        </div>

        {/* Main split */}
        <div className="dsp-split">
          <div className="dsp-table">
            <div className="dsp-table-head">
              <div>Time</div>
              <div>ID</div>
              <div>Incident</div>
              <div>Zara → Operator</div>
              <div>Outcome</div>
              <div style={{textAlign:"right"}}>Duration</div>
              <div style={{textAlign:"right"}}>Conf</div>
            </div>
            <div className="dsp-table-body">
              {today.length > 0 && (
                <>
                  <DayHeader label="Tonight" count={today.length} concur={todayConcur}/>
                  {today.map(d => <DispatchRow key={d.id} d={d} selected={d.id === selected} onClick={() => setSelected(d.id)}/>)}
                </>
              )}
              {yesterday.length > 0 && (
                <>
                  <DayHeader label="Last night" count={yesterday.length} concur={yesterdayConcur}/>
                  {yesterday.map(d => <DispatchRow key={d.id} d={d} selected={d.id === selected} onClick={() => setSelected(d.id)}/>)}
                </>
              )}
            </div>
          </div>

          <TruthRail d={selectedDispatch}/>
        </div>
      </div>
    </Shell>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<DispatchesPage/>);
