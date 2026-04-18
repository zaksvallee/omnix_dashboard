/* global React, Icon */
const { useState } = React;

/* ======================================================================
   REPORTS — BI / executive analytics
   ====================================================================== */

/* Library */
const RP_LIB = {
  dashboards: [
    { id: "port-nov", kind: "portfolio", n: "November 2025 · Portfolio performance", meta: ["auto · live", "122 sites", "last run 14 min ago"], st: "live", stTxt: "LIVE" },
    { id: "sla",      kind: "sla",       n: "SLA scorecard · rolling 90 days",       meta: ["ops", "across 7 clients"], st: "live", stTxt: "LIVE" },
    { id: "cost",     kind: "cost",      n: "Cost to serve · by site",               meta: ["finance", "nov 2025"], st: "live", stTxt: "LIVE" },
    { id: "margin",   kind: "margin",    n: "Contract margin · by client",           meta: ["finance", "ytd"], st: "live", stTxt: "LIVE" },
    { id: "hc",       kind: "headcount", n: "Headcount & utilisation",               meta: ["hr", "1,843 guards"], st: "live", stTxt: "LIVE" },
    { id: "tr",       kind: "training",  n: "Training compliance rollup",            meta: ["hr · psira"], st: "live", stTxt: "LIVE" },
  ],
  scheduled: [
    { id: "daily",  kind: "daily",   n: "Daily operations brief · 06:00",            meta: ["mail · 18 recipients", "next 06:00 tomorrow"], st: "sched", stTxt: "DAILY" },
    { id: "weekly", kind: "weekly",  n: "Weekly exec brief · Monday 08:00",          meta: ["mail · 7 recipients", "next Mon 08:00"], st: "sched", stTxt: "WEEKLY" },
    { id: "mth",    kind: "monthly", n: "Monthly board pack · 3rd business day",     meta: ["print + sign", "next Dec 03"], st: "sched", stTxt: "MONTHLY" },
    { id: "inc",    kind: "incident",n: "Incident digest · on every P1/P2 close",    meta: ["event-driven"], st: "sched", stTxt: "TRIGGER" },
  ],
  qbr: [
    { id: "hyp-q3", kind: "qbr", n: "HYPERION Retail Group · Q3 2025",               meta: ["14 Nov · 14:00", "J. Cele signs"], st: "qbr", stTxt: "DUE" },
    { id: "saph-q3",kind: "qbr", n: "Sapphire Hotels Africa · Q3 2025",              meta: ["21 Nov · 10:00"], st: "qbr", stTxt: "DUE" },
    { id: "dia-q3", kind: "qbr", n: "Diamond Trust · Q3 2025",                        meta: ["27 Nov · 09:00"], st: "draft", stTxt: "DRAFT" },
    { id: "van-q3", kind: "qbr", n: "Vantage Logistics · Q3 2025",                    meta: ["04 Dec · 11:00"], st: "draft", stTxt: "DRAFT" },
  ],
  templates: [
    { id: "tpl-qbr", kind: "tpl", n: "Client QBR · 22 slides",                        meta: ["last edit P. Govender · 2d ago"], st: "draft", stTxt: "TEMPLATE" },
    { id: "tpl-ins", kind: "tpl", n: "Insurance claim brief",                         meta: ["schema locked"], st: "draft", stTxt: "TEMPLATE" },
    { id: "tpl-saps",kind: "tpl", n: "SAPS case handover",                            meta: ["CAS format · legal approved"], st: "draft", stTxt: "TEMPLATE" },
    { id: "tpl-brd", kind: "tpl", n: "Board pack · operations section",               meta: ["18 slides · J. Cele owner"], st: "draft", stTxt: "TEMPLATE" },
  ],
};

const RP_KIND_ICON = {
  portfolio:<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M3 17l5-6 4 4 8-9"/><path d="M14 6h6v6"/></svg>,
  sla:      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3.5 2"/></svg>,
  cost:     <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M5 12h14M7 7h10M7 17h10"/></svg>,
  margin:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M4 20V8M10 20V4M16 20v-9M22 20H4"/></svg>,
  headcount:<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="9" r="3"/><circle cx="17" cy="10" r="2.4"/><path d="M3 19c0-2.8 2.7-5 6-5s6 2.2 6 5M14 18c.2-2 1.8-4 4-4s3.4 1.3 3.6 3"/></svg>,
  training: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M3 8l9-4 9 4-9 4-9-4z"/><path d="M7 10v5c0 1.5 2.2 3 5 3s5-1.5 5-3v-5"/></svg>,
  daily:    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/></svg>,
  weekly:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M4 10h16M8 14h2M12 14h2M16 14h2M8 18h2M12 18h2"/></svg>,
  monthly:  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="4" y="6" width="16" height="14" rx="2"/><path d="M4 10h16M8 14h8M8 17h5"/></svg>,
  incident: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><path d="M12 3l10 18H2z"/><path d="M12 9v5M12 17v.5"/></svg>,
  qbr:      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="3" y="4" width="18" height="12" rx="1.5"/><path d="M8 20h8M12 16v4"/></svg>,
  tpl:      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><rect x="4" y="4" width="16" height="16" rx="2"/><path d="M4 10h16M10 10v10"/></svg>,
};

function ReportsLeft({ tab, setTab, sel, setSel }) {
  const items = RP_LIB[tab];
  return (
    <aside className="rp-left">
      <div className="rp-left-h">
        <div className="rp-left-t"><span>Reports</span><span className="ct">38</span></div>
        <div className="rp-left-s">6 DASH · 4 SCHED · 4 QBR · 4 TPL</div>
      </div>
      <div className="rp-tabs">
        {[["dashboards", "Dash"], ["scheduled", "Sched"], ["qbr", "QBR"], ["templates", "Tpl"]].map(([k, l]) => (
          <div key={k} className={"rp-tab" + (tab === k ? " on" : "")} onClick={() => setTab(k)}>{l}</div>
        ))}
      </div>
      <div className="rp-list">
        {items.map(it => (
          <div key={it.id} className={"rp-item" + (sel === it.id ? " on" : "")} onClick={() => setSel(it.id)}>
            <div className="rp-item-row">
              <div className="body">
                <div className="ic">{RP_KIND_ICON[it.kind]}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="n">{it.n}</div>
                  <div className="meta">
                    <span className={"st " + it.st}>{it.stTxt}</span>
                    {it.meta.map((m, i) => <React.Fragment key={i}><span className="sep">·</span><span>{m}</span></React.Fragment>)}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
      <div className="rp-new"><span className="plus">+</span>Build a report</div>
    </aside>
  );
}

/* ============ CENTER BITS ============ */

/* Stacked area chart — incidents by severity over 30 days */
function IncidentArea() {
  const days = 30;
  const W = 920, H = 260, pad = { l: 42, r: 16, t: 12, b: 28 };
  // deterministic wobbly data
  const rand = (i, s) => {
    let x = Math.sin(i * 12.9898 + s * 78.233) * 43758.5453;
    return x - Math.floor(x);
  };
  const data = Array.from({ length: days }, (_, i) => {
    const weekendBoost = (i % 7 === 5 || i % 7 === 6) ? 1.6 : 1;
    const p4 = 30 + rand(i, 1) * 18;
    const p3 = 14 + rand(i, 2) * 9 * weekendBoost;
    const p2 = 4 + rand(i, 3) * 4 * weekendBoost;
    const p1 = rand(i, 4) < 0.15 ? 1 + Math.floor(rand(i, 5) * 2) : 0;
    return { p4, p3, p2, p1 };
  });
  // add a spike for "yesterday" (day 28) to tell a story
  data[28] = { p4: 42, p3: 28, p2: 8, p1: 2 };
  data[27] = { p4: 36, p3: 22, p2: 7, p1: 1 };

  const totals = data.map(d => d.p1 + d.p2 + d.p3 + d.p4);
  const maxT = Math.max(...totals) * 1.15;
  const xs = i => pad.l + (i / (days - 1)) * (W - pad.l - pad.r);
  const ys = v => H - pad.b - (v / maxT) * (H - pad.t - pad.b);

  const buildArea = (getStack, getBase) => {
    const top = data.map((d, i) => [xs(i), ys(getStack(d, i))]);
    const bot = data.map((d, i) => [xs(i), ys(getBase(d, i))]).reverse();
    return "M" + top.concat(bot).map(p => p.join(",")).join(" L") + " Z";
  };
  // cumulative: base p4 -> p4+p3 -> p4+p3+p2 -> all
  const areas = [
    { fill: "#6B4CB8", stroke: "#7A5DC9", get: d => d.p4, base: () => 0 }, // P4
    { fill: "#9D4BFF", stroke: "#B17DFF", get: d => d.p4 + d.p3, base: d => d.p4 }, // P3
    { fill: "#F5A623", stroke: "#FFD28A", get: d => d.p4 + d.p3 + d.p2, base: d => d.p4 + d.p3 }, // P2
    { fill: "#F25555", stroke: "#FFB4B4", get: d => d.p4 + d.p3 + d.p2 + d.p1, base: d => d.p4 + d.p3 + d.p2 }, // P1
  ];

  const yTicks = [0, 0.25, 0.5, 0.75, 1].map(t => Math.round(maxT * t));

  return (
    <svg viewBox={`0 0 ${W} ${H}`}>
      {/* grid */}
      {yTicks.map((v, i) => (
        <g key={i}>
          <line x1={pad.l} x2={W - pad.r} y1={ys(v)} y2={ys(v)} stroke="var(--border)" strokeDasharray="2 3"/>
          <text x={pad.l - 8} y={ys(v) + 3} textAnchor="end" fontSize="9" fontFamily="var(--font-mono)" fill="var(--text-3)" letterSpacing="0.04em">{v}</text>
        </g>
      ))}
      {/* areas bottom-up */}
      {areas.map((a, i) => (
        <path key={i} d={buildArea(a.get, a.base)} fill={a.fill} fillOpacity={0.28} stroke={a.stroke} strokeWidth="1.2"/>
      ))}
      {/* x labels — every 5 days */}
      {data.map((_, i) => (
        i % 5 === 0 || i === days - 1 ? (
          <text key={i} x={xs(i)} y={H - 10} textAnchor="middle" fontSize="9" fontFamily="var(--font-mono)" fill="var(--text-3)" letterSpacing="0.04em">
            {i === days - 1 ? "14 NOV" : `${String(i + 1).padStart(2, "0")} OCT`}
          </text>
        ) : null
      ))}
      {/* spike annotation on day 28 */}
      <g>
        <line x1={xs(28)} x2={xs(28)} y1={pad.t} y2={H - pad.b} stroke="#FFD28A" strokeOpacity="0.5" strokeDasharray="3 3"/>
        <circle cx={xs(28)} cy={ys(totals[28])} r="4" fill="#FFD28A" stroke="var(--bg-0)" strokeWidth="2"/>
        <rect x={xs(28) - 105} y={ys(totals[28]) - 40} width="100" height="26" rx="4" fill="#0A0912" stroke="#FFD28A" strokeOpacity="0.4"/>
        <text x={xs(28) - 97} y={ys(totals[28]) - 27} fontSize="9" fontFamily="var(--font-mono)" fill="#FFD28A" letterSpacing="0.06em">SPIKE · STORM EVENT</text>
        <text x={xs(28) - 97} y={ys(totals[28]) - 17} fontSize="9" fontFamily="var(--font-mono)" fill="var(--text-2)" letterSpacing="0.04em">80 events · +46% vs avg</text>
      </g>
    </svg>
  );
}

/* Small sparkline */
function Spark({ data, color = "var(--brand-2)", fill = "rgba(157,75,255,0.2)" }) {
  const W = 200, H = 36;
  const max = Math.max(...data), min = Math.min(...data);
  const xs = i => (i / (data.length - 1)) * W;
  const ys = v => H - 4 - ((v - min) / Math.max(max - min, 0.01)) * (H - 8);
  const d = data.map((v, i) => `${i === 0 ? "M" : "L"}${xs(i)},${ys(v)}`).join(" ");
  const area = `${d} L${W},${H} L0,${H} Z`;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
      <path d={area} fill={fill}/>
      <path d={d} fill="none" stroke={color} strokeWidth="1.5"/>
    </svg>
  );
}

function PortfolioReport() {
  return (
    <>
      <div className="rp-hero">
        <div>
          <div className="kind">Portfolio dashboard · monthly</div>
          <div className="t">November 2025 · Portfolio performance</div>
          <div className="s">
            <span><span style={{color:"var(--text-4)"}}>period </span><span className="v">01 Nov – 14 Nov</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>sites </span><span className="v">122</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>clients </span><span className="v">18</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>guards on roster </span><span className="v">1,843</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>owner </span><span className="v">J. Cele</span></span>
          </div>
        </div>
        <div className="actions">
          <button className="btn">Export PDF</button>
          <button className="btn">Print</button>
          <button className="btn btn-primary">Share</button>
        </div>
      </div>

      <div className="rp-kpis">
        <div className="rp-kpi">
          <div className="k">Events</div>
          <div className="v">8,312</div>
          <div className="d up"><span className="ar">▲</span>4.1%<span className="lbl" style={{marginLeft:4}}>vs Oct</span></div>
        </div>
        <div className="rp-kpi">
          <div className="k">P1 + P2</div>
          <div className="v">412</div>
          <div className="d dn"><span className="ar">▲</span>12.0%<span className="lbl" style={{marginLeft:4}}>vs Oct</span></div>
        </div>
        <div className="rp-kpi">
          <div className="k">SLA met</div>
          <div className="v">98.4<span className="u">%</span></div>
          <div className="d up"><span className="ar">▲</span>0.6pp<span className="lbl" style={{marginLeft:4}}>vs Oct</span></div>
        </div>
        <div className="rp-kpi">
          <div className="k">P2 avg ack</div>
          <div className="v">3:18<span className="u"> m:s</span></div>
          <div className="d dn"><span className="ar">▲</span>14s<span className="lbl" style={{marginLeft:4}}>target 3:00</span></div>
        </div>
        <div className="rp-kpi">
          <div className="k">Net margin</div>
          <div className="v">22.7<span className="u">%</span></div>
          <div className="d up"><span className="ar">▲</span>0.9pp<span className="lbl" style={{marginLeft:4}}>YTD 21.8%</span></div>
        </div>
        <div className="rp-kpi">
          <div className="k">Headcount util.</div>
          <div className="v">91.2<span className="u">%</span></div>
          <div className="d flat"><span className="ar">▬</span>0.1pp<span className="lbl" style={{marginLeft:4}}>target 90%</span></div>
        </div>
      </div>

      <div className="rp-section">
        <div className="rp-section-h">
          <div>
            <div className="t">Incident volume by severity</div>
            <div className="s" style={{marginTop:2}}>30-day stacked area · P1 – P4</div>
          </div>
          <div className="seg">
            <span>7D</span><span className="on">30D</span><span>90D</span><span>YTD</span>
          </div>
        </div>
        <div className="rp-chart">
          <IncidentArea/>
          <div className="legend">
            <span><span className="sw" style={{background:"#F25555"}}/>P1 Critical</span>
            <span><span className="sw" style={{background:"#F5A623"}}/>P2 Elevated</span>
            <span><span className="sw" style={{background:"#9D4BFF"}}/>P3 Standard</span>
            <span><span className="sw" style={{background:"#6B4CB8"}}/>P4 Informational</span>
          </div>
        </div>
      </div>

      <div className="rp-section">
        <div className="rp-section-h"><div className="t">SLA adherence · by priority</div><div className="s">rolling 90d</div></div>
        <div className="rp-smalls">
          <div className="rp-small">
            <div className="k">P1 · ack ≤ 60s</div>
            <div className="v">99.7<span className="u">%</span></div>
            <Spark data={[99.1,99.3,99.0,99.5,99.6,99.4,99.7,99.8,99.7,99.6,99.7,99.7]} color="#6FE8B0" fill="rgba(0,217,126,0.2)"/>
            <div className="d up">▲ 0.3pp · 62 events</div>
          </div>
          <div className="rp-small">
            <div className="k">P2 · dispatch ≤ 3m</div>
            <div className="v">94.1<span className="u">%</span></div>
            <Spark data={[95.2,94.8,95.0,93.7,94.2,93.9,94.1,94.3,94.0,94.1,93.8,94.1]} color="#FFD28A" fill="rgba(245,166,35,0.2)"/>
            <div className="d dn">▼ 1.1pp · 347 events</div>
          </div>
          <div className="rp-small">
            <div className="k">P2 · on-scene ≤ 8m</div>
            <div className="v">96.9<span className="u">%</span></div>
            <Spark data={[96.3,96.7,97.0,96.9,96.8,97.1,96.9,96.9,97.0,96.8,96.9,96.9]}/>
            <div className="d up">▲ 0.4pp · 347 events</div>
          </div>
          <div className="rp-small">
            <div className="k">P3 · resolve ≤ 30m</div>
            <div className="v">99.1<span className="u">%</span></div>
            <Spark data={[98.8,98.9,99.0,99.1,99.0,99.2,99.1,99.1,99.0,99.1,99.2,99.1]} color="#6FE8B0" fill="rgba(0,217,126,0.2)"/>
            <div className="d up">▲ 0.2pp · 2,118 events</div>
          </div>
        </div>
      </div>

      <div className="rp-section">
        <div className="rp-row2">
          <div>
            <div className="rp-section-h"><div className="t">Incidents by class</div><div className="s">this month</div></div>
            <div className="rp-bars">
              {[
                { l: "Intrusion / breach", f: "f1", w: 82, v: "643", d: "+4.1%", dd: "up" },
                { l: "Panic button",       f: "f4", w: 64, v: "501", d: "+9.2%", dd: "dn" },
                { l: "Alarm · verified",   f: "f3", w: 58, v: "454", d: "+2.1%", dd: "up" },
                { l: "Tailgate / access",  f: "f2", w: 42, v: "329", d: "−1.3%", dd: "up" },
                { l: "Suspicious loiter",  f: "f1", w: 38, v: "297", d: "+12%", dd: "dn" },
                { l: "Vehicle / perim.",   f: "f5", w: 30, v: "235", d: "−4.0%", dd: "up" },
                { l: "Fire / smoke",       f: "f4", w: 12, v: "94",  d: "−8.1%", dd: "up" },
                { l: "Medical assist",     f: "f6", w: 8,  v: "62",  d: "+1.2%", dd: "flat" },
              ].map((b, i) => (
                <div className="row" key={i}>
                  <div className="lbl">{b.l}</div>
                  <div className="track"><div className={"fill " + b.f} style={{ width: b.w + "%" }}/></div>
                  <div className="v">{b.v}</div>
                  <div className={"delta " + b.dd}>{b.d}</div>
                </div>
              ))}
            </div>
          </div>
          <div>
            <div className="rp-section-h"><div className="t">Contract margin · top 8 clients</div><div className="s">MTD</div></div>
            <table className="rp-table">
              <thead>
                <tr>
                  <th style={{width:"44%"}}>Client</th>
                  <th className="r">Revenue</th>
                  <th className="r">Cost</th>
                  <th className="r">Margin</th>
                </tr>
              </thead>
              <tbody>
                {[
                  ["HY", "Hyperion Retail Group",      "18 sites", "R 4.82m", "R 3.41m", "29.2%", "good"],
                  ["SA", "Sapphire Hotels Africa",     "12 sites", "R 3.11m", "R 2.38m", "23.5%", "good"],
                  ["DT", "Diamond Trust",              " 9 sites · VIP", "R 2.74m", "R 1.89m", "31.0%", "good"],
                  ["VL", "Vantage Logistics",          "23 depots", "R 2.41m", "R 1.96m", "18.7%", "warn"],
                  ["NO", "Noble Office Parks",         " 8 parks",  "R 1.92m", "R 1.42m", "26.1%", "good"],
                  ["AP", "Apex Mining SA",             " 3 shafts", "R 1.41m", "R 1.29m", "8.5%",  "bad"],
                  ["KC", "Kingsway Cold Chain",        " 4 DCs",    "R 0.98m", "R 0.77m", "21.4%", "good"],
                  ["IS", "Isidingo Schools",           " 6 schools","R 0.71m", "R 0.58m", "18.3%", "warn"],
                ].map(([sw, name, sub, rev, cost, mg, mc], i) => (
                  <tr key={i}>
                    <td>
                      <div className="client">
                        <div className="sw">{sw}</div>
                        <div>
                          <div>{name}</div>
                          <div className="sub">{sub}</div>
                        </div>
                      </div>
                    </td>
                    <td className="r">{rev}</td>
                    <td className="r">{cost}</td>
                    <td className={"r margin-cell " + mc}>{mg}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </>
  );
}

/* ============ RIGHT ============ */

function ReportsRight() {
  return (
    <aside className="rp-right">
      <div className="rp-right-h">
        <div className="rp-right-t">Distribution</div>
        <div className="rp-right-s">PORTFOLIO · NOV 2025</div>
      </div>

      <div className="rp-rsec">
        <div className="rp-rsec-h"><div className="t">Schedule</div><div className="c">auto</div></div>
        <div className="rp-sched">
          <div className="when">MONTHLY · 3RD BUSINESS DAY · 07:00</div>
          <div className="n">Next delivery · Mon 03 Dec 07:00</div>
          <div className="d">Final cut · run Dec 01 midnight · review window 48h</div>
        </div>
        <div className="rp-sched">
          <div className="when">ON CHANGE</div>
          <div className="n">Re-run when P1 closes or SLA breach</div>
          <div className="d">Debounce 10 min · since last 14 min ago</div>
        </div>
      </div>

      <div className="rp-rsec">
        <div className="rp-rsec-h"><div className="t">Recipients</div><div className="c">7 people</div></div>
        <div className="rp-recip">
          <div className="av c">JC</div>
          <div>
            <div className="n">Jabulani Cele</div>
            <div className="r">CEO · ONYX</div>
          </div>
          <div className="ch sgn">SIGN</div>
        </div>
        <div className="rp-recip">
          <div className="av c">PG</div>
          <div>
            <div className="n">Priya Govender</div>
            <div className="r">COO · ONYX</div>
          </div>
          <div className="ch sgn">SIGN</div>
        </div>
        <div className="rp-recip">
          <div className="av">LM</div>
          <div>
            <div className="n">Lerato Masondo</div>
            <div className="r">CFO · ONYX</div>
          </div>
          <div className="ch eml">EMAIL</div>
        </div>
        <div className="rp-recip">
          <div className="av">RN</div>
          <div>
            <div className="n">Rashaad Naidoo</div>
            <div className="r">Chair · Board</div>
          </div>
          <div className="ch prt">PRINT</div>
        </div>
        <div className="rp-recip">
          <div className="av">BS</div>
          <div>
            <div className="n">Bongani Sithole</div>
            <div className="r">INED · Board</div>
          </div>
          <div className="ch prt">PRINT</div>
        </div>
        <div className="rp-recip">
          <div className="av">+2</div>
          <div>
            <div className="n">2 more board members</div>
            <div className="r">Non-exec directors</div>
          </div>
          <div className="ch prt">PRINT</div>
        </div>
      </div>

      <div className="rp-rsec">
        <div className="rp-rsec-h"><div className="t">Anomalies in this period</div><div className="c">3</div></div>
        <div className="rp-anom">
          <div className="t">Storm-event spike · 12 Nov</div>
          <div className="b">80 events (+46% vs. 30d avg). Driven by power outages at Sandton, Rosebank, Menlyn. Auto-annotated on chart.</div>
          <div className="l">Open in Intel →</div>
        </div>
        <div className="rp-anom" style={{borderLeftColor:"#CDA9FF", background:"rgba(157,75,255,0.06)", borderColor:"rgba(157,75,255,0.25)"}}>
          <div className="t" style={{color:"#CDA9FF"}}>Apex Mining margin decline</div>
          <div className="b">Q3 margin 8.5% (−4.3pp vs Q2). Overtime cost driven by inbound transport delays. Flagged for QBR.</div>
          <div className="l">Open in Clients →</div>
        </div>
        <div className="rp-anom" style={{borderLeftColor:"#FFB4B4", background:"rgba(242,85,85,0.06)", borderColor:"rgba(242,85,85,0.25)"}}>
          <div className="t" style={{color:"#FFB4B4"}}>P2 dispatch SLA trending down</div>
          <div className="b">94.1% rolling 90d (target 95%). Root-cause: dispatcher vacancies in Pretoria NOC. HR escalated.</div>
          <div className="l">Open in Guards →</div>
        </div>
      </div>

      <div className="rp-rsec" style={{borderBottom:0}}>
        <div className="rp-rsec-h"><div className="t">Sign-off chain</div><div className="c">3 of 4</div></div>
        <div className="rp-signoff done">
          <div className="dot"/>
          <div>
            <div className="n">Data committed · 14 Nov 14:00</div>
            <div className="m">sys · ledger block #849,170</div>
          </div>
        </div>
        <div className="rp-signoff done">
          <div className="dot"/>
          <div>
            <div className="n">Analyst review · P. Govender</div>
            <div className="m">14 Nov 15:20 · 2 comments resolved</div>
          </div>
        </div>
        <div className="rp-signoff cur">
          <div className="dot"/>
          <div>
            <div className="n">CFO review · L. Masondo</div>
            <div className="m">pending · 2 cells flagged in margin table</div>
          </div>
        </div>
        <div className="rp-signoff last">
          <div className="dot"/>
          <div>
            <div className="n">CEO sign-off · J. Cele</div>
            <div className="m">blocked by CFO review</div>
          </div>
        </div>
      </div>
    </aside>
  );
}

function ReportsScreen() {
  const [tab, setTab] = useState("dashboards");
  const [sel, setSel] = useState("port-nov");
  return (
    <div className="rp-page">
      <ReportsLeft tab={tab} setTab={setTab} sel={sel} setSel={setSel}/>
      <section className="rp-center">
        <PortfolioReport/>
      </section>
      <ReportsRight/>
    </div>
  );
}

Object.assign(window, { ReportsScreen });
