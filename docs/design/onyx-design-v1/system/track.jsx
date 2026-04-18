// ONYX — Track (live map)
// Jo'burg / Sandton area stylised cartographic render.
// Sites, guards (stationary), response units (moving), VIP convoy, and Zara awareness heatmap.

(function () {
  const { useState, useEffect, useRef, useMemo } = React;
  const Icon = window.Icon;

  // ============ DATA ============
  // Map uses a 1000x680 virtual coordinate system.
  // Districts & landmark labels, roads (stylised lines), sites.
  const DISTRICTS = [
    { x: 150, y: 90,  label: "RANDBURG" },
    { x: 430, y: 100, label: "SANDOWN" },
    { x: 730, y: 110, label: "SUNNINGHILL" },
    { x: 200, y: 300, label: "ROSEBANK" },
    { x: 500, y: 300, label: "SANDTON CBD" },
    { x: 800, y: 320, label: "WOODMEAD" },
    { x: 260, y: 520, label: "PARKTOWN" },
    { x: 580, y: 540, label: "ILLOVO" },
    { x: 840, y: 560, label: "KELVIN" },
  ];

  // Parks — softened rectangles
  const PARKS = [
    { d: "M 70 210 Q 130 200 180 220 L 200 280 Q 160 300 110 290 Z" },
    { d: "M 640 160 Q 720 150 770 180 L 760 240 Q 700 250 650 230 Z" },
    { d: "M 380 450 Q 450 440 500 460 L 495 510 Q 440 520 385 500 Z" },
  ];

  // Water — Jukskei + small dam
  const WATER = [
    { d: "M 0 400 Q 120 380 220 420 Q 320 450 430 430 Q 540 410 640 460 Q 760 500 900 480 L 1000 500 L 1000 520 Q 860 540 740 510 Q 620 480 500 490 Q 380 500 280 470 Q 160 440 0 460 Z" },
  ];

  // Major + minor roads (M1, N1, Rivonia, Grayston, Katherine, William Nicol etc.)
  const ROADS_MAJOR = [
    { d: "M 0 180 Q 250 200 500 210 Q 750 220 1000 210", label: "N1", lx: 850, ly: 205 },
    { d: "M 500 0 Q 510 200 520 400 Q 530 600 540 680", label: "M1", lx: 535, ly: 420 },
    { d: "M 0 340 Q 250 345 500 350 Q 750 355 1000 360", label: "RIVONIA RD", lx: 660, ly: 347 },
    { d: "M 100 0 Q 180 200 280 380 Q 350 520 420 680", label: "WILLIAM NICOL", lx: 250, ly: 340 },
  ];
  const ROADS_MINOR = [
    { d: "M 0 120 Q 350 125 700 130 L 1000 135" },
    { d: "M 0 260 Q 300 265 600 270 Q 800 275 1000 278" },
    { d: "M 0 460 Q 300 455 600 465 L 1000 470" },
    { d: "M 0 560 Q 400 555 800 568 L 1000 572" },
    { d: "M 200 0 L 220 680" },
    { d: "M 320 0 L 330 680" },
    { d: "M 620 0 L 640 680" },
    { d: "M 760 0 L 780 680" },
    { d: "M 880 0 L 900 680" },
  ];

  // Sites — aligned to districts, Sandton-weighted
  const SITES = [
    { id: "VAL",  name: "Valley Estate", area: "Sandton CBD",  x: 505, y: 300, ev: "red",   guards: 8, staff: 34,  cat: "Perimeter",  incidents: 2 },
    { id: "EVT", name: "Everstone Estate", area: "Sunninghill", x: 720, y: 185, ev: "amber", guards: 6, staff: 28, cat: "Perimeter", incidents: 1 },
    { id: "MSV",  name: "Ms Vallée",       area: "Illovo",      x: 575, y: 540, ev: "red",   guards: 4, staff: 12, cat: "Residence",  incidents: 2 },
    { id: "SMT", name: "Sanderton Estate N", area: "Sandown",    x: 440, y: 170, ev: "amber", guards: 5, staff: 22, cat: "Perimeter",  incidents: 1 },
    { id: "BLR",  name: "Blue Ridge Pk",    area: "Rosebank",    x: 235, y: 310, ev: "ok",    guards: 3, staff: 14, cat: "Community",  incidents: 0 },
    { id: "OAK",  name: "Oakley",           area: "Woodmead",    x: 805, y: 330, ev: "ok",    guards: 3, staff: 10, cat: "Residence",  incidents: 0 },
    { id: "HLB",  name: "Holbrook",         area: "Parktown",    x: 280, y: 520, ev: "amber", guards: 4, staff: 18, cat: "Community",  incidents: 1 },
    { id: "DKL",  name: "Dakley (Camera 9)", area: "Kelvin",     x: 850, y: 555, ev: "ok",    guards: 2, staff: 6,  cat: "Camera-only", incidents: 0 },
    { id: "PRK",  name: "Parkview South",   area: "Randburg",    x: 155, y: 120, ev: "ok",    guards: 3, staff: 16, cat: "Community",  incidents: 0 },
    { id: "MDW",  name: "Meadowlark Place", area: "Sandown",     x: 385, y: 110, ev: "ok",    guards: 2, staff: 8,  cat: "Camera-only", incidents: 0 },
  ];

  // Guards on station, fixed positions (slight drift)
  const GUARDS = [
    { id: "G-214", name: "K. Mofokeng",   site: "VAL",  x: 498, y: 293, status: "engaged", post: "North line" },
    { id: "G-221", name: "S. Pillay",     site: "VAL",  x: 515, y: 308, status: "radio",   post: "East gate" },
    { id: "G-188", name: "T. Dlamini",    site: "EVT",  x: 713, y: 180, status: "ok",      post: "Gatehouse" },
    { id: "G-192", name: "R. Nkosi",      site: "SMT",  x: 445, y: 175, status: "ok",      post: "Roving" },
    { id: "G-207", name: "L. Mbeki",      site: "MSV",  x: 570, y: 545, status: "engaged", post: "Residence" },
    { id: "G-155", name: "J. Coetzee",    site: "BLR",  x: 240, y: 314, status: "ok",      post: "Patrol" },
    { id: "G-167", name: "A. Khumalo",    site: "HLB",  x: 285, y: 517, status: "ok",      post: "Gatehouse" },
    { id: "G-174", name: "P. Sithole",    site: "OAK",  x: 810, y: 335, status: "ok",      post: "Night watch" },
  ];

  // Response units — moving. path points animated along.
  const RESPONSE = [
    {
      id: "R-04",
      name: "Response 04",
      crew: 2,
      toSite: "VAL",
      t: 0.35,
      eta: "02:18",
      path: [[820,180],[700,220],[600,260],[540,290],[505,300]],
    },
    {
      id: "R-11",
      name: "Response 11",
      crew: 2,
      toSite: "MSV",
      t: 0.55,
      eta: "01:40",
      path: [[820,555],[750,558],[680,548],[620,544],[575,540]],
    },
    {
      id: "R-02",
      name: "Response 02",
      crew: 2,
      toSite: null,
      t: 0.5,
      eta: "—",
      patrol: true,
      path: [[180,200],[300,220],[380,260],[280,320],[180,260],[180,200]],
    },
  ];

  // VIP convoy — moving through the map
  const VIP = {
    id: "VIP-Argus",
    name: "Argus principal",
    t: 0.4,
    path: [[60,540],[180,520],[300,500],[420,470],[520,440],[620,410],[720,380]],
    route: "Illovo → Sandton CBD",
    eta: "16:04 arrive",
  };

  // Heatmap blobs — Zara awareness
  const HEAT = [
    { x: 500, y: 310, r: 160, tone: "red"   },
    { x: 570, y: 540, r: 110, tone: "red"   },
    { x: 720, y: 185, r:  90, tone: "amber" },
    { x: 440, y: 170, r:  70, tone: "amber" },
  ];

  // Helpers — interpolate along path
  function pointOn(path, t) {
    const segs = path.length - 1;
    const tt = Math.max(0, Math.min(0.999, t));
    const s = Math.floor(tt * segs);
    const f = (tt * segs) - s;
    const [x1,y1] = path[s], [x2,y2] = path[s+1];
    return { x: x1 + (x2-x1)*f, y: y1 + (y2-y1)*f, angle: Math.atan2(y2-y1, x2-x1)*180/Math.PI };
  }

  // ============ LEFT RAIL ============
  function LeftRail({ selected, onSelect, layers, setLayers }) {
    const pills = [
      { id: "guard",  label: "GUARDS",    tone: "guard"  },
      { id: "resp",   label: "RESPONSE",  tone: "resp"   },
      { id: "vip",    label: "VIP",       tone: "vip"    },
      { id: "site",   label: "SITES",     tone: "site"   },
      { id: "patrol", label: "PATROLS",   tone: "patrol" },
      { id: "heat",   label: "AWARENESS", tone: "heat"   },
    ];
    const sorted = [...SITES].sort((a,b) => {
      const order = { red: 0, amber: 1, ok: 2 };
      return order[a.ev] - order[b.ev];
    });
    return (
      <aside className="tr-left">
        <div className="tr-left-head">
          <div className="tr-left-title">
            <Icon name="layers" size={14}/>
            Live terrain
          </div>
          <div className="tr-left-sub">Gauteng · {SITES.length} sites · 4 response</div>
        </div>
        <div className="tr-layer-row">
          {pills.map(p => (
            <button key={p.id}
              data-tone={p.tone}
              onClick={() => setLayers(l => ({...l, [p.id]: !l[p.id]}))}
              className={"tr-layer-pill " + (layers[p.id] ? "on" : "off")}
            >
              <span className="sw"/>{p.label}
            </button>
          ))}
        </div>
        <div className="tr-sites">
          <div className="tr-sites-head">
            <span>SITES</span>
            <span className="count">{sorted.length}</span>
          </div>
          {sorted.map(s => (
            <div key={s.id}
              className={"tr-site ev-" + s.ev + (selected === s.id ? " sel" : "")}
              onClick={() => onSelect(s.id)}
            >
              <div className="tr-site-glyph">{s.id}</div>
              <div>
                <div className="tr-site-name">{s.name}</div>
                <div className="tr-site-meta">{s.area.toUpperCase()} · {s.cat}</div>
              </div>
              <div className="tr-site-stat">
                <div className="num">{s.guards}/{s.staff}</div>
                <div className="lbl">GRD</div>
              </div>
            </div>
          ))}
        </div>
      </aside>
    );
  }

  // ============ MAP ============
  function MapView({ selected, onSelect, layers, hover, setHover }) {
    const [tick, setTick] = useState(0);
    const live = useRef(true);
    useEffect(() => {
      let raf;
      const loop = () => {
        if (live.current) setTick(t => t + 1);
        raf = requestAnimationFrame(loop);
      };
      raf = requestAnimationFrame(loop);
      return () => cancelAnimationFrame(raf);
    }, []);

    // Animated positions
    const resp = RESPONSE.map(r => {
      const t = (r.t + tick * 0.0006) % 1;
      const pt = pointOn(r.path, r.patrol ? t : Math.min(0.98, r.t + (tick * 0.0002))); // approach slows as incident-bound
      return { ...r, pos: pt };
    });
    const vipPt = pointOn(VIP.path, (VIP.t + tick * 0.0005) % 1);

    const selSite = SITES.find(s => s.id === selected);

    return (
      <div className="tr-map-wrap">
        <div className="tr-map">
          <svg viewBox="0 0 1000 680" preserveAspectRatio="xMidYMid slice">
            <defs>
              <radialGradient id="heatRed" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stopColor="rgba(242,85,85,0.35)"/>
                <stop offset="60%" stopColor="rgba(242,85,85,0.12)"/>
                <stop offset="100%" stopColor="rgba(242,85,85,0)"/>
              </radialGradient>
              <radialGradient id="heatAmber" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stopColor="rgba(245,166,35,0.3)"/>
                <stop offset="60%" stopColor="rgba(245,166,35,0.1)"/>
                <stop offset="100%" stopColor="rgba(245,166,35,0)"/>
              </radialGradient>
              <radialGradient id="sectorGrad" cx="0%" cy="50%" r="100%">
                <stop offset="0%" stopColor="currentColor" stopOpacity="0.6"/>
                <stop offset="100%" stopColor="currentColor" stopOpacity="0"/>
              </radialGradient>
            </defs>

            {/* Land */}
            <rect className="tr-bg-land" x="0" y="0" width="1000" height="680"/>

            {/* Graticule */}
            <g className="tr-bg-graticule">
              {Array.from({length: 21}).map((_,i) => (
                <line key={"h"+i} x1="0" y1={i*35} x2="1000" y2={i*35}/>
              ))}
              {Array.from({length: 30}).map((_,i) => (
                <line key={"v"+i} x1={i*35} y1="0" x2={i*35} y2="680"/>
              ))}
            </g>

            {/* Parks */}
            {PARKS.map((p, i) => <path key={i} d={p.d} className="tr-bg-park"/>)}

            {/* Water */}
            {WATER.map((w, i) => <path key={i} d={w.d} className="tr-bg-water"/>)}

            {/* Roads */}
            <g>
              {ROADS_MINOR.map((r, i) => <path key={i} d={r.d} className="tr-road minor"/>)}
              {ROADS_MAJOR.map((r, i) => <path key={i} d={r.d} className="tr-road major"/>)}
            </g>

            {/* Road labels */}
            {ROADS_MAJOR.map((r, i) => (
              <text key={i} x={r.lx} y={r.ly} className="tr-road-lbl">{r.label}</text>
            ))}

            {/* District labels */}
            {DISTRICTS.map((d, i) => (
              <text key={i} x={d.x} y={d.y} className="tr-district">{d.label}</text>
            ))}

            {/* Heatmap — Zara awareness */}
            {layers.heat && (
              <g className="tr-heat">
                {HEAT.map((h, i) => (
                  <circle key={i} cx={h.x} cy={h.y} r={h.r}
                    fill={h.tone === "red" ? "url(#heatRed)" : "url(#heatAmber)"}/>
                ))}
              </g>
            )}

            {/* VIP trail + marker */}
            {layers.vip && (
              <g className="tr-vip">
                <path d={"M " + VIP.path.map(p => p.join(" ")).join(" L ")} className="trail"/>
                <g transform={`translate(${vipPt.x},${vipPt.y})`}>
                  <circle cx="0" cy="0" r="7" className="body"/>
                  <text y="2.3" className="glyph">V</text>
                </g>
              </g>
            )}

            {/* Response units + arcs */}
            {layers.resp && resp.map(r => {
              const sitePt = r.toSite ? SITES.find(s => s.id === r.toSite) : null;
              return (
                <g key={r.id} className="tr-resp">
                  <path d={"M " + r.path.map(p => p.join(" ")).join(" L ")} className="trail"/>
                  {sitePt && <path d={`M ${r.pos.x} ${r.pos.y} Q ${(r.pos.x+sitePt.x)/2} ${(r.pos.y+sitePt.y)/2 - 25} ${sitePt.x} ${sitePt.y}`} className="tr-inc-arc"/>}
                  <g transform={`translate(${r.pos.x},${r.pos.y}) rotate(${r.pos.angle || 0})`}
                     onMouseEnter={e => setHover({ type: "resp", data: r, x: r.pos.x, y: r.pos.y })}
                     onMouseLeave={() => setHover(null)}>
                    <rect x="-7" y="-5" width="14" height="10" rx="2" className="body" transform="rotate(0)"/>
                    <text y="1.8" className="glyph">{r.id.replace("R-","")}</text>
                  </g>
                </g>
              );
            })}

            {/* Patrol routes (existing guards) */}
            {layers.patrol && (
              <g>
                {/* Patrol 1 — Rosebank loop */}
                <path d="M 220 310 Q 260 290 280 330 Q 260 350 230 340 Q 215 325 220 310 Z"
                      fill="none" stroke="rgba(245,210,138,0.35)" strokeWidth="1" strokeDasharray="3 3"/>
                <path d="M 800 330 Q 840 320 850 360 Q 820 370 795 355 Q 785 340 800 330 Z"
                      fill="none" stroke="rgba(245,210,138,0.35)" strokeWidth="1" strokeDasharray="3 3"/>
              </g>
            )}

            {/* Guards — with sector wedge */}
            {layers.guard && GUARDS.map(g => {
              const angle = (g.id.charCodeAt(g.id.length-1) * 37) % 360;
              return (
                <g key={g.id}
                   className={"tr-guard status-" + g.status}
                   transform={`translate(${g.x},${g.y})`}
                   onMouseEnter={e => setHover({ type: "guard", data: g, x: g.x, y: g.y })}
                   onMouseLeave={() => setHover(null)}>
                  <path d={sectorPath(0, 0, 16, angle-25, angle+25)} className="wedge"/>
                  <circle cx="0" cy="0" r="5" className="body"/>
                  <text y="2" className="glyph">G</text>
                </g>
              );
            })}

            {/* Sites */}
            {layers.site && SITES.map(s => (
              <g key={s.id}
                 className={"tr-site-marker ev-" + s.ev + (selected === s.id ? " sel" : "")}
                 transform={`translate(${s.x},${s.y})`}
                 onClick={() => onSelect(s.id)}
                 onMouseEnter={e => setHover({ type: "site", data: s, x: s.x, y: s.y })}
                 onMouseLeave={() => setHover(null)}>
                {s.ev !== "ok" && <circle className="pulse" cx="0" cy="0" r="10"/>}
                <circle className="ring" cx="0" cy="0" r="10"/>
                <circle className="ring" cx="0" cy="0" r="6" strokeOpacity="0.55"/>
                <circle className="core" cx="0" cy="0" r="3"/>
                <text x="12" y="3" className="label">{s.id}</text>
              </g>
            ))}
          </svg>
        </div>

        {/* Top bar */}
        <div className="tr-map-top">
          <div className="tr-map-search">
            <Icon name="search" size={13}/>
            <span>Find site, guard, plate…</span>
            <kbd>⌘F</kbd>
          </div>
          <button className="tr-map-toggle act">
            <span className="dot brand"/> LIVE · {new Date().toLocaleTimeString("en-GB",{hour12:false})}
          </button>
          <button className="tr-map-toggle" onClick={() => live.current = !live.current}>
            <Icon name="pause" size={12}/>
            FREEZE
          </button>
        </div>

        {/* Side tools */}
        <div className="tr-map-tools">
          <button className="tr-map-tool on" title="2D"><span className="mono" style={{fontSize: 10, fontWeight: 700}}>2D</span></button>
          <button className="tr-map-tool" title="Satellite"><Icon name="eye" size={14}/></button>
          <button className="tr-map-tool" title="Radio coverage"><Icon name="radio" size={14}/></button>
          <button className="tr-map-tool" title="Measure"><span className="mono" style={{fontSize: 9, fontWeight: 700, letterSpacing: 0.08}}>KM</span></button>
          <button className="tr-map-tool" title="Draw geofence"><Icon name="filter" size={14}/></button>
        </div>

        {/* Scale */}
        <div className="tr-map-scale">
          <span className="bar"/>
          <span>500 M</span>
        </div>
        <div className="tr-map-coord">
          <span className="k">CENTER</span>
          <span>−26.1076° S</span>
          <span>28.0567° E</span>
          <span className="k">ZOOM</span>
          <span>14.2</span>
        </div>

        {/* Hover callout */}
        {hover && <Callout hover={hover}/>}
      </div>
    );
  }

  // Sector path helper (for guard cone)
  function sectorPath(cx, cy, r, a0, a1) {
    const rad = a => (a * Math.PI) / 180;
    const x0 = cx + r * Math.cos(rad(a0)), y0 = cy + r * Math.sin(rad(a0));
    const x1 = cx + r * Math.cos(rad(a1)), y1 = cy + r * Math.sin(rad(a1));
    const large = (a1 - a0) > 180 ? 1 : 0;
    return `M ${cx} ${cy} L ${x0} ${y0} A ${r} ${r} 0 ${large} 1 ${x1} ${y1} Z`;
  }

  // Callout positioned over the map — uses percentage (coordinate system is 1000x680)
  function Callout({ hover }) {
    if (!hover) return null;
    const leftPct = (hover.x / 1000) * 100;
    const topPct  = (hover.y / 680) * 100;
    const style = { left: `calc(${leftPct}% )`, top: `calc(${topPct}% )` };
    if (hover.type === "site") {
      const s = hover.data;
      return (
        <div className="tr-callout" style={style}>
          <div className="tr-co-head">
            <div className="tr-co-name">{s.name}</div>
            <div className="tr-co-id">{s.id}</div>
          </div>
          <div className="tr-co-row"><span className="k">area</span><span className="v">{s.area}</span></div>
          <div className="tr-co-row"><span className="k">status</span><span className="v">{s.ev === "red" ? "Engaged" : s.ev === "amber" ? "Elevated" : "Nominal"}</span></div>
          <div className="tr-co-row"><span className="k">on-station</span><span className="v">{s.guards} guard{s.guards===1?"":"s"}</span></div>
          <div className="tr-co-row"><span className="k">open inc.</span><span className="v">{s.incidents}</span></div>
        </div>
      );
    }
    if (hover.type === "guard") {
      const g = hover.data;
      return (
        <div className="tr-callout" style={style}>
          <div className="tr-co-head">
            <div className="tr-co-name">{g.name}</div>
            <div className="tr-co-id">{g.id}</div>
          </div>
          <div className="tr-co-row"><span className="k">site</span><span className="v">{g.site}</span></div>
          <div className="tr-co-row"><span className="k">post</span><span className="v">{g.post}</span></div>
          <div className="tr-co-row"><span className="k">status</span><span className="v">{g.status.toUpperCase()}</span></div>
        </div>
      );
    }
    if (hover.type === "resp") {
      const r = hover.data;
      return (
        <div className="tr-callout" style={style}>
          <div className="tr-co-head">
            <div className="tr-co-name">{r.name}</div>
            <div className="tr-co-id">{r.id}</div>
          </div>
          <div className="tr-co-row"><span className="k">to</span><span className="v">{r.toSite || "PATROL"}</span></div>
          <div className="tr-co-row"><span className="k">crew</span><span className="v">{r.crew}</span></div>
          <div className="tr-co-row"><span className="k">eta</span><span className="v">{r.eta}</span></div>
        </div>
      );
    }
    return null;
  }

  // ============ INSPECTOR ============
  function Inspector({ selected, onSelect }) {
    const site = SITES.find(s => s.id === selected) || SITES[0];
    const guards = GUARDS.filter(g => g.site === site.id);
    const inbound = RESPONSE.filter(r => r.toSite === site.id);

    const stateLabel = site.ev === "red" ? "ENGAGED" : site.ev === "amber" ? "ELEVATED" : "NOMINAL";
    const stateTone = site.ev === "red" ? "red" : site.ev === "amber" ? "amber" : "green";

    return (
      <aside className="tr-right">
        <div className="tr-insp-head">
          <div className="tr-insp-eyebrow">
            <span className={"dot " + stateTone}/>
            <span>SITE · {stateLabel}</span>
            <span style={{marginLeft: "auto", color: "var(--text-3)"}}>{site.id}</span>
          </div>
          <div className="tr-insp-title">{site.name}</div>
          <div className="tr-insp-sub">{site.area.toUpperCase()} · {site.cat.toUpperCase()}</div>
        </div>

        <div className="tr-insp-body">
          <div className="tr-stat-grid">
            <div className="tr-stat"><div className="k">On-station</div><div className="v">{site.guards}<span className="unit">/ {site.staff}</span></div></div>
            <div className="tr-stat"><div className="k">Open incidents</div><div className="v">{site.incidents}</div></div>
            <div className="tr-stat"><div className="k">Perimeter</div><div className="v">{site.ev === "red" ? "Breach" : site.ev === "amber" ? "Anom." : "OK"}</div></div>
            <div className="tr-stat"><div className="k">Cam coverage</div><div className="v">92<span className="unit">%</span></div></div>
          </div>

          <div>
            <div className="tr-meter tone-green">
              <span className="lbl">Radio link</span>
              <span className="val">STRONG · −58 dBm</span>
              <span className="bar"><i style={{width:"88%"}}/></span>
            </div>
            <div className="tr-meter tone-amber">
              <span className="lbl">Anomaly score</span>
              <span className="val">0.74</span>
              <span className="bar"><i style={{width:"74%"}}/></span>
            </div>
            <div className={"tr-meter tone-" + (site.ev === "ok" ? "green" : site.ev === "amber" ? "amber" : "red")}>
              <span className="lbl">Crowd density</span>
              <span className="val">{site.ev === "red" ? "HIGH" : site.ev === "amber" ? "ELEVATED" : "NORMAL"}</span>
              <span className="bar"><i style={{width: site.ev === "red" ? "86%" : site.ev === "amber" ? "58%" : "24%"}}/></span>
            </div>
          </div>

          <div className="tr-insp-zara">
            <div className="tr-insp-zara-head">
              <window.ZAvatar size={18}/>
              <span>ZARA · LIVE READ</span>
            </div>
            <div className="tr-insp-zara-body">
              {site.ev === "red" && <>
                <em>Motion at north fence line</em> — Perimeter team Zone 3 treated at 22:40:26. Two units within radio range; <em>Response 04 inbound, 02:18</em>. Recommended: hold <em>Dispatch</em>, concur on 90%.
              </>}
              {site.ev === "amber" && <>
                <em>Pattern shift detected</em> — Wildlife-class signals recurring at gate C. Sensitivity bumped 6db; Perimeter team advised of false-positive bias. Holding at <em>ELEVATED</em>.
              </>}
              {site.ev === "ok" && <>
                <em>No anomalies in last 4h</em> — All guards at post, heartbeats green. Routine patrol in 00:14. Nothing requires your attention here.
              </>}
            </div>
          </div>

          <div>
            <div className="tr-insp-eyebrow" style={{marginBottom: 8}}>
              <Icon name="guards" size={12}/>
              <span>ON-STATION · {guards.length}</span>
            </div>
            <div className="tr-unit-list">
              {guards.map(g => (
                <div key={g.id} className={"tr-unit status-" + g.status}>
                  <span className="tr-unit-pip"/>
                  <div>
                    <div className="tr-unit-name">{g.name}</div>
                    <div className="tr-unit-role">{g.id} · {g.post.toUpperCase()}</div>
                  </div>
                  <div>
                    <div className="tr-unit-eta">{g.status === "engaged" ? "ACTIVE" : g.status === "radio" ? "ON RADIO" : "OK"}</div>
                    <div className="tr-unit-sub" style={{textAlign:"right"}}>04m ago</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {inbound.length > 0 && (
            <div>
              <div className="tr-insp-eyebrow" style={{marginBottom: 8}}>
                <Icon name="truck" size={12}/>
                <span>INBOUND · {inbound.length}</span>
              </div>
              <div className="tr-unit-list">
                {inbound.map(r => (
                  <div key={r.id} className="tr-unit status-engaged">
                    <span className="tr-unit-pip"/>
                    <div>
                      <div className="tr-unit-name">{r.name}</div>
                      <div className="tr-unit-role">{r.id} · {r.crew} CREW · LIGHTS ON</div>
                    </div>
                    <div>
                      <div className="tr-unit-eta">{r.eta}</div>
                      <div className="tr-unit-sub" style={{textAlign:"right"}}>ETA</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        <div className="tr-insp-act">
          <button className="btn sm"><Icon name="radio" size={13}/>Hail site</button>
          <button className="btn sm"><Icon name="eye" size={13}/>Open cameras</button>
          <button className="btn sm primary"><Icon name="dispatch" size={13}/>Dispatch</button>
        </div>
      </aside>
    );
  }

  // ============ ROOT ============
  function Track() {
    const [selected, setSelected] = useState("VAL");
    const [hover, setHover] = useState(null);
    const [layers, setLayers] = useState({
      guard: true, resp: true, vip: true, site: true, patrol: true, heat: true
    });

    return (
      <window.Shell active="track" title="Track" crumb="Gauteng · Live">
        <div className="tr-page">
          <LeftRail selected={selected} onSelect={setSelected} layers={layers} setLayers={setLayers}/>
          <MapView selected={selected} onSelect={setSelected} layers={layers} hover={hover} setHover={setHover}/>
          <Inspector selected={selected} onSelect={setSelected}/>
        </div>
      </window.Shell>
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(<Track/>);
})();
