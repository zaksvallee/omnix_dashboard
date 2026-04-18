// ONYX — Alarms (triage lanes)
// Live unconfirmed signals. Lanes: Zara Queue / Needs Human / Watching / Auto-closed
// Select a card to see the full triage detail on the right.

(function () {
  const { useState, useMemo } = React;
  const Icon = window.Icon;

  // ============ DATA ============
  const ALARMS = [
    {
      id: "AL-8821", sev: "P1", lane: "queue",
      title: "Perimeter breach — north fence, Zone 3",
      siteId: "VAL", siteName: "Valley Estate", area: "Sandton CBD",
      kind: "perimeter",
      age: "00:24",
      time: "22:41:18",
      zScore: 0.94,
      zRec: "DISPATCH",
      zBody: "Two perimeter motion events + human silhouette at 68cm profile. Wildlife ruled out (recurrence pattern, 22:40:26 vs last 14d scheduled maintenance). Recommending immediate dispatch; <em>Response 04</em> is 2 min away.",
      signals: [
        { src: "CAM-03", txt: "Human silhouette 68cm, dark clothing", tt: "22:40:26" },
        { src: "FENCE", txt: "Vibration burst 41 dB, 1.8s", tt: "22:40:28" },
        { src: "THERM", txt: "Warm body 34.1°C moving east→west", tt: "22:40:31" },
      ],
      evidence: [
        { lbl: "CAM-03 · 22:40:26", time: "pre", bbox: true },
        { lbl: "CAM-03 · 22:40:41", time: "post", bbox: true },
      ],
      meters: {
        perim: { v: 92, tone: "red", l: "BREACH" },
        crowd: { v: 24, tone: "green", l: "NORMAL" },
        anom:  { v: 87, tone: "red", l: "0.94" },
        radio: { v: 88, tone: "green", l: "STRONG" },
      },
    },
    {
      id: "AL-8822", sev: "P1", lane: "queue",
      title: "Panic button — armed",
      siteId: "SMT", siteName: "Sanderton Estate N", area: "Sandown",
      kind: "panic", age: "00:12", time: "22:41:58",
      zScore: 1.00, zRec: "DISPATCH",
      zBody: "Panic pressed 2× with guard codename, not a drill. Audio channel opened, no verbal distress, ambient sounds consistent with residence interior. <em>Response 11</em> assigned; client notified.",
      signals: [
        { src: "PANIC", txt: "Two presses, code B2 (not drill)", tt: "22:41:58" },
        { src: "MIC-01", txt: "No verbal distress; TV audio", tt: "22:42:04" },
      ],
      evidence: [
        { lbl: "CAM-01 · interior", time: "live", bbox: false },
        { lbl: "CAM-05 · front door", time: "live", bbox: false },
      ],
      meters: {
        perim: { v: 12, tone: "green", l: "OK" },
        crowd: { v: 18, tone: "green", l: "LOW" },
        anom:  { v: 72, tone: "amber", l: "0.72" },
        radio: { v: 92, tone: "green", l: "STRONG" },
      },
    },
    {
      id: "AL-8823", sev: "P2", lane: "human",
      title: "Loitering vehicle — 3 passes, 14min window",
      siteId: "MSV", siteName: "Ms Vallée", area: "Illovo",
      kind: "vehicle", age: "00:47", time: "22:38:20",
      zScore: 0.71, zRec: "VERIFY",
      zBody: "Silver sedan ZQ 41 FS GP passed gate at 22:24, 22:32, 22:38. Not on known-visitor list. Not a registered Uber / delivery plate. Recommend human verify before dispatch.",
      signals: [
        { src: "ANPR", txt: "ZQ 41 FS GP · 3 passes", tt: "22:38:11" },
        { src: "CAM-02", txt: "Driver face obscured (cap, mask)", tt: "22:38:13" },
      ],
      evidence: [
        { lbl: "PASS 1 · 22:24", time: "1/3" },
        { lbl: "PASS 3 · 22:38", time: "3/3" },
      ],
      meters: {
        perim: { v: 8, tone: "green", l: "OK" },
        crowd: { v: 9, tone: "green", l: "LOW" },
        anom:  { v: 71, tone: "amber", l: "0.71" },
        radio: { v: 84, tone: "green", l: "STRONG" },
      },
    },
    {
      id: "AL-8824", sev: "P2", lane: "human",
      title: "Glass-break audio — kitchen",
      siteId: "MSV", siteName: "Ms Vallée", area: "Illovo",
      kind: "audio", age: "01:02", time: "22:38:05",
      zScore: 0.66, zRec: "VERIFY",
      zBody: "Glass-break signature matched 66% — could be a dropped glass. Household has ZARA-verified presence of housekeeper. Verify with client/housekeeper before dispatch.",
      waveDur: "1.2s",
    },
    {
      id: "AL-8825", sev: "P2", lane: "human",
      title: "Facial match — known contractor in exclusion window",
      siteId: "EVT", siteName: "Everstone Estate", area: "Sunninghill",
      kind: "face", age: "02:11", time: "22:36:14",
      zScore: 0.82, zRec: "VERIFY",
      zBody: "Face matches contractor M. Venter (88%). Contractor access ended 18:00 per site policy. Could be legitimate overtime — verify with site lead before flagging as trespass.",
    },
    {
      id: "AL-8826", sev: "P3", lane: "watching",
      title: "Unusual lights-on pattern — Unit 14",
      siteId: "HLB", siteName: "Holbrook", area: "Parktown",
      kind: "pattern", age: "12:40", time: "22:25:00",
      zScore: 0.48, zRec: "WATCH",
      zBody: "Lights on at 22:10 for Unit 14 — resident travel flag active. Not a hard anomaly; keeping eyes on camera 7 until lights resume normal pattern or for 30 more min.",
    },
    {
      id: "AL-8827", sev: "P3", lane: "watching",
      title: "Intermittent radio loss — roving patrol",
      siteId: "BLR", siteName: "Blue Ridge Pk", area: "Rosebank",
      kind: "radio", age: "08:20", time: "22:28:12",
      zScore: 0.42, zRec: "WATCH",
      zBody: "Guard J. Coetzee radio dropout 3× in last 8 min. Battery at 42%. Within allowed tolerance; next check-in due in 04:20.",
    },
    {
      id: "AL-8828", sev: "P3", lane: "watching",
      title: "Gate left ajar — auto-close timeout",
      siteId: "OAK", siteName: "Oakley", area: "Woodmead",
      kind: "gate", age: "05:11", time: "22:31:30",
      zScore: 0.38, zRec: "WATCH",
      zBody: "Service gate open >90s. Delivery van ETA 22:36 per manifest. Will auto-clear when gate closes or at timeout.",
    },
    // AUTO-CLOSED
    {
      id: "AL-8819", sev: "P3", lane: "closed",
      title: "Wildlife — kudu cluster at east fence",
      siteId: "EVT", siteName: "Everstone Estate", area: "Sunninghill",
      kind: "wildlife", age: "27:14", time: "22:14:00",
      zScore: 0.14, zRec: "CLOSED",
      zBody: "Kudu herd at 4/7 of flagged motion, no human-sized targets. Closed with signature added to kudu-east-fence profile.",
    },
    {
      id: "AL-8818", sev: "P3", lane: "closed",
      title: "False-positive cluster — camera 7 rain",
      siteId: "DKL", siteName: "Dakley (Cam 9)", area: "Kelvin",
      kind: "weather", age: "32:40", time: "22:08:55",
      zScore: 0.09, zRec: "CLOSED",
      zBody: "Auto-bumped sensitivity threshold for 30 min while rain persists. No client impact.",
    },
    {
      id: "AL-8817", sev: "P3", lane: "closed",
      title: "Duplicate camera event — double-index",
      siteId: "VAL", siteName: "Valley Estate", area: "Sandton CBD",
      kind: "system", age: "41:02", time: "22:00:30",
      zScore: 0.04, zRec: "CLOSED",
      zBody: "Same frame hash indexed twice by CAM-03 and CAM-03-mirror. Deduped. Telemetry filed for Intel.",
    },
  ];

  const LANES = [
    { id: "queue",    title: "Zara Queue",     tone: "brand", sub: "AWAITING AI DECISION" },
    { id: "human",    title: "Needs Human",    tone: "amber", sub: "ESCALATED TO OPERATOR" },
    { id: "watching", title: "Watching",       tone: "red",   sub: "ACTIVE · NOT YET DECIDED" },
    { id: "closed",   title: "Auto-Closed",    tone: "green", sub: "LAST 60 MIN · EXPLAINED" },
  ];

  // Site glyph helper
  function siteGlyph(id) {
    return id.slice(0, 3);
  }

  // Waveform SVG
  function Waveform() {
    const bars = 32;
    return (
      <svg viewBox="0 0 100 14" preserveAspectRatio="none">
        {Array.from({length: bars}).map((_,i) => {
          const h = 4 + (Math.sin(i * 0.9) * 0.5 + Math.cos(i * 1.7) * 0.5 + 1) * 3.5;
          return <rect key={i} x={i * (100/bars)} y={(14-h)/2} width={100/bars - 0.6} height={h} fill="currentColor" opacity={0.85}/>;
        })}
      </svg>
    );
  }

  // Evidence thumbnail — synthetic
  function EvidenceBox({ lbl, bbox, size = "lg" }) {
    const isLg = size === "lg";
    return (
      <div className={isLg ? "al-evid" : "al-thumb"}>
        <svg viewBox="0 0 100 60" preserveAspectRatio="none" style={{width:"100%", height:"100%"}}>
          <defs>
            <linearGradient id={"gv" + lbl.length} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#1e2a3a"/>
              <stop offset="100%" stopColor="#0a0d14"/>
            </linearGradient>
          </defs>
          <rect width="100" height="60" fill={"url(#gv" + lbl.length + ")"}/>
          {/* Ground line */}
          <path d="M 0 45 Q 30 43 60 47 Q 80 49 100 46" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="0.6"/>
          {/* Fence */}
          <g stroke="rgba(168,168,180,0.25)" strokeWidth="0.4">
            <line x1="15" y1="35" x2="15" y2="50"/>
            <line x1="25" y1="35" x2="25" y2="50"/>
            <line x1="35" y1="35" x2="35" y2="50"/>
            <line x1="45" y1="35" x2="45" y2="50"/>
            <line x1="55" y1="35" x2="55" y2="50"/>
            <line x1="65" y1="35" x2="65" y2="50"/>
            <line x1="75" y1="35" x2="75" y2="50"/>
            <line x1="85" y1="35" x2="85" y2="50"/>
            <line x1="10" y1="38" x2="90" y2="38"/>
            <line x1="10" y1="42" x2="90" y2="42"/>
          </g>
          {/* Figure */}
          <g fill="rgba(255,255,255,0.4)">
            <ellipse cx="50" cy="28" rx="1.8" ry="2.2"/>
            <path d="M 48 30 L 52 30 L 52 42 L 48 42 Z"/>
            <path d="M 48 42 L 47 50 M 52 42 L 53 50" stroke="rgba(255,255,255,0.4)" strokeWidth="0.8"/>
          </g>
        </svg>
        {bbox && <div className="bbox" style={{left: "38%", top: "35%", width: "26%", height: "40%"}}/>}
        <div className="lbl">{lbl}</div>
      </div>
    );
  }

  function Card({ a, selected, onSelect }) {
    const tone = a.sev === "P1" ? "p1" : a.sev === "P2" ? "p2" : "p3";
    return (
      <div className={"al-card tone-" + tone + (selected === a.id ? " sel" : "")}
           onClick={() => onSelect(a.id)}>
        <div className="al-card-head">
          <span className="al-card-id">{a.id}</span>
          <span className={"chip " + (a.sev === "P1" ? "red" : a.sev === "P2" ? "amber" : "")} style={{height: 18, padding: "0 6px", fontSize: 9.5}}>{a.sev}</span>
          <span>· {a.kind.toUpperCase()}</span>
          <span className="al-card-age">{a.age}</span>
        </div>
        <div className="al-card-title">{a.title}</div>

        {a.kind === "perimeter" && a.evidence && (
          <div className="al-thumbs">
            {a.evidence.slice(0,2).map((e, i) => <EvidenceBox key={i} lbl={e.lbl} bbox={e.bbox} size="sm"/>)}
          </div>
        )}
        {a.kind === "audio" && (
          <div className="al-wave">
            <Waveform/>
            <span className="al-wave-dur">{a.waveDur}</span>
          </div>
        )}

        <div className="al-card-site">
          <span className="site-glyph">{siteGlyph(a.siteId)}</span>
          <span>{a.siteName}</span>
          <span style={{color: "var(--text-3)"}}>· {a.area}</span>
        </div>
        <div className="al-card-foot">
          <div className="al-card-zara">
            <span className="zdot"/>
            <span>Zara · <span className="score">{a.zScore.toFixed(2)}</span></span>
            <span style={{color: "var(--text-3)", marginLeft: 6}}>→ {a.zRec}</span>
          </div>
          <div className="al-card-act">
            <button className="al-mini confirm" title="Concur & dispatch" onClick={e => e.stopPropagation()}><Icon name="check" size={12}/></button>
            <button className="al-mini danger" title="Reject" onClick={e => e.stopPropagation()}><Icon name="x" size={12}/></button>
            <button className="al-mini" title="Escalate" onClick={e => e.stopPropagation()}><Icon name="escalate" size={12}/></button>
          </div>
        </div>
      </div>
    );
  }

  function Lane({ lane, alarms, selected, onSelect }) {
    const items = alarms.filter(a => a.lane === lane.id);
    return (
      <div className={"al-lane tone-" + lane.tone}>
        <div className="al-lane-head">
          <span className="pip"/>
          <span className="al-lane-title">{lane.title}</span>
          <span className="al-lane-count">{items.length}</span>
          <span className="al-lane-sub">{lane.sub}</span>
        </div>
        <div className="al-lane-body">
          {items.length === 0 ? (
            <div className="al-empty">
              <div className="m">no items</div>
            </div>
          ) : items.map(a => (
            <Card key={a.id} a={a} selected={selected} onSelect={onSelect}/>
          ))}
        </div>
      </div>
    );
  }

  function Drawer({ alarm }) {
    if (!alarm) return null;
    const sev = alarm.sev.toLowerCase();
    const m = alarm.meters || { perim: {v: 50, tone: "amber", l: "—"}, crowd: {v: 20, tone: "green", l: "LOW"}, anom: {v: Math.round(alarm.zScore*100), tone: alarm.zScore > 0.7 ? "red" : alarm.zScore > 0.4 ? "amber" : "green", l: alarm.zScore.toFixed(2)}, radio: {v: 85, tone: "green", l: "STRONG"} };

    return (
      <aside className="al-drawer">
        <div className="al-dr-head">
          <div className="al-dr-eyebrow">
            <span className={"sev " + sev}>{alarm.sev} · {alarm.kind.toUpperCase()}</span>
            <span>{alarm.id}</span>
            <span className="age">{alarm.age} OLD</span>
          </div>
          <div className="al-dr-title">{alarm.title}</div>
          <div className="al-dr-sub">{alarm.siteName.toUpperCase()} · {alarm.area.toUpperCase()} · {alarm.time}</div>
        </div>

        <div className="al-dr-body">
          <div className="al-dr-zara">
            <div className="al-dr-zara-head">
              <window.ZAvatar size={18}/>
              <span>ZARA · ASSESSMENT</span>
              <span className="rec">RECOMMEND · {alarm.zRec}</span>
            </div>
            <div className="al-dr-zara-body" dangerouslySetInnerHTML={{__html: alarm.zBody}}/>
            <div className="al-dr-zara-conf">
              <span>CONFIDENCE</span>
              <span className="bar"><i style={{width: (alarm.zScore*100) + "%"}}/></span>
              <span className="score">{alarm.zScore.toFixed(2)}</span>
            </div>
          </div>

          {alarm.evidence && (
            <div>
              <div className="al-sec-hd">
                <Icon name="eye" size={12}/> <span>EVIDENCE · SEALED</span>
              </div>
              <div className="al-evid-thumbs">
                {alarm.evidence.map((e, i) => <EvidenceBox key={i} lbl={e.lbl} bbox={e.bbox}/>)}
              </div>
            </div>
          )}

          <div>
            <div className="al-sec-hd">
              <Icon name="waveform" size={12}/> <span>SITE STATE</span>
            </div>
            <div className="al-meter-grid">
              <div className={"al-meterv tone-" + m.perim.tone}>
                <div className="k">Perimeter</div>
                <div className="v">{m.perim.l}</div>
                <div className="bar"><i style={{width: m.perim.v + "%"}}/></div>
              </div>
              <div className={"al-meterv tone-" + m.crowd.tone}>
                <div className="k">Crowd</div>
                <div className="v">{m.crowd.l}</div>
                <div className="bar"><i style={{width: m.crowd.v + "%"}}/></div>
              </div>
              <div className={"al-meterv tone-" + m.anom.tone}>
                <div className="k">Anomaly</div>
                <div className="v">{m.anom.l}</div>
                <div className="bar"><i style={{width: m.anom.v + "%"}}/></div>
              </div>
              <div className={"al-meterv tone-" + m.radio.tone}>
                <div className="k">Radio</div>
                <div className="v">{m.radio.l}</div>
                <div className="bar"><i style={{width: m.radio.v + "%"}}/></div>
              </div>
            </div>
          </div>

          <div>
            <div className="al-sec-hd"><span>RAW SIGNALS</span></div>
            {(alarm.signals || [
              { src: alarm.kind.toUpperCase(), txt: alarm.title, tt: alarm.time },
            ]).map((s, i) => (
              <div key={i} className="al-signal">
                <span className="src">{s.src}</span>
                <span className="txt">{s.txt}</span>
                <span className="tt">{s.tt}</span>
              </div>
            ))}
          </div>

          <div>
            <div className="al-sec-hd"><span>CONTEXT</span></div>
            <div className="al-kv">
              <span className="k">Site</span><span className="v">{alarm.siteName} <span className="mono">· {alarm.siteId}</span></span>
              <span className="k">Area</span><span className="v">{alarm.area}</span>
              <span className="k">Class</span><span className="v">{alarm.kind}</span>
              <span className="k">Started</span><span className="v mono">{alarm.time}</span>
              <span className="k">Source</span><span className="v mono">CAM+FENCE+THERM</span>
              <span className="k">Context</span><span className="v">Scheduled maintenance · 0 · VIP presence · 0</span>
            </div>
          </div>
        </div>

        <div className="al-dr-act">
          <button className="btn primary"><Icon name="dispatch" size={14}/>Concur · Dispatch R-04</button>
          <button className="btn"><Icon name="escalate" size={13}/>Escalate</button>
          <button className="btn"><Icon name="x" size={13}/>Reject</button>
          <div className="ghost-row">
            <button className="btn sm"><Icon name="eye" size={12}/>Open cams</button>
            <button className="btn sm"><Icon name="radio" size={12}/>Hail site</button>
            <button className="btn sm"><Icon name="more" size={12}/>More</button>
          </div>
        </div>
      </aside>
    );
  }

  function Alarms() {
    const [selected, setSelected] = useState(ALARMS[0].id);
    const [filter, setFilter] = useState("all");
    const alarm = useMemo(() => ALARMS.find(a => a.id === selected), [selected]);

    const filters = [
      { id: "all",   label: "ALL",    ct: ALARMS.length },
      { id: "p1",    label: "P1",     ct: ALARMS.filter(a => a.sev === "P1").length },
      { id: "p2",    label: "P2",     ct: ALARMS.filter(a => a.sev === "P2").length },
      { id: "p3",    label: "P3",     ct: ALARMS.filter(a => a.sev === "P3").length },
    ];
    const kinds = [
      { id: "allk",      label: "ALL CLASSES" },
      { id: "perimeter", label: "PERIMETER" },
      { id: "panic",     label: "PANIC" },
      { id: "vehicle",   label: "VEHICLE" },
      { id: "audio",     label: "AUDIO" },
      { id: "face",      label: "FACE" },
    ];

    const filtered = filter === "all" ? ALARMS : ALARMS.filter(a => a.sev.toLowerCase() === filter);

    return (
      <window.Shell active="alarms" title="Alarms" crumb="Triage · Live">
        <div className="al-page">
          <div className="al-main">
            <div className="al-strip">
              <div>
                <div className="al-title">Signals. Seen, sorted, explained.</div>
                <div className="al-sub">
                  <span className="mono">{ALARMS.length}</span> open · <span className="mono">{ALARMS.filter(a => a.sev === "P1").length}</span> P1 · Zara holding <span className="mono">{ALARMS.filter(a => a.lane === "queue").length}</span> in queue · median decision time <span className="mono">18s</span>
                </div>
              </div>
              <div className="al-strip-right">
                <div className="al-meter"><span className="k">Auto-close rate</span><span className="v">61%</span><span className="k">Last 24h</span><span className="v">342 / 561</span></div>
                <div className="al-meter"><span className="k">Escalation rate</span><span className="v">8.4%</span><span className="k">Dispatch rate</span><span className="v">12%</span></div>
                <button className="btn"><Icon name="filter" size={13}/>Filter</button>
              </div>
            </div>

            <div className="al-filter">
              <div className="al-filter-group">
                {filters.map(f => (
                  <button key={f.id} className={"al-fpill " + (filter === f.id ? "on" : "")} onClick={() => setFilter(f.id)}>
                    {f.label}<span className="ct">{f.ct}</span>
                  </button>
                ))}
              </div>
              <span className="al-sep"/>
              <div className="al-filter-group">
                {kinds.map(f => (
                  <button key={f.id} className={"al-fpill " + (f.id === "allk" ? "on" : "")}>
                    {f.label}
                  </button>
                ))}
              </div>
              <span className="grow"/>
              <button className="al-fpill"><Icon name="clock" size={12}/> LAST HOUR</button>
              <button className="al-fpill"><Icon name="layers" size={12}/> GROUPED</button>
            </div>

            <div className="al-lanes">
              {LANES.map(l => (
                <Lane key={l.id} lane={l} alarms={filtered} selected={selected} onSelect={setSelected}/>
              ))}
            </div>
          </div>
          <Drawer alarm={alarm}/>
        </div>
      </window.Shell>
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(<Alarms/>);
})();
