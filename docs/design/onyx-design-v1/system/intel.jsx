// ONYX — Intel
// Threat feed + pattern library. Cross-site signal correlation.

(function () {
  const { useState } = React;
  const Icon = window.Icon;

  const THREADS = [
    {
      id: "IN-0412", sev: "ACTIVE",
      title: "Coordinated loitering — silver sedan ZQ 41 FS GP",
      age: "2h 14m", class: "vehicle",
      tags: [{l:"VEHICLE", t:""}, {l:"ACTIVE", t:"red"}, {l:"3 SITES", t:"brand"}],
      sites: ["MSV", "SMT", "EVT"],
      zBody: "Silver BMW sedan, plate <em>ZQ 41 FS GP</em>, seen across <strong>3 sites</strong> in 14 days: <em>Ms Vallée</em> (3 passes tonight, 22:24–22:38), <em>Sanderton Estate N</em> (pre-dawn pass Oct 16), <em>Everstone Estate</em> (slow drive-by Oct 11). Plate not on Uber/delivery registries. Driver face obscured in all instances. Pattern matches <strong>pre-incident surveillance</strong> profile from the 2024 Rosebank residential series.",
      timeline: [
        { site: "EVT", events: [{ pos: 8,  w: 4, t: "OCT 11 · 03:14", cls: "amber" }] },
        { site: "SMT", events: [{ pos: 38, w: 4, t: "OCT 16 · 05:40", cls: "amber" }] },
        { site: "MSV", events: [
          { pos: 92, w: 2, t: "TONIGHT · 22:24" },
          { pos: 95, w: 2, t: "22:32" },
          { pos: 97, w: 2, t: "22:38" },
        ]},
      ],
      graph: true,
      evidence: [
        { site: "MSV", kind: "ANPR capture", pct: "94%", time: "TONIGHT 22:38" },
        { site: "SMT", kind: "Camera still",  pct: "88%", time: "OCT 16 05:40" },
        { site: "EVT", kind: "Gate camera",   pct: "91%", time: "OCT 11 03:14" },
      ],
    },
    {
      id: "IN-0411", sev: "WATCHING",
      title: "Recurrent fence-vibration pattern — Valley Estate Zone 3",
      age: "4d", class: "perimeter",
      tags: [{l:"PERIMETER", t:""}, {l:"PATTERN", t:""}, {l:"1 SITE", t:""}],
      sites: ["VAL"],
    },
    {
      id: "IN-0410", sev: "ACTIVE",
      title: "Known grievance — former guard posting on social",
      age: "6d", class: "person",
      tags: [{l:"PERSON", t:""}, {l:"ACTIVE", t:"red"}, {l:"VIP-LINKED", t:"brand"}],
      sites: ["MSV"],
    },
    {
      id: "IN-0409", sev: "WATCHING",
      title: "Regional uptick — smash-and-grabs, N1 offramps 21:00–23:30",
      age: "9d", class: "region",
      tags: [{l:"REGION", t:""}, {l:"TREND", t:"amber"}],
      sites: ["OAK", "EVT"],
    },
    {
      id: "IN-0408", sev: "CLOSED",
      title: "Power-surge false-positive cluster — resolved by firmware patch",
      age: "14d", class: "signal",
      tags: [{l:"SIGNAL", t:""}, {l:"CLOSED", t:""}],
      sites: ["DKL", "OAK", "BLR"],
    },
  ];

  const LIBRARY = {
    faces: [
      { id: "P-4120", name: "Unknown M1", sub: "8 appearances · MSV/SMT", tone: "hot" },
      { id: "P-4119", name: "M. Venter",  sub: "Contractor · expired",   tone: "warn" },
      { id: "P-4101", name: "Unknown F2", sub: "2 appearances · EVT",    tone: "" },
      { id: "P-4098", name: "S. Mokoena", sub: "Ex-staff · grievance",   tone: "hot" },
      { id: "P-4097", name: "Unknown M3", sub: "1 appearance · HLB",     tone: "" },
      { id: "P-4077", name: "Delivery A", sub: "Registered · uptown",    tone: "" },
    ],
    plates: [
      { id: "V-112", name: "ZQ 41 FS GP", sub: "BMW · silver · 3 sites",  tone: "hot" },
      { id: "V-111", name: "BH 98 TT GP", sub: "Toyota · white · 1 site", tone: "" },
      { id: "V-110", name: "FG 02 LY GP", sub: "VW · black · 2 sites",    tone: "warn" },
      { id: "V-107", name: "DB 66 RR GP", sub: "Delivery · 1 site",       tone: "" },
    ],
    voices: [
      { id: "VX-22", name: "Known panic impersonator", sub: "2 attempts", tone: "hot" },
      { id: "VX-21", name: "Social engineer (male, SA accent)", sub: "1 attempt", tone: "warn" },
    ],
    signatures: [
      { id: "S-033", name: "Kudu cluster — east fences",   sub: "7 sites · whitelisted", tone: "" },
      { id: "S-031", name: "Rain-on-CAM-7 false-positive", sub: "cluster closed",        tone: "" },
      { id: "S-030", name: "Pre-incident surveillance MO", sub: "14d · 3 sites",          tone: "hot" },
    ],
  };

  function FaceThumb() {
    return (
      <svg viewBox="0 0 60 60" preserveAspectRatio="xMidYMid slice">
        <defs>
          <radialGradient id="fg" cx="50%" cy="45%" r="60%">
            <stop offset="0%" stopColor="#2d3a4c"/>
            <stop offset="100%" stopColor="#0a0d14"/>
          </radialGradient>
        </defs>
        <rect width="60" height="60" fill="url(#fg)"/>
        <ellipse cx="30" cy="26" rx="10" ry="13" fill="rgba(255,255,255,0.15)"/>
        <path d="M 18 50 Q 30 40 42 50 L 42 60 L 18 60 Z" fill="rgba(255,255,255,0.1)"/>
        <circle cx="26" cy="24" r="1.2" fill="rgba(255,255,255,0.5)"/>
        <circle cx="34" cy="24" r="1.2" fill="rgba(255,255,255,0.5)"/>
        <rect x="12" y="12" width="36" height="36" fill="none" stroke="rgba(157,75,255,0.4)" strokeWidth="0.8"/>
      </svg>
    );
  }

  function PlateThumb({ text }) {
    return (
      <svg viewBox="0 0 80 28" preserveAspectRatio="xMidYMid meet" style={{width:"80%", height:"auto"}}>
        <rect width="80" height="28" rx="3" fill="#dde0e4" stroke="#111"/>
        <text x="40" y="20" textAnchor="middle" fontFamily="var(--font-mono)" fontSize="11" fontWeight="700" fill="#111" letterSpacing="0.06em">{text}</text>
      </svg>
    );
  }

  function VoiceThumb() {
    const bars = Array.from({length: 24}, (_,i) => 3 + (Math.sin(i*0.7)*0.5 + Math.cos(i*1.3)*0.5 + 1) * 12);
    return (
      <svg viewBox="0 0 60 60" preserveAspectRatio="xMidYMid meet">
        <rect width="60" height="60" fill="none"/>
        {bars.map((h,i) => <rect key={i} x={2 + i*2.4} y={30 - h/2} width="1.5" height={h} fill="rgba(166,204,244,0.65)"/>)}
      </svg>
    );
  }

  function SigThumb() {
    return (
      <svg viewBox="0 0 60 60" preserveAspectRatio="xMidYMid meet">
        <path d="M 4 48 Q 14 10 24 30 T 44 18 T 58 42" fill="none" stroke="rgba(205,169,255,0.7)" strokeWidth="1.4"/>
        <circle cx="24" cy="30" r="2" fill="#CDA9FF"/>
        <circle cx="44" cy="18" r="2" fill="#CDA9FF"/>
      </svg>
    );
  }

  function LibraryPanel() {
    const [tab, setTab] = useState("plates");
    const tabs = [
      { id: "faces",      label: "FACES",       ct: LIBRARY.faces.length },
      { id: "plates",     label: "PLATES",      ct: LIBRARY.plates.length },
      { id: "voices",     label: "VOICES",      ct: LIBRARY.voices.length },
      { id: "signatures", label: "SIG.",        ct: LIBRARY.signatures.length },
    ];
    const items = LIBRARY[tab];

    return (
      <aside className="in-right">
        <div className="in-right-head">
          <div className="in-right-title">Pattern library</div>
          <div className="in-right-sub">Learned signatures · live</div>
        </div>
        <div className="in-lib-tabs">
          {tabs.map(t => (
            <button key={t.id} className={"in-lib-tab " + (tab === t.id ? "on" : "")} onClick={() => setTab(t.id)}>
              {t.label}<span className="ct">{t.ct}</span>
            </button>
          ))}
        </div>
        <div className="in-lib-list">
          {items.map(it => (
            <div key={it.id} className="in-lib-item">
              <div className="in-lib-thumb">
                <span className="tag">{it.id}</span>
                {tab === "faces" && <FaceThumb/>}
                {tab === "plates" && <PlateThumb text={it.name}/>}
                {tab === "voices" && <VoiceThumb/>}
                {tab === "signatures" && <SigThumb/>}
              </div>
              <div className="in-lib-name">{it.name}</div>
              <div className="in-lib-sub"><span className={it.tone}>{it.sub}</span></div>
            </div>
          ))}
        </div>
      </aside>
    );
  }

  function Timeline({ thread }) {
    if (!thread.timeline) return null;
    return (
      <div className="in-timeline">
        <div className="in-tl-head">
          <span className="lbl">Appearances · 14 days</span>
          <span className="span">OCT 08 → OCT 22 · 22:42 SAST</span>
        </div>
        <div className="in-tl">
          {thread.timeline.map((row, i) => (
            <React.Fragment key={i}>
              <div className="site">
                <span className="g">{row.site}</span>
              </div>
              <div className="track">
                {row.events.map((e, j) => (
                  <div key={j} className={"event " + (e.cls || "")} style={{left: e.pos + "%", minWidth: "64px"}}>
                    {e.t}
                  </div>
                ))}
              </div>
            </React.Fragment>
          ))}
          <div className="in-tl-scale">
            <span/>
            <div className="sc">
              <span>OCT 08</span><span>OCT 11</span><span>OCT 15</span><span>OCT 19</span><span>TONIGHT</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  function ConnectionGraph() {
    return (
      <div className="in-graph">
        <svg viewBox="0 0 600 260" preserveAspectRatio="xMidYMid meet">
          <defs>
            <radialGradient id="nodeGrad" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="rgba(157,75,255,0.35)"/>
              <stop offset="100%" stopColor="rgba(157,75,255,0)"/>
            </radialGradient>
          </defs>

          {/* Central entity */}
          <circle cx="300" cy="130" r="38" fill="url(#nodeGrad)"/>
          <circle cx="300" cy="130" r="22" fill="#141420" stroke="var(--brand)" strokeWidth="1.5"/>
          <text x="300" y="134" className="in-graph-node-lbl">ZQ 41 FS GP</text>
          <text x="300" y="170" className="in-graph-node-sub">VEHICLE · SILVER BMW</text>

          {/* Sites */}
          {[
            { x: 100, y: 70,  lbl: "MSV",  sub: "MS VALLÉE",    strong: true,  note: "3 PASSES" },
            { x: 480, y: 70,  lbl: "SMT",  sub: "SANDERTON N",  strong: false, note: "1 PASS" },
            { x: 100, y: 200, lbl: "EVT",  sub: "EVERSTONE",    strong: false, note: "1 PASS" },
            { x: 480, y: 200, lbl: "INC",  sub: "ROSEBANK SERIES 2024", strong: false, note: "MO MATCH" },
          ].map((n, i) => (
            <g key={i}>
              <path d={`M 300 130 Q ${(300+n.x)/2} ${(130+n.y)/2 - 20} ${n.x} ${n.y}`} className={"in-graph-edge" + (n.strong ? " strong" : "")}/>
              <text x={(300+n.x)/2} y={(130+n.y)/2 - 22} className="in-graph-edge-lbl">{n.note}</text>
              <circle cx={n.x} cy={n.y} r="18" fill="#141420" stroke={n.strong ? "rgba(242,85,85,0.6)" : "var(--border-strong)"} strokeWidth="1.2"/>
              <text x={n.x} y={n.y - 1} className="in-graph-node-lbl">{n.lbl}</text>
              <text x={n.x} y={n.y + 32} className="in-graph-node-sub">{n.sub}</text>
            </g>
          ))}
        </svg>
      </div>
    );
  }

  function EvidenceThumb({ site }) {
    return (
      <svg viewBox="0 0 100 60" preserveAspectRatio="xMidYMid slice">
        <defs>
          <linearGradient id={"eg"+site} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#1d2a3a"/>
            <stop offset="100%" stopColor="#0a0d14"/>
          </linearGradient>
        </defs>
        <rect width="100" height="60" fill={"url(#eg"+site+")"}/>
        {/* Road with sedan silhouette */}
        <path d="M 0 48 L 100 44" stroke="rgba(255,255,255,0.08)" strokeWidth="1"/>
        <rect x="35" y="32" width="30" height="10" rx="2" fill="rgba(200,200,210,0.3)" stroke="rgba(255,255,255,0.15)" strokeWidth="0.4"/>
        <rect x="40" y="28" width="20" height="6" rx="2" fill="rgba(200,200,210,0.22)"/>
        <rect x="38" y="40" width="24" height="3" fill="rgba(0,0,0,0.5)"/>
        <circle cx="42" cy="42" r="1.5" fill="#111"/>
        <circle cx="58" cy="42" r="1.5" fill="#111"/>
        <rect x="41" y="42" width="18" height="3" fill="rgba(255,255,255,0.08)"/>
      </svg>
    );
  }

  function CenterPane({ thread }) {
    return (
      <div className="in-center">
        <div className="in-center-head">
          <div>
            <div className="in-center-title">{thread.title}</div>
            <div className="in-center-sub">{thread.id} · {thread.sev} · {thread.class.toUpperCase()} · AGE {thread.age}</div>
          </div>
          <div className="in-center-actions">
            <button className="btn sm"><Icon name="eye" size={12}/>Scrub evidence</button>
            <button className="btn sm"><Icon name="link" size={12}/>Link to dispatch</button>
            <button className="btn sm primary"><Icon name="escalate" size={12}/>Push to watch</button>
          </div>
        </div>

        <div className="in-thread-body">
          {thread.zBody && (
            <>
              <div className="in-sec-hd"><span>ZARA · PATTERN BRIEF</span><span className="line"/><span>0.91 CONF</span></div>
              <div className="in-zara">
                <div className="in-zara-h">
                  <window.ZAvatar size={18}/>
                  <span>CROSS-SITE CORRELATION</span>
                </div>
                <div className="in-zara-body" dangerouslySetInnerHTML={{__html: thread.zBody}}/>
              </div>
            </>
          )}

          {thread.timeline && (
            <>
              <div className="in-sec-hd"><span>TIMELINE · ACROSS SITES</span><span className="line"/></div>
              <Timeline thread={thread}/>
            </>
          )}

          {thread.graph && (
            <>
              <div className="in-sec-hd"><span>CONNECTION GRAPH</span><span className="line"/></div>
              <ConnectionGraph/>
            </>
          )}

          {thread.evidence && (
            <>
              <div className="in-sec-hd"><span>EVIDENCE · {thread.evidence.length} CAPTURES</span><span className="line"/></div>
              <div className="in-evidence">
                {thread.evidence.map((e, i) => (
                  <div key={i} className="in-ev-card">
                    <div className="in-ev-thumb">
                      <EvidenceThumb site={e.site}/>
                      <span className="site">{e.site}</span>
                      <span className="time">{e.time}</span>
                    </div>
                    <div className="in-ev-body">
                      <div className="in-ev-kind">{e.kind}</div>
                      <div className="in-ev-match"><span className="n">Plate match</span><span className="pct">{e.pct}</span></div>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
          {!thread.zBody && (
            <div style={{padding: "40px 24px", color: "var(--text-3)", fontSize: 13}}>
              <div style={{fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", marginBottom: 8}}>DRAFT</div>
              Zara is still collecting signals for this thread. Full brief will populate once correlation score crosses 0.80.
            </div>
          )}
        </div>
      </div>
    );
  }

  function Intel() {
    const [selected, setSelected] = useState(THREADS[0].id);
    const thread = THREADS.find(t => t.id === selected);
    const [filter, setFilter] = useState("all");

    const filters = [
      { id: "all",      label: "ALL" },
      { id: "ACTIVE",   label: "ACTIVE" },
      { id: "WATCHING", label: "WATCH" },
      { id: "CLOSED",   label: "CLOSED" },
    ];
    const list = filter === "all" ? THREADS : THREADS.filter(t => t.sev === filter);

    return (
      <window.Shell active="intel" title="Intel" crumb="Pattern Library">
        <div className="in-page">
          <div className="in-strip">
            <div>
              <div className="in-title">Signals across sites, over time.</div>
              <div className="in-sub">
                Zara watches <span className="mono">10 sites</span> for recurring patterns — vehicles, faces, voices, MO.
                She surfaces threads when she sees the same thing twice in a way that isn't coincidence.
              </div>
            </div>
            <div className="in-strip-kpi">
              <div className="in-kpi tone-red"><div className="k">Active threads</div><div className="v">{THREADS.filter(t=>t.sev==="ACTIVE").length}</div><div className="d">+1 last 24h</div></div>
              <div className="in-kpi tone-amber"><div className="k">Watching</div><div className="v">{THREADS.filter(t=>t.sev==="WATCHING").length}</div><div className="d">stable</div></div>
              <div className="in-kpi tone-brand"><div className="k">Signatures</div><div className="v">{LIBRARY.plates.length + LIBRARY.faces.length + LIBRARY.voices.length + LIBRARY.signatures.length}</div><div className="d">indexed</div></div>
              <div className="in-kpi"><div className="k">Cross-site hits</div><div className="v">14</div><div className="d">last 14d</div></div>
            </div>
          </div>

          <div className="in-body">
            <aside className="in-left">
              <div className="in-left-head">
                <div className="in-left-title">Threads <span className="ct">{list.length}</span></div>
                <div className="in-left-filter">
                  {filters.map(f => (
                    <button key={f.id} className={filter === f.id ? "on" : ""} onClick={() => setFilter(f.id)}>{f.label}</button>
                  ))}
                </div>
              </div>
              <div className="in-threads">
                {list.map(t => (
                  <div key={t.id} className={"in-thread" + (selected === t.id ? " sel" : "")} onClick={() => setSelected(t.id)}>
                    <div className="in-thread-head">
                      <span className="in-thread-id">{t.id}</span>
                      <span>· {t.class.toUpperCase()}</span>
                      <span className="in-thread-age">{t.age}</span>
                    </div>
                    <div className="in-thread-title">{t.title}</div>
                    <div className="in-thread-meta">
                      {t.tags.map((tg, i) => <span key={i} className={"in-thread-tag " + tg.t}>{tg.l}</span>)}
                    </div>
                    {t.sites && (
                      <div className="in-thread-sites">
                        {t.sites.slice(0,3).map(s => <span key={s} className="g">{s}</span>)}
                        {t.sites.length > 3 && <span className="more">+{t.sites.length-3}</span>}
                        <span style={{marginLeft: 6}}>· {t.sites.length} site{t.sites.length===1?"":"s"}</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </aside>

            <CenterPane thread={thread}/>
            <LibraryPanel/>
          </div>
        </div>
      </window.Shell>
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(<Intel/>);
})();
