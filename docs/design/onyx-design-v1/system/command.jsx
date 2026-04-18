// ONYX — Command Center (/dashboard)
// Three-panel operational surface: Focus (left) / Queue (center) / Rail (right)
// Bottom: 4-up camera grid

const Icon = window.Icon;
const { Shell, ZaraSummary, ZAvatar, StatusChip, KPI, Tabs, PillGroup } = window;

// ---- Data ----
const CAMERAS = [
  { id: "VAL-N-03", site: "MS Vallee",    zone: "North Perimeter", status: "alert", sweeping: false },
  { id: "VAL-E-01", site: "MS Vallee",    zone: "East Gate",       status: "ok",    sweeping: true },
  { id: "VAL-W-02", site: "MS Vallee",    zone: "West Lane",       status: "ok",    sweeping: true },
  { id: "VAL-S-04", site: "MS Vallee",    zone: "South Garden",    status: "ok",    sweeping: false },
];

const QUEUE = [
  { id: "Q-8829", site: "Sandton Estate N", type: "Perimeter motion", conf: 94, eta: "00:26", kind: "AUTO-DISPATCH", severity: "p1" },
  { id: "Q-8830", site: "Hilbrook Estate",  type: "Vehicle loitering", conf: 71, eta: "01:42", kind: "VERIFY",  severity: "p2" },
  { id: "Q-8831", site: "Waterfall",        type: "Gate anomaly",     conf: 88, eta: "02:08", kind: "VOIP CLIENT", severity: "p2" },
  { id: "Q-8832", site: "Blue Ridge",       type: "Panic device low",  conf: 99, eta: "—",     kind: "MAINTENANCE", severity: "p3" },
];

const DISPATCHES = [
  { id: "DSP-4", site: "MS Vallee",   unit: "GUARD-1",  phase: "on-scene",   elapsed: "08:00" },
  { id: "DSP-5", site: "Hilbrook",    unit: "RX-03",    phase: "en-route",   elapsed: "03:42" },
  { id: "DSP-6", site: "Sandton N",   unit: "Echo-3",   phase: "assigned",   elapsed: "00:14" },
  { id: "DSP-2", site: "Waterfall",   unit: "Tango-1",  phase: "on-scene",   elapsed: "14:31" },
  { id: "DSP-1", site: "Blue Ridge",  unit: "Sierra-2", phase: "closing",    elapsed: "22:09" },
];

const EVENTS = [
  { t: "22:41:18", site: "VALLEE-N-03", tag: "AI DECISION",     text: "Motion classified as human · zone 3" },
  { t: "22:41:03", site: "HILBROOK",    tag: "COMMUNITY",       text: "Vehicle scouting report · cross-ref no match" },
  { t: "22:40:42", site: "VALLEE",      tag: "GEOFENCE",        text: "RX-03 entered perimeter" },
  { t: "22:40:12", site: "OAKLEY-07",   tag: "CCTV",            text: "Sensitivity auto-tuned (false-positive cluster)" },
  { t: "22:39:58", site: "SANDBURY",    tag: "COMMS",           text: "PD-1142 low battery · replacement dispatched" },
  { t: "22:39:22", site: "VALLEE-N",    tag: "CHECK-IN",        text: "TK-08 check-in acknowledged" },
];

// ---- CCTV Frame ----
function CameraFrame({ cam, focus }) {
  return (
    <div className={"cctv " + (cam.status === "alert" ? "alert " : "") + (focus ? "focus " : "") + (cam.sweeping ? "sweeping" : "")}>
      <div className="cctv-scene">
        {/* synthetic scene */}
        <svg viewBox="0 0 400 225" className="cctv-bg" preserveAspectRatio="xMidYMid slice">
          <defs>
            <linearGradient id="skyG" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor="#0e1526"/>
              <stop offset="1" stopColor="#1a1f32"/>
            </linearGradient>
            <pattern id="gridCCTV" width="20" height="20" patternUnits="userSpaceOnUse">
              <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(150,180,220,0.05)" strokeWidth="0.5"/>
            </pattern>
          </defs>
          <rect width="400" height="225" fill="url(#skyG)"/>
          <rect width="400" height="225" fill="url(#gridCCTV)"/>
          {/* ground line + posts */}
          <line x1="0" y1="160" x2="400" y2="160" stroke="rgba(180,200,230,0.15)" strokeWidth="1"/>
          <rect x="40" y="100" width="3" height="60" fill="rgba(200,200,220,0.3)"/>
          <rect x="140" y="90" width="3" height="70" fill="rgba(200,200,220,0.3)"/>
          <rect x="240" y="95" width="3" height="65" fill="rgba(200,200,220,0.3)"/>
          <rect x="340" y="100" width="3" height="60" fill="rgba(200,200,220,0.3)"/>
          {/* YOLO detection */}
          {cam.status === "alert" && focus && (
            <g className="yolo-box">
              <rect x="180" y="112" width="58" height="68" fill="none" stroke="#F25555" strokeWidth="1.5"/>
              <rect x="180" y="104" width="80" height="10" fill="#F25555"/>
              <text x="184" y="112" fill="white" fontFamily="var(--font-mono)" fontSize="7" fontWeight="600">HUMAN · 0.94</text>
              {/* figure */}
              <circle cx="209" cy="128" r="6" fill="rgba(200,220,255,0.7)"/>
              <rect x="202" y="134" width="14" height="24" fill="rgba(200,220,255,0.55)"/>
              <rect x="204" y="158" width="4" height="18" fill="rgba(200,220,255,0.5)"/>
              <rect x="210" y="158" width="4" height="18" fill="rgba(200,220,255,0.5)"/>
            </g>
          )}
        </svg>
      </div>
      <div className="cctv-hud">
        <span className="mono m-xs" style={{color: "#C5F0FF"}}>● REC</span>
        <span className="mono m-xs">{cam.id}</span>
        <span className="mono m-xs" style={{marginLeft: "auto"}}>22:41:{focus ? "18.4" : "12.1"}</span>
      </div>
      <div className="cctv-footer">
        <span className="cctv-site">{cam.site}</span>
        <span className="cctv-zone mono">{cam.zone}</span>
      </div>
      {cam.sweeping && <div className="cctv-sweep"/>}
      {cam.status === "alert" && <div className="cctv-alert-edge"/>}
    </div>
  );
}

// ---- Focus panel ----
function FocusPanel({ cam, onApprove, onReject, onEscalate, state }) {
  return (
    <div className="focus-panel">
      <div className="focus-head">
        <div className="fh-left">
          <StatusChip status={state === "resolved" ? "VERIFIED" : "ACTIVE INCIDENT"}>{state === "resolved" ? "VERIFIED" : "ACTIVE INCIDENT"}</StatusChip>
          <div className="fh-title">
            <div className="t-body" style={{color: "var(--text-3)", fontSize: 11, letterSpacing: "0.14em", textTransform: "uppercase"}}>MS Vallee · Zone 3 perimeter</div>
            <h2 className="focus-h1">Motion at north fence line</h2>
          </div>
        </div>
        <div className="fh-right">
          <span className="mono m-xs" style={{color:"var(--text-3)"}}>INC-8829-QX · PRIORITY P1 · ELAPSED 00:42</span>
        </div>
      </div>
      <div className="focus-body">
        <div className="focus-feed">
          <CameraFrame cam={cam} focus={true}/>
        </div>
        <div className="focus-meta">
          <div className="fm-row">
            <span className="fm-k mono">CAMERA</span><span className="fm-v mono">{cam.id}</span>
            <span className="fm-k mono">ZONE</span><span className="fm-v mono">NORTH-P3</span>
          </div>
          <div className="fm-row">
            <span className="fm-k mono">DETECTION</span><span className="fm-v">Human silhouette</span>
            <span className="fm-k mono">CONFIDENCE</span><span className="fm-v mono" style={{color: "var(--amber)"}}>0.94</span>
          </div>
          <div className="fm-row">
            <span className="fm-k mono">ENV</span><span className="fm-v">Clear · 14°C · wind 8km/h SW</span>
            <span className="fm-k mono">LUX</span><span className="fm-v mono">2 (low)</span>
          </div>
          <div className="fm-row">
            <span className="fm-k mono">RECENT</span>
            <span className="fm-v" style={{gridColumn: "2 / -1"}}>4 sweep verifications in last 60s. No prior alert at this camera in 14d.</span>
          </div>
        </div>
      </div>

      <div className="zara-proposal">
        <div className="zp-head">
          <ZAvatar size={24}/>
          <span className="mono" style={{fontSize: 10.5, letterSpacing: "0.14em", color: "var(--brand-2)"}}>ZARA PROPOSES</span>
          <span className="mono m-xs" style={{color: "var(--text-3)", marginLeft: "auto"}}>AUTO-EXECUTE IN 00:26</span>
        </div>
        <div className="zp-text">
          Dispatch <span className="mono">Echo-3</span> (on-duty, 2.4km) to <span className="mono">VALLEE-N</span>. Initiate client VoIP verification call in parallel. Hold for 90s, re-evaluate with approach telemetry.
        </div>
        <div className="zp-actions">
          <button className="btn primary lg" onClick={onApprove}>
            <Icon name="check" size={16}/>APPROVE &amp; DISPATCH
          </button>
          <button className="btn lg" onClick={onEscalate} style={{background: "var(--amber-wash)", borderColor: "rgba(245,166,35,0.4)", color: "#FFD28A"}}>
            <Icon name="escalate" size={16}/>ESCALATE
          </button>
          <button className="btn danger lg" onClick={onReject}>
            <Icon name="x" size={16}/>REJECT
          </button>
          <div className="zp-kbd mono m-xs">⏎ approve · E escalate · Esc reject</div>
        </div>
        <div className="zp-countdown"><div className="zp-bar"/></div>
      </div>
    </div>
  );
}

// ---- Queue card ----
function QueueCard({ q, active, onClick }) {
  const tone = q.severity === "p1" ? "red" : q.severity === "p2" ? "amber" : "neutral";
  return (
    <button className={"q-card" + (active ? " active" : "")} onClick={onClick}>
      <div className="qc-head">
        <StatusChip status={q.kind}>{q.kind}</StatusChip>
        <span className={"status-chip tone-" + tone} style={{marginLeft: "auto"}}>{q.severity.toUpperCase()}</span>
      </div>
      <div className="qc-site">{q.site}</div>
      <div className="qc-type">{q.type}</div>
      <div className="qc-foot">
        <span className="mono m-xs">{q.id}</span>
        <span className="qc-conf mono">
          <span className="qc-bar"><span style={{width: q.conf + "%"}}/></span>
          {q.conf}%
        </span>
        <span className="mono m-xs" style={{color: "var(--text-3)"}}>{q.eta}</span>
      </div>
    </button>
  );
}

// ---- Right rail ----
function DispatchStrip({ d }) {
  const phaseColor = d.phase === "on-scene" ? "green" : d.phase === "en-route" ? "amber" : d.phase === "closing" ? "blue" : "neutral";
  return (
    <div className="dispatch-strip">
      <span className={"dot " + phaseColor}/>
      <div className="ds-body">
        <div className="ds-top">
          <span className="mono" style={{fontSize: 11, fontWeight: 600, color: "var(--text-1)"}}>{d.id}</span>
          <span className="ds-site">{d.site}</span>
          <span className="mono m-xs" style={{marginLeft: "auto", color: "var(--text-3)"}}>{d.elapsed}</span>
        </div>
        <div className="ds-bot">
          <span className="mono m-xs" style={{color: "var(--text-2)"}}>{d.unit}</span>
          <span className="mono m-xs" style={{color: "var(--text-3)", textTransform: "uppercase", letterSpacing: "0.12em"}}>{d.phase.replace("-", " ")}</span>
        </div>
      </div>
    </div>
  );
}

// ---- Event micro-row ----
function EventMicro({ e }) {
  return (
    <div className="evt-micro">
      <span className="mono m-xs" style={{color: "var(--text-3)"}}>{e.t}</span>
      <span className="status-chip tone-brand" style={{fontSize: 9}}>{e.tag}</span>
      <span className="evt-text">{e.text}</span>
      <span className="mono m-xs evt-site">{e.site}</span>
    </div>
  );
}

// ---- Main ----
function CommandCenter() {
  const [focusCamIx, setFocusCamIx] = React.useState(0);
  const [activeQueueIx, setActiveQueueIx] = React.useState(0);
  const [state, setState] = React.useState("incident"); // nominal | incident | sweeping | resolved | multi
  const [toast, setToast] = React.useState(null);

  const showToast = (msg, tone = "green") => {
    setToast({ msg, tone });
    setTimeout(() => setToast(null), 3800);
  };

  const handleApprove = () => {
    showToast("Dispatch approved · Echo-3 en route to VALLEE-N · VoIP call initiated", "green");
    setState("resolved");
    setTimeout(() => setState("incident"), 8000);
  };
  const handleReject  = () => showToast("Decision rejected · queue cleared", "amber");
  const handleEscalate= () => showToast("Escalated to Ops Manager · awaiting concurrence", "amber");

  return (
    <Shell active="command" title="Command Center" crumb={state === "incident" ? "Perimeter Alerts" : "Monitoring"} showHeartbeat={false}>
      {/* Elevated watch banner */}
      {state === "incident" && (
        <div className="elevated-banner">
          <span className="eb-pulse"/>
          <div className="eb-content">
            <span className="status-chip tone-amber">ELEVATED WATCH · MS VALLEE</span>
            <span className="eb-text">Perimeter activity at <span className="mono">VAL-N-03</span>. Zara is verifying. Intervention window open.</span>
          </div>
          <div className="eb-right">
            <span className="mono m-xs" style={{color:"var(--text-3)"}}>TRIGGERED 22:40:36 · ASSESSING</span>
          </div>
        </div>
      )}

      {state === "resolved" && (
        <div className="elevated-banner resolved">
          <span className="eb-pulse green"/>
          <div className="eb-content">
            <span className="status-chip tone-green">RESOLVED · DISPATCH APPROVED</span>
            <span className="eb-text">Echo-3 acknowledged · ETA 4m 12s · Chain seal pending on <span className="mono">DSP-6</span></span>
          </div>
          <div className="eb-right">
            <button className="btn sm">Review full incident <Icon name="arrow" size={12}/></button>
          </div>
        </div>
      )}

      <div className="cc-grid">
        {/* Left — Focus */}
        <div className="cc-focus">
          <FocusPanel
            cam={CAMERAS[0]}
            state={state}
            onApprove={handleApprove}
            onReject={handleReject}
            onEscalate={handleEscalate}
          />
        </div>

        {/* Center — Queue */}
        <div className="cc-queue">
          <div className="q-head">
            <div className="t-h2">AI Queue</div>
            <span className="mono m-xs" style={{color: "var(--text-3)"}}>{QUEUE.length} pending · Zara auto-executes approved</span>
          </div>
          <div className="q-list">
            {QUEUE.map((q, i) => (
              <QueueCard key={q.id} q={q} active={i === activeQueueIx} onClick={() => setActiveQueueIx(i)}/>
            ))}
          </div>
          <div className="q-foot">
            <button className="btn sm" style={{width:"100%"}}>
              <Icon name="eye" size={13}/>View full AI queue
            </button>
          </div>
        </div>

        {/* Right — Rail */}
        <div className="cc-rail">
          {/* Operator status */}
          <div className="rail-block">
            <div className="rb-head">
              <span className="t-h2">Operator · Zaks M.</span>
              <span className="status-chip tone-green">READY</span>
            </div>
            <div className="op-stats">
              <div className="os-cell">
                <span className="os-k mono">SHIFT</span>
                <span className="os-v mono">18:00 → 06:00</span>
              </div>
              <div className="os-cell">
                <span className="os-k mono">DECISIONS</span>
                <span className="os-v mono">47 ·  <span style={{color: "var(--green)"}}>97% ZARA CONCUR</span></span>
              </div>
              <div className="os-cell">
                <span className="os-k mono">REACTION</span>
                <span className="os-v mono">6.2s AVG</span>
              </div>
            </div>
          </div>

          {/* Dispatches timeline */}
          <div className="rail-block">
            <div className="rb-head">
              <span className="t-h2">Active Dispatches · {DISPATCHES.length}</span>
              <a className="rb-link mono m-xs" href="dispatches.html">OPEN <Icon name="arrow" size={10}/></a>
            </div>
            <div className="dispatch-list">
              {DISPATCHES.map(d => <DispatchStrip key={d.id} d={d}/>)}
            </div>
          </div>

          {/* Events micro-feed */}
          <div className="rail-block tight">
            <div className="rb-head">
              <span className="t-h2">Recent Events</span>
              <span className="mono m-xs" style={{color: "var(--text-3)"}}>LIVE</span>
            </div>
            <div className="events-list">
              {EVENTS.map((e, i) => <EventMicro key={i} e={e}/>)}
            </div>
          </div>
        </div>
      </div>

      {/* Bottom 4-up camera strip */}
      <div className="cc-cctv-strip">
        <div className="cctv-strip-head">
          <span className="t-h2">Live cameras · Zara sweep</span>
          <div style={{marginLeft: "auto", display: "flex", gap: 10, alignItems: "center"}}>
            <span className="mono m-xs" style={{color: "var(--text-3)"}}>SEQUENTIAL VERIFY · 14s CYCLE</span>
            <PillGroup items={[
              {id:"vallee", label:"MS Vallee"},
              {id:"all", label:"All sites", count: 142},
            ]} active="vallee" onChange={()=>{}}/>
          </div>
        </div>
        <div className="cctv-grid">
          {CAMERAS.map((c, i) => (
            <div key={c.id} className={"cctv-cell" + (i === focusCamIx ? " promoted" : "")} onClick={() => setFocusCamIx(i)}>
              <CameraFrame cam={c} focus={false}/>
            </div>
          ))}
        </div>
      </div>

      {toast && (
        <div className={"cc-toast tone-" + toast.tone}>
          <Icon name={toast.tone === "green" ? "check" : "escalate"} size={14}/>
          <span>{toast.msg}</span>
        </div>
      )}
    </Shell>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<CommandCenter/>);
