// ONYX — Zara Home (/)
// Ambient presence, rotating intelligence, autonomous ops log, quick nav.
// Three visual-presence variants toggleable via Tweaks.

const TWEAKS = /*EDITMODE-BEGIN*/{
  "presence": "orb",
  "accent": "purple",
  "density": 5
}/*EDITMODE-END*/;

// --- Intelligence statements, cross-faded ---
const STATEMENTS = [
  { k: "PATROL",   t: "6 patrol routes verified. All checkpoints confirmed — no anomalies." },
  { k: "CCTV",     t: "142 cameras online across 38 sites. 2 channels in known-fault, flagged for maintenance." },
  { k: "PERIMETER",t: "MS Vallee Residence perimeter quiet. Last movement 04:12, housekeeping." },
  { k: "RISK",     t: "Area risk elevated in Westbrook following community report. Watch escalated." },
  { k: "GUARDS",   t: "17 guards on-shift. 3 panic-device batteries below 40%. Replacements dispatched." },
  { k: "INTEL",    t: "Weather front moving north. 72% probability of thunderstorm disruption by 02:00." },
  { k: "AUDIT",    t: "Sovereign ledger chain integrity verified. 1,284,091 entries. No breaks since genesis." },
];

const AUTONOMOUS_OPS = [
  { t: "22:38:12", icon: "eye",      tag: "CCTV",     msg: "Confirmed motion at Hilbrook Estate cam 04 as domestic fauna. No dispatch required.", site: "HILBROOK-04" },
  { t: "22:35:41", icon: "guards",   tag: "WELFARE",  msg: "Guard TK-08 check-in overdue by 4 min. Radio prompt sent; acknowledged.", site: "VALLEE-N" },
  { t: "22:31:07", icon: "radio",    tag: "COMMS",    msg: "Escalated low-battery alert for panic device PD-1142. Replacement en route.", site: "SANDBURY" },
  { t: "22:24:55", icon: "mapPin",   tag: "GEOFENCE", msg: "Reaction unit RX-03 entered Vallee perimeter on schedule. Patrol logged.", site: "VALLEE" },
  { t: "22:18:03", icon: "intel",    tag: "INTEL",    msg: "Community report ingested from Nextdoor feed. Cross-referenced; no match to monitored addresses.", site: "—" },
  { t: "22:12:47", icon: "ledger",   tag: "LEDGER",   msg: "Auto-sealed 214 events from prior hour into ledger block #8492. Hash chain verified.", site: "—" },
  { t: "22:06:20", icon: "shield",   tag: "CCTV",     msg: "Identified repeated false-positive on Oakley cam 07 (tree motion). Sensitivity auto-tuned.", site: "OAKLEY-07" },
];

// Zara presence — three variants
function Presence({ variant, mode }) {
  if (variant === "rings") return <PresenceRings mode={mode}/>;
  if (variant === "field") return <PresenceField mode={mode}/>;
  return <PresenceOrb mode={mode}/>;
}

function PresenceOrb({ mode }) {
  return (
    <div className={"presence orb mode-" + mode}>
      <div className="orb-glow"/>
      <div className="orb-core">
        <svg viewBox="0 0 320 320" width="100%" height="100%">
          <defs>
            <radialGradient id="orbFill" cx="50%" cy="42%" r="60%">
              <stop offset="0%" stopColor="#E4CFFF" stopOpacity="0.95"/>
              <stop offset="28%" stopColor="#B07BFF" stopOpacity="0.8"/>
              <stop offset="62%" stopColor="#6A22CC" stopOpacity="0.55"/>
              <stop offset="100%" stopColor="#1A0A3F" stopOpacity="0"/>
            </radialGradient>
            <radialGradient id="orbRim" cx="50%" cy="50%" r="50%">
              <stop offset="82%" stopColor="#9D4BFF" stopOpacity="0"/>
              <stop offset="94%" stopColor="#C89BFF" stopOpacity="0.7"/>
              <stop offset="100%" stopColor="#9D4BFF" stopOpacity="0"/>
            </radialGradient>
            <filter id="orbBlur"><feGaussianBlur stdDeviation="1.2"/></filter>
          </defs>
          <circle cx="160" cy="160" r="140" fill="url(#orbRim)"/>
          <circle cx="160" cy="160" r="120" fill="url(#orbFill)"/>
          {/* Inner striations */}
          <g opacity="0.35" filter="url(#orbBlur)">
            {Array.from({length: 28}).map((_,i) => {
              const a = (i / 28) * Math.PI * 2;
              const r1 = 60 + (i % 5) * 10;
              const r2 = r1 + 20 + (i % 3) * 6;
              const x1 = 160 + Math.cos(a) * r1, y1 = 160 + Math.sin(a) * r1;
              const x2 = 160 + Math.cos(a) * r2, y2 = 160 + Math.sin(a) * r2;
              return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke="#E4CFFF" strokeWidth="0.8" strokeLinecap="round"/>;
            })}
          </g>
        </svg>
      </div>
      <div className="orb-wave"/>
    </div>
  );
}

function PresenceRings({ mode }) {
  return (
    <div className={"presence rings mode-" + mode}>
      <svg viewBox="0 0 320 320" width="100%" height="100%">
        <defs>
          <radialGradient id="ringCore" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#B07BFF" stopOpacity="0.7"/>
            <stop offset="100%" stopColor="#6A22CC" stopOpacity="0"/>
          </radialGradient>
        </defs>
        <circle cx="160" cy="160" r="22" fill="url(#ringCore)"/>
        <circle cx="160" cy="160" r="6" fill="#E4CFFF"/>
        {[40, 62, 88, 118, 152].map((r, i) => (
          <circle key={i} cx="160" cy="160" r={r}
            stroke={i === 2 ? "#B07BFF" : "#9D4BFF"}
            strokeOpacity={0.55 - i * 0.08}
            strokeWidth={i === 0 ? 1.2 : 0.7}
            strokeDasharray={i === 1 ? "2 4" : i === 3 ? "1 3" : undefined}
            fill="none"/>
        ))}
        {/* sweep */}
        <g className="sweep">
          <path d="M160 160 L160 20 A140 140 0 0 1 280 140 Z" fill="url(#ringCore)" opacity="0.2"/>
        </g>
      </svg>
    </div>
  );
}

function PresenceField({ mode }) {
  // constellation of points breathing
  const pts = React.useMemo(() => {
    const arr = [];
    const seed = 13;
    for (let i = 0; i < 140; i++) {
      const t = i / 140;
      const a = t * Math.PI * 2 * 7 + seed;
      const r = 30 + Math.pow(t, 0.7) * 120 + Math.sin(i * 2.3) * 8;
      arr.push({ x: 160 + Math.cos(a) * r, y: 160 + Math.sin(a) * r, s: 0.6 + (i % 5) * 0.3, d: (i % 9) * 0.12 });
    }
    return arr;
  }, []);
  return (
    <div className={"presence field mode-" + mode}>
      <svg viewBox="0 0 320 320" width="100%" height="100%">
        <defs>
          <radialGradient id="fieldGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#9D4BFF" stopOpacity="0.25"/>
            <stop offset="100%" stopColor="#9D4BFF" stopOpacity="0"/>
          </radialGradient>
        </defs>
        <circle cx="160" cy="160" r="150" fill="url(#fieldGlow)"/>
        <circle cx="160" cy="160" r="4" fill="#E4CFFF"/>
        {pts.map((p, i) => (
          <circle key={i} cx={p.x} cy={p.y} r={p.s}
            fill={i % 12 === 0 ? "#E4CFFF" : "#B07BFF"}
            opacity={0.4 + (i % 7) * 0.08}
            style={{animation: `fieldBreath 3.4s ease-in-out ${p.d}s infinite`}}/>
        ))}
      </svg>
    </div>
  );
}

// Rotating intelligence statement
function Rotator({ items, intervalMs = 7000 }) {
  const [i, setI] = React.useState(0);
  React.useEffect(() => {
    const t = setInterval(() => setI(x => (x + 1) % items.length), intervalMs);
    return () => clearInterval(t);
  }, [items.length, intervalMs]);
  const cur = items[i];
  return (
    <div className="rotator">
      <div className="rotator-dots">
        {items.map((_, idx) => (
          <span key={idx} className={"rd" + (idx === i ? " on" : "")}/>
        ))}
      </div>
      <div className="rotator-body" key={i}>
        <span className="rotator-kind mono">{cur.k}</span>
        <span className="rotator-text">{cur.t}</span>
      </div>
    </div>
  );
}

// Autonomous ops log
function AutonomousLog({ items }) {
  const Icon = window.Icon;
  return (
    <div className="auto-log">
      <div className="log-head">
        <div className="t-h2">Autonomous operations</div>
        <div className="log-meta">
          <span className="dot brand"/>
          <span className="mono m-xs">LAST 30 MIN · {items.length} HANDLED</span>
        </div>
      </div>
      <div className="log-body">
        {items.map((it, i) => (
          <div className="log-row" key={i} style={{animationDelay: (i*60) + "ms"}}>
            <span className="mono m-xs log-time">{it.t}</span>
            <span className="log-ic"><Icon name={it.icon} size={14}/></span>
            <span className={"chip brand log-tag"}>{it.tag}</span>
            <span className="log-msg">{it.msg}</span>
            <span className="mono m-xs log-site">{it.site}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// Quick-access destinations
function QuickNav() {
  const Icon = window.Icon;
  const items = [
    { id: "command",    icon: "command",  label: "Command Center", sub: "1 active", href: "command.html" },
    { id: "dispatches", icon: "dispatch", label: "Dispatches",     sub: "5 in progress", href: "dispatches.html" },
    { id: "alarms",     icon: "alarm",    label: "Alarms",         sub: "Nominal" },
    { id: "track",      icon: "map",      label: "Track",          sub: "17 units live" },
  ];
  return (
    <div className="qnav">
      {items.map(it => (
        <a key={it.id} href={it.href || "#"} className="qnav-item">
          <div className="qnav-ic"><Icon name={it.icon} size={18}/></div>
          <div className="qnav-lbl">
            <div className="qnav-title">{it.label}</div>
            <div className="qnav-sub mono">{it.sub}</div>
          </div>
          <button className="qnav-detach" title="Pop out" onClick={e => { e.preventDefault(); e.stopPropagation(); }}>
            <Icon name="detach" size={13}/>
          </button>
        </a>
      ))}
    </div>
  );
}

// Notification chip (alert)
function AlertChip({ visible, onDismiss, onOpen }) {
  const Icon = window.Icon;
  if (!visible) return null;
  return (
    <div className="alert-chip">
      <div className="ac-ic"><Icon name="alarm" size={16}/></div>
      <div className="ac-body">
        <div className="ac-t1 mono">PERIMETER · MS VALLEE · ZONE 3</div>
        <div className="ac-t2">Motion confirmed by Zara — approval needed</div>
      </div>
      <button className="btn primary sm" onClick={onOpen}>Handle</button>
      <button className="btn ghost icon sm" onClick={onDismiss}><Icon name="x" size={14}/></button>
    </div>
  );
}

// ============================================================
// ZaraHome
// ============================================================
function ZaraHome() {
  const Icon = window.Icon;
  const [tweaks, setTweaks] = React.useState(TWEAKS);
  const [mode, setMode] = React.useState("idle"); // idle | speaking | alert
  const [alertOn, setAlertOn] = React.useState(false);
  const [greetIx] = React.useState(0);

  // accent re-theme
  React.useEffect(() => {
    document.documentElement.setAttribute("data-accent", tweaks.accent || "purple");
  }, [tweaks.accent]);

  // demo: surface an alert every 45s, auto-dismiss after 12s
  React.useEffect(() => {
    const t1 = setTimeout(() => { setAlertOn(true); setMode("alert"); }, 20000);
    return () => clearTimeout(t1);
  }, []);

  // edit-mode protocol
  React.useEffect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.type === "__activate_edit_mode") setEditOn(true);
      if (d.type === "__deactivate_edit_mode") setEditOn(false);
    };
    window.addEventListener("message", onMsg);
    window.parent.postMessage({type: "__edit_mode_available"}, "*");
    return () => window.removeEventListener("message", onMsg);
  }, []);
  const [editOn, setEditOn] = React.useState(false);
  const updateTweak = (k, v) => {
    const next = { ...tweaks, [k]: v };
    setTweaks(next);
    window.parent.postMessage({type: "__edit_mode_set_keys", edits: { [k]: v }}, "*");
  };

  return (
    <window.Shell active="zara" title="Zara" crumb="Home" showHeartbeat={false}>
      <div className="zara-page">
        {/* Ambient background */}
        <div className="zara-bg">
          <div className="zbg-grain"/>
          <div className="zbg-grid"/>
          <div className="zbg-vignette"/>
        </div>

        {/* Top overlay bar — meta */}
        <div className="zara-meta">
          <div className="zm-left">
            <span className="chip brand"><span className="dot brand"/>ZARA · {mode.toUpperCase()}</span>
            <span className="mono m-xs" style={{color:"var(--text-3)"}}>v4.12.0 · INFERENCE @ 14ms · 142 CAM · 38 SITE</span>
          </div>
          <div className="zm-right">
            <button className="btn ghost sm" onClick={() => setMode(mode === "idle" ? "speaking" : "idle")}>
              <Icon name={mode === "speaking" ? "pause" : "play"} size={13}/>
              {mode === "speaking" ? "Pause demo" : "Demo voice"}
            </button>
            <button className="btn ghost sm" onClick={() => setAlertOn(true)}>
              <Icon name="alarm" size={13}/>Simulate alert
            </button>
          </div>
        </div>

        {/* Hero */}
        <div className="zara-hero">
          <div className="zara-presence-wrap">
            <Presence variant={tweaks.presence} mode={mode}/>
          </div>
          <div className="zara-hero-text">
            <div className="greet-eyebrow mono m-xs">ONYX · SOVEREIGN WATCH · 22:41 SAST · TUE 18 APR 2026</div>
            <h1 className="greet-main">
              Good evening, Zaks.
            </h1>
            <p className="greet-sub">
              MS Vallee Residence active. <span className="mono">5</span> dispatches in progress. Monitoring <span className="mono">38</span> sites autonomously.
            </p>
            <div className="rotator-wrap">
              <Rotator items={STATEMENTS}/>
            </div>
          </div>
        </div>

        {/* Bottom shelf */}
        <div className="zara-shelf">
          <div className="shelf-left">
            <AutonomousLog items={AUTONOMOUS_OPS}/>
          </div>
          <div className="shelf-right">
            <div className="t-h2" style={{margin:"0 0 12px 4px"}}>Operational surfaces</div>
            <QuickNav/>
            <div className="shelf-footer">
              <div className="sf-row">
                <span className="mono m-xs">CHAIN INTEGRITY</span>
                <span className="dot green"/><span className="mono m-sm" style={{color:"var(--green)"}}>VERIFIED · 1,284,091 ENTRIES</span>
              </div>
              <div className="sf-row">
                <span className="mono m-xs">HEARTBEAT</span>
                <span className="hb-inline"><span className="hb-dot"/></span>
                <span className="mono m-sm" style={{color:"var(--text-2)"}}>ZARA · WATCHING</span>
              </div>
            </div>
          </div>
        </div>

        <AlertChip visible={alertOn} onDismiss={() => setAlertOn(false)} onOpen={() => { location.href = "command.html"; }}/>

        {editOn && (
          <div className="tweaks-panel">
            <div className="tweaks-head">
              <span className="t-h2">Tweaks</span>
              <button className="btn ghost icon sm" onClick={() => setEditOn(false)}><Icon name="x" size={14}/></button>
            </div>
            <div className="tweaks-row">
              <div className="tweaks-lbl">Presence</div>
              <div className="tweaks-segs">
                {["orb","rings","field"].map(v => (
                  <button key={v}
                    className={"seg" + (tweaks.presence === v ? " on" : "")}
                    onClick={() => updateTweak("presence", v)}>{v}</button>
                ))}
              </div>
            </div>
            <div className="tweaks-row">
              <div className="tweaks-lbl">Accent</div>
              <div className="tweaks-segs">
                {["purple","cyan","amber"].map(v => (
                  <button key={v}
                    className={"seg" + (tweaks.accent === v ? " on" : "")}
                    onClick={() => updateTweak("accent", v)}>{v}</button>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </window.Shell>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<ZaraHome/>);
