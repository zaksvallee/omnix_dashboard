// ONYX — VIP (protective detail operations)
// Principals list + selected principal's full operating picture:
// hero posture, advance brief, today's manifest, detail roster, route, venue, vehicle,
// threats linked to the principal, recent events.

(function () {
  const { useState } = React;
  const Icon = window.Icon;

  const PRINCIPALS = [
    {
      id: "P-ARG",
      name: "Argus principal",
      tier: "TIER 1",
      callsign: "ARGUS-6",
      initials: "AR",
      client: "Argus Holdings",
      state: "moving",
      stateLbl: "MOVING",
      posture: { lbl: "IN TRANSIT", cls: "amber", where: "N1-N · Jan Smuts offramp", note: "2 of 3 legs complete · 9 min to arrival" },
      alert: null,
      advance: "Principal moving from <em>Sandton residence</em> to <em>Melrose Arch Piazza</em> for 19:30 engagement. Route cleared 18:14, <strong>alt routes loaded</strong>. Known grievance contact posted within 6km of venue this afternoon — <strong>flagged for recce</strong>. Weather dry, sunset 18:02.",
      advanceConf: "0.88",
      manifest: [
        { t: "14:30", title: "Office — Sandton Central", where: "Sandton Tower · 34F", tags:[{l:"HOME BASE"}], eta: "CLEARED", etaCls: "done" },
        { t: "17:20", title: "Depart residence", where: "Morningside · R1 safehouse",  tags:[{l:"MOVE", cls:"green"}], eta: "ON TIME", etaCls: "done" },
        { t: "18:55", title: "Transit — Melrose", where: "Route M1 primary",           tags:[{l:"IN PROGRESS", cls:"brand"}, {l:"DETAIL+2"}], eta: "ETA 19:21", etaCls: "current", current: true },
        { t: "19:30", title: "Engagement — Melrose Piazza", where: "Client dinner · back room reserved", tags:[{l:"PUBLIC", cls:"amber"}, {l:"RECCE · 17:50"}], eta: "9 min", etaCls: "good" },
        { t: "22:00", title: "Return — Morningside", where: "Route M2 alt · reviewed", tags:[{l:"MOVE"}], eta: "PLANNED", etaCls: "" },
      ],
      detail: [
        { cs: "A6-1", name: "L. Mazibuko", role: "TEAM LEAD",   st: "ON·STATION", d: "green" },
        { cs: "A6-2", name: "M. Dlamini",  role: "DRIVER",      st: "ON·STATION", d: "green" },
        { cs: "A6-3", name: "P. Nkosi",    role: "ADVANCE",     st: "ON VENUE",   d: "green" },
        { cs: "A6-4", name: "J. Cloete",   role: "TRAIL",       st: "ON·STATION", d: "green" },
        { cs: "A6-5", name: "R. Venter",   role: "MEDIC",       st: "STANDBY",    d: "amber" },
      ],
      route: {
        primary: "M1 · N1 Jan Smuts → Melrose",
        distance: "14.8 km",
        eta: "19:21",
        cleared: true,
        alt: "M2 · Corlett → Athol Oaklands",
      },
      venue: [
        { k: "Venue",     v: "Melrose Arch Piazza",          badge: { l: "ADVANCE ✓", cls: "" } },
        { k: "Advance by",v: "P. Nkosi · A6-3",              badge: { l: "17:50", cls: "brand" } },
        { k: "Arrival",   v: "West service entry",           badge: { l: "CLEARED", cls: "" } },
        { k: "Hold rm.",  v: "Private · Lvl 2, Rm 204",      badge: { l: "SWEPT", cls: "" } },
        { k: "Egress",    v: "East · alt via loading bay",   badge: { l: "READY", cls: "" } },
        { k: "Medical",   v: "Netcare Linksfield · 4.1km",   badge: { l: "4 MIN", cls: "" } },
      ],
      vehicle: { name: "BMW X5 · armoured B6", plate: "GP · ZK 88 JH", stat: "FUEL", val: "82%" },
      threats: [
        { tag: "WATCH", cls: "", age: "36m", body: "Known grievance contact — <em>S. Mokoena</em> posted from Melrose Arch area at 15:42. Zara monitoring." },
        { tag: "ROUTE", cls: "brand", age: "2h", body: "N1-N has unresolved incident ~4km from Jan Smuts offramp. <em>M2 alt cleared</em>." },
      ],
      events: [
        { t: "18:42", k: "MOVE",  body: "Motorcade <em>departed residence</em>. Convoy 2 vehicles + trail." },
        { t: "18:01", k: "ADV",   body: "Advance team on venue. Holding room <em>swept</em>." },
        { t: "17:18", k: "BRIEF", body: "Pre-movement brief complete. 5 of 5 detail acknowledged." },
        { t: "15:42", k: "INTEL", body: "Grievance contact geo-inference within 6km radius of venue." },
        { t: "14:04", k: "NOTE",  body: "Principal confirmed 19:30 engagement." },
      ],
      prefs: [
        { k: "Address",   v: "“Sir” · first name in private" },
        { k: "Seating",   v: "Rear-right · door nearest exit" },
        { k: "Allergies", v: "Shellfish" },
        { k: "Medical",   v: "Netcare Linksfield on file" },
      ],
    },
    {
      id: "P-RND",
      name: "Rand family (2 adults · 3 minors)",
      tier: "TIER 2",
      callsign: "RAND-3",
      initials: "RF",
      client: "Rand Household",
      state: "static",
      stateLbl: "AT HOME",
      posture: { lbl: "STATIC · HOME", cls: "", where: "Ms Vallée · Sandhurst", note: "School run 07:15, static since 08:02" },
      alert: null,
    },
    {
      id: "P-VLK",
      name: "J. Volker",
      tier: "TIER 1",
      callsign: "VULCAN-2",
      initials: "JV",
      client: "Volker Industries",
      state: "travel",
      stateLbl: "INT'L",
      posture: { lbl: "OUT OF COUNTRY", cls: "amber", where: "London · Mayfair", note: "Off-rotation · local detail (Blackstone UK)" },
      alert: { cls: "amber", text: "OFF-ROTATION · passive monitoring only" },
    },
    {
      id: "P-KGM",
      name: "T. Khumalo",
      tier: "TIER 2",
      callsign: "KG-4",
      initials: "TK",
      client: "Khumalo Estate",
      state: "moving",
      stateLbl: "MOVING",
      posture: { lbl: "IN TRANSIT", cls: "amber", where: "Oxford Rd · Rosebank", note: "Routine · school pickup" },
      alert: null,
    },
    {
      id: "P-NDV",
      name: "Ndlovu children (3 minors)",
      tier: "TIER 2",
      callsign: "NDL-5",
      initials: "ND",
      client: "Ndlovu Household",
      state: "static",
      stateLbl: "AT SCHOOL",
      posture: { lbl: "AT SCHOOL", cls: "", where: "St John's · Houghton", note: "Pickup scheduled 15:10" },
      alert: null,
    },
    {
      id: "P-HRT",
      name: "Hartford visitors (2)",
      tier: "TIER 3",
      callsign: "VST-7",
      initials: "HV",
      client: "Hartford Holdings",
      state: "static",
      stateLbl: "AT VENUE",
      posture: { lbl: "STATIC · VENUE", cls: "", where: "The Saxon · Sandhurst", note: "Visitor detail · 48h contract" },
      alert: null,
    },
    {
      id: "P-OPE",
      name: "N. Opéra",
      tier: "TIER 1",
      callsign: "OPERA-1",
      initials: "NO",
      client: "Opéra Family Office",
      state: "off",
      stateLbl: "OFF DETAIL",
      posture: { lbl: "OFF DETAIL", cls: "", where: "Not assigned", note: "Returns 22 Oct · routing pre-loaded" },
      alert: null,
    },
  ];

  /* ---------- Avatar SVG (neutral silhouette) ---------- */
  function PrincipalAvatar({ initials, size = "sm" }) {
    return (
      <>
        <div className="ring"/>
        <span className="init">{initials}</span>
      </>
    );
  }

  /* ---------- Route sketch ---------- */
  function RouteSketch() {
    return (
      <svg viewBox="0 0 260 108" preserveAspectRatio="none">
        <defs>
          <pattern id="vipGrid" width="20" height="20" patternUnits="userSpaceOnUse">
            <path d="M 20 0 L 0 0 0 20" fill="none" stroke="rgba(255,255,255,0.04)" strokeWidth="0.5"/>
          </pattern>
        </defs>
        <rect width="260" height="108" fill="url(#vipGrid)"/>

        {/* Alt route — dashed amber */}
        <path d="M 14 82 Q 50 62 100 70 T 180 50 Q 215 42 246 34"
              fill="none" stroke="rgba(245,166,35,0.6)" strokeWidth="1.3" strokeDasharray="3 3"/>

        {/* Primary route — solid brand */}
        <path d="M 14 82 Q 60 80 110 60 Q 170 34 246 28"
              fill="none" stroke="#CDA9FF" strokeWidth="2" strokeLinecap="round"/>

        {/* Convoy position dot */}
        <g transform="translate(118, 57)">
          <circle r="8" fill="rgba(157,75,255,0.18)"/>
          <circle r="4" fill="#CDA9FF"/>
          <circle r="4" fill="none" stroke="#CDA9FF" strokeWidth="0.5" opacity="0.5">
            <animate attributeName="r" values="4;10;4" dur="2.2s" repeatCount="indefinite"/>
            <animate attributeName="opacity" values="0.5;0;0.5" dur="2.2s" repeatCount="indefinite"/>
          </circle>
        </g>

        {/* Origin / Destination */}
        <circle cx="14" cy="82" r="3" fill="#6FE8B0"/>
        <circle cx="246" cy="28" r="3" fill="#FFB4B4"/>

        {/* Labels */}
        <text x="14" y="98" fontFamily="var(--font-mono)" fontSize="7.5" fill="rgba(255,255,255,0.75)" letterSpacing="0.06em">RES</text>
        <text x="246" y="20" fontFamily="var(--font-mono)" fontSize="7.5" fill="rgba(255,255,255,0.75)" textAnchor="end" letterSpacing="0.06em">VEN</text>

        {/* Roads faint */}
        <path d="M 0 40 L 260 48" stroke="rgba(166,204,244,0.08)" strokeWidth="8" fill="none"/>
        <path d="M 0 40 L 260 48" stroke="rgba(166,204,244,0.12)" strokeWidth="0.4" fill="none" strokeDasharray="4 4"/>
      </svg>
    );
  }

  /* ---------- Principal list item ---------- */
  function PrincipalRow({ p, selected, onSelect }) {
    return (
      <div className={"vip-princ" + (selected ? " sel" : "")} onClick={() => onSelect(p.id)}>
        <div className="vip-princ-avatar">
          <PrincipalAvatar initials={p.initials}/>
        </div>
        <div className="vip-princ-body">
          <div className="vip-princ-name">{p.name}</div>
          <div className="vip-princ-meta">
            <span>{p.tier}</span>
            <span>·</span>
            <span className="cs">{p.callsign}</span>
          </div>
        </div>
        <div className="vip-princ-state">
          <span className={"vip-princ-pulse " + p.state}/>
          <span className="pulse-lbl">{p.stateLbl}</span>
        </div>
        {p.alert && (
          <div className={"vip-princ-alert " + (p.alert.cls || "")}>
            <span>⚠</span>
            <span>{p.alert.text}</span>
          </div>
        )}
      </div>
    );
  }

  /* ---------- Left: Principals panel ---------- */
  function LeftPanel({ selected, onSelect }) {
    const [filter, setFilter] = useState("all");
    const filters = [
      { id: "all",    label: "ALL" },
      { id: "active", label: "ACTIVE" },
      { id: "t1",     label: "TIER 1" },
      { id: "off",    label: "OFF" },
    ];
    const list = PRINCIPALS.filter(p => {
      if (filter === "all") return true;
      if (filter === "active") return p.state !== "off" && p.state !== "travel";
      if (filter === "t1") return p.tier === "TIER 1";
      if (filter === "off") return p.state === "off" || p.state === "travel";
    });
    return (
      <aside className="vip-left">
        <div className="vip-left-head">
          <div className="vip-left-title">
            Principals <span className="ct">{PRINCIPALS.length}</span>
          </div>
          <div className="vip-left-sub">Active details · today</div>
        </div>
        <div className="vip-left-filter">
          {filters.map(f => (
            <button key={f.id} className={filter === f.id ? "on" : ""} onClick={() => setFilter(f.id)}>
              {f.label}
            </button>
          ))}
        </div>
        <div className="vip-princ-list">
          {list.map(p => (
            <PrincipalRow key={p.id} p={p} selected={selected === p.id} onSelect={onSelect}/>
          ))}
        </div>
      </aside>
    );
  }

  /* ---------- Center: Principal detail ---------- */
  function CenterPanel({ p }) {
    if (!p) return null;
    const full = p.manifest && p.detail && p.advance;

    return (
      <main className="vip-center">
        {/* Hero */}
        <div className="vip-hero">
          <div className="vip-hero-avatar">
            <PrincipalAvatar initials={p.initials} size="lg"/>
          </div>
          <div>
            <div className="vip-hero-name">{p.name}</div>
            <div className="vip-hero-meta">
              <span className="tier">{p.tier}</span>
              <span>{p.callsign}</span>
              <span className="dotsep">·</span>
              <span>{p.client}</span>
            </div>
            <div className="vip-hero-posture">
              <span className={"dot " + (p.state === "moving" ? "amber" : p.state === "static" ? "green" : p.state === "travel" ? "amber" : "")}/>
              <span className={"state " + (p.posture.cls || "")}>{p.posture.lbl}</span>
              <span>· {p.posture.where}</span>
              <span>· {p.posture.note}</span>
            </div>
          </div>
          <div className="vip-hero-actions">
            <div className="btn-row">
              <button className="btn sm"><Icon name="map" size={12}/>Open on map</button>
              <button className="btn sm"><Icon name="events" size={12}/>Itinerary</button>
            </div>
            <div className="btn-row">
              <button className="btn sm"><Icon name="link" size={12}/>Link event</button>
              <button className="btn sm primary"><Icon name="bell" size={12}/>Hail detail</button>
            </div>
          </div>
        </div>

        {!full && (
          <div style={{padding: "60px 24px", color: "var(--text-3)", fontSize: 13}}>
            <div style={{fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", marginBottom: 8}}>NOT ACTIVE</div>
            Full operating picture is only shown for principals with an active detail today.
            {" "}Select another principal from the list, or view the archive from Itinerary.
          </div>
        )}

        {full && (
          <>
            {/* Zara advance brief */}
            <div className="vip-sec-hd">
              <span>ZARA · ADVANCE BRIEF</span>
              <span className="line"/>
              <span className="sub">brief compiled {p.advanceConf} conf</span>
            </div>
            <div className="vip-advance">
              <div className="vip-advance-h">
                <window.ZAvatar size={18}/>
                <span>TODAY'S MOVEMENT</span>
                <span className="conf">CONF {p.advanceConf}</span>
              </div>
              <div className="vip-advance-body" dangerouslySetInnerHTML={{__html: p.advance}}/>
            </div>

            {/* Manifest */}
            <div className="vip-sec-hd">
              <span>MANIFEST · TODAY</span>
              <span className="line"/>
              <span className="sub">{p.manifest.length} movements · 3 of 5 complete</span>
            </div>
            <div className="vip-manifest">
              <div className="vip-manifest-head">
                <span className="lbl">Argus principal · 22 Oct</span>
                <span className="meta">ALL TIMES SAST · AS OF 18:53</span>
              </div>
              {p.manifest.map((row, i) => (
                <div key={i} className={"vip-manifest-row " + (row.etaCls || "")}>
                  <div className="vip-manifest-time">{row.t}</div>
                  <div className="spine"><div className="node"/></div>
                  <div className="vip-manifest-content">
                    <div className="vip-manifest-title">{row.title}</div>
                    <div className="vip-manifest-where">{row.where}</div>
                    <div className="vip-manifest-tags">
                      {row.tags.map((tg, j) => (
                        <span key={j} className={"vip-manifest-tag " + (tg.cls || "")}>{tg.l}</span>
                      ))}
                    </div>
                  </div>
                  <div className="vip-manifest-eta">
                    <span className={row.etaCls === "good" ? "good" : row.etaCls === "current" ? "warn" : ""}>
                      {row.eta}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            {/* Roster + route cards */}
            <div className="vip-sec-hd">
              <span>DETAIL &amp; ROUTE</span>
              <span className="line"/>
            </div>
            <div className="vip-grid">
              <div className="vip-gridcard">
                <div className="vip-gridcard-h">
                  <span className="t">Detail on rotation</span>
                  <span className="sub">{p.detail.length} · all acknowledged</span>
                </div>
                <div className="vip-roster">
                  {p.detail.map((m, i) => (
                    <div key={i} className="vip-roster-row">
                      <span className="cs">{m.cs}</span>
                      <span className="name">{m.name}</span>
                      <span className="role">{m.role}</span>
                      <span className="status"><span className={"d " + m.d}/>{m.st}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="vip-gridcard">
                <div className="vip-gridcard-h">
                  <span className="t">Route · primary</span>
                  <span className="sub">{p.route.primary}</span>
                </div>
                <div className="vip-route">
                  <RouteSketch/>
                  <div className="vip-route-legend">
                    <span><span className="sw" style={{background:"#CDA9FF"}}/>PRIMARY</span>
                    <span><span className="sw" style={{background:"rgba(245,166,35,0.6)", borderTop:"1px dashed #FFD28A"}}/>ALT</span>
                  </div>
                </div>
                <div className="vip-route-stats">
                  <div className="st"><span className="k">Distance</span><span className="v">{p.route.distance}</span></div>
                  <div className="st"><span className="k">ETA</span><span className="v warn">{p.route.eta}</span></div>
                  <div className="st"><span className="k">Status</span><span className="v good">CLEARED</span></div>
                  <div className="st"><span className="k">Alt</span><span className="v" style={{fontSize:10.5, color:"var(--text-2)"}}>{p.route.alt}</span></div>
                </div>
              </div>
            </div>

            {/* Venue advance + vehicle */}
            <div className="vip-sec-hd">
              <span>VENUE ADVANCE &amp; VEHICLE</span>
              <span className="line"/>
            </div>
            <div className="vip-grid" style={{marginBottom: 8}}>
              <div className="vip-gridcard">
                <div className="vip-gridcard-h">
                  <span className="t">Venue advance</span>
                  <span className="sub">19:30 · Melrose Arch</span>
                </div>
                <div className="vip-venue">
                  {p.venue.map((row, i) => (
                    <div key={i} className="vip-venue-row">
                      <span className="k">{row.k}</span>
                      <span className="v">{row.v}</span>
                      <span className={"badge " + (row.badge.cls || "")}>{row.badge.l}</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="vip-gridcard">
                <div className="vip-gridcard-h">
                  <span className="t">Principal vehicle</span>
                  <span className="sub">armoured · B6 rated</span>
                </div>
                <div style={{display:"flex", alignItems:"center", gap:14}}>
                  <svg viewBox="0 0 120 70" style={{width:140, height:80, flexShrink:0}}>
                    <defs>
                      <linearGradient id="carG" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0" stopColor="#2a2a3c"/>
                        <stop offset="1" stopColor="#14141f"/>
                      </linearGradient>
                    </defs>
                    {/* SUV silhouette */}
                    <path d="M 14 48 L 22 32 L 44 26 L 82 26 L 98 32 L 108 44 L 108 54 L 14 54 Z"
                          fill="url(#carG)" stroke="var(--border-strong)" strokeWidth="0.8"/>
                    <path d="M 28 32 L 46 30 L 46 42 L 28 42 Z" fill="rgba(166,204,244,0.12)" stroke="rgba(166,204,244,0.22)" strokeWidth="0.4"/>
                    <path d="M 52 30 L 76 30 L 78 42 L 50 42 Z" fill="rgba(166,204,244,0.12)" stroke="rgba(166,204,244,0.22)" strokeWidth="0.4"/>
                    <path d="M 82 32 L 96 34 L 96 42 L 80 42 Z" fill="rgba(166,204,244,0.12)" stroke="rgba(166,204,244,0.22)" strokeWidth="0.4"/>
                    <circle cx="34" cy="56" r="7" fill="#0a0a12" stroke="var(--border-strong)" strokeWidth="0.6"/>
                    <circle cx="34" cy="56" r="3" fill="#2a2a3c"/>
                    <circle cx="90" cy="56" r="7" fill="#0a0a12" stroke="var(--border-strong)" strokeWidth="0.6"/>
                    <circle cx="90" cy="56" r="3" fill="#2a2a3c"/>
                    <rect x="100" y="40" width="8" height="4" fill="rgba(245,222,179,0.6)"/>
                    <text x="60" y="50" fontFamily="var(--font-mono)" fontSize="5.5" fontWeight="700" fill="#E4CFFF" textAnchor="middle" letterSpacing="0.06em">B6</text>
                  </svg>
                  <div style={{flex:1, minWidth:0}}>
                    <div className="vip-veh-name">{p.vehicle.name}</div>
                    <div className="vip-veh-plate">{p.vehicle.plate}</div>
                    <div style={{display:"flex", gap:14, marginTop:10}}>
                      <div className="vip-veh-stat" style={{textAlign:"left"}}>
                        <span>Fuel</span>
                        <span className="v" style={{color:"#6FE8B0"}}>82%</span>
                      </div>
                      <div className="vip-veh-stat" style={{textAlign:"left"}}>
                        <span>Last svc.</span>
                        <span className="v">09/22</span>
                      </div>
                      <div className="vip-veh-stat" style={{textAlign:"left"}}>
                        <span>Tracker</span>
                        <span className="v" style={{color:"#6FE8B0"}}>ONLINE</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="vip-spacer"/>
          </>
        )}
      </main>
    );
  }

  /* ---------- Right: Threats + Events + Prefs ---------- */
  function RightPanel({ p }) {
    if (!p || !p.threats) {
      return (
        <aside className="vip-right">
          <div className="vip-right-head">
            <div className="vip-right-title">Signals &amp; events</div>
            <div className="vip-right-sub">Select an active principal</div>
          </div>
        </aside>
      );
    }
    return (
      <aside className="vip-right">
        <div className="vip-right-head">
          <div className="vip-right-title">Signals &amp; events</div>
          <div className="vip-right-sub">Scoped to {p.callsign} · last 24h</div>
        </div>

        <div className="vip-right-sec">
          <div className="vip-right-sec-h">
            <span className="t">Threats &amp; watches</span>
            <span className="ct">{p.threats.length}</span>
          </div>
          {p.threats.map((th, i) => (
            <div key={i} className={"vip-threat " + (th.cls || "")}>
              <div className="vip-threat-h">
                <span className="tg">{th.tag}</span>
                <span className="age">{th.age}</span>
              </div>
              <div className="vip-threat-body" dangerouslySetInnerHTML={{__html: th.body}}/>
            </div>
          ))}
        </div>

        <div className="vip-right-sec">
          <div className="vip-right-sec-h">
            <span className="t">Recent events</span>
            <span className="ct">{p.events.length}</span>
          </div>
          {p.events.map((e, i) => (
            <div key={i} className="vip-event">
              <span className="t">{e.t}</span>
              <span className="b"><span className="k">{e.k}</span><span dangerouslySetInnerHTML={{__html: e.body}}/></span>
            </div>
          ))}
        </div>

        <div className="vip-right-sec" style={{borderBottom:0}}>
          <div className="vip-right-sec-h">
            <span className="t">Standing preferences</span>
          </div>
          {p.prefs.map((pr, i) => (
            <div key={i} className="vip-pref">
              <span className="k">{pr.k}</span>
              <span className="v">{pr.v}</span>
            </div>
          ))}
        </div>
      </aside>
    );
  }

  /* ---------- Root ---------- */
  function VIP() {
    const [selected, setSelected] = useState("P-ARG");
    const p = PRINCIPALS.find(x => x.id === selected);
    return (
      <window.Shell active="vip" title="VIP" crumb="Protective Detail">
        <div className="vip-page">
          <LeftPanel selected={selected} onSelect={setSelected}/>
          <CenterPanel p={p}/>
          <RightPanel p={p}/>
        </div>
      </window.Shell>
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(<VIP/>);
})();
