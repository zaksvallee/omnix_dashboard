/* ============================================================
   Events — dispatch / incident console
   ============================================================ */

const EV_STREAM = [
  { id: "INC-7712", sev: "P2", src: "zara",  title: "Unattended bag — Sandton atrium, fountain quadrant", site: "Sandton City", t: "16:42", slaCat: "warn", sla: "SLA 4:12" },
  { id: "INC-7711", sev: "P1", src: "panic", title: "Panic button pressed — Argus residence driveway", site: "Argus residence", t: "16:38", slaCat: "ok", sla: "ACK 0:38" },
  { id: "INC-7710", sev: "P3", src: "cam",   title: "Motion after hours — Nexus DC perimeter fence (zone N-4)", site: "Nexus DC · Isando", t: "16:34", slaCat: "ok", sla: "SLA 7:22" },
  { id: "INC-7709", sev: "P2", src: "alarm", title: "Glassbreak — embassy chancery · ground floor east", site: "Belgium chancery", t: "16:29", slaCat: "ok", sla: "DSP 2:11" },
  { id: "INC-7708", sev: "P3", src: "zara",  title: "3 subjects matching earlier shoplift MO — north entrance", site: "Sandton City", t: "16:14", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7707", sev: "P4", src: "guard", title: "Routine patrol anomaly — door AD-07 propped 4m", site: "Sandton City", t: "16:18", slaCat: "ok", sla: "INFO" },
  { id: "INC-7706", sev: "P2", src: "cam",   title: "Tailgate at vehicle gate — Kagiso plant 1", site: "Kagiso plant 1", t: "15:58", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7705", sev: "P4", src: "guard", title: "Radio check missed (3x) — Menlyn post W-2", site: "Menlyn Maine", t: "15:52", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7704", sev: "P1", src: "alarm", title: "Intrusion zone Z-14 — V&A basement parking", site: "V&A Waterfront", t: "15:30", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7703", sev: "P3", src: "zara",  title: "Plate match watchlist — Bryanston village entrance", site: "Bryanston", t: "15:22", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7702", sev: "P2", src: "cam",   title: "Loitering 11+ min — Mall of Africa ramp P3", site: "Mall of Africa", t: "15:14", slaCat: "closed", sla: "RESOLVED" },
  { id: "INC-7701", sev: "P4", src: "guard", title: "Shift handover — Sandton (Khumalo in)", site: "Sandton City", t: "15:00", slaCat: "closed", sla: "LOGGED" },
];

const EV_SELECTED = {
  id: "INC-7712",
  sev: "P2",
  title: "Unattended bag · Sandton atrium",
  summary: "Black duffle left at fountain, quadrant SE. No owner returned after 3:42.",
  opened: "16:42:08 SAST",
  age: "4:12",
  sla: { tgt: "8:00", used: 4.2, state: "warn" },
  status: "ACTIVE · RESPONDER ON SCENE",
  client: "Hyperion Retail Group",
  site: "Sandton City flagship",
  zone: "Atrium · SE fountain",
  cam: "CAM-041",
  responders: "L. Cele (HOTEL-2) · V. Dlamini (K9-1)",
  risk: "Low-medium · crowd flow 14%",
  sop: "SOP-SC-12 · Unattended item protocol",
  keys: [
    { k: "PRIORITY", v: "P2 · STANDARD", cls: "" },
    { k: "SITE", v: "Sandton City flagship", cls: "" },
    { k: "ZONE", v: "Atrium · SE · CAM-041", cls: "" },
    { k: "OPENED", v: "16:42:08 SAST", cls: "" },
    { k: "SLA TARGET", v: "8 min on-scene", cls: "amber" },
    { k: "ELAPSED", v: "4:12 / 8:00", cls: "amber" },
    { k: "RESPONDERS", v: "HOTEL-2 · K9-1", cls: "" },
    { k: "CLIENT NOTIFIED", v: "Not required · P2", cls: "good" },
  ],
  chain: [
    { t: "16:42:08", state: "done", head: "DETECTED", em: "ZARA 2.3 · anomaly", sub: "Unattended object ≥180s · confidence 0.82 · class: duffle. Frame 04a3", who: "CAM-041 · atrium SE" },
    { t: "16:42:14", state: "done", head: "TRIAGE", em: "Auto-classified P2", sub: "Passed SOP-SC-12 decision tree: no crowd dispersal, no heat signature, no prior flags on object class. Routed to Sandton desk.", who: "Dispatcher: Aisha N." },
    { t: "16:42:39", state: "done", head: "DISPATCH", em: "Responders assigned", sub: "HOTEL-2 (L. Cele · 42m) · K9-1 (V. Dlamini · 85m). Radio TG-SANDTON-1 alerted. ETA 2m.", who: "Dispatcher: Aisha N." },
    { t: "16:44:12", state: "active", head: "ON SCENE", em: "HOTEL-2 arrived", sub: "Visual confirm of duffle, owner not present. Setting 10m soft perimeter. K9-1 arriving 16:45. Requesting CAM-041 live feed, preserved.", who: "HOTEL-2 · L. Cele" },
    { t: "—", state: "pending", head: "RESOLUTION", em: "pending K-9 clear + owner return check", sub: "Next step: K-9 sniff. If clear and no owner by 16:50, escalate to SAPS canine.", who: "" },
  ],
  comms: [
    { t: "16:44:08", src: "rdo", body: <span><span className="actor">HOTEL-2 → DESK</span> <span className="q">"On scene, visual on the bag. No owner. Pulling back 10m."</span></span> },
    { t: "16:44:22", src: "op",  body: <span><span className="actor">Aisha N. → HOTEL-2</span> <span className="q">"Copy. K9-1 ETA 1 min. Do not touch. Preserve CAM-041."</span></span> },
    { t: "16:43:51", src: "zara", body: <span><em>ZARA</em> suggested similar event 2024-03-14 — cleared as lost luggage (tourist). Same quadrant. Similarity 0.71.</span> },
    { t: "16:43:12", src: "sys", body: <span>Frame 04a3 preserved · chain-of-custody token issued <span className="q">CC-772211</span>. CAM-041 stream locked for evidence.</span> },
    { t: "16:42:48", src: "op",  body: <span><span className="actor">Aisha N.</span> opened incident · applied SOP-SC-12 · assigned HOTEL-2 + K9-1.</span> },
    { t: "16:42:39", src: "sys", body: <span>Radio talkgroup <span className="q">TG-SANDTON-1</span> alerted via TETRA. 6 operators on channel.</span> },
    { t: "16:42:14", src: "zara", body: <span><em>ZARA</em> triage: P2 (standard). No hazard class match · no crowd panic detected · no prior flags.</span> },
    { t: "16:42:08", src: "zara", body: <span><em>ZARA</em> detected unattended object at CAM-041 · confidence 0.82 · class: duffle · duration ≥180s.</span> },
  ],
  evid: [
    { kind: "still", camLbl: "CAM-041 · atrium SE", t: "16:42:11", badge: "PRESERVED", frame: 1 },
    { kind: "live",  camLbl: "CAM-041 · atrium SE", t: "LIVE", badge: "LIVE", live: true },
    { kind: "still", camLbl: "CAM-019 · 3F north",  t: "16:39:44", badge: "CONTEXT", frame: 2 },
    { kind: "body",  camLbl: "BC-0448 · HOTEL-2",   t: "LIVE", badge: "BODYCAM", bodycam: true },
  ],
};

const EV_SRC_LABEL = { zara: "ZARA", cam: "CAM", alarm: "ALRM", guard: "OPR", panic: "PANIC" };

/* ---- Evidence thumbnail SVGs ---- */
function EvFrame({ kind, frame, live, bodycam }) {
  if (bodycam) {
    return (
      <svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid slice">
        <defs>
          <radialGradient id="bcg" cx="50%" cy="50%">
            <stop offset="0" stopColor="#2a1a12"/>
            <stop offset="1" stopColor="#0a0508"/>
          </radialGradient>
        </defs>
        <rect width="160" height="90" fill="url(#bcg)"/>
        {/* floor grid suggestion */}
        <line x1="0" y1="60" x2="160" y2="50" stroke="rgba(255,255,255,0.08)" strokeWidth="0.4"/>
        <line x1="0" y1="70" x2="160" y2="62" stroke="rgba(255,255,255,0.06)" strokeWidth="0.4"/>
        {/* bag silhouette */}
        <ellipse cx="82" cy="70" rx="22" ry="4" fill="rgba(0,0,0,0.4)"/>
        <rect x="66" y="52" width="34" height="18" rx="3" fill="#1a1a22" stroke="#333" strokeWidth="0.6"/>
        <rect x="74" y="48" width="18" height="6" rx="2" fill="#222" stroke="#333" strokeWidth="0.4"/>
        {/* HUD */}
        <text x="6" y="10" fontFamily="var(--font-mono)" fontSize="5" fill="#F25555">● REC</text>
        <text x="154" y="10" fontFamily="var(--font-mono)" fontSize="4.5" fill="rgba(255,255,255,0.7)" textAnchor="end">BC-0448</text>
        <text x="6" y="86" fontFamily="var(--font-mono)" fontSize="4" fill="rgba(255,255,255,0.55)">HOTEL-2 · L.CELE</text>
        {/* reticle */}
        <circle cx="80" cy="60" r="14" fill="none" stroke="rgba(245,166,35,0.6)" strokeWidth="0.4" strokeDasharray="1 1"/>
      </svg>
    );
  }
  if (live) {
    return (
      <svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid slice">
        <defs>
          <linearGradient id="liv" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#0a1016"/>
            <stop offset="1" stopColor="#050708"/>
          </linearGradient>
        </defs>
        <rect width="160" height="90" fill="url(#liv)"/>
        {/* floor tiles */}
        <g opacity="0.4">
          {[...Array(8)].map((_, i) => (
            <line key={i} x1={(i * 22) - 20} y1="90" x2={80 + (i - 4) * 8} y2="40" stroke="rgba(180,200,220,0.2)" strokeWidth="0.4"/>
          ))}
          <line x1="0" y1="60" x2="160" y2="50" stroke="rgba(180,200,220,0.15)" strokeWidth="0.4"/>
          <line x1="0" y1="72" x2="160" y2="62" stroke="rgba(180,200,220,0.12)" strokeWidth="0.4"/>
        </g>
        {/* fountain */}
        <circle cx="80" cy="50" r="18" fill="none" stroke="rgba(100,160,200,0.4)" strokeWidth="0.4"/>
        <circle cx="80" cy="50" r="12" fill="rgba(100,160,200,0.1)" stroke="rgba(100,160,200,0.3)" strokeWidth="0.3"/>
        {/* bag */}
        <ellipse cx="110" cy="68" rx="8" ry="2" fill="rgba(0,0,0,0.5)"/>
        <rect x="104" y="60" width="12" height="8" rx="1.5" fill="#181820" stroke="#2a2a35" strokeWidth="0.4"/>
        {/* alert reticle around bag */}
        <rect x="99" y="55" width="22" height="18" fill="none" stroke="#FFD28A" strokeWidth="0.5" strokeDasharray="1 1"/>
        <line x1="99" y1="55" x2="103" y2="55" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="99" y1="55" x2="99" y2="59" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="117" y1="55" x2="121" y2="55" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="121" y1="55" x2="121" y2="59" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="99" y1="69" x2="99" y2="73" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="99" y1="73" x2="103" y2="73" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="121" y1="69" x2="121" y2="73" stroke="#FFD28A" strokeWidth="0.8"/>
        <line x1="117" y1="73" x2="121" y2="73" stroke="#FFD28A" strokeWidth="0.8"/>
        {/* responder figure */}
        <g>
          <circle cx="60" cy="60" r="2" fill="#6FE8B0"/>
          <rect x="58.5" y="61.5" width="3" height="6" fill="#6FE8B0"/>
          <line x1="56" y1="64" x2="64" y2="64" stroke="#6FE8B0" strokeWidth="0.6"/>
        </g>
        <text x="58" y="57" fontFamily="var(--font-mono)" fontSize="3" fill="#6FE8B0">HOTEL-2</text>
        {/* HUD */}
        <circle cx="154" cy="8" r="2" fill="#F25555"><animate attributeName="opacity" values="1;0.3;1" dur="1.5s" repeatCount="indefinite"/></circle>
        <text x="150" y="10" fontFamily="var(--font-mono)" fontSize="4" fill="rgba(255,255,255,0.7)" textAnchor="end">LIVE</text>
        <text x="6" y="86" fontFamily="var(--font-mono)" fontSize="4" fill="rgba(255,255,255,0.55)">ATRIUM SE · CAM-041</text>
      </svg>
    );
  }
  if (frame === 1) {
    return (
      <svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid slice">
        <rect width="160" height="90" fill="#0d1017"/>
        <g opacity="0.4">
          <line x1="0" y1="55" x2="160" y2="45" stroke="rgba(180,200,220,0.2)" strokeWidth="0.4"/>
          <line x1="0" y1="70" x2="160" y2="58" stroke="rgba(180,200,220,0.15)" strokeWidth="0.4"/>
        </g>
        <circle cx="80" cy="48" r="16" fill="none" stroke="rgba(100,160,200,0.35)" strokeWidth="0.3"/>
        <rect x="104" y="62" width="12" height="8" rx="1.5" fill="#181820" stroke="#2a2a35" strokeWidth="0.4"/>
        <rect x="99" y="57" width="22" height="18" fill="none" stroke="#FFD28A" strokeWidth="0.5" strokeDasharray="1 1"/>
        <text x="6" y="86" fontFamily="var(--font-mono)" fontSize="4" fill="rgba(255,255,255,0.55)">T-00:03 · FRAME 04a3</text>
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid slice">
      <rect width="160" height="90" fill="#0c0f16"/>
      {/* aerial / 3F view */}
      <g opacity="0.5">
        <rect x="20" y="20" width="50" height="50" fill="none" stroke="rgba(180,200,220,0.22)" strokeWidth="0.3"/>
        <rect x="80" y="20" width="60" height="50" fill="none" stroke="rgba(180,200,220,0.22)" strokeWidth="0.3"/>
        <line x1="70" y1="0" x2="70" y2="90" stroke="rgba(180,200,220,0.18)" strokeWidth="0.4"/>
        <line x1="0" y1="70" x2="160" y2="70" stroke="rgba(180,200,220,0.18)" strokeWidth="0.4"/>
      </g>
      {/* figures */}
      {[[40, 35], [55, 45], [95, 30], [110, 55], [125, 40], [70, 55]].map(([x, y], i) => (
        <circle key={i} cx={x} cy={y} r="1.5" fill="rgba(200,210,230,0.5)"/>
      ))}
      <text x="6" y="86" fontFamily="var(--font-mono)" fontSize="4" fill="rgba(255,255,255,0.55)">CAM-019 · 3F north</text>
    </svg>
  );
}

/* ============ Map (mini) ============ */
function EvMiniMap() {
  return (
    <svg viewBox="0 0 160 100" preserveAspectRatio="xMidYMid meet">
      <defs>
        <pattern id="evgrid" width="8" height="8" patternUnits="userSpaceOnUse">
          <path d="M 8 0 L 0 0 0 8" stroke="rgba(255,255,255,0.04)" strokeWidth="0.3" fill="none"/>
        </pattern>
      </defs>
      <rect width="160" height="100" fill="url(#evgrid)"/>

      {/* simplified Sandton City mall - cross layout */}
      <rect x="60" y="18" width="40" height="22" fill="rgba(157,75,255,0.08)" stroke="rgba(157,75,255,0.35)" strokeWidth="0.4"/>
      <rect x="54" y="38" width="52" height="26" fill="rgba(157,75,255,0.1)" stroke="rgba(157,75,255,0.4)" strokeWidth="0.4"/>
      <rect x="20" y="44" width="34" height="16" fill="rgba(157,75,255,0.08)" stroke="rgba(157,75,255,0.35)" strokeWidth="0.4"/>
      <rect x="106" y="44" width="34" height="16" fill="rgba(157,75,255,0.08)" stroke="rgba(157,75,255,0.35)" strokeWidth="0.4"/>
      <rect x="60" y="62" width="40" height="22" fill="rgba(157,75,255,0.08)" stroke="rgba(157,75,255,0.35)" strokeWidth="0.4"/>

      <text x="80" y="50" fontFamily="var(--font-mono)" fontSize="2.5" fill="rgba(205,169,255,0.6)" textAnchor="middle">ATRIUM</text>

      {/* incident marker - SE atrium */}
      <g transform="translate(90 55)">
        <circle r="7" fill="none" stroke="#FFD28A" strokeWidth="0.3" opacity="0.4">
          <animate attributeName="r" values="4;9;4" dur="2s" repeatCount="indefinite"/>
          <animate attributeName="opacity" values="0.5;0;0.5" dur="2s" repeatCount="indefinite"/>
        </circle>
        <circle r="4" fill="none" stroke="#FFD28A" strokeWidth="0.5" opacity="0.8"/>
        <circle r="1.5" fill="#FFD28A"/>
      </g>
      <text x="94" y="55" fontFamily="var(--font-mono)" fontSize="3" fill="#FFD28A">INC-7712 · P2</text>
      <text x="94" y="59" fontFamily="var(--font-mono)" fontSize="2.2" fill="rgba(255,210,138,0.7)">unattended bag · CAM-041</text>

      {/* responders converging */}
      {/* HOTEL-2 - from atrium */}
      <g>
        <path d="M 78 44 Q 84 50 88 54" fill="none" stroke="#6FE8B0" strokeWidth="0.5" strokeDasharray="1 0.7"/>
        <circle cx="78" cy="44" r="1.5" fill="#6FE8B0"/>
        <text x="76" y="42" fontFamily="var(--font-mono)" fontSize="2.3" fill="#6FE8B0" textAnchor="end">HOTEL-2 · on scene</text>
      </g>
      {/* K9-1 - from east */}
      <g>
        <path d="M 112 50 Q 100 53 92 54" fill="none" stroke="#6FE8B0" strokeWidth="0.5" strokeDasharray="1 0.7"/>
        <circle cx="112" cy="50" r="1.5" fill="#6FE8B0"/>
        <text x="114" y="48" fontFamily="var(--font-mono)" fontSize="2.3" fill="#6FE8B0">K9-1 · 40m</text>
      </g>

      {/* compass */}
      <g transform="translate(150 10)">
        <circle r="5" fill="rgba(10,9,18,0.75)" stroke="rgba(180,180,200,0.3)" strokeWidth="0.3"/>
        <path d="M 0 -4 L 1.2 0 L 0 -1.5 L -1.2 0 Z" fill="#CDA9FF"/>
        <text x="0" y="-5.5" fontFamily="var(--font-mono)" fontSize="2.3" fill="#CDA9FF" textAnchor="middle">N</text>
      </g>
    </svg>
  );
}

/* ====================== Screen ====================== */
function EventsScreen() {
  const [selId, setSelId] = React.useState("INC-7712");
  const [filter, setFilter] = React.useState("active");
  const e = EV_SELECTED;

  return (
    <div className="ev-page">
      {/* LEFT */}
      <aside className="ev-left">
        <div className="ev-left-h">
          <div className="ev-left-title">
            <span>Event stream</span>
            <span className="live"><span className="d"></span>LIVE · 12 TODAY</span>
          </div>
          <div className="ev-left-counts">
            <button className="p1"><span className="k">P1</span><span className="v">1</span></button>
            <button className="p2"><span className="k">P2</span><span className="v">3</span></button>
            <button className="p3"><span className="k">P3</span><span className="v">3</span></button>
            <button className="p4"><span className="k">P4</span><span className="v">5</span></button>
          </div>
          <div className="ev-filter-bar">
            <button className={filter === "active" ? "on" : ""} onClick={() => setFilter("active")}>ACTIVE</button>
            <button className={filter === "all" ? "on" : ""} onClick={() => setFilter("all")}>ALL</button>
            <button className={filter === "mine" ? "on" : ""} onClick={() => setFilter("mine")}>MINE</button>
            <button className={filter === "escal" ? "on" : ""} onClick={() => setFilter("escal")}>ESCAL</button>
          </div>
        </div>
        <div className="ev-stream">
          {EV_STREAM.map(ev => (
            <div key={ev.id}
                 className={"ev-row" + (ev.id === selId ? " sel" : "")}
                 onClick={() => setSelId(ev.id)}>
              <div className={"sev " + ev.sev}>{ev.sev}<span className="n">{ev.id.slice(-4)}</span></div>
              <div className="body">
                <div className="title">{ev.title}</div>
                <div className="meta">
                  <span className="site">{ev.site}</span>
                  <span className="sep">·</span>
                  <span className={"src " + ev.src}>{EV_SRC_LABEL[ev.src]}</span>
                </div>
              </div>
              <div className="right">
                <div className="t">{ev.t}</div>
                <div className={"sla " + ev.slaCat}>{ev.sla}</div>
              </div>
            </div>
          ))}
        </div>
      </aside>

      {/* CENTER */}
      <section className="ev-center">
        {/* HERO */}
        <div className="ev-hero">
          <div className="ev-hero-sev">
            <span className="code">{e.sev}</span>
            <span className="lbl">STANDARD</span>
          </div>
          <div>
            <div className="ev-hero-name">{e.title}</div>
            <div className="ev-hero-id">{e.id} · OPENED {e.opened} · {e.summary}</div>
            <div className="ev-hero-tags">
              <span className="pill active">● {e.status}</span>
              <span><span className="k">SITE</span> {e.site}</span>
              <span className="sep">·</span>
              <span><span className="k">CLIENT</span> {e.client}</span>
              <span className="sep">·</span>
              <span><span className="k">SOP</span> {e.sop}</span>
            </div>
          </div>
          <div className="ev-hero-actions">
            <div className="ev-hero-sla">
              <span>SLA · </span>
              <span className="big">{e.age}</span>
              <span>/ {e.sla.tgt}</span>
            </div>
            <div className="btn-row">
              <button className="btn">Note</button>
              <button className="btn">Dispatch</button>
              <button className="btn btn-primary">Resolve</button>
            </div>
          </div>
        </div>

        {/* MAP + KEYS */}
        <div className="ev-topsplit">
          <div className="ev-card">
            <div className="ev-card-h">
              <span className="t">Location &amp; responders</span>
              <span className="sub">ATRIUM SE · LIVE</span>
            </div>
            <div className="ev-map">
              <EvMiniMap/>
              <div className="ev-map-overlay">
                <span className="tab on">SITE</span>
                <span className="tab">CITY</span>
                <span className="tab">STREET</span>
              </div>
              <div className="ev-map-scale">20 m</div>
            </div>
          </div>
          <div className="ev-card">
            <div className="ev-card-h">
              <span className="t">Incident facts</span>
              <span className="sub">AUTO + OPERATOR</span>
            </div>
            <div className="ev-keys">
              {e.keys.map((c, i) => (
                <div className={"cell" + (i === 7 ? " wide" : "")} key={i}>
                  <span className="k">{c.k}</span>
                  <span className={"v " + c.cls}>{c.v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* DISPATCH CHAIN */}
        <div className="ev-sh">
          <span>DISPATCH CHAIN</span>
          <span className="line"></span>
          <span className="sub">detected → triaged → dispatched → on scene → resolved</span>
        </div>
        <div className="ev-chain">
          {e.chain.map((c, i) => (
            <div className="ev-chain-row" key={i}>
              <span className="t">{c.t}</span>
              <span className={"ev-chain-dot " + (c.state === "done" ? "" : c.state === "active" ? "active" : "pending")}></span>
              <div className="body">
                <div className="head">{c.head} <em>· {c.em}</em></div>
                <div className="sub">{c.sub}</div>
              </div>
              <div className="who">{c.who}</div>
            </div>
          ))}
        </div>

        {/* COMMS LOG */}
        <div className="ev-sh">
          <span>COMMS LOG</span>
          <span className="line"></span>
          <span className="sub">TETRA · operator notes · Zara correlations</span>
          <span className="link">filter</span>
        </div>
        <div className="ev-comms">
          {e.comms.map((c, i) => (
            <div className="ev-comms-row" key={i}>
              <span className="t">{c.t}</span>
              <span className={"src " + c.src}>{c.src === "rdo" ? "RADIO" : c.src === "op" ? "OP" : c.src === "zara" ? "ZARA" : "SYS"}</span>
              <span className="msg">{c.body}</span>
            </div>
          ))}
          <div className="ev-comms-input">
            <input type="text" placeholder="Add note · /cmd for commands · ↵ to send" />
            <span style={{fontFamily:"var(--font-mono)",fontSize:"9.5px",color:"var(--text-3)",letterSpacing:"0.08em"}}>↵ SEND</span>
          </div>
        </div>

        {/* EVIDENCE */}
        <div className="ev-sh">
          <span>EVIDENCE</span>
          <span className="line"></span>
          <span className="sub">4 items · CoC sealed · CC-772211</span>
          <span className="link">preserve all</span>
        </div>
        <div className="ev-evidence">
          {e.evid.map((ev, i) => (
            <div className="ev-evid" key={i}>
              <div className="thumb">
                <EvFrame kind={ev.kind} frame={ev.frame} live={ev.live} bodycam={ev.bodycam}/>
                <span className={"badge" + (ev.badge === "LIVE" ? " live" : ev.badge === "CONTEXT" ? " blue" : "")}>{ev.badge}</span>
                <span className="tcode">{ev.t}</span>
              </div>
              <div className="lbl">
                <div className="n">{ev.camLbl}</div>
              </div>
            </div>
          ))}
        </div>

        <div className="ev-spacer"></div>
      </section>

      {/* RIGHT */}
      <aside className="ev-right">
        <div className="ev-right-h">
          <div className="ev-right-t">Dispatch floor</div>
          <div className="ev-right-s">3 DISPATCHERS · 22 RESPONDERS LIVE</div>
        </div>

        <div className="ev-rsec">
          <div className="ev-rsec-h">
            <span className="t">ACTIVE DISPATCHES</span>
            <span className="c">4 LIVE</span>
          </div>
          <div className="ev-disp">
            <span className="sev P1">P1</span>
            <div>
              <div className="ti">Panic button — Argus residence</div>
              <div className="ms">ACK 0:38 · SIERRA · EP</div>
            </div>
          </div>
          <div className="ev-disp">
            <span className="sev P2">P2</span>
            <div>
              <div className="ti">Unattended bag — Sandton atrium</div>
              <div className="ms">SLA 4:12 · HOTEL-2 · K9-1</div>
            </div>
          </div>
          <div className="ev-disp">
            <span className="sev P2">P2</span>
            <div>
              <div className="ti">Glassbreak — embassy chancery</div>
              <div className="ms">DSP 2:11 · ROMEO-1</div>
            </div>
          </div>
          <div className="ev-disp">
            <span className="sev P3">P3</span>
            <div>
              <div className="ti">Motion — Nexus DC perimeter</div>
              <div className="ms">SLA 7:22 · OSCAR</div>
            </div>
          </div>
        </div>

        <div className="ev-rsec">
          <div className="ev-rsec-h">
            <span className="t">RADIO CHANNELS</span>
            <span className="c">TETRA · LTE</span>
          </div>
          <div className="ev-radio">
            <div>
              <div className="n"><span className="d live"></span>TG-SANDTON-1</div>
              <div className="meta">atrium sweep · active comms</div>
            </div>
            <div className="ops">6 OPS</div>
          </div>
          <div className="ev-radio">
            <div>
              <div className="n"><span className="d"></span>TG-EP-ARGUS</div>
              <div className="meta">principal detail · quiet</div>
            </div>
            <div className="ops">4 OPS</div>
          </div>
          <div className="ev-radio">
            <div>
              <div className="n"><span className="d live"></span>TG-AMBS-CHAN</div>
              <div className="meta">embassy chancery · alarm</div>
            </div>
            <div className="ops">3 OPS</div>
          </div>
          <div className="ev-radio">
            <div>
              <div className="n"><span className="d"></span>TG-CONTROL</div>
              <div className="meta">dispatcher floor</div>
            </div>
            <div className="ops">3 OPS</div>
          </div>
          <div className="ev-radio">
            <div>
              <div className="n"><span className="d"></span>TG-SAPS-L</div>
              <div className="meta">liaison · standby</div>
            </div>
            <div className="ops">—</div>
          </div>
        </div>

        <div className="ev-rsec">
          <div className="ev-rsec-h">
            <span className="t">SLA · TODAY</span>
            <span className="c">ROLLING 24H</span>
          </div>
          <div className="ev-sla">
            <div className="ev-sla-cell"><div className="k">P1 ACK</div><div className="v good">0:42</div><div className="d">avg · 8 events</div></div>
            <div className="ev-sla-cell"><div className="k">P2 DSP</div><div className="v amber">3:18</div><div className="d">avg · tgt 3:00</div></div>
            <div className="ev-sla-cell"><div className="k">P2 OS</div><div className="v good">6:51</div><div className="d">avg · tgt 8:00</div></div>
          </div>
          <div style={{marginTop:"10px", fontFamily:"var(--font-mono)",fontSize:"10px",color:"var(--text-3)",letterSpacing:"0.03em",lineHeight:1.5}}>
            <div style={{color:"var(--text-2)"}}>Compliance · 98.4%</div>
            <div>1 breach · INC-7712 · SLA clock 4:12 / 8:00</div>
          </div>
        </div>

        <div className="ev-rsec" style={{borderBottom: 0}}>
          <div className="ev-rsec-h">
            <span className="t">ESCALATION QUEUE</span>
            <span className="c">2</span>
          </div>
          <div className="ev-esc">
            <div className="head">
              <span className="who">Aisha N. · dispatcher</span>
              <span className="due">DUE 16:50</span>
            </div>
            <div className="what">If INC-7712 not resolved by K-9 clear by 16:50, escalate to SAPS canine + notify client duty mgr.</div>
          </div>
          <div className="ev-esc">
            <div className="head">
              <span className="who">Naledi Khumalo · head</span>
              <span className="due">WAITING</span>
            </div>
            <div className="what">Ambassador residence panic · awaiting second-factor clearance from principal aide before stand-down.</div>
          </div>
        </div>
      </aside>
    </div>
  );
}

window.EventsScreen = EventsScreen;
