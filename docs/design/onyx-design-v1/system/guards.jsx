/* ============================================================
   Guards — operator workforce dossier
   ============================================================ */

const GD_ROSTER = [
  { id: "O-0004", av: "TK", name: "T. Khumalo",   grade: "A", cs: "HOTEL-1", status: "ON",  post: "Sandton City · Control" },
  { id: "O-0011", av: "LC", name: "L. Cele",      grade: "B", cs: "HOTEL-2", status: "ON",  post: "Sandton City · Atrium" },
  { id: "O-0007", av: "VD", name: "V. Dlamini",   grade: "B", cs: "K9-1",    status: "ON",  post: "Sandton · East loading" },
  { id: "O-0019", av: "SM", name: "S. Mokoena",   grade: "B", cs: "WHISKEY", status: "ON",  post: "Sandton · West" },
  { id: "O-0032", av: "NO", name: "N. Opéra",     grade: "B", cs: "PAPA-1",  status: "ON",  post: "Sandton · P1" },
  { id: "O-0040", av: "JM", name: "J. Mokwena",   grade: "C", cs: "PAPA-2",  status: "ON",  post: "Sandton · P2" },
  { id: "O-0002", av: "SN", name: "S. Naidoo",    grade: "A", cs: "ECHO-1",  status: "ON",  post: "Argus detail · Lead" },
  { id: "O-0008", av: "RN", name: "R. Naidoo",    grade: "B", cs: "ECHO-3",  status: "ON",  post: "Argus detail · Driver" },
  { id: "O-0013", av: "AM", name: "A. Mbele",     grade: "A", cs: "FOXTROT", status: "SB",  post: "Standby · Home 45 min" },
  { id: "O-0027", av: "MN", name: "M. Ngwenya",   grade: "B", cs: "JULIET",  status: "TR",  post: "Sentinel · UoF refresh" },
  { id: "O-0045", av: "PZ", name: "P. Zulu",      grade: "C", cs: "LIMA-4",  status: "LV",  post: "Annual leave · Day 3 of 14" },
  { id: "O-0051", av: "GK", name: "G. Khan",      grade: "B", cs: "MIKE-2",  status: "SK",  post: "Sick leave · flu · day 2" },
  { id: "O-0055", av: "BM", name: "B. Mahlangu",  grade: "B", cs: "NOV-1",   status: "ON",  post: "Menlyn Maine · atrium" },
  { id: "O-0061", av: "DX", name: "D. Xolani",    grade: "C", cs: "OSCAR",   status: "ON",  post: "Nexus DC · perimeter" },
  { id: "O-0068", av: "YP", name: "Y. Peters",    grade: "A", cs: "ROMEO-1", status: "ON",  post: "Embassy chancery" },
  { id: "O-0072", av: "NK", name: "N. Kruger",    grade: "A", cs: "SIERRA",  status: "SB",  post: "Standby · EP pool" },
];

const GD_SELECTED = {
  id: "O-0011",
  av: "LC",
  name: "Lindiwe Cele",
  idno: "OPR-0011 · ID 8803241234082",
  callsign: "HOTEL-2",
  grade: "B",
  tenure: "6 yr 3 mo · joined Aug 2019",
  post: "Sandton City · Atrium sweep",
  tags: ["ON DUTY", "SHIFT 15:00–23:00", "3h 42m remaining"],
  license: {
    no: "PSIRA 2200 1184 X",
    issued: "14 Aug 2019",
    expires: "13 Aug 2026 · 289 days",
    grade: "B",
    year: "2019",
    class: "PSIRA Grade B",
    sector: "Commercial / Retail · Protective Officer",
    status: "VALID",
    compliance: "CLEAN · no sanctions",
  },
  endorsements: [
    { t: "FIREARM COMP", state: "good" },
    { t: "NDT 2024", state: "good" },
    { t: "FIRST-AID L2", state: "good" },
    { t: "DRIVER CAT C", state: "good" },
    { t: "USE-OF-FORCE 2025", state: "amber" },
    { t: "K-9", state: "miss" },
    { t: "EP CLOSE-PROTECT", state: "miss" },
  ],
  readiness: {
    composite: 91,
    bars: [
      { k: "COMPLIANCE", v: 96, tone: "" },
      { k: "PROFICIENCY", v: 94, tone: "" },
      { k: "PHYSICAL", v: 88, tone: "" },
      { k: "RANGE Q-SCORE", v: 82, tone: "amber" },
      { k: "FATIGUE (inv)", v: 74, tone: "amber" },
    ],
  },
  perf: [
    { k: "SHIFTS · 90D",        v: "68",   d: "2,720 hrs", tone: "" },
    { k: "INCIDENTS HANDLED",   v: "14",   d: "12 resolved · 2 refer", tone: "" },
    { k: "COMMENDATIONS",       v: "3",    d: "last · 18 Oct", tone: "good" },
    { k: "BREACHES",            v: "0",    d: "clean record", tone: "good" },
    { k: "ATTENDANCE",          v: "98%",  d: "1 late · 0 no-show", tone: "good" },
    { k: "AVG RESPONSE",        v: "1:42", d: "vs team 2:08", tone: "good" },
  ],
  cal: [
    // 30 days; codes: f=full, o=ot, l=leave, s=sick, m=miss, ""
    "f","f","f","","f","o","f",
    "f","f","","f","f","f","l",
    "l","l","","f","f","f","f",
    "o","","f","f","f","f","","f","f",
  ],
  deployment: [
    { d: "22 Oct", site: "Sandton City flagship", post: "Atrium sweep · HOTEL-2", hrs: "8h", tag: "clean" },
    { d: "21 Oct", site: "Sandton City flagship", post: "Atrium sweep · HOTEL-2", hrs: "8h", tag: "clean" },
    { d: "20 Oct", site: "Sandton City flagship", post: "West entrance relief", hrs: "8h", tag: "inc", note: "INC-7692 · 11 min response" },
    { d: "18 Oct", site: "Sandton City flagship", post: "North main · close-down", hrs: "9h OT", tag: "comm", note: "commendation · shoplift intercept" },
    { d: "17 Oct", site: "Menlyn Maine",          post: "Atrium sweep · fill-in", hrs: "8h", tag: "clean" },
    { d: "16 Oct", site: "Sandton City flagship", post: "Atrium sweep · HOTEL-2", hrs: "8h", tag: "clean" },
    { d: "15 Oct", site: "Sandton City flagship", post: "Control room · relief", hrs: "4h", tag: "clean" },
    { d: "14 Oct", site: "— — —",                  post: "Range re-qual · Sentinel", hrs: "6h", tag: "clean" },
    { d: "11 Oct", site: "Sandton City flagship", post: "Atrium sweep · HOTEL-2", hrs: "8h", tag: "inc", note: "loitering ejection · no SAPS" },
    { d: "10 Oct", site: "Sandton City flagship", post: "Atrium sweep · HOTEL-2", hrs: "8h", tag: "clean" },
  ],
  shift: {
    site: "Sandton City flagship",
    post: "Atrium sweep · HOTEL-2",
    start: "15:00", end: "23:00", elapsed: 0.54,
    withWhom: "T. Khumalo (CR) · V. Dlamini (K9) · 4 others",
  },
  equipment: [
    { ico: "radio", n: "Tetra handset",   sn: "TRA-2217 · paired 14:55", st: "good" },
    { ico: "gun",   n: "Beretta 92X Perf.", sn: "FA-0882 · 30 rds issued", st: "good" },
    { ico: "veh",   n: "None assigned",     sn: "on foot · atrium", st: "info" },
    { ico: "cam",   n: "Bodycam HW-V6",    sn: "BC-0448 · recording", st: "good" },
    { ico: "badge", n: "Access badge",     sn: "B-8821 · AD-01..14", st: "good" },
  ],
  welfare: {
    leave_bal: "12/21 days",
    ot_ytd: "68 hrs",
    fatigue: "MODERATE",
    last_rest: "21 Oct · 14h",
    pulse: {
      tag: "FATIGUE WATCH · ZARA",
      body: "3 consecutive 9-hr shifts with OT. Suggest capping this week at 40h. AM notified.",
    },
  },
  kin: [
    { n: "Nomsa Cele", r: "Mother · next of kin", p: "+27 82 551 7742" },
    { n: "Sibongile Cele", r: "Sister · secondary", p: "+27 71 228 0094" },
    { n: "Dr M. Patel", r: "GP · medical aid", p: "+27 11 784 3320" },
    { n: "Payroll · ONYX", r: "Account R. Dube", p: "payroll@onyx.za" },
  ],
};

const GD_EQ_ICOS = {
  radio: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="6" y="4" width="12" height="17" rx="1"/><path d="M12 2v2M9 9h6M9 13h6"/></svg>,
  gun:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 10h11l2-2h5v4l-3 1-2 3h-8l-2-3H3z"/><path d="M7 14v4"/></svg>,
  veh:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M4 16V9l3-4h10l3 4v7"/><circle cx="8" cy="17" r="2"/><circle cx="16" cy="17" r="2"/></svg>,
  cam:   <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="7" width="14" height="10" rx="1"/><path d="M17 10l4-2v8l-4-2"/></svg>,
  badge: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="12" cy="11" r="2.5"/><path d="M7 17c1-2 3-2.5 5-2.5s4 .5 5 2.5"/></svg>,
};

function GuardsScreen() {
  const [selId, setSelId] = React.useState("O-0011");
  const g = GD_SELECTED;

  return (
    <div className="gd-page">

      {/* LEFT */}
      <aside className="gd-left">
        <div className="gd-left-h">
          <div className="gd-left-t">Operators <span className="ct">214</span></div>
          <div className="gd-left-s">146 ON · 38 SB · 18 LV · 6 SK · 6 TR</div>
        </div>
        <div className="gd-left-summary">
          <div className="gd-sum good"><div className="k">GRADE A</div><div className="v">42</div></div>
          <div className="gd-sum"><div className="k">GRADE B</div><div className="v">98</div></div>
          <div className="gd-sum"><div className="k">GRADE C</div><div className="v">54</div></div>
          <div className="gd-sum"><div className="k">K-9 / EP</div><div className="v">20</div></div>
        </div>
        <div className="gd-facet">
          <button className="on">ALL</button>
          <button>ON DUTY</button>
          <button>STANDBY</button>
          <button>TRAINING</button>
          <button>LEAVE</button>
          <button>ISSUES</button>
        </div>
        <div className="gd-list">
          {GD_ROSTER.map(r => (
            <div key={r.id}
                 className={"gd-row" + (r.id === selId ? " sel" : "")}
                 onClick={() => setSelId(r.id)}>
              <div className="gd-av">
                {r.av}
                <span className={"grade " + r.grade}>{r.grade}</span>
              </div>
              <div className="gd-row-body">
                <div className="gd-row-name">{r.name}</div>
                <div className="gd-row-meta">
                  <span className="cs">{r.cs}</span>
                  <span className="sep">·</span>
                  <span>{r.post}</span>
                </div>
              </div>
              <div className={"gd-row-status " + (r.status.toLowerCase())}>{r.status}</div>
            </div>
          ))}
        </div>
      </aside>

      {/* CENTER */}
      <section className="gd-center">

        {/* HERO */}
        <div className="gd-hero">
          <div className="gd-hero-photo">
            {g.av}
            <span className="tag">ID</span>
          </div>
          <div>
            <div className="gd-hero-name">{g.name}</div>
            <div className="gd-hero-id">{g.idno}</div>
            <div className="gd-hero-tags">
              <span className="pill on">● ON DUTY</span>
              <span className="pill grade">GRADE {g.grade}</span>
              <span><span className="k">CALLSIGN</span> {g.callsign}</span>
              <span className="sep">·</span>
              <span><span className="k">POST</span> {g.post}</span>
              <span className="sep">·</span>
              <span><span className="k">TENURE</span> {g.tenure}</span>
            </div>
          </div>
          <div className="gd-hero-actions">
            <div className="btn-row">
              <button className="btn">Message</button>
              <button className="btn">Roster</button>
              <button className="btn btn-primary">Reassign</button>
            </div>
            <div className="ts">shift 15:00–23:00 · 3h 42m left</div>
          </div>
        </div>

        {/* PSIRA */}
        <div className="gd-sh">
          <span>LICENSE &amp; CERTIFICATIONS</span>
          <span className="line"></span>
          <span className="sub">PSIRA Grade B · valid · 289 days to renew</span>
          <span className="link">full compliance file</span>
        </div>

        <div className="gd-twocol">
          <div className="gd-card">
            <div className="gd-card-h">
              <span className="t">PSIRA license</span>
              <span className="sub">VALID · CLEAN</span>
            </div>
            <div className="gd-lic">
              <div className="gd-lic-grade">
                <span className="lbl">GRADE</span>
                <span className="g">{g.license.grade}</span>
                <span className="year">SINCE {g.license.year}</span>
              </div>
              <div className="gd-lic-info">
                <div className="row"><span className="k">LICENSE NO.</span><span className="v">{g.license.no}</span></div>
                <div className="row"><span className="k">SECTOR</span><span className="v">Commercial retail</span></div>
                <div className="row"><span className="k">ISSUED</span><span className="v">{g.license.issued}</span></div>
                <div className="row"><span className="k">EXPIRES</span><span className="v amber">{g.license.expires}</span></div>
                <div className="row"><span className="k">STATUS</span><span className="v good">{g.license.status}</span></div>
                <div className="row"><span className="k">SANCTIONS</span><span className="v good">None (clean)</span></div>
              </div>
            </div>
            <div className="gd-endorse">
              {g.endorsements.map((e, i) => (
                <span className={"chip " + (e.state === "good" ? "" : e.state)} key={i}>
                  {e.state === "good" ? "✓ " : e.state === "amber" ? "! " : ""}{e.t}
                </span>
              ))}
            </div>
          </div>

          <div className="gd-card">
            <div className="gd-card-h">
              <span className="t">Readiness</span>
              <span className="sub">COMPOSITE · ROLLING 30D</span>
            </div>
            <div className="gd-read">
              <div className="gd-read-composite">
                <span className="big">{g.readiness.composite}</span>
                <span className="lbl">/ 100 · DEPLOY-READY</span>
                <span className="sub">team median 83</span>
              </div>
              {g.readiness.bars.map((b, i) => (
                <div className="gd-read-bar" key={i}>
                  <span className="lbl">{b.k}</span>
                  <div className="bar"><div className={"f " + b.tone} style={{width: b.v + "%"}}></div></div>
                  <span className="v">{b.v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* PERFORMANCE */}
        <div className="gd-sh">
          <span>PERFORMANCE · 90D</span>
          <span className="line"></span>
          <span className="sub">shifts, incidents, attendance</span>
        </div>
        <div className="gd-twocol">
          <div className="gd-card">
            <div className="gd-card-h">
              <span className="t">Key metrics</span>
              <span className="sub">01 AUG — 22 OCT</span>
            </div>
            <div className="gd-perf">
              {g.perf.map((p, i) => (
                <div className="gd-perf-cell" key={i}>
                  <div className="k">{p.k}</div>
                  <div className={"v " + p.tone}>{p.v}</div>
                  <div className="d">{p.d}</div>
                </div>
              ))}
            </div>
          </div>

          <div className="gd-card">
            <div className="gd-card-h">
              <span className="t">Attendance · 30d</span>
              <span className="sub">22 SEP — 22 OCT</span>
            </div>
            <div className="gd-cal">
              <div className="gd-cal-h">
                <span>SHIFTS WORKED</span>
                <span>22 / 30 days · 98% kept</span>
              </div>
              <div className="gd-cal-grid">
                {g.cal.map((c, i) => (
                  <div key={i} className={"cell " + (
                    c === "f" ? "full" :
                    c === "o" ? "ot" :
                    c === "l" ? "lv" :
                    c === "s" ? "sk" :
                    c === "m" ? "miss" : ""
                  )}></div>
                ))}
              </div>
              <div className="gd-cal-legend">
                <span className="item"><span className="sw full"></span>Shift</span>
                <span className="item"><span className="sw ot"></span>OT</span>
                <span className="item"><span className="sw lv"></span>Leave</span>
                <span className="item"><span className="sw sk"></span>Sick</span>
                <span className="item"><span className="sw"></span>Off</span>
              </div>
            </div>
          </div>
        </div>

        {/* DEPLOYMENT */}
        <div className="gd-sh">
          <span>DEPLOYMENT HISTORY</span>
          <span className="line"></span>
          <span className="sub">last 10 posts · most recent first</span>
          <span className="link">full roster</span>
        </div>
        <div className="gd-dep">
          <div className="gd-dep-row head">
            <span>DATE</span>
            <span>SITE</span>
            <span>POST</span>
            <span>HOURS</span>
            <span style={{textAlign:"center"}}>OUTCOME</span>
          </div>
          {g.deployment.map((d, i) => (
            <div className="gd-dep-row" key={i}>
              <span className="d">{d.d}</span>
              <span className="s">{d.site}</span>
              <span className="p">{d.post}</span>
              <span className="h">{d.hrs}</span>
              <span>
                <span className={"tag " + d.tag}>
                  {d.tag === "clean" ? "CLEAN" : d.tag === "comm" ? "COMMEND" : "INCIDENT"}
                </span>
              </span>
            </div>
          ))}
        </div>

        <div className="gd-spacer"></div>
      </section>

      {/* RIGHT */}
      <aside className="gd-right">
        <div className="gd-right-h">
          <div className="gd-right-t">Current shift</div>
          <div className="gd-right-s">LIVE · {g.callsign}</div>
        </div>

        <div className="gd-rsec">
          <div className="gd-shift">
            <div className="site">{g.shift.site}</div>
            <div className="post">{g.shift.post}</div>
            <div className="timeline"><div className="f" style={{width: (g.shift.elapsed * 100) + "%"}}></div></div>
            <div className="tmarks">
              <span>{g.shift.start}</span>
              <span>NOW 19:18</span>
              <span>{g.shift.end}</span>
            </div>
            <div className="with"><span className="k">WITH</span> {g.shift.withWhom}</div>
          </div>
        </div>

        <div className="gd-rsec">
          <div className="gd-rsec-h">
            <span className="t">EQUIPMENT ISSUED</span>
            <span className="c">5 ITEMS</span>
          </div>
          {g.equipment.map((e, i) => (
            <div className="gd-eq" key={i}>
              <div className="ico">{GD_EQ_ICOS[e.ico] || null}</div>
              <div>
                <div className="n">{e.n}</div>
                <div className="sn">{e.sn}</div>
              </div>
              <div className={"st " + (e.st === "good" ? "" : e.st)}>{e.st === "good" ? "OK" : e.st === "amber" ? "CHK" : "INFO"}</div>
            </div>
          ))}
        </div>

        <div className="gd-rsec">
          <div className="gd-rsec-h">
            <span className="t">WELFARE</span>
            <span className="c">HR · LIVE</span>
          </div>
          <div className="gd-welfare">
            <div className="row"><span className="k">LEAVE BALANCE</span><span className="v">{g.welfare.leave_bal}</span></div>
            <div className="row"><span className="k">OVERTIME YTD</span><span className="v">{g.welfare.ot_ytd}</span></div>
            <div className="row"><span className="k">FATIGUE INDEX</span><span className="v amber">{g.welfare.fatigue}</span></div>
            <div className="row"><span className="k">LAST FULL REST</span><span className="v">{g.welfare.last_rest}</span></div>
            <div className="pulse">
              <span className="tag">{g.welfare.pulse.tag}</span>
              {g.welfare.pulse.body}
            </div>
          </div>
        </div>

        <div className="gd-rsec" style={{borderBottom: 0}}>
          <div className="gd-rsec-h">
            <span className="t">CONTACTS &amp; KIN</span>
            <span className="c">CONFIDENTIAL</span>
          </div>
          <div className="gd-kin">
            {g.kin.map((k, i) => (
              <div className="row" key={i}>
                <div>
                  <div className="n">{k.n}</div>
                  <div className="r">{k.r}</div>
                </div>
                <div className="p">{k.p}</div>
              </div>
            ))}
          </div>
        </div>
      </aside>
    </div>
  );
}

window.GuardsScreen = GuardsScreen;
