/* global React */
const { useState } = React;

/* ======================================================================
   ADMIN — platform configuration
   ====================================================================== */

const AD_NAV = [
  { group: "Platform", items: [
    { id: "system",   n: "System",          ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>, ct: "" },
    { id: "identity", n: "Identity & SSO",  ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 4-6 8-6s8 2 8 6"/></svg>, ct: "214" },
    { id: "roles",    n: "Roles & access",  ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6l8-4z"/></svg>, ct: "11" },
    { id: "audit",    n: "Admin audit log", ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 6h16M4 12h16M4 18h10"/></svg>, ct: "" },
  ]},
  { group: "Connectivity", items: [
    { id: "ints",     n: "Integrations",    ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M8 3v5M16 3v5M3 12h5M16 12h5M8 16v5M16 16v5"/><rect x="8" y="8" width="8" height="8" rx="1.5"/></svg>, ct: "12", on: true },
    { id: "zara",     n: "Zara models",     ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 3L3 8l9 5 9-5-9-5zM3 13l9 5 9-5M3 18l9 5 9-5"/></svg>, ct: "9" },
    { id: "api",      n: "API keys",        ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="9" cy="12" r="5"/><path d="M14 12h8M18 9v6M22 10v4"/></svg>, ct: "34" },
    { id: "webhooks", n: "Webhooks",        ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 10a4 4 0 10-6-4M10 13a4 4 0 115 3M13 19a4 4 0 11-5-5"/></svg>, ct: "18" },
  ]},
  { group: "Controls", items: [
    { id: "flags",    n: "Feature flags",   ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M5 3v18M5 4h13l-3 4 3 4H5"/></svg>, ct: "27" },
    { id: "data",     n: "Data retention",  ic: <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><ellipse cx="12" cy="6" rx="8" ry="3"/><path d="M4 6v6c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12v6c0 1.7 3.6 3 8 3s8-1.3 8-3v-6"/></svg>, ct: "" },
    { id: "billing",  n: "Billing & licence",ic:<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M3 10h18M7 15h3"/></svg>, ct: "" },
  ]},
];

const AD_INTEGRATIONS = [
  { id: "saps",   cls: "gov", sw: "SAPS", n: "SAPS Case Registry",           k: "Government · crime.gov.za", st: "live", stTxt: "LIVE",
    meta: [["Last sync", "17:08 SAST · 4 min ago"], ["This week", "11 cases submitted"], ["Auth", "mTLS · cert ok"]],
    owner: "Legal · A. Pillay", upd: "cert renews in 112d" },
  { id: "popia",  cls: "gov", sw: "IR",   n: "Information Regulator (POPIA)", k: "Government · inforegulator.org.za", st: "live", stTxt: "LIVE",
    meta: [["Last sync", "06:00 daily"], ["Open requests", "2"], ["Auth", "OAuth2 + DPA"]],
    owner: "Compliance · T. Adams", upd: "next run 06:00" },
  { id: "psira",  cls: "gov", sw: "PSR",  n: "PSIRA registry feed",            k: "Government · psira.co.za", st: "live", stTxt: "LIVE",
    meta: [["Last sync", "02:00 daily"], ["Guards on file", "1,843"], ["Renewals due 30d", "47"]],
    owner: "HR · N. Khumalo", upd: "feed v2.1" },
  { id: "santam", cls: "ins", sw: "SNT",  n: "Santam Claims API",              k: "Insurance · claims-v3", st: "live", stTxt: "LIVE",
    meta: [["Last sync", "11:02 · 6h ago"], ["YTD claims", "R 1.4m"], ["Open", "3"]],
    owner: "Finance · L. Masondo", upd: "rate 200 req/h" },
  { id: "mman",   cls: "ins", sw: "MM",   n: "Minemet Mutual",                 k: "Insurance · industrial partner", st: "warn", stTxt: "RATE",
    meta: [["Last sync", "yesterday 14:20"], [<>Backoff</>, <span className="warn">22 min</span>], ["Retry", "in 4 min"]],
    owner: "Finance · L. Masondo", upd: "was throttled at 09:40" },
  { id: "tetra",  cls: "tel", sw: "TRA",  n: "TETRA dispatch radio",           k: "Telecom · national TETRA", st: "live", stTxt: "LIVE",
    meta: [["Talkgroups", "14 active"], ["Ops on-net", "38"], ["Roundtrip", "82ms"]],
    owner: "Ops · A. Ndlovu", upd: "ISSI-range stable" },
  { id: "nokia",  cls: "tel", sw: "NOK",  n: "Nokia cellular backhaul",         k: "Telecom · SIM fleet 4G/5G", st: "live", stTxt: "LIVE",
    meta: [["Sims", "2,104 · 1,989 online"], ["Data MTD", "4.2 TB"], ["Cost MTD", "R 211k"]],
    owner: "Ops · T. Mabena", upd: "low-coverage at 3 sites" },
  { id: "netbase",cls: "vid", sw: "NB",   n: "Netbase CCTV VMS",                 k: "Video · 8,412 cameras", st: "warn", stTxt: "DEGR.",
    meta: [["Online", <span className="warn">8,189 / 8,412</span>], ["Offline > 1h", "223"], ["Storage used", "78% of 4.2 PB"]],
    owner: "Ops · A. Ndlovu", upd: "3 sites offline" },
  { id: "axis",   cls: "vid", sw: "AX",   n: "Axis camera fleet",                k: "Video · edge models", st: "live", stTxt: "LIVE",
    meta: [["Fleet", "1,204 units"], ["Firmware", "10.9.3"], ["Drift", "0 units"]],
    owner: "Ops · T. Mabena", upd: "auto-update on" },
  { id: "sage",   cls: "fin", sw: "SG",   n: "Sage 300 ERP",                     k: "Finance · on-prem", st: "live", stTxt: "LIVE",
    meta: [["Last sync", "00:30 nightly"], ["GL mapping", "87 clients"], ["Drift", "0"]],
    owner: "Finance · L. Masondo", upd: "v2024.R2" },
  { id: "btc",    cls: "fin", sw: "BTC",  n: "OpenTimestamps (BTC anchor)",      k: "Notary · public chain", st: "live", stTxt: "LIVE",
    meta: [["Last anchor", "16:00 · height 871,229"], ["Hourly seals", "24/24"], ["Cost today", "R 14"]],
    owner: "Ledger · sys", upd: "next in 12:44" },
  { id: "xero",   cls: "fin", sw: "XR",   n: "Xero (client billing)",            k: "Finance · SaaS", st: "bad", stTxt: "AUTH",
    meta: [["Last sync", <span className="bad">failed · 22:14 last night</span>], ["Cause", "OAuth token expired"], ["Action", "re-auth required"]],
    owner: "Finance · L. Masondo", upd: "pending A. Pillay" },
];

const AD_HEALTH = [
  { st: "ok",   k: "Core services",      v: "12 / 12", s: "p99 104ms · uptime 99.99%" },
  { st: "ok",   k: "Regional pops",      v: "JHB CPT DBN", s: "all green · failover hot" },
  { st: "warn", k: "Integrations",       v: "10 live · 1 degr. · 1 auth", s: "Xero re-auth required" },
  { st: "ok",   k: "Zara inference",     v: "9 models live", s: "p95 180ms · 412 infer/s" },
  { st: "ok",   k: "Ledger sealing",     v: "sealed 16:00", s: "next seal in 12:44" },
];

const AD_FLAGS = [
  { n: "Zara auto-dispatch for P3", d: "Let the model auto-dispatch responders for Standard priority events without human confirmation. Currently human-in-the-loop for all P1/P2/P3.", m: ["pilot", "3 clients", "dual-ctrl"], on: false },
  { n: "Voice transcript in comms", d: "Real-time transcription of TETRA radio into the event chain. Portuguese + English + isiZulu.", m: ["on", "all clients"], on: true },
  { n: "Predictive guard roster",   d: "Forecast-based roster suggestion 14 days out using weather, holidays, local incident history.", m: ["on", "HR-controlled"], on: true },
  { n: "Client portal v3",          d: "New self-service portal for client KAMs. Contract amendments, live cameras, QBR scheduler.", m: ["rollout", "12/18 clients"], on: "pend" },
  { n: "Drone perimeter sweeps",    d: "Scheduled drone patrols at mining + logistics sites. Requires CAA licence per site.", m: ["pilot", "Apex Mining only"], on: false },
  { n: "FIC Act flagging",          d: "Auto-flag high-value cash handling events per FIC Act thresholds for compliance review.", m: ["on", "finance review"], on: true },
];

const AD_AUDIT = [
  { ini: "LM", name: "L. Masondo", role: "CFO",     ts: "17:42:11 · today",   desc: <>Changed <span className="code">billing.rate_card</span> for HYPERION Q4</>, target: "C-118-R3", sig: "signed", sigTxt: "SIGNED" },
  { ini: "AP", name: "A. Pillay",  role: "Legal",   ts: "17:30:04 · today",   desc: <>Rotated SAPS mTLS cert <span className="code">ea-01 → ea-02</span></>, target: "integrations.saps", sig: "signed", sigTxt: "SIGNED" },
  { ini: "JC", name: "J. Cele",    role: "CEO",     ts: "16:15:22 · today",   desc: <>Approved feature flag <span className="code">voice_transcript</span> → ON (all clients)</>, target: "flags.voice_transcript", sig: "signed", sigTxt: "SIGNED" },
  { ini: "PG", name: "P. Govender",role: "COO",     ts: "14:58:00 · today",   desc: <>Added role binding — <span className="code">N. Khumalo</span> to HR.manager</>, target: "roles.hr.manager", sig: "signed", sigTxt: "SIGNED" },
  { ini: "ZK", name: "Zaks M.",    role: "Admin",   ts: "14:32:48 · today",   desc: <>Invited new dispatcher <span className="code">t.mabena@onyx.co.za</span></>, target: "identity.users", sig: "pend", sigTxt: "MFA" },
  { ini: "SY", name: "sys",        role: "System",  ts: "14:00:00 · today",   desc: <>Auto-rotated quorum shard (3-of-5) — <span className="code">shard-04</span></>, target: "keys.quorum", sig: "signed", sigTxt: "AUTO" },
  { ini: "AP", name: "A. Pillay",  role: "Legal",   ts: "11:12:09 · today",   desc: <>Revoked API key <span className="code">pk_live_8f…3a1</span> for former partner</>, target: "api.pk_live_8f…3a1", sig: "rev", sigTxt: "REVOKE" },
  { ini: "JC", name: "J. Cele",    role: "CEO",     ts: "09:02:31 · today",   desc: <>Countersigned contract amendment <span className="code">C-118-R3</span></>, target: "contracts.c-118", sig: "signed", sigTxt: "SIGNED" },
];

/* ============ LEFT ============ */
function AdminLeft({ sel, onSel }) {
  return (
    <aside className="ad-left">
      <div className="ad-left-h">
        <div className="ad-left-t">Admin</div>
        <div className="ad-left-s">PLATFORM CONFIGURATION</div>
      </div>
      {AD_NAV.map(g => (
        <div className="ad-nav-group" key={g.group}>
          <div className="head">{g.group}</div>
          {g.items.map(it => {
            const on = sel === it.id;
            return (
              <div key={it.id} className={"ad-nav" + (on ? " on" : "")} onClick={() => onSel(it.id)}>
                <span className="ic">{it.ic}</span>
                <span>{it.n}</span>
                <span className="ct">
                  {it.id === "ints" && <span className="dot warn" style={{marginRight: 6}}/>}
                  {it.ct}
                </span>
              </div>
            );
          })}
        </div>
      ))}
      <div className="ad-left-foot">
        <div>ENV <b style={{color:"#6FE8B0"}}>production</b></div>
        <div>REGION <b>af-south-1</b></div>
        <div>BUILD <b>2025.11.3</b> · 14 Nov 02:30</div>
      </div>
    </aside>
  );
}

/* ============ CENTER ============ */
function AdminCenter() {
  return (
    <section className="ad-center">
      <div className="ad-hero">
        <div>
          <div className="kind">Platform · integrations</div>
          <div className="t">Integrations</div>
          <div className="s">
            <span><span style={{color:"var(--text-4)"}}>active </span><span className="v">12</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>issues </span><span className="v" style={{color:"#FFD28A"}}>2</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>region </span><span className="v">af-south-1</span></span>
            <span className="sep">·</span>
            <span><span style={{color:"var(--text-4)"}}>last deploy </span><span className="v">14 Nov 02:30</span></span>
          </div>
        </div>
        <div className="actions">
          <button className="btn">Health check all</button>
          <button className="btn">Docs</button>
          <button className="btn btn-primary">+ Add integration</button>
        </div>
      </div>

      <div className="ad-health">
        {AD_HEALTH.map((h, i) => (
          <div key={i} className={"cell " + (h.st === "warn" ? "warn" : h.st === "bad" ? "bad" : "")}>
            <div className="d"/>
            <div>
              <div className="k">{h.k}</div>
              <div className="v">{h.v}</div>
              <div className="s">{h.s}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="ad-section">
        <div className="ad-section-h">
          <div>
            <div className="t">Connected services</div>
            <div className="s" style={{marginTop:2}}>12 integrations · 2 need attention</div>
          </div>
          <div className="right">
            <span style={{ fontFamily:"var(--font-mono)", fontSize:10, letterSpacing:"0.06em", color:"var(--text-3)", textTransform:"uppercase" }}>Filter</span>
            <button className="btn">All</button>
            <button className="btn">Needs attention</button>
            <button className="btn">Government</button>
            <button className="btn">Insurance</button>
          </div>
        </div>
        <div className="ad-int-grid">
          {AD_INTEGRATIONS.map(it => (
            <div className="ad-int" key={it.id}>
              <div className="ad-int-head">
                <div className={"logo " + it.cls}>{it.sw}</div>
                <div>
                  <div className="n">{it.n}</div>
                  <div className="k">{it.k}</div>
                </div>
                <div className={"pill " + it.st}>{it.stTxt}</div>
              </div>
              <div className="meta">
                {it.meta.map((m, j) => (
                  <React.Fragment key={j}>
                    <span className="mk">{m[0]}</span>
                    <span className={"mv" + (it.st === "warn" && typeof m[1] === "object" ? "" : "")}>{m[1]}</span>
                  </React.Fragment>
                ))}
              </div>
              <div className="foot">
                <span className="owner">{it.owner}</span>
                <span>{it.upd}</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="ad-section">
        <div className="ad-section-h">
          <div>
            <div className="t">Feature flags</div>
            <div className="s" style={{marginTop:2}}>runtime switches · changes require dual control + CEO sign-off</div>
          </div>
          <div className="right">
            <button className="btn">New flag</button>
          </div>
        </div>
        <div className="ad-flags">
          {AD_FLAGS.map((f, i) => (
            <div className="ad-flag" key={i}>
              <div>
                <div className="n">{f.n}</div>
                <div className="d">{f.d}</div>
                <div className="m">
                  {f.m.map((c, j) => (
                    <span key={j} className={"chip" + (f.on === true && c === "on" ? " on" : "")}>{c}</span>
                  ))}
                </div>
              </div>
              <div className={"sw " + (f.on === true ? "on" : f.on === "pend" ? "pend" : "")}/>
            </div>
          ))}
        </div>
      </div>

      <div className="ad-section">
        <div className="ad-section-h">
          <div>
            <div className="t">Admin audit log</div>
            <div className="s" style={{marginTop:2}}>Every admin action, signed and written to the ledger</div>
          </div>
          <div className="right">
            <button className="btn">Open in Ledger</button>
          </div>
        </div>
        <div className="ad-audit">
          {AD_AUDIT.map((a, i) => (
            <div className="row" key={i}>
              <div className="av">{a.ini}</div>
              <div>
                <div style={{ fontSize: 11.5, color: "var(--text-1)", fontWeight: 500 }}>{a.name}</div>
                <div className="ts" style={{marginTop:2}}>{a.role} · {a.ts}</div>
              </div>
              <div className="desc">{a.desc}</div>
              <div className="target">{a.target}</div>
              <div>
                <span className={"sig " + a.sig}>{a.sigTxt}</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ============ RIGHT ============ */
function AdminRight() {
  return (
    <aside className="ad-right">
      <div className="ad-right-h">
        <div className="ad-right-t">Your session</div>
        <div className="ad-right-s">ONYX ADMIN · ELEVATED</div>
      </div>

      <div className="ad-rsec">
        <div className="ad-session">
          <div className="ad-session-head">
            <div className="av">ZK</div>
            <div>
              <div className="n">Zaks Meshesha</div>
              <div className="r">Super-admin · Platform</div>
            </div>
          </div>
          <div className="kv">
            <div className="k">Session</div><div className="v good">ELEVATED · 01:42</div>
            <div className="k">MFA</div><div className="v good">YubiKey · 14 Nov 13:20</div>
            <div className="k">IP</div><div className="v">196.201.14.82 · JHB</div>
            <div className="k">Device</div><div className="v">MBP14 · trusted</div>
            <div className="k">Dual-ctrl</div><div className="v">P. Govender</div>
          </div>
        </div>
      </div>

      <div className="ad-rsec">
        <div className="ad-rsec-h"><div className="t">Safety toggles</div><div className="c">session</div></div>
        <div className="ad-toggle">
          <div>
            <div className="l">Read-only mode</div>
            <div className="d">browse without edit risk</div>
          </div>
          <div className="sw"/>
        </div>
        <div className="ad-toggle">
          <div>
            <div className="l">Break-glass log</div>
            <div className="d">record every click to ledger</div>
          </div>
          <div className="sw on"/>
        </div>
        <div className="ad-toggle">
          <div>
            <div className="l">Screen-record</div>
            <div className="d">auto-record admin session</div>
          </div>
          <div className="sw on"/>
        </div>
        <div className="ad-toggle">
          <div>
            <div className="l">Change window</div>
            <div className="d">only allow changes 06:00–20:00</div>
          </div>
          <div className="sw on"/>
        </div>
      </div>

      <div className="ad-rsec">
        <div className="ad-rsec-h"><div className="t">System alerts</div><div className="c">2 open</div></div>
        <div className="ad-alert">
          <div className="t">Xero OAuth expired</div>
          <div className="d">Client billing sync failed 22:14. Re-auth required — action assigned to A. Pillay.</div>
          <div className="meta">integrations.xero · blocking QBR pack</div>
        </div>
        <div className="ad-alert">
          <div className="t">Netbase VMS · 223 cameras offline</div>
          <div className="d">3 client sites degraded. Investigating upstream ISP. Service desk ticket SD-4412.</div>
          <div className="meta">integrations.netbase · since 15:10</div>
        </div>
        <div className="ad-alert info">
          <div className="t">Zara m-vision-8.3 canary</div>
          <div className="d">New model canarying on 5% of Sandton traffic. Accuracy +0.8pp so far.</div>
          <div className="meta">zara.canary · started 14 Nov 09:00</div>
        </div>
      </div>

      <div className="ad-rsec" style={{ borderBottom: 0 }}>
        <div className="ad-rsec-h"><div className="t">Licence</div><div className="c">renews 2026-02-28</div></div>
        <div className="ad-lic">
          <div className="tier">ENTERPRISE · TIER III</div>
          <div className="n">ONYX for Operators</div>
          <div className="bar"><div className="f" style={{ width: "72%" }}/></div>
          <div className="meta"><span>2,104 / 3,000 sims</span><span>72%</span></div>
          <div className="kv">
            <div className="k">Sites</div><div className="v">122 / unlimited</div>
            <div className="k">Guards</div><div className="v">1,843 / 2,500</div>
            <div className="k">Dispatchers</div><div className="v">38 / 50</div>
            <div className="k">Zara infer</div><div className="v">412 / 1,000 rps</div>
            <div className="k">Storage</div><div className="v">4.2 / 6.0 PB</div>
          </div>
        </div>
      </div>
    </aside>
  );
}

function AdminScreen() {
  const [sel, setSel] = useState("ints");
  return (
    <div className="ad-page">
      <AdminLeft sel={sel} onSel={setSel}/>
      <AdminCenter/>
      <AdminRight/>
    </div>
  );
}

Object.assign(window, { AdminScreen });
