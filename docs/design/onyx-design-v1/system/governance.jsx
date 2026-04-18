/* ============================================================
   Governance screen — policies, adherence, exceptions, audit
   ============================================================ */

const GV_POLICIES = [
  { group: "RESPONSE SLAs", items: [
    { id: "SOP-R-01", name: "Priority 1 alarm response", window: "≤ 8 min", adh: 96.4, flag: null },
    { id: "SOP-R-02", name: "Priority 2 alarm response", window: "≤ 15 min", adh: 94.1, flag: null },
    { id: "SOP-R-03", name: "Panic button / duress dispatch", window: "≤ 6 min", adh: 88.7, flag: { tone: "amber", t: "5 BREACHES · 7 DAYS" } },
    { id: "SOP-R-04", name: "Perimeter response (non-active)", window: "≤ 20 min", adh: 97.0, flag: null },
  ]},
  { group: "USE OF FORCE", items: [
    { id: "SOP-U-01", name: "Use-of-force doctrine", window: "Tier II / graduated", adh: 100, flag: null, sel: true },
    { id: "SOP-U-02", name: "Firearm discharge reporting (Sec 31)", window: "Within 24h of incident", adh: 100, flag: null },
    { id: "SOP-U-03", name: "Non-lethal deployment log", window: "Within 4h of incident", adh: 91.2, flag: { tone: "brand", t: "2 ZARA FLAGS · LATE FILE" } },
  ]},
  { group: "ESCALATION", items: [
    { id: "SOP-E-01", name: "Alarm → SAPS handoff", window: "≤ 12 min on confirmed", adh: 93.4, flag: null },
    { id: "SOP-E-02", name: "Medical (MIE) protocol", window: "Netcare 911 within 3 min", adh: 98.8, flag: null },
    { id: "SOP-E-03", name: "Client notification ladder", window: "Tier-matched", adh: 89.0, flag: { tone: "red", t: "1 MISSED NOTIFY · AMBASSADE" } },
  ]},
  { group: "DATA & RETENTION", items: [
    { id: "SOP-D-01", name: "Bodycam upload cadence", window: "End-of-shift +2h", adh: 95.5, flag: null },
    { id: "SOP-D-02", name: "Bodycam retention", window: "90 days / 7yr on incident", adh: 100, flag: null },
    { id: "SOP-D-03", name: "CCTV evidence hold", window: "On request within 24h", adh: 97.7, flag: null },
    { id: "SOP-D-04", name: "POPIA — subject access", window: "≤ 30 days", adh: 100, flag: null },
  ]},
  { group: "LICENSING & FITNESS", items: [
    { id: "SOP-L-01", name: "PSIRA grade currency", window: "Continuous", adh: 99.3, flag: null },
    { id: "SOP-L-02", name: "Firearm competency (CFR)", window: "5yr renewal", adh: 97.1, flag: { tone: "amber", t: "4 EXPIRING · 60 DAYS" } },
    { id: "SOP-L-03", name: "Driver category re-cert", window: "Annual", adh: 94.0, flag: null },
  ]},
];

const GV_SELECTED = {
  id: "SOP-U-01",
  title: "Use-of-force doctrine",
  catalog: "ARGUS STANDARD / PROTECTIVE SERVICES",
  owner: "J. NAIDOO · CHIEF COMPLIANCE",
  effective: "2025-03-14",
  next_review: "2025-09-14",
  version: "v4.2",
  classification: "INTERNAL · BINDING",
  adherence: 98.4,
  delta: "+0.6",
  trend: [97.0, 96.8, 97.4, 97.2, 98.0, 97.8, 97.6, 98.1, 98.3, 98.0, 98.4, 97.9, 98.1, 98.2, 98.5, 98.2, 98.4, 98.6, 98.3, 98.5, 98.4, 98.7, 98.5, 98.6, 98.8, 98.5, 98.4, 98.6, 98.5, 98.4],
};

const GV_EXCEPTIONS = [
  { id: "EXC-2416", when: "22 Oct 14:32", body: "Non-lethal (OC) deployed at Sandton loading bay — subject already prone. Graduated response ladder not fully logged; body reviewed and cleared by compliance.", src: "INC-7714 · V. Dlamini (K-9 handler)", sev: "major", status: "rev", statusText: "UNDER REVIEW" },
  { id: "EXC-2409", when: "19 Oct 22:08", body: "Verbal warning / physical restraint used on trespasser at ARGOS-6 north gate. Bodycam cut at 00:41 into encounter — device fault logged.", src: "INC-7681 · J. Mokwena", sev: "moderate", status: "rev", statusText: "UNDER REVIEW" },
  { id: "EXC-2398", when: "11 Oct 09:15", body: "Training scenario — not a live event. Drill marker applied retroactively per Zara's recommendation.", src: "DRL-0412 · Mock force-on-force", sev: "minor", status: "ok", statusText: "CLEARED" },
];

const GV_ATTESTATIONS = [
  { name: "S. Mokoena", role: "Grade B · Firearm · Driver Cat D", stat: "CURRENT", tone: "" },
  { name: "V. Dlamini", role: "Grade B · K-9 handler · NDT-cert", stat: "CURRENT", tone: "" },
  { name: "T. Khumalo", role: "Grade A · Protection Officer", stat: "57d", tone: "warn", subStat: "CFR renewal due" },
  { name: "J. Mokwena", role: "Grade C · Firearm", stat: "12d", tone: "warn", subStat: "First-aid renewal" },
  { name: "R. Naidoo", role: "Grade B · Firearm · Driver Cat D", stat: "OVERDUE", tone: "bad", subStat: "NDT-cert lapsed" },
  { name: "L. Cele", role: "Grade A · Protection Officer · K-9", stat: "CURRENT", tone: "" },
  { name: "N. Opéra", role: "Grade B · Firearm", stat: "CURRENT", tone: "" },
];

const GV_AUDIT = [
  { t: "16:47", k: "SIGN", body: "SOP-U-01 v4.2 countersigned by Legal (Attorney S. Mthembu)." },
  { t: "15:12", k: "EDIT", body: "SOP-R-03 panic-dispatch window tightened from 8min to 6min. Effective in 30d." },
  { t: "14:32", k: "EXCEPT", body: "EXC-2416 opened against SOP-U-03 — non-lethal log filed 3h after window." },
  { t: "11:08", k: "POLICY", body: "SOP-L-02 firearm-competency renewal workflow linked to HR pipeline. 4 operators auto-queued." },
  { t: "10:41", k: "ZARA", body: "Zara proposed wording clarification on SOP-E-03 ladder — routed to policy board." },
  { t: "09:05", k: "READ", body: "Full distribution of SOP-U-01 v4.2 to 214 licensed operators. 211 acknowledged, 3 pending." },
];

function GV_Spark({ data }) {
  const w = 260, h = 56, p = 4;
  const min = Math.min(...data) - 0.4;
  const max = Math.max(...data) + 0.4;
  const range = max - min || 1;
  const pts = data.map((v, i) => {
    const x = p + (i / (data.length - 1)) * (w - 2 * p);
    const y = p + (1 - (v - min) / range) * (h - 2 * p);
    return [x, y];
  });
  const d = "M " + pts.map(([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`).join(" L ");
  const area = d + ` L ${pts[pts.length-1][0].toFixed(1)} ${h-p} L ${p} ${h-p} Z`;
  const last = pts[pts.length - 1];

  return (
    <svg viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
      <defs>
        <linearGradient id="gvspark-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#00D97E" stopOpacity="0.18" />
          <stop offset="100%" stopColor="#00D97E" stopOpacity="0" />
        </linearGradient>
      </defs>
      {/* baseline at target 98% */}
      {(() => {
        const target = 98;
        const ty = p + (1 - (target - min) / range) * (h - 2 * p);
        return (
          <g>
            <line x1={p} x2={w-p} y1={ty} y2={ty} stroke="rgba(157,75,255,0.28)" strokeWidth="1" strokeDasharray="3 3" />
            <text x={w - p - 2} y={ty - 4} textAnchor="end" fontFamily="var(--font-mono)" fontSize="8.5" fill="#9D4BFF" letterSpacing="0.05em">TARGET 98.0</text>
          </g>
        );
      })()}
      <path d={area} fill="url(#gvspark-fill)" />
      <path d={d} stroke="#6FE8B0" strokeWidth="1.25" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx={last[0]} cy={last[1]} r="2.5" fill="#6FE8B0" />
    </svg>
  );
}

function GV_Policy({ p, selected, onClick }) {
  const tone = p.adh >= 95 ? "good" : p.adh >= 90 ? "warn" : "bad";
  const barTone = p.adh >= 95 ? "" : p.adh >= 90 ? "warn" : "bad";
  return (
    <div className={"gv-pol" + (selected ? " sel" : "")} onClick={onClick}>
      <div>
        <div className="gv-pol-name">{p.name}</div>
        <div className="gv-pol-meta">
          <span className="id">{p.id}</span>
          <span className="sep">·</span>
          <span>{p.window}</span>
        </div>
      </div>
      <div className="gv-pol-adh">
        <div className={"val " + tone}>{p.adh.toFixed(1)}<span style={{fontSize:"9px", color:"var(--text-3)", marginLeft:"1px"}}>%</span></div>
        <div className="bar"><div className={"fill " + barTone} style={{width: p.adh + "%"}}></div></div>
      </div>
      {p.flag && <div className={"gv-pol-flag " + p.flag.tone}>{p.flag.t}</div>}
    </div>
  );
}

function GovernanceScreen() {
  const [selId, setSelId] = React.useState("SOP-U-01");

  return (
    <div className="gv-page">
      {/* ─── strip ─── */}
      <div className="gv-strip">
        <div>
          <div className="gv-title">Governance &amp; compliance</div>
          <div className="gv-sub">
            <strong>Argus Standard v4.2</strong> — binding rulebook for 214 licensed operators across 8 provinces. Adherence tracked against <strong>64 active SOPs</strong> and <strong>12 PSIRA / POPIA obligations</strong>. Zara patrols 24/7 for drift.
          </div>
        </div>
        <div className="gv-strip-kpi">
          <div className="gv-kpi tone-green"><div className="k">POSTURE</div><div className="v">94.8%</div><div className="d">30-day trailing</div></div>
          <div className="gv-kpi tone-amber"><div className="k">OPEN EXCEPTIONS</div><div className="v">12</div><div className="d">3 under review · 0 overdue</div></div>
          <div className="gv-kpi tone-red"><div className="k">AT-RISK SLAs</div><div className="v">2</div><div className="d">SOP-R-03 · SOP-E-03</div></div>
          <div className="gv-kpi tone-brand"><div className="k">ATTESTATIONS</div><div className="v">4</div><div className="d">expiring ≤60d</div></div>
        </div>
      </div>

      {/* ─── body ─── */}
      <div className="gv-body">

        {/* LEFT — policy list */}
        <aside className="gv-left">
          <div className="gv-left-head">
            <div className="gv-left-title">Policies &amp; SOPs <span className="ct">64</span></div>
            <div className="gv-left-sub">ARGUS STANDARD · v4.2 · BINDING</div>
          </div>
          <div className="gv-left-filter">
            <button className="on">ALL</button>
            <button>AT-RISK</button>
            <button>ZARA FLAGS</button>
            <button>DRAFT</button>
          </div>
          <div className="gv-pol-list">
            {GV_POLICIES.map(group => (
              <React.Fragment key={group.group}>
                <div className="gv-pol-group">
                  <span>{group.group}</span>
                  <span className="line"></span>
                </div>
                {group.items.map(p => (
                  <GV_Policy key={p.id} p={p} selected={p.id === selId} onClick={() => setSelId(p.id)} />
                ))}
              </React.Fragment>
            ))}
          </div>
        </aside>

        {/* CENTER — policy detail */}
        <section className="gv-center">

          <div className="gv-doc-head">
            <div>
              <div className="gv-doc-id">{GV_SELECTED.id} · {GV_SELECTED.classification}</div>
              <div className="gv-doc-title">{GV_SELECTED.title}</div>
              <div className="gv-doc-meta">
                <span><span className="k">CATALOG</span> {GV_SELECTED.catalog}</span>
                <span className="sep">·</span>
                <span><span className="k">OWNER</span> {GV_SELECTED.owner}</span>
                <span className="sep">·</span>
                <span><span className="k">EFFECTIVE</span> {GV_SELECTED.effective}</span>
                <span className="sep">·</span>
                <span><span className="k">NEXT REVIEW</span> {GV_SELECTED.next_review}</span>
              </div>
            </div>
            <div className="gv-doc-actions">
              <div className="btn-row">
                <button className="btn">Acknowledge</button>
                <button className="btn">Propose amendment</button>
                <button className="btn btn-primary">Export signed PDF</button>
              </div>
              <div style={{fontFamily:"var(--font-mono)",fontSize:"10px",color:"var(--text-3)",letterSpacing:"0.04em"}}>
                You acknowledged v4.2 · 09:07 · 2025-03-14
              </div>
            </div>
          </div>

          {/* rule text */}
          <div className="gv-sec-hd">
            <span>RULE</span>
            <span className="line"></span>
            <span className="sub">authoritative text · countersigned by Legal</span>
          </div>
          <div className="gv-rule">
            <div className="gv-rule-h">
              <span>{GV_SELECTED.id} · Article 4 — graduated response</span>
              <span className="ver">{GV_SELECTED.version} · adopted 2025-03-14</span>
            </div>
            <div className="gv-rule-body">
              <p>An Argus operator shall escalate through <strong>five</strong> defined tiers before discharging a firearm, except where reasonable apprehension of <em>immediate and grave</em> bodily harm to a principal, third party, or the operator permits direct escalation under <span className="tag">PSIRA s.21(3)</span>.</p>
              <ol>
                <li><strong>Presence</strong> — visible, identifiable Argus livery. Verbal identification mandatory.</li>
                <li><strong>Verbal direction</strong> — in English, Zulu, Xhosa, or Afrikaans where practicable. Two warnings minimum.</li>
                <li><strong>Soft-hand restraint</strong> — empty-hand technique. Requires <span className="numeric">NDT</span> certification.</li>
                <li><strong>Intermediate force</strong> — OC spray or baton. Non-lethal deployment log filed within <span className="numeric">4h</span>.</li>
                <li><strong>Deadly force</strong> — firearm discharge. Section 31 report filed within <span className="numeric">24h</span>; firearm surrendered for ballistic hold.</li>
              </ol>
              <p>Bodycam shall be <strong>active and unobstructed</strong> from tier 2 onward. A deactivated or obstructed bodycam during a force event is itself a reportable exception under <span className="tag">SOP-D-01</span> regardless of justification.</p>
            </div>
          </div>

          {/* adherence */}
          <div className="gv-sec-hd">
            <span>ADHERENCE</span>
            <span className="line"></span>
            <span className="sub">30-day trailing · 41 force events · 1 ballistic hold</span>
          </div>
          <div className="gv-adh-card">
            <div className="gv-adh-head">
              <div className="l">Current posture</div>
              <div className="r">41/41 events conformant · baseline {GV_SELECTED.trend[0].toFixed(1)}%</div>
            </div>
            <div className="gv-adh-row">
              <div className="gv-adh-big good">{GV_SELECTED.adherence.toFixed(1)}<sup>%</sup></div>
              <div className="gv-spark"><GV_Spark data={GV_SELECTED.trend} /></div>
              <div className="gv-adh-delta">
                <div className="k">Δ vs prior 30d</div>
                <div className="v good">{GV_SELECTED.delta} pp</div>
                <div className="k" style={{marginTop:"6px"}}>BREACHES</div>
                <div className="v">0</div>
              </div>
            </div>
          </div>

          {/* exceptions */}
          <div className="gv-sec-hd">
            <span>EXCEPTIONS</span>
            <span className="line"></span>
            <span className="sub">30-day window · all resolved or under review · no overdue</span>
          </div>
          <div className="gv-excep">
            <div className="gv-excep-h">
              <div>EXCEPTION</div>
              <div>WHEN</div>
              <div>RATIONALE</div>
              <div>SOURCE</div>
              <div>SEVERITY</div>
              <div>STATUS</div>
            </div>
            {GV_EXCEPTIONS.map(e => (
              <div className="gv-excep-row" key={e.id}>
                <div className="id">{e.id}</div>
                <div className="when">{e.when}</div>
                <div className="body">{e.body}</div>
                <div style={{fontFamily:"var(--font-mono)",fontSize:"10.5px",color:"var(--text-2)",letterSpacing:"0.02em"}}>{e.src}</div>
                <div><span className={"sev " + e.sev}>{e.sev}</span></div>
                <div><span className="status"><span className={"d " + (e.status==='ok'?'green':'amber')}></span>{e.statusText}</span></div>
              </div>
            ))}
          </div>

          {/* version */}
          <div className="gv-sec-hd">
            <span>VERSION HISTORY</span>
            <span className="line"></span>
            <span className="sub">all amendments are dual-signed (policy board + legal)</span>
          </div>
          <div className="gv-ver">
            <div className="gv-ver-row">
              <div className="ver">v4.2</div>
              <div className="when">14 MAR 2025</div>
              <div className="body">
                Tightened intermediate-force log window from 6h to 4h. Added Xhosa to verbal-warning language set. Clarified bodycam-obstruction clause.
                <span className="who">J. NAIDOO · countersigned S. MTHEMBU (legal)</span>
              </div>
              <div className="signoff ok">DUAL-SIGNED</div>
            </div>
            <div className="gv-ver-row">
              <div className="ver">v4.1</div>
              <div className="when">09 NOV 2024</div>
              <div className="body">
                Aligned SOP to amended Firearms Control Act notice. Removed obsolete "warning shot" provision.
                <span className="who">J. NAIDOO · countersigned S. MTHEMBU (legal)</span>
              </div>
              <div className="signoff ok">DUAL-SIGNED</div>
            </div>
            <div className="gv-ver-row">
              <div className="ver">v4.0</div>
              <div className="when">04 APR 2024</div>
              <div className="body">
                Full rewrite for POPIA alignment. Introduced bodycam mandate from tier 2 onward.
                <span className="who">M. TSHABALALA · countersigned S. MTHEMBU (legal)</span>
              </div>
              <div className="signoff ok">DUAL-SIGNED</div>
            </div>
          </div>

          <div className="gv-spacer"></div>
        </section>

        {/* RIGHT — attestations + audit */}
        <aside className="gv-right">
          <div className="gv-right-head">
            <div className="gv-right-title">Attestations &amp; audit</div>
            <div className="gv-right-sub">SCOPED TO POLICY · LAST 24H</div>
          </div>

          <div className="gv-right-sec">
            <div className="gv-right-sec-h">
              <span className="t">OPERATORS</span>
              <span className="ct">7 of 214 shown · <span style={{color:"var(--brand-2)"}}>see all</span></span>
            </div>
            {GV_ATTESTATIONS.map((a, i) => (
              <div className="gv-att" key={i}>
                <div className="gv-att-body">
                  <div className="gv-att-name">{a.name}</div>
                  <div className="gv-att-sub">{a.role}{a.subStat ? " · " + a.subStat : ""}</div>
                </div>
                <div className={"gv-att-stat " + a.tone}>{a.stat}</div>
              </div>
            ))}
          </div>

          <div className="gv-right-sec">
            <div className="gv-right-sec-h">
              <span className="t">AUDIT TRAIL</span>
              <span className="ct">TODAY · 6 EVENTS</span>
            </div>
            {GV_AUDIT.map((a, i) => (
              <div className="gv-audit" key={i}>
                <div className="t">{a.t}</div>
                <div className="b"><span className="k">{a.k}</span>{a.body}</div>
              </div>
            ))}
          </div>

          <div className="gv-right-sec" style={{borderBottom:0}}>
            <div className="gv-right-sec-h">
              <span className="t">ZARA</span>
              <span className="ct" style={{color:"#CDA9FF"}}>MONITORING</span>
            </div>
            <div style={{fontSize:"12px",color:"var(--text-1)",lineHeight:"1.5",padding:"6px 10px",background:"var(--brand-wash)",border:"1px solid rgba(157,75,255,0.22)",borderRadius:"6px"}}>
              <span style={{fontFamily:"var(--font-mono)",fontSize:"9.5px",letterSpacing:"0.1em",color:"#CDA9FF",textTransform:"uppercase",display:"block",marginBottom:"4px"}}>SUGGESTION · 10:41</span>
              SOP-E-03 rung 3 language is ambiguous when an Ambassade-class client is unreachable. Draft amendment proposes falling to rung 4 after 11 min. Ready for board review.
            </div>
          </div>
        </aside>

      </div>
    </div>
  );
}

window.GovernanceScreen = GovernanceScreen;
