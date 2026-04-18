/* global React, Icon */
const { useState } = React;

/* ======================================================================
   LEDGER — cryptographic chain-of-custody
   ====================================================================== */

const LD_FACETS = [
  { key: "all",    label: "All entries",   count: 12_847, sw: "sys" },
  { key: "evid",   label: "Evidence",      count: 3_104,  sw: "evid" },
  { key: "weap",   label: "Weapons",       count: 421,    sw: "weap" },
  { key: "acc",    label: "Access",        count: 5_289,  sw: "acc" },
  { key: "dec",    label: "Decisions",     count: 1_732,  sw: "dec" },
  { key: "cont",   label: "Contracts",     count: 89,     sw: "cont" },
  { key: "zara",   label: "Zara classify", count: 1_874,  sw: "zara" },
  { key: "sys",    label: "System",        count: 338,    sw: "sys" },
];

const LD_AUDITS = [
  { n: "INC-7712 — SAPS transmission", meta: ["Case CAS-118/10/25", "Sandton SAPS"], tag: "saps", tagTxt: "SAPS" },
  { n: "Glassbreak Belgium — HYPERION claim", meta: ["Insurance · Santam", "CLM-2025-4411"], tag: "ins", tagTxt: "INSURANCE" },
  { n: "HYPERION Q3 client review", meta: ["QBR packet · 14 Nov"], tag: "qbr", tagTxt: "QBR" },
  { n: "PAIA request #R-0082", meta: ["Info Regulator SA", "Due 22 Nov"], tag: "pop", tagTxt: "PAIA" },
  { n: "PSIRA quarterly return", meta: ["Reg no 1821293", "Oct–Dec 2025"], tag: "pop", tagTxt: "PSIRA" },
  { n: "Guard M. Dube — use of force review", meta: ["EP-018 · internal"], tag: "saps", tagTxt: "INTERNAL" },
];

/* the ledger feed — each block is a real forensic event */
const LD_BLOCKS = [
  {
    id: 849_204,
    t: "evid",
    tag: "EVIDENCE",
    time: "17:12:44.081 SAST",
    title: <>Evidence frame preserved · <em>CC-772211</em></>,
    sub: "Video segment 16:42:08–16:44:12, camera CAM-041 (Sandton atrium SE). Original SHA-256 sealed. Chain-of-custody token issued to dispatcher A. Ndlovu.",
    meta: [
      { k: "prev", v: "3fa…9c7b" },
      { k: "this", v: "a18…4d09" },
      { k: "actor", v: "sys.evidence" },
      { k: "witness", v: "A. Ndlovu" },
    ],
    // when selected, detailed panel rendered below
    detail: {
      kv: [
        ["block", "#849,204"],
        ["type", "EVIDENCE.preserved"],
        ["incident", "INC-7712"],
        ["site", "SIT-118 · Sandton City Flagship"],
        ["timestamp", "2025-11-14 17:12:44.081 SAST"],
        ["merkle root", "0xa18f 4d09 b772 cc81 · 26e4 9fa0 1b33 5c12"],
        ["prev hash", "0x3fa1 9c7b 8d04 e1c2 · 50ab 731e 0c88 aa4d"],
        ["size", "312.4 MB · H.265 · 24.04 s · 4K30"],
        ["signer cert", "CN=ONYX Evidence Authority · exp 2027-03-02"],
        ["state", "SEALED · WITNESSED"],
      ],
      payload: `{
  "block":      849204,
  "type":       "EVIDENCE.preserved",
  "ts":         "2025-11-14T17:12:44.081+02:00",
  "source":     "CAM-041",
  "incident":   "INC-7712",
  "segment":    { "from": "16:42:08", "to": "16:44:12", "duration_s": 124 },
  "artifact":   {
    "id":        "CC-772211",
    "sha256":    "0xa18f4d09b772cc8126e49fa01b335c12...",
    "bytes":     327_610_112,
    "codec":     "H.265",
    "container": "ISO-BMFF"
  },
  "custody":    [
    { "role": "capture",   "actor": "CAM-041",            "ts": "16:42:08" },
    { "role": "preserve",  "actor": "sys.evidence",       "ts": "17:12:44" },
    { "role": "witness",   "actor": "usr:andlovu",        "ts": "17:12:47" }
  ],
  "prev_hash":  "0x3fa19c7b8d04e1c250ab731e0c88aa4d..."
}`,
      sigs: [
        { who: "Evidence Authority", role: "CA · ONYX-EA-01", ini: "EA" },
        { who: "Aisha Ndlovu",       role: "Dispatcher · witness", ini: "AN" },
      ],
      related: [
        { k: "INC", v: "7712" }, { k: "SITE", v: "SIT-118" }, { k: "CAM", v: "CAM-041" },
        { k: "CLIENT", v: "Hyperion Retail" }, { k: "ZARA", v: "m-vision-8.2" },
      ],
    },
  },
  {
    id: 849_203,
    t: "zara",
    tag: "ZARA",
    time: "17:12:43.002 SAST",
    title: <>Zara classification · <em>abandoned_object 0.82</em></>,
    sub: "Model m-vision-8.2 emitted classification on CAM-041 frame 0403. Decision path SOP-SC-12 routed to dispatcher for human confirmation.",
    meta: [
      { k: "prev", v: "8c1…a49e" },
      { k: "this", v: "3fa…9c7b" },
      { k: "model", v: "m-vision-8.2" },
      { k: "conf", v: "0.82" },
    ],
  },
  {
    id: 849_198,
    t: "acc",
    tag: "ACCESS",
    time: "17:08:11 SAST",
    title: <>Badge scan · gate B07 · <em>Z. Mokoena</em></>,
    sub: "Supervisor credential ZM-024 presented at perimeter gate B07, Sandton City. Shift change-over, authorised per roster R-2025-W46.",
    meta: [
      { k: "this", v: "8c1…a49e" },
      { k: "device", v: "RDR-B07-A" },
      { k: "actor", v: "usr:zmokoena" },
    ],
  },
  {
    id: 849_190,
    t: "weap",
    tag: "WEAPON",
    time: "16:54:20 SAST",
    title: <>Firearm drawn & returned · <em>FX-041 / Glock 17 Gen5</em></>,
    sub: "Armoury checkout by M. Dube (EP-018) for VIP escort JP-DUBOIS. Round count 17/17 at out, 17/17 at return. No discharge.",
    meta: [
      { k: "prev", v: "1c0…5bba" },
      { k: "this", v: "4d2…887f" },
      { k: "serial", v: "FX-041" },
      { k: "holder", v: "EP-018" },
    ],
  },
  {
    id: 849_184,
    t: "dec",
    tag: "DECISION",
    time: "16:42:14 SAST",
    title: <>Auto-triage · <em>SOP-SC-12</em> applied to INC-7712</>,
    sub: "Decision tree traversal: class=abandoned, crowd_dispersal=false, heat_sig=false, prior_flag=false → route: dispatch HOTEL-2 + K9-1. Inputs and weights logged.",
    meta: [
      { k: "this", v: "9aa…12e0" },
      { k: "policy", v: "SOP-SC-12 v4.2" },
      { k: "outcome", v: "dispatch" },
    ],
  },
  {
    id: 849_177,
    t: "cont",
    tag: "CONTRACT",
    time: "16:30:02 SAST",
    title: <>Contract amendment executed · <em>HYPERION — Sandton flagship rider</em></>,
    sub: "Rider C-118-R3 countersigned by Hyperion (L. van der Merwe) and ONYX (J. Cele). Adds two additional K9 responders and extends radio channel TG-SANDTON-1 hours to 24/7.",
    meta: [
      { k: "this", v: "f02…3410" },
      { k: "doc", v: "C-118-R3.pdf" },
      { k: "hash", v: "e1b…772a" },
    ],
  },
  {
    id: 849_170,
    t: "sys",
    tag: "SYSTEM",
    time: "16:00:00 SAST",
    title: <>Chain sealed · <em>epoch 2025-11-14 T16</em></>,
    sub: "Hourly Merkle seal of blocks 849,048 → 849,170 committed. Notarised to public anchor chain (OpenTimestamps BTC) at height 871,229.",
    meta: [
      { k: "root", v: "77ab…e001" },
      { k: "anchor", v: "BTC#871229" },
      { k: "blocks", v: "122" },
    ],
  },
  {
    id: 849_102,
    t: "acc",
    tag: "ACCESS",
    time: "15:47:33 SAST",
    title: <>Override · gate VIP-03 · <em>A. Ndlovu</em> for JP-DUBOIS arrival</>,
    sub: "Dispatcher override of automatic lockdown to admit PRINCIPAL-01 convoy (2× armoured, advance team on-site). Authorisation token held by L. Bester (ops manager).",
    meta: [
      { k: "prev", v: "6e5…1124" },
      { k: "this", v: "2bf…c509" },
      { k: "override", v: "OP-0112" },
    ],
  },
  {
    id: 849_061,
    t: "evid",
    tag: "EVIDENCE",
    time: "14:22:09 SAST",
    title: <>Evidence bundle exported · <em>INC-7692</em> → SAPS Sandton</>,
    sub: "19 video segments (4h 11m), 2 radio recordings, 1 badge audit. Bundle hash sealed; transmission receipt signed by SAPS Det. T. Nkosi.",
    meta: [
      { k: "this", v: "11e…8c22" },
      { k: "bundle", v: "7.4 GB" },
      { k: "dest", v: "SAPS · Sandton" },
    ],
  },
];

function LedgerLeft({ sel, onSel }) {
  return (
    <aside className="ld-left">
      <div className="ld-left-h">
        <div className="ld-left-t">
          <span>Ledger</span>
          <span className="ct">12,847</span>
        </div>
        <div className="ld-left-s">TODAY · 324 ENTRIES · SEALED TO 16:00</div>
      </div>

      <div className="ld-left-sum">
        <div className="cell"><div className="k">Chain height</div><div className="v">849,204</div></div>
        <div className="cell"><div className="k">Last seal</div><div className="v good">16:00:00</div></div>
        <div className="cell"><div className="k">Sealing in</div><div className="v">12:44</div></div>
        <div className="cell"><div className="k">Anchors (BTC)</div><div className="v">4,122</div></div>
      </div>

      <div className="ld-section">Entry type</div>
      <div className="ld-facet">
        {LD_FACETS.map(f => (
          <div key={f.key} className={"ld-facet-row" + (sel === f.key ? " on" : "")} onClick={() => onSel(f.key)}>
            <span className="swatch"><span className={"sw " + f.sw}></span>{f.label}</span>
            <span className="ct">{f.count.toLocaleString()}</span>
          </div>
        ))}
      </div>

      <div className="ld-section">Saved audits</div>
      <div className="ld-audits">
        {LD_AUDITS.map((a, i) => (
          <div key={i} className="ld-audit-item">
            <div className="n"><span className="icon"/>{a.n}</div>
            <div className="meta">
              <span className={"tag " + a.tag}>{a.tagTxt}</span>
              {a.meta.map((m, j) => (
                <React.Fragment key={j}>
                  {j > 0 && <span className="sep">·</span>}
                  <span>{m}</span>
                </React.Fragment>
              ))}
            </div>
          </div>
        ))}
      </div>
    </aside>
  );
}

function LedgerBlock({ b, sel, onSel }) {
  return (
    <div className={"ld-block t-" + b.t + (sel ? " sel" : "")} onClick={() => onSel(b.id)}>
      <div className="blk-head">
        <div className="blk"><span className="num">#{b.id.toLocaleString()}</span></div>
        <div className="title">{b.title}</div>
        <div className="right"><span className="tag">{b.tag}</span></div>
      </div>
      <div className="blk-meta">
        <span><span className="k">ts </span><span className="v">{b.time}</span></span>
        {b.meta.map((m, i) => (
          <span key={i}><span className="k">{m.k} </span><span className="v hash">{m.v}</span></span>
        ))}
      </div>
      <div className="blk-sub">{b.sub}</div>
    </div>
  );
}

function LedgerDetail({ b }) {
  if (!b?.detail) return null;
  const d = b.detail;
  const payload = d.payload
    .replace(/("[^"]+")(\s*:)/g, '<span class="k">$1</span>$2')
    .replace(/:\s*("[^"]+")/g, ': <span class="s">$1</span>')
    .replace(/:\s*(\d[\d_.]*)/g, ': <span class="n">$1</span>')
    .replace(/(true|false)/g, '<span class="b">$1</span>')
    .replace(/(\/\/[^\n]*)/g, '<span class="c">$1</span>');
  return (
    <div className="ld-detail">
      <div className="ld-detail-h">
        <span className="t">Block inspection · #{b.id.toLocaleString()}</span>
        <span className="sub">SEALED · WITNESSED · ANCHORED</span>
      </div>
      <div className="ld-detail-body">
        <div>
          <div className="ld-kv">
            {d.kv.map(([k, v], i) => (
              <React.Fragment key={i}>
                <div className="k">{k}</div>
                <div className={"v" + (/hash|merkle|prev/i.test(k) ? " hash" : "") + (v === "SEALED · WITNESSED" ? " good" : "")}>{v}</div>
              </React.Fragment>
            ))}
          </div>
          <div style={{ marginTop: 14, fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.12em", color: "var(--text-3)", textTransform: "uppercase", marginBottom: 8 }}>Signatures</div>
          <div className="ld-sigs">
            {d.sigs.map((s, i) => (
              <div className="ld-sig" key={i}>
                <div className="av">{s.ini}</div>
                <div>
                  <div className="who">{s.who}</div>
                  <div className="role">{s.role}</div>
                </div>
                <div className="ok">✓</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 14, fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.12em", color: "var(--text-3)", textTransform: "uppercase", marginBottom: 8 }}>Related entities</div>
          <div className="ld-related">
            {d.related.map((r, i) => (
              <div className="chip" key={i}><span className="k">{r.k}</span>{r.v}</div>
            ))}
          </div>
        </div>
        <div>
          <div style={{ fontFamily: "var(--font-mono)", fontSize: 10, letterSpacing: "0.12em", color: "var(--text-3)", textTransform: "uppercase", marginBottom: 8 }}>Payload (canonical JSON)</div>
          <pre className="ld-payload" dangerouslySetInnerHTML={{ __html: payload }} />
        </div>
      </div>
    </div>
  );
}

function LedgerRight() {
  // 48 ticks representing last 48 hours of chain verification
  const ticks = Array.from({ length: 48 }, (_, i) => {
    if (i === 47) return "self";
    return "ok";
  });
  return (
    <aside className="ld-right">
      <div className="ld-right-h">
        <div className="ld-right-t">Chain health</div>
        <div className="ld-right-s">VERIFIED 14:00:00 · P. MOFOKENG</div>
      </div>

      <div className="ld-rsec">
        <div className="ld-integrity">
          <div className="shield">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 3l8 3v6c0 5-3.5 8.5-8 9-4.5-.5-8-4-8-9V6l8-3z"/>
              <path d="M9 12l2 2 4-4"/>
            </svg>
          </div>
          <div>
            <div className="state">Integrity verified</div>
            <div className="detail">849,204 blocks · 0 breaks<br/>anchored to BTC#871,229</div>
          </div>
        </div>
        <div className="ld-verify-strip">
          {ticks.map((t, i) => <div key={i} className={"tick" + (t === "self" ? " self" : "")} />)}
        </div>
        <div className="ld-verify-strip-lbl"><span>48h ago</span><span>now</span></div>
      </div>

      <div className="ld-rsec">
        <div className="ld-rsec-h"><div className="t">Export queue</div><div className="c">4 active</div></div>
        <div className="ld-exp">
          <div className="ld-exp-head">
            <span className="ld-exp-name">INC-7712 · SAPS packet</span>
            <span className="ld-exp-state building">BUILDING</span>
          </div>
          <div className="ld-exp-meta"><span>124 blocks · 312 MB</span><span>62%</span></div>
          <div className="ld-exp-bar"><div className="f" style={{ width: "62%" }}/></div>
        </div>
        <div className="ld-exp">
          <div className="ld-exp-head">
            <span className="ld-exp-name">HYPERION QBR Q3</span>
            <span className="ld-exp-state ready">READY</span>
          </div>
          <div className="ld-exp-meta"><span>2,411 blocks · 84 MB</span><span>signed</span></div>
          <div className="ld-exp-bar"><div className="f green" style={{ width: "100%" }}/></div>
        </div>
        <div className="ld-exp">
          <div className="ld-exp-head">
            <span className="ld-exp-name">Santam claim CLM-4411</span>
            <span className="ld-exp-state sent">SENT</span>
          </div>
          <div className="ld-exp-meta"><span>receipt 11:02:18</span><span>R. van Wyk</span></div>
          <div className="ld-exp-bar"><div className="f" style={{ width: "100%", background: "#CDA9FF" }}/></div>
        </div>
        <div className="ld-exp">
          <div className="ld-exp-head">
            <span className="ld-exp-name">PAIA R-0082 (Info Regulator)</span>
            <span className="ld-exp-state building">BUILDING</span>
          </div>
          <div className="ld-exp-meta"><span>redaction pass 2/3</span><span>28%</span></div>
          <div className="ld-exp-bar"><div className="f" style={{ width: "28%" }}/></div>
        </div>
      </div>

      <div className="ld-rsec">
        <div className="ld-rsec-h"><div className="t">Signing keys</div><div className="c">4 custodians</div></div>
        <div className="ld-key">
          <div className="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="12" r="5"/><path d="M14 12h8M18 9v6M22 10v4"/></svg></div>
          <div>
            <div className="n">Evidence authority (CA)</div>
            <div className="kid">onyx-ea-01 · RSA-4096 · exp 2027-03-02</div>
          </div>
          <div className="st">ACTIVE</div>
        </div>
        <div className="ld-key">
          <div className="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="12" r="5"/><path d="M14 12h8M18 9v6"/></svg></div>
          <div>
            <div className="n">Dispatch ops (per-dispatcher)</div>
            <div className="kid">12 subordinate keys · Ed25519</div>
          </div>
          <div className="st">ACTIVE</div>
        </div>
        <div className="ld-key">
          <div className="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="12" r="5"/><path d="M14 12h8"/></svg></div>
          <div>
            <div className="n">Client witness (HYPERION)</div>
            <div className="kid">L. van der Merwe · HSM offsite</div>
          </div>
          <div className="st">ACTIVE</div>
        </div>
        <div className="ld-key">
          <div className="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="12" r="5"/><path d="M14 12h8"/></svg></div>
          <div>
            <div className="n">Quorum recovery (3-of-5)</div>
            <div className="kid">shards held offsite · rotated Aug</div>
          </div>
          <div className="st amber">ROTATE 42d</div>
        </div>
      </div>

      <div className="ld-rsec" style={{ borderBottom: 0 }}>
        <div className="ld-rsec-h"><div className="t">Regulation coverage</div><div className="c">today</div></div>
        <div className="ld-reg">
          <div>
            <div className="n">POPIA</div>
            <div className="d">Protection of Personal Information Act</div>
          </div>
          <div className="pct">99.4%</div>
        </div>
        <div className="ld-reg">
          <div>
            <div className="n">PAIA</div>
            <div className="d">Promotion of Access to Information Act</div>
          </div>
          <div className="pct">100%</div>
        </div>
        <div className="ld-reg">
          <div>
            <div className="n">PSIRA</div>
            <div className="d">Priv. Security Industry Regulatory Authority</div>
          </div>
          <div className="pct">100%</div>
        </div>
        <div className="ld-reg">
          <div>
            <div className="n">CPA §55</div>
            <div className="d">Consumer Protection Act — supply of services</div>
          </div>
          <div className="pct amber">96.1%</div>
        </div>
        <div className="ld-reg">
          <div>
            <div className="n">FIC Act</div>
            <div className="d">Financial Intelligence Centre (cash handling)</div>
          </div>
          <div className="pct">100%</div>
        </div>
      </div>
    </aside>
  );
}

function LedgerScreen() {
  const [facet, setFacet] = useState("all");
  const [sel, setSel] = useState(849_204);
  const visible = facet === "all" ? LD_BLOCKS : LD_BLOCKS.filter(b => b.t === facet);
  const selBlock = LD_BLOCKS.find(b => b.id === sel);

  return (
    <div className="ld-page">
      <LedgerLeft sel={facet} onSel={setFacet} />
      <section className="ld-center">
        <div className="ld-hero">
          <div>
            <div className="t">Chain-of-custody ledger</div>
            <div className="s">
              <span className="pill sealed"><span className="d"/>SEALED</span>
              <span><span style={{ color: "var(--text-4)" }}>height </span><span className="v">849,204</span></span>
              <span className="sep">·</span>
              <span><span style={{ color: "var(--text-4)" }}>root </span><span className="v">77ab…e001</span></span>
              <span className="sep">·</span>
              <span><span style={{ color: "var(--text-4)" }}>anchor </span><span className="v">BTC #871,229</span></span>
              <span className="sep">·</span>
              <span><span style={{ color: "var(--text-4)" }}>next seal </span><span className="v">16:00 + 12:44</span></span>
            </div>
          </div>
          <div className="actions">
            <button className="btn">Verify chain</button>
            <button className="btn">New audit</button>
            <button className="btn btn-primary">Export packet</button>
          </div>
        </div>

        <div className="ld-feed">
          {visible.map(b => <LedgerBlock key={b.id} b={b} sel={sel === b.id} onSel={setSel} />)}
        </div>

        {selBlock?.detail && <LedgerDetail b={selBlock} />}
      </section>
      <LedgerRight />
    </div>
  );
}

Object.assign(window, { LedgerScreen });
