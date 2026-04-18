/* ============================================================
   Sites — physical facility atlas
   ============================================================ */

const ST_SITES = [
  { id: "SND",  kind: "retail", name: "Sandton City flagship",   cli: "Hyperion",  on: 24, sch: 24, state: "green",  risk: "TIER-2", },
  { id: "MEN",  kind: "retail", name: "Menlyn Maine",            cli: "Hyperion",  on: 18, sch: 18, state: "green",  risk: "TIER-2", },
  { id: "VAW",  kind: "retail", name: "V&A Waterfront",          cli: "Hyperion",  on: 22, sch: 24, state: "amber",  risk: "TIER-2", },
  { id: "MOA",  kind: "retail", name: "Mall of Africa",          cli: "Hyperion",  on: 20, sch: 20, state: "green",  risk: "TIER-2", },
  { id: "ARG6", kind: "office", name: "Argos-6 Sandton Tower",   cli: "Argus",     on: 8,  sch: 8,  state: "green",  risk: "TIER-1", },
  { id: "ARGR", kind: "resi",   name: "Argus principal residence", cli: "Argus",   on: 6,  sch: 6,  state: "green",  risk: "TIER-1", },
  { id: "KAG1", kind: "indus",  name: "Kagiso Industrial · Plant 1", cli: "Kagiso", on: 12, sch: 14, state: "red",   risk: "TIER-2", },
  { id: "KAG2", kind: "indus",  name: "Kagiso Industrial · Plant 2", cli: "Kagiso", on: 10, sch: 10, state: "green", risk: "TIER-3", },
  { id: "AMB",  kind: "consul", name: "Embassy of Belgium · chancery", cli: "Belgium", on: 8, sch: 8, state: "amber", risk: "TIER-1", },
  { id: "AMB2", kind: "consul", name: "Embassy of Belgium · residence", cli: "Belgium", on: 4, sch: 4, state: "green", risk: "TIER-1", },
  { id: "NEX1", kind: "indus",  name: "Nexus DC · Isando",       cli: "Nexus",     on: 12, sch: 12, state: "green",  risk: "TIER-1", },
  { id: "BRY",  kind: "resi",   name: "Bryanston Village HOA",   cli: "Village",   on: 11, sch: 12, state: "amber",  risk: "TIER-3", },
  { id: "HRT",  kind: "resi",   name: "Hartford Residences",     cli: "Hartford",  on: 3,  sch: 3,  state: "green",  risk: "TIER-3", },
  { id: "SPZ",  kind: "office", name: "Sandton Piazza Trust · plaza", cli: "Piazza", on: 9, sch: 9, state: "green",  risk: "TIER-2", },
  { id: "OPR",  kind: "resi",   name: "Opéra Private Wealth · vault", cli: "Opéra", on: 5, sch: 5, state: "green",   risk: "TIER-1", },
];

const KIND_ICONS = {
  retail: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l1.5-5h15L21 9"/><path d="M4 9h16v11H4z"/><path d="M9 13h6"/></svg>,
  resi:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-7h-6v7H4a1 1 0 0 1-1-1z"/></svg>,
  office: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M5 21V4h10v17M15 10h5v11M8 8h2M8 12h2M8 16h2"/></svg>,
  indus:  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 21V10l6 3V10l6 3V6l6 3v12z"/></svg>,
  consul: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 21V8l8-4 8 4v13"/><path d="M8 21v-6h8v6"/><path d="M12 4v4"/></svg>,
};

const ST_SELECTED = {
  id: "SND",
  kind: "retail",
  name: "Sandton City flagship",
  client: "Hyperion Retail Group",
  addr: "163 5th St, Sandton · Johannesburg · -26.1076, 28.0567",
  tier: "TIER-2",
  posture: "ELEVATED WATCH",
  hours: "24/7 staffed · retail 09:00–21:00",
  infra: {
    cameras: { v: 184, online: 182, k: "CAMERAS", h: "amber", note: "2 offline · cam-147, cam-093" },
    alarms:  { v: 22, online: 22, k: "ALARM ZONES", h: "green", note: "all armed & green" },
    access:  { v: 14, online: 14, k: "ACCESS DOORS", h: "green", note: "12 controlled · 2 manual" },
    panics:  { v: 38, online: 38, k: "PANIC POINTS", h: "green", note: "tested 18 Oct 06:00" },
    radios:  { v: 24, online: 24, k: "RADIOS", h: "green", note: "all paired · TETRA+LTE" },
    vehicles:{ v: 3,  online: 3,  k: "VEHICLES ON-SITE", h: "green", note: "2 response · 1 K9" },
  },
  roster: [
    { av: "TK", n: "T. Khumalo",  r: "Site Controller",      post: "Control room", state: "green" },
    { av: "LC", n: "L. Cele",     r: "Shift Supervisor",     post: "Atrium sweep", state: "green" },
    { av: "VD", n: "V. Dlamini",  r: "K-9 Handler",          post: "East loading", state: "green" },
    { av: "SM", n: "S. Mokoena",  r: "Grade B Officer",      post: "West entrance", state: "green" },
    { av: "NO", n: "N. Opéra",    r: "Grade B Officer",      post: "Parkade P1",   state: "amber" },
    { av: "JM", n: "J. Mokwena",  r: "Grade C Officer",      post: "Parkade P2",   state: "green" },
  ],
  activity: [
    { t: "16:42", ico: "zara", tag: null,    body: "Zara flagged <em>unattended bag</em> · atrium SE near fountain. Patrol dispatched, cleared at 16:47.", src: "CAM-041 · confidence 0.82" },
    { t: "16:18", ico: "access", tag: "open", body: "Access door AD-07 (east loading) propped open 4m 12s. Policy violation notice issued to delivery contractor.", src: "Badge B-8821 · last through 16:14" },
    { t: "15:55", ico: "patrol", tag: "resolved", body: "Patrol route PR-3 complete by <em>L. Cele</em>. 14 checkpoints hit · no anomalies.", src: "Duration 22m · 2.3 km" },
    { t: "14:07", ico: "alarm", tag: "resolved", body: "Panic test — PB-22 at jewellery store activated by staff for monthly drill. Control room acknowledged at 14:07:08.", src: "Test · scheduled" },
    { t: "11:31", ico: "zara", tag: "resolved", body: "Zara correlated 3 loitering subjects at north entrance with earlier shoplifting MO. <em>Escorted out</em> by L. Cele.", src: "INC-7708 · SAPS not required" },
    { t: "09:00", ico: "patrol", tag: "resolved", body: "Shift handover complete. 24/24 posts filled. Site posture ELEVATED WATCH maintained.", src: "Briefing led by T. Khumalo" },
  ],
  risk: {
    score: 4.2, // of 10
    crime: "Contact & burglary 12% above metro mean (30d)",
    facts: [
      { k: "LAST INCIDENT", v: "11 Oct · loiter" },
      { k: "INCIDENTS · 90D", v: "7 total · 0 major" },
      { k: "SAPS PRECINCT", v: "Sandton · 3.2 km" },
      { k: "ZARA VIGILANCE", v: "HEIGHTENED" },
    ],
  },
  env: [
    { k: "WEATHER", v: "22°C · clear", d: "sunset 18:02", tone: "" },
    { k: "POWER", v: "STAGE 2", d: "10-12:30 window", tone: "amber" },
    { k: "TRAFFIC", v: "HEAVY", d: "M1 N · Grayston", tone: "amber" },
    { k: "AIR QUAL.", v: "GOOD", d: "PM2.5 18 µg/m³", tone: "" },
  ],
  contacts: [
    { n: "S. Botha",  r: "Site Owner · Hyperion",   p: "+27 11 883 2200" },
    { n: "M. Reddy",  r: "Centre Manager",          p: "+27 82 447 1198" },
    { n: "Sandton SAPS", r: "Precinct · 3.2 km",    p: "10111" },
    { n: "Netcare 911", r: "MIE provider",          p: "082 911" },
    { n: "City Power", r: "Fault line",             p: "011 375 5555" },
  ],
};

/* ------ Activity icons ------ */
const ST_ACT_ICO = {
  zara:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3l3 6 6 1-4.5 4 1 6-5.5-3-5.5 3 1-6L3 10l6-1z"/></svg>,
  access: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="3" width="14" height="18" rx="1"/><circle cx="15" cy="12" r="1" fill="currentColor"/></svg>,
  patrol: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z"/><path d="M12 7v5l3 2"/></svg>,
  alarm:  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M6 8a6 6 0 1 1 12 0v5l2 3H4l2-3z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>,
};

/* ============ Site plan SVG ============ */
function ST_SitePlan({ show }) {
  // Schematic retail mall footprint: 4 wings + atrium
  // Viewbox 100 x 56 (16:9)
  return (
    <svg viewBox="0 0 160 90" preserveAspectRatio="xMidYMid meet">
      <defs>
        <pattern id="grid" width="8" height="8" patternUnits="userSpaceOnUse">
          <path d="M 8 0 L 0 0 0 8" stroke="rgba(255,255,255,0.04)" strokeWidth="0.3" fill="none"/>
        </pattern>
        <linearGradient id="bldg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="rgba(157,75,255,0.08)"/>
          <stop offset="1" stopColor="rgba(157,75,255,0.02)"/>
        </linearGradient>
      </defs>

      <rect width="160" height="90" fill="url(#grid)"/>

      {/* street labels */}
      <text x="80" y="5" fontFamily="var(--font-mono)" fontSize="3" fill="rgba(180,180,200,0.35)" textAnchor="middle" letterSpacing="0.2">5TH  STREET</text>
      <text x="80" y="87" fontFamily="var(--font-mono)" fontSize="3" fill="rgba(180,180,200,0.35)" textAnchor="middle" letterSpacing="0.2">RIVONIA  RD</text>
      <text x="5" y="45" fontFamily="var(--font-mono)" fontSize="3" fill="rgba(180,180,200,0.35)" textAnchor="middle" letterSpacing="0.2" transform="rotate(-90 5 45)">WEST  ST</text>
      <text x="155" y="45" fontFamily="var(--font-mono)" fontSize="3" fill="rgba(180,180,200,0.35)" textAnchor="middle" letterSpacing="0.2" transform="rotate(-90 155 45)">NELSON  MANDELA</text>

      {/* Main building footprint - Sandton City cross shape */}
      <g>
        {/* North wing */}
        <rect x="60" y="12" width="40" height="22" fill="url(#bldg)" stroke="rgba(157,75,255,0.4)" strokeWidth="0.5"/>
        {/* Central atrium */}
        <rect x="54" y="32" width="52" height="26" fill="url(#bldg)" stroke="rgba(157,75,255,0.45)" strokeWidth="0.5"/>
        {/* West wing */}
        <rect x="20" y="38" width="34" height="16" fill="url(#bldg)" stroke="rgba(157,75,255,0.4)" strokeWidth="0.5"/>
        {/* East wing */}
        <rect x="106" y="38" width="34" height="16" fill="url(#bldg)" stroke="rgba(157,75,255,0.4)" strokeWidth="0.5"/>
        {/* South wing */}
        <rect x="60" y="56" width="40" height="22" fill="url(#bldg)" stroke="rgba(157,75,255,0.4)" strokeWidth="0.5"/>

        {/* atrium glass roof (dashed) */}
        <rect x="72" y="40" width="16" height="10" fill="none" stroke="rgba(205,169,255,0.5)" strokeWidth="0.4" strokeDasharray="1.5 1"/>
        <text x="80" y="46" fontFamily="var(--font-mono)" fontSize="2.5" fill="rgba(205,169,255,0.7)" textAnchor="middle">ATRIUM</text>

        {/* parkade */}
        <rect x="112" y="62" width="28" height="16" fill="rgba(255,255,255,0.02)" stroke="rgba(180,180,200,0.22)" strokeWidth="0.4" strokeDasharray="2 1"/>
        <text x="126" y="72" fontFamily="var(--font-mono)" fontSize="2.5" fill="rgba(180,180,200,0.4)" textAnchor="middle">PARKADE P1–P3</text>

        {/* loading bay */}
        <rect x="102" y="14" width="12" height="8" fill="none" stroke="rgba(180,180,200,0.22)" strokeWidth="0.4" strokeDasharray="2 1"/>
        <text x="108" y="19" fontFamily="var(--font-mono)" fontSize="2.2" fill="rgba(180,180,200,0.4)" textAnchor="middle">LOAD</text>
      </g>

      {/* Patrol route (show.patrols) */}
      {show.patrols && (
        <g opacity="0.9">
          <path d="M 40 46 Q 50 42 64 46 Q 74 52 80 50 Q 92 48 124 46 Q 130 50 126 68"
                fill="none" stroke="#6FE8B0" strokeWidth="0.7" strokeDasharray="1 1"/>
          <circle cx="40" cy="46" r="1.2" fill="#6FE8B0"/>
          <circle cx="126" cy="68" r="1.2" fill="#6FE8B0"/>
          <text x="40" y="42" fontFamily="var(--font-mono)" fontSize="2.2" fill="#6FE8B0" textAnchor="middle">PR-3</text>
        </g>
      )}

      {/* Access points / entrances (show.access) */}
      {show.access && (
        <g>
          {/* North main entrance */}
          <circle cx="80" cy="12" r="1.6" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.4"/>
          <text x="80" y="9" fontFamily="var(--font-mono)" fontSize="2.2" fill="#9DD4FF" textAnchor="middle">N-MAIN</text>
          {/* West entrance */}
          <circle cx="20" cy="46" r="1.6" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.4"/>
          <text x="17" y="42" fontFamily="var(--font-mono)" fontSize="2.2" fill="#9DD4FF" textAnchor="end">W</text>
          {/* East entrance */}
          <circle cx="140" cy="46" r="1.6" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.4"/>
          <text x="143" y="42" fontFamily="var(--font-mono)" fontSize="2.2" fill="#9DD4FF" textAnchor="start">E</text>
          {/* South entrance */}
          <circle cx="80" cy="78" r="1.6" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.4"/>
          <text x="80" y="83" fontFamily="var(--font-mono)" fontSize="2.2" fill="#9DD4FF" textAnchor="middle">S-MAIN</text>
          {/* Loading dock */}
          <circle cx="108" cy="18" r="1.4" fill="#FFD28A" stroke="#0A0912" strokeWidth="0.4"/>
          {/* Parkade */}
          <circle cx="112" cy="70" r="1.4" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.4"/>
          <text x="109" y="74" fontFamily="var(--font-mono)" fontSize="2.2" fill="#9DD4FF" textAnchor="end">P-ENT</text>
        </g>
      )}

      {/* Cameras (show.cameras) — small triangles indicating FOV */}
      {show.cameras && (
        <g opacity="0.95">
          {[
            [70, 14, 180], [90, 14, 180],
            [22, 40, 90], [22, 52, 90],
            [138, 40, 270], [138, 52, 270],
            [64, 34, 135], [96, 34, 225],
            [64, 58, 45], [96, 58, 315],
            [70, 76, 0], [90, 76, 0],
            [56, 45, 90], [104, 45, 270],
            [80, 42, 180], [80, 50, 0],
            [116, 66, 135], [136, 66, 225], [126, 76, 0],
            [108, 16, 270],
          ].map(([x, y, rot], i) => (
            <g key={i} transform={`translate(${x} ${y}) rotate(${rot})`}>
              <circle r="0.7" fill="#CDA9FF"/>
              <path d="M 0 0 L -2.5 -5 L 2.5 -5 Z" fill="rgba(205,169,255,0.22)" stroke="rgba(205,169,255,0.45)" strokeWidth="0.25"/>
            </g>
          ))}
        </g>
      )}

      {/* Alarm zones (show.alarms) — numbered zones */}
      {show.alarms && (
        <g>
          <rect x="62" y="14" width="36" height="18" fill="none" stroke="rgba(0,217,126,0.5)" strokeWidth="0.3" strokeDasharray="1 1"/>
          <text x="64" y="18" fontFamily="var(--font-mono)" fontSize="2" fill="#6FE8B0">Z01</text>
          <rect x="22" y="40" width="30" height="12" fill="none" stroke="rgba(0,217,126,0.5)" strokeWidth="0.3" strokeDasharray="1 1"/>
          <text x="24" y="44" fontFamily="var(--font-mono)" fontSize="2" fill="#6FE8B0">Z08</text>
          <rect x="108" y="40" width="30" height="12" fill="none" stroke="rgba(0,217,126,0.5)" strokeWidth="0.3" strokeDasharray="1 1"/>
          <text x="110" y="44" fontFamily="var(--font-mono)" fontSize="2" fill="#6FE8B0">Z12</text>
          <rect x="62" y="58" width="36" height="18" fill="none" stroke="rgba(0,217,126,0.5)" strokeWidth="0.3" strokeDasharray="1 1"/>
          <text x="64" y="62" fontFamily="var(--font-mono)" fontSize="2" fill="#6FE8B0">Z16</text>
          <rect x="56" y="34" width="48" height="22" fill="none" stroke="rgba(0,217,126,0.5)" strokeWidth="0.3" strokeDasharray="1 1"/>
          <text x="58" y="38" fontFamily="var(--font-mono)" fontSize="2" fill="#6FE8B0">Z22 · ATRIUM</text>
        </g>
      )}

      {/* Posts / Guards (show.posts) */}
      {show.posts && (
        <g>
          {[
            [80, 12, "TK · CR"],   // control room
            [78, 44, "LC"],        // atrium
            [110, 18, "VD · K9"],  // east loading
            [22, 46, "SM"],        // west entrance
            [116, 68, "NO"],       // parkade P1
            [132, 72, "JM"],       // parkade P2
          ].map(([x, y, lbl], i) => (
            <g key={i} transform={`translate(${x} ${y})`}>
              <circle r="1.8" fill="#0A0912" stroke="#6FE8B0" strokeWidth="0.5"/>
              <circle r="0.9" fill="#6FE8B0"/>
              <text x={i === 3 ? 3 : (i === 2 || i >= 4 ? 3 : -3)}
                    y="0.5"
                    fontFamily="var(--font-mono)" fontSize="2"
                    fill="#6FE8B0"
                    textAnchor={i === 3 ? "start" : (i === 2 || i >= 4 ? "start" : "end")}>
                {lbl}
              </text>
            </g>
          ))}
        </g>
      )}

      {/* Live incident marker (always shown — from Zara flag) */}
      <g transform="translate(84 47)">
        <circle r="3" fill="none" stroke="#FFD28A" strokeWidth="0.3" opacity="0.5"/>
        <circle r="2" fill="none" stroke="#FFD28A" strokeWidth="0.4" opacity="0.7"/>
        <circle r="0.9" fill="#FFD28A"/>
        <text x="4" y="1" fontFamily="var(--font-mono)" fontSize="2.3" fill="#FFD28A">UNATTENDED · cleared</text>
      </g>
    </svg>
  );
}

function SitesScreen() {
  const [selId, setSelId] = React.useState("SND");
  const [layers, setLayers] = React.useState({ cameras: true, alarms: false, access: true, posts: true, patrols: true });
  const toggle = (k) => setLayers(l => ({ ...l, [k]: !l[k] }));
  const s = ST_SELECTED;

  return (
    <div className="st-page">

      {/* LEFT */}
      <aside className="st-left">
        <div className="st-left-h">
          <div className="st-left-t">Sites <span className="ct">142</span></div>
          <div className="st-left-s">138 GREEN · 3 AMBER · 1 RED · 24/7 STAFFED</div>
        </div>
        <div className="st-left-filter">
          <button className="on">ALL</button>
          <button>ARMED</button>
          <button>ISSUES</button>
          <button>VIP</button>
        </div>
        <div className="st-facet">
          <button className="on">RETAIL <span className="ct">52</span></button>
          <button>RESI <span className="ct">31</span></button>
          <button>OFFICE <span className="ct">28</span></button>
          <button>INDUS <span className="ct">14</span></button>
          <button>CONSUL <span className="ct">9</span></button>
          <button>OTHER <span className="ct">8</span></button>
        </div>
        <div className="st-list">
          {ST_SITES.map(site => (
            <div key={site.id}
                 className={"st-row" + (site.id === selId ? " sel" : "")}
                 onClick={() => setSelId(site.id)}>
              <div className={"st-row-ico " + site.kind}>{KIND_ICONS[site.kind]}</div>
              <div className="st-row-body">
                <div className="st-row-name">{site.name}</div>
                <div className="st-row-meta">
                  <span className="cli">{site.cli}</span>
                  <span className="sep">·</span>
                  <span>{site.risk}</span>
                </div>
              </div>
              <div className="st-row-manning">
                <div className="v">{site.on}<span className="sl">/{site.sch}</span></div>
                <div className="dot"><span className={"d " + (site.state === "green" ? "" : site.state)}></span>{site.state.toUpperCase()}</div>
              </div>
            </div>
          ))}
        </div>
      </aside>

      {/* CENTER */}
      <section className="st-center">
        <div className="st-hero">
          <div className="st-hero-ico">{KIND_ICONS[s.kind]}</div>
          <div>
            <div className="st-hero-name">{s.name}</div>
            <div className="st-hero-addr">{s.addr}</div>
            <div className="st-hero-tags">
              <span className="pill elev">● {s.posture}</span>
              <span><span className="k">CLIENT</span> {s.client}</span>
              <span className="sep">·</span>
              <span><span className="k">TIER</span> {s.tier}</span>
              <span className="sep">·</span>
              <span><span className="k">HOURS</span> {s.hours}</span>
            </div>
          </div>
          <div className="st-hero-actions">
            <div className="btn-row">
              <button className="btn">Ops log</button>
              <button className="btn">Cameras</button>
              <button className="btn btn-primary">Dispatch</button>
            </div>
            <div className="ts">last patrol sweep · 15:55 · next 17:10</div>
          </div>
        </div>

        {/* site plan */}
        <div className="st-sh">
          <span>SITE PLAN</span>
          <span className="line"></span>
          <span className="sub">live layers · toggle to focus</span>
        </div>
        <div className="st-plan-wrap">
          <div className="st-plan">
            <div className="st-plan-toolbar">
              {[
                ["cameras", "CAMERAS"],
                ["alarms", "ALARMS"],
                ["access", "ACCESS"],
                ["posts", "POSTS"],
                ["patrols", "PATROLS"],
              ].map(([k, lbl]) => (
                <button key={k} className={layers[k] ? "on" : ""} onClick={() => toggle(k)}>{lbl}</button>
              ))}
            </div>
            <div className="st-plan-compass">
              <svg viewBox="0 0 42 42" width="38" height="38">
                <circle cx="21" cy="21" r="15" fill="none" stroke="rgba(180,180,200,0.25)" strokeWidth="0.6"/>
                <path d="M 21 8 L 24 21 L 21 18 L 18 21 Z" fill="#CDA9FF"/>
                <text x="21" y="7" fontFamily="var(--font-mono)" fontSize="5" fill="#CDA9FF" textAnchor="middle" fontWeight="600">N</text>
              </svg>
            </div>
            <div className="st-plan-scale">
              <span className="bar"></span>
              <span>50 m</span>
            </div>
            <ST_SitePlan show={layers} />
          </div>
          <div className="st-plan-legend">
            <h4>Legend</h4>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><path d="M 7 4 L 3 12 L 11 12 Z" fill="rgba(205,169,255,0.4)" stroke="#CDA9FF" strokeWidth="0.6"/><circle cx="7" cy="4" r="1" fill="#CDA9FF"/></svg></div>
              <span>Camera · FOV</span>
              <span className="c">184</span>
            </div>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><circle cx="7" cy="7" r="3" fill="#9DD4FF" stroke="#0A0912" strokeWidth="0.6"/></svg></div>
              <span>Access door</span>
              <span className="c">14</span>
            </div>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><rect x="1" y="1" width="12" height="12" fill="none" stroke="#6FE8B0" strokeWidth="0.8" strokeDasharray="2 1"/></svg></div>
              <span>Alarm zone</span>
              <span className="c">22</span>
            </div>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><circle cx="7" cy="7" r="4" fill="#0A0912" stroke="#6FE8B0" strokeWidth="0.8"/><circle cx="7" cy="7" r="1.8" fill="#6FE8B0"/></svg></div>
              <span>Guard post</span>
              <span className="c">6</span>
            </div>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><path d="M 2 10 Q 5 5 7 7 Q 10 9 12 4" fill="none" stroke="#6FE8B0" strokeWidth="0.8" strokeDasharray="1 1"/></svg></div>
              <span>Patrol route</span>
              <span className="c">5</span>
            </div>
            <div className="st-leg-row">
              <div className="st-leg-glyph"><svg viewBox="0 0 14 14"><circle cx="7" cy="7" r="2" fill="#FFD28A"/><circle cx="7" cy="7" r="5" fill="none" stroke="#FFD28A" strokeWidth="0.5"/></svg></div>
              <span>Live event</span>
              <span className="c">1</span>
            </div>

            <h4 style={{marginTop: 10}}>Layer opacity</h4>
            <div style={{fontFamily:"var(--font-mono)",fontSize:"10px",color:"var(--text-3)",letterSpacing:"0.04em"}}>
              Last synced from <span style={{color:"var(--text-1)"}}>Genetec</span> 16:43<br/>
              4 layers visible · 1 off
            </div>
          </div>
        </div>

        {/* Roster + Infra */}
        <div className="st-sh">
          <span>ROSTER &amp; INFRASTRUCTURE</span>
          <span className="line"></span>
          <span className="sub">current shift · live health</span>
        </div>
        <div className="st-twocol">
          <div className="st-card">
            <div className="st-card-h">
              <span className="t">Shift — 15:00–23:00</span>
              <span className="sub">6 ON · 0 LATE · 0 NO-SHOW</span>
            </div>
            <div className="st-roster">
              <div className="st-roster-head">
                <span>OPERATOR / ROLE</span>
                <span>POST</span>
              </div>
              {s.roster.map((r, i) => (
                <div className="st-roster-row" key={i}>
                  <div className="av">{r.av}</div>
                  <div>
                    <div className="n">{r.n}</div>
                    <div className="r">{r.r}</div>
                  </div>
                  <div className="post">
                    <span className={"d " + (r.state === "green" ? "" : r.state)}></span>
                    {r.post}
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="st-card">
            <div className="st-card-h">
              <span className="t">Infrastructure</span>
              <span className="sub">GENETEC · SECUROS · TETRA</span>
            </div>
            <div className="st-infra">
              {Object.entries(s.infra).map(([key, v]) => (
                <div className="st-infra-cell" key={key}>
                  <div className="k">{v.k}</div>
                  <div className="v">
                    <span>{v.online}</span>
                    <span className="slash">/</span>
                    <span className="total">{v.v}</span>
                  </div>
                  <div className="h">
                    <span className={"d " + (v.h === "green" ? "" : v.h)}></span>
                    {v.note}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Activity */}
        <div className="st-sh">
          <span>ACTIVITY · LAST 8H</span>
          <span className="line"></span>
          <span className="sub">site-scoped events · Zara, alarms, access, patrols</span>
          <span className="link">full ops log</span>
        </div>
        <div className="st-act">
          {s.activity.map((a, i) => (
            <div className="st-act-row" key={i}>
              <div className="t">{a.t}</div>
              <div className={"ico " + a.ico}>{ST_ACT_ICO[a.ico]}</div>
              <div className="body">
                <span dangerouslySetInnerHTML={{__html: a.body}} />
                <span className="src">{a.src}</span>
              </div>
              <div>{a.tag ? <span className={"tag " + a.tag}>{a.tag.toUpperCase()}</span> : <span style={{fontFamily:"var(--font-mono)",fontSize:"10px",color:"var(--text-3)",letterSpacing:"0.08em"}}>INFO</span>}</div>
            </div>
          ))}
        </div>

        <div className="st-spacer"></div>
      </section>

      {/* RIGHT */}
      <aside className="st-right">
        <div className="st-right-h">
          <div className="st-right-t">Risk &amp; environment</div>
          <div className="st-right-s">SCOPED TO {s.id} · AS OF 16:48</div>
        </div>

        <div className="st-rsec">
          <div className="st-rsec-h">
            <span className="t">RISK PROFILE</span>
            <span className="c">{s.tier}</span>
          </div>
          <div className="st-risk-head">
            <span className="big">{s.risk.score}</span>
            <span className="lbl">/ 10 · ELEVATED</span>
          </div>
          <div className="st-risk-bar">
            <div className="f" style={{width: "100%"}}></div>
            <div className="m" style={{left: (s.risk.score * 10) + "%"}}></div>
          </div>
          <div style={{fontSize:"11.5px",color:"var(--text-2)",marginBottom:"10px",lineHeight:"1.4"}}>
            {s.risk.crime}
          </div>
          <div className="st-risk-facts">
            {s.risk.facts.map((f, i) => (
              <div className="row" key={i}><span className="k">{f.k}</span><span className="v">{f.v}</span></div>
            ))}
          </div>
        </div>

        <div className="st-rsec">
          <div className="st-rsec-h">
            <span className="t">ENVIRONMENT</span>
            <span className="c">LIVE</span>
          </div>
          <div className="st-env">
            {s.env.map((e, i) => (
              <div className={"st-env-cell " + e.tone} key={i}>
                <div className="k">{e.k}</div>
                <div className="v">{e.v}</div>
                <div className="d">{e.d}</div>
              </div>
            ))}
          </div>
        </div>

        <div className="st-rsec" style={{borderBottom:0}}>
          <div className="st-rsec-h">
            <span className="t">CONTACTS</span>
            <span className="c">5 ON FILE</span>
          </div>
          {s.contacts.map((c, i) => (
            <div className="st-contact" key={i}>
              <div>
                <div className="n">{c.n}</div>
                <div className="r">{c.r}</div>
              </div>
              <div className="p">{c.p}</div>
            </div>
          ))}
        </div>
      </aside>
    </div>
  );
}

window.SitesScreen = SitesScreen;
