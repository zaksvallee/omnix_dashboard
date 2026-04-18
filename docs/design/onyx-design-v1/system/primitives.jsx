// ONYX — reusable primitives: ZaraSummary, StatusChip, KPI, Card, etc.
// The ZaraSummary block appears on many operational pages: Z avatar + bullets + flow-row.

function ZAvatar({ size = 32 }) {
  return (
    <div className="z-avatar" style={{width: size, height: size}}>
      <svg viewBox="0 0 32 32" width={size} height={size}>
        <defs>
          <linearGradient id="zg" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#C89BFF"/>
            <stop offset="1" stopColor="#7B2CF0"/>
          </linearGradient>
        </defs>
        <rect x="2" y="2" width="28" height="28" rx="8" fill="rgba(157,75,255,0.12)" stroke="rgba(157,75,255,0.45)"/>
        <text x="16" y="21" textAnchor="middle" fill="url(#zg)" fontFamily="var(--font-sans)" fontSize="15" fontWeight="700" letterSpacing="-0.02em">Z</text>
      </svg>
    </div>
  );
}

// FLOW / SOURCE / NEXT / REF row
function FlowRow({ flow, source, next, ref }) {
  return (
    <div className="flow-row">
      {flow   && <><span className="fr-k">FLOW</span><span className="fr-v mono">{flow}</span></>}
      {source && <><span className="fr-k">SOURCE</span><span className="fr-v mono">{source}</span></>}
      {next   && <><span className="fr-k">NEXT</span><span className="fr-v mono">{next}</span></>}
      {ref    && <><span className="fr-k">REF</span><span className="fr-v mono">{ref}</span></>}
    </div>
  );
}

function ZaraSummary({ title = "ZARA · INTELLIGENCE SUMMARY", bullets = [], flow, source, next, refId, badge, action }) {
  return (
    <div className="zara-summary">
      <div className="zs-head">
        <ZAvatar size={28}/>
        <span className="zs-title mono">{title}</span>
        <div className="zs-right">
          {badge && <span className={"chip " + (badge.tone || "amber")}>{badge.label}</span>}
          {action && action}
        </div>
      </div>
      <ul className="zs-bullets">
        {bullets.map((b, i) => (
          <li key={i}>
            <span className={"dot " + (b.tone || "amber")}/>
            <span>{b.text}</span>
          </li>
        ))}
      </ul>
      {(flow || source || next || refId) && <FlowRow flow={flow} source={source} next={next} ref={refId}/>}
    </div>
  );
}

// Status chip — matches existing product (ENGAGED, READY, STRONG, DEGRADED, LOST, etc.)
function StatusChip({ status, children }) {
  const s = (status || "").toLowerCase();
  let tone = "neutral";
  if (["ready","strong","verified","resolved","cleared","completed","stable","nominal","active","on-station","full"].includes(s)) tone = "green";
  if (["elevated watch","degraded","pending","thin","high activity","amber","in-transit","submitted"].includes(s)) tone = "amber";
  if (["engaged","lost","unavailable","at-risk","critical","breach","p1-critical","gap","no movement","extended shift"].includes(s)) tone = "red";
  if (["focus","info"].includes(s)) tone = "blue";
  return <span className={"status-chip tone-" + tone}>{children || status}</span>;
}

// KPI card
function KPI({ label, value, unit, tone, sub }) {
  return (
    <div className={"kpi tone-" + (tone || "neutral")}>
      <div className="kpi-label mono">{label}</div>
      <div className="kpi-value">
        <span className="kpi-num">{value}</span>
        {unit && <span className="kpi-unit mono">{unit}</span>}
      </div>
      {sub && <div className="kpi-sub mono">{sub}</div>}
    </div>
  );
}

// Tab bar
function Tabs({ items, active, onChange }) {
  return (
    <div className="tabs">
      {items.map(it => (
        <button key={it.id}
          className={"tab" + (active === it.id ? " active" : "")}
          onClick={() => onChange && onChange(it.id)}>
          {it.label}
          {it.count != null && <span className="tab-count mono">{it.count}</span>}
        </button>
      ))}
    </div>
  );
}

// Segmented filter (pills row)
function PillGroup({ items, active, onChange }) {
  return (
    <div className="pill-group">
      {items.map(it => (
        <button key={it.id}
          className={"pill" + (active === it.id ? " active" : "")}
          onClick={() => onChange && onChange(it.id)}>
          {it.label}
          {it.count != null && <span className="pill-count mono">{it.count}</span>}
        </button>
      ))}
    </div>
  );
}

window.ZAvatar = ZAvatar;
window.ZaraSummary = ZaraSummary;
window.FlowRow = FlowRow;
window.StatusChip = StatusChip;
window.KPI = KPI;
window.Tabs = Tabs;
window.PillGroup = PillGroup;
