/* ============================================================
   Clients — account book, coverage, health, commercial
   ============================================================ */

const CL_CLIENTS = [
  { id: "ARG", name: "Argus Holdings", tier: "PLAT", pulse: "green", mrr: "R 2.41M", sites: 12, term: "Mar 2028", state: "Healthy", since: "2018" },
  { id: "KAG", name: "Kagiso Industrial", tier: "GOLD", pulse: "amber", mrr: "R 1.18M", sites: 8, term: "Jul 2026", state: "SLA drift", since: "2021" },
  { id: "HYP", name: "Hyperion Retail Group", tier: "PLAT", pulse: "green", mrr: "R 3.62M", sites: 47, term: "Dec 2027", state: "Healthy", since: "2015" },
  { id: "AMB", name: "Embassy of Belgium", tier: "GOLD", pulse: "red", mrr: "R 0.94M", sites: 3, term: "Feb 2026", state: "Renewal at risk", since: "2019" },
  { id: "VLG", name: "Bryanston Village HOA", tier: "SLVR", pulse: "green", mrr: "R 0.38M", sites: 1, term: "Oct 2026", state: "Healthy", since: "2020" },
  { id: "NEX", name: "Nexus Data Centres", tier: "PLAT", pulse: "green", mrr: "R 1.88M", sites: 4, term: "Apr 2029", state: "Healthy", since: "2022" },
  { id: "SPZ", name: "Sandton Piazza Trust", tier: "GOLD", pulse: "amber", mrr: "R 0.72M", sites: 2, term: "Nov 2025", state: "Renewal open", since: "2019" },
  { id: "GLD", name: "Golden Reef Mining", tier: "GOLD", pulse: "green", mrr: "R 1.44M", sites: 6, term: "Aug 2027", state: "Healthy", since: "2017" },
  { id: "HRT", name: "Hartford Residences", tier: "SLVR", pulse: "green", mrr: "R 0.22M", sites: 1, term: "May 2026", state: "Healthy", since: "2023" },
  { id: "OPR", name: "Opéra Private Wealth", tier: "PLAT", pulse: "green", mrr: "R 0.86M", sites: 1, term: "Jun 2028", state: "Healthy", since: "2020" },
];

const CL_SELECTED = {
  id: "HYP",
  name: "Hyperion Retail Group",
  initials: "HY",
  tier: "PLATINUM",
  since: "Nov 2015 · 10 yr",
  am: "R. Ngcobo",
  acct: "ARG-C-0042",
  mrr_now: "R 3.62M",
  mrr_delta: "+R 92k",
  mrr_pct: "+2.6%",
  trend: [3.42, 3.44, 3.43, 3.45, 3.46, 3.48, 3.47, 3.49, 3.51, 3.53, 3.52, 3.55, 3.58, 3.57, 3.59, 3.61, 3.60, 3.62],
  posture: "HEALTHY",
  contract: {
    start: "01 Dec 2024",
    end: "30 Dec 2027",
    elapsed: 0.31,
    term: "36-month · auto-renew with 90-day notice",
    value: "R 148.6M TCV",
    billing: "Monthly, net-30",
    aup: "v3.2 · 14 Mar 2025",
  },
  coverage: {
    sites: { count: 47, list: [
      { n: "Sandton City flagship", c: "24/7" },
      { n: "Menlyn Maine", c: "24/7" },
      { n: "V&A Waterfront", c: "24/7" },
      { n: "Mall of Africa", c: "24/7" },
      { n: "+ 43 stores", c: "HR-only" },
    ]},
    guards: { count: 146, list: [
      { n: "Grade A officers", c: "24" },
      { n: "Grade B officers", c: "98" },
      { n: "K-9 handlers", c: "6" },
      { n: "EP / close-protect", c: "4" },
      { n: "Relief pool", c: "14" },
    ]},
    vehicles: { count: 18, list: [
      { n: "Response (armoured)", c: "4" },
      { n: "Response (soft)", c: "8" },
      { n: "Executive transport", c: "2" },
      { n: "K-9 units", c: "2" },
      { n: "Utility", c: "2" },
    ]},
    systems: { count: 12, list: [
      { n: "Alarm monitoring", c: "all sites" },
      { n: "CCTV analytics", c: "42 sites" },
      { n: "ANPR gates", c: "6 sites" },
      { n: "Radio net", c: "Tetra+LTE" },
      { n: "AI camera review", c: "Zara" },
    ]},
  },
  issues: [
    { id: "TK-884", body: "Sandton City — <em>duress alarm</em> response took 11 min on Sun 20 Oct (SLA 8). Root cause: N1 closure detour. Credit memo issued.", src: "INC-7692 · ticket closed · credit R 12k", sev: "p1" },
    { id: "TK-881", body: "Menlyn — requested additional K-9 sweeps Fri-Sat evenings for 8-week holiday window. Quote prepared.", src: "Requested 22 Oct by Y. Pillay (client ops)", sev: "info" },
    { id: "TK-876", body: "V&A Waterfront — CCTV analytics false-positive rate above contract threshold (2.1% vs 1.5%). Zara retrained; now tracking at 1.3%.", src: "Resolved 18 Oct · Zara model v6.3 deployed", sev: "p2" },
    { id: "TK-870", body: "Rosebank store cluster — shift rotation dispute. Two officers requested reassignment. HR completed 14 Oct.", src: "Closed · no client impact", sev: "info" },
  ],
  contacts: [
    { n: "Yolanda Pillay", r: "Head of Asset Protection · client side", av: "YP" },
    { n: "David Mohale", r: "Executive Sponsor · COO", av: "DM" },
    { n: "R. Ngcobo", r: "Account Manager · ONYX", av: "RN" },
    { n: "A. de Souza", r: "Delivery Lead · ONYX", av: "AS" },
  ],
  signals: [
    { tone: "brand", tag: "EXPANSION SIGNAL · CONFIDENCE 0.78", body: "Client-side RFP circulating for 6 new stores opening Q1 2026. Scope fits current AUP. AM briefed." },
    { tone: "", tag: "RENEWAL · 26 MO OUT", body: "Contract auto-renews Dec 2027. No churn signals detected. Current NPS 71." },
    { tone: "amber", tag: "EXCEPTION · CREDIT MEMO", body: "R 12k credit issued against SOP-R-03 breach at Sandton flagship. No pattern." },
  ],
  touchpoints: [
    { t: "22 Oct", k: "MTG", body: "QBR with <em>Y. Pillay</em> and <em>D. Mohale</em>. Reviewed Oct incidents, confirmed expansion scope. Satisfaction: high." },
    { t: "18 Oct", k: "EMAIL", body: "Delivery confirmation for Zara v6.3 retrain. Acknowledged by client ops." },
    { t: "14 Oct", k: "SITE", body: "Site walk at Menlyn Maine. Reviewed K-9 sweep proposal with floor manager." },
    { t: "09 Oct", k: "CALL", body: "Weekly ops sync. 3 minor items, all on track." },
  ],
};

function CL_Spark({ data }) {
  const w = 260, h = 48, p = 4;
  const min = Math.min(...data) - 0.05;
  const max = Math.max(...data) + 0.05;
  const range = max - min || 1;
  const pts = data.map((v, i) => [
    p + (i / (data.length - 1)) * (w - 2 * p),
    p + (1 - (v - min) / range) * (h - 2 * p),
  ]);
  const d = "M " + pts.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(" L ");
  const area = d + ` L ${pts[pts.length-1][0].toFixed(1)} ${h-p} L ${p} ${h-p} Z`;
  const last = pts[pts.length - 1];
  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
      <defs>
        <linearGradient id="clspark-f" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#00D97E" stopOpacity="0.18" />
          <stop offset="100%" stopColor="#00D97E" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill="url(#clspark-f)" />
      <path d={d} stroke="#6FE8B0" strokeWidth="1.25" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={last[0]} cy={last[1]} r="2.5" fill="#6FE8B0" />
    </svg>
  );
}

function CL_Row({ c, selected, onClick }) {
  return (
    <div className={"cl-row" + (selected ? " sel" : "")} onClick={onClick}>
      <div className="cl-logo">
        {c.id.slice(0,2)}
        <span className={"pulse " + (c.pulse === "green" ? "" : c.pulse)}></span>
      </div>
      <div className="cl-row-body">
        <div className="cl-row-name">
          {c.name}
          <span className={"tier " + (c.tier === "PLAT" ? "plat" : c.tier === "GOLD" ? "gold" : "")}>{c.tier}</span>
        </div>
        <div className="cl-row-meta">
          <span>{c.sites} {c.sites === 1 ? "site" : "sites"}</span>
          <span className="sep">·</span>
          <span>{c.state}</span>
        </div>
      </div>
      <div className="cl-row-mrr">
        {c.mrr}<span className="u">/ MO</span>
      </div>
    </div>
  );
}

function ClientsScreen() {
  const [selId, setSelId] = React.useState("HYP");
  const c = CL_SELECTED;

  return (
    <div className="cl-page">

      {/* LEFT */}
      <aside className="cl-left">
        <div className="cl-left-h">
          <div className="cl-left-t">
            Clients <span className="ct">38</span>
          </div>
          <div className="cl-left-s">R 14.82M MRR · 91.3% RETAINED</div>
        </div>
        <div className="cl-left-filter">
          <button className="on">ALL</button>
          <button>HEALTHY</button>
          <button>AT RISK</button>
          <button>RENEWAL</button>
        </div>
        <div className="cl-sort">
          <span>SORT</span>
          <span className="chip on">MRR ↓</span>
          <span className="chip">HEALTH</span>
          <span className="chip">TERM</span>
        </div>
        <div className="cl-list">
          {CL_CLIENTS.map(cc => (
            <CL_Row key={cc.id} c={cc} selected={cc.id === selId} onClick={() => setSelId(cc.id)} />
          ))}
        </div>
      </aside>

      {/* CENTER */}
      <section className="cl-center">

        {/* HERO */}
        <div className="cl-hero">
          <div className="cl-hero-logo">{c.initials}</div>
          <div>
            <div className="cl-hero-name">{c.name}</div>
            <div className="cl-hero-tags">
              <span className="pill good">● {c.posture}</span>
              <span><span className="k">TIER</span> {c.tier}</span>
              <span className="sep">·</span>
              <span><span className="k">SINCE</span> {c.since}</span>
              <span className="sep">·</span>
              <span><span className="k">ACCT</span> {c.acct}</span>
              <span className="sep">·</span>
              <span><span className="k">AM</span> {c.am}</span>
            </div>
          </div>
          <div className="cl-hero-actions">
            <div className="btn-row">
              <button className="btn">Log touchpoint</button>
              <button className="btn">Open contract</button>
              <button className="btn btn-primary">Create ticket</button>
            </div>
            <div className="ts">last QBR 22 Oct · next 15 Jan</div>
          </div>
        </div>

        {/* KPI strip */}
        <div className="cl-kpi-strip">
          <div className="cl-kpi good"><div className="k">MRR</div><div className="v">{c.mrr_now}</div><div className="d">{c.mrr_pct} vs prior month</div></div>
          <div className="cl-kpi"><div className="k">SLA ADHERENCE</div><div className="v">97.8<span className="u">%</span></div><div className="d">30-day · 1 breach</div></div>
          <div className="cl-kpi"><div className="k">INCIDENTS · 30D</div><div className="v">14</div><div className="d">12 resolved · 2 ongoing</div></div>
          <div className="cl-kpi amber"><div className="k">OPEN TICKETS</div><div className="v">4</div><div className="d">1 P1 · 1 P2 · 2 info</div></div>
          <div className="cl-kpi brand"><div className="k">NPS</div><div className="v">71</div><div className="d">n=12 · q3 survey</div></div>
        </div>

        {/* CONTRACT / MRR row */}
        <div className="cl-sh">
          <span>COMMERCIAL</span>
          <span className="line"></span>
          <span className="sub">MRR trend, contract term, renewal posture</span>
        </div>

        <div className="cl-twocol">
          {/* MRR card */}
          <div className="cl-card">
            <div className="cl-card-h">
              <span className="t">MRR · 18 mo</span>
              <span className="sub">MONTHLY · ZAR</span>
            </div>
            <div className="cl-card-b">
              <div className="cl-mrr-row">
                <div className="cl-mrr-big">{c.mrr_now}</div>
                <div className="cl-spark"><CL_Spark data={c.trend} /></div>
                <div className="cl-mrr-delta">
                  <div className="k">Δ MOM</div>
                  <div className="v">{c.mrr_delta}</div>
                  <div className="k" style={{marginTop:"6px"}}>CUMULATIVE</div>
                  <div className="v">+5.8%</div>
                </div>
              </div>
            </div>
          </div>

          {/* Contract card */}
          <div className="cl-card">
            <div className="cl-card-h">
              <span className="t">Contract · 36-month term</span>
              <span className="sub">AUTO-RENEW · 90D NOTICE</span>
            </div>
            <div className="cl-card-b">
              <div className="cl-tl">
                <div className="cl-tl-bar">
                  <div className="cl-tl-fill" style={{width: (c.contract.elapsed * 100) + "%"}}></div>
                  <div className="cl-tl-now" style={{left: (c.contract.elapsed * 100) + "%"}}></div>
                </div>
                <div className="cl-tl-marks">
                  <div><span className="k">START</span><span className="v">{c.contract.start}</span></div>
                  <div className="c"><span className="k">NEXT QBR</span><span className="v">15 Jan 2026</span></div>
                  <div className="r"><span className="k">TERM END</span><span className="v">{c.contract.end}</span></div>
                </div>
              </div>
              <div className="cl-contract-info">
                <div><span className="k">CONTRACT VALUE</span><span className="v">{c.contract.value}</span></div>
                <div><span className="k">BILLING</span><span className="v">{c.contract.billing}</span></div>
                <div><span className="k">AUP / SOW</span><span className="v">{c.contract.aup}</span></div>
                <div><span className="k">CHURN RISK</span><span className="v" style={{color:"#6FE8B0"}}>Low (0.08)</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* COVERAGE */}
        <div className="cl-sh">
          <span>COVERAGE</span>
          <span className="line"></span>
          <span className="sub">what we deliver against this contract</span>
          <span className="link">open matrix</span>
        </div>
        <div className="cl-cov">
          {[
            { k: "SITES", d: c.coverage.sites },
            { k: "GUARDS DEPLOYED", d: c.coverage.guards },
            { k: "VEHICLES", d: c.coverage.vehicles },
            { k: "SYSTEMS & SVCS", d: c.coverage.systems },
          ].map((col, i) => (
            <div className="cl-cov-col" key={i}>
              <div className="k">{col.k}</div>
              <div className="v">{col.d.count}</div>
              <div className="list">
                {col.d.list.map((row, j) => (
                  <div className="row" key={j}>
                    <span className="n">{row.n}</span>
                    <span className="c">{row.c}</span>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* ISSUES */}
        <div className="cl-sh">
          <span>SERVICE DELIVERY</span>
          <span className="line"></span>
          <span className="sub">recent tickets &amp; incident follow-ups</span>
          <span className="link">all 24</span>
        </div>
        <div style={{padding: "0 24px"}}>
          <div className="cl-card" style={{background:"transparent"}}>
            <div className="cl-card-b" style={{padding: "0 16px"}}>
              {c.issues.map((i, idx) => (
                <div className="cl-issue" key={idx}>
                  <div className="id">{i.id}</div>
                  <div className="body">
                    <span dangerouslySetInnerHTML={{__html: i.body}} />
                    <span className="src">{i.src}</span>
                  </div>
                  <div><span className={"sev " + i.sev}>{i.sev === "info" ? "INFO" : i.sev.toUpperCase()}</span></div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="cl-spacer"></div>
      </section>

      {/* RIGHT */}
      <aside className="cl-right">
        <div className="cl-right-h">
          <div className="cl-right-t">Relationship</div>
          <div className="cl-right-s">SCOPED TO {c.id} · LAST 30D</div>
        </div>

        <div className="cl-rsec">
          <div className="cl-rsec-h">
            <span className="t">CONTACTS</span>
            <span className="c">4 OF 11</span>
          </div>
          {c.contacts.map((p, i) => (
            <div className="cl-contact" key={i}>
              <div className="av">{p.av}</div>
              <div>
                <div className="n">{p.n}</div>
                <div className="r">{p.r}</div>
              </div>
            </div>
          ))}
        </div>

        <div className="cl-rsec">
          <div className="cl-rsec-h">
            <span className="t">SIGNALS</span>
            <span className="c">ZARA-WATCHED</span>
          </div>
          {c.signals.map((s, i) => (
            <div className={"cl-signal " + s.tone} key={i}>
              <span className="tag">{s.tag}</span>
              {s.body}
            </div>
          ))}
        </div>

        <div className="cl-rsec" style={{borderBottom: 0}}>
          <div className="cl-rsec-h">
            <span className="t">TOUCHPOINTS</span>
            <span className="c">30D · 14 LOGGED</span>
          </div>
          {c.touchpoints.map((t, i) => (
            <div className="cl-touch" key={i}>
              <div className="t">{t.t}</div>
              <div className="b"><span className="k">{t.k}</span><span dangerouslySetInnerHTML={{__html: t.body}} /></div>
            </div>
          ))}
        </div>
      </aside>
    </div>
  );
}

window.ClientsScreen = ClientsScreen;
