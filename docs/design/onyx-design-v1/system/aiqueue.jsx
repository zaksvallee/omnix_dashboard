// ONYX — AI Queue
// Zara's working memory: live task feed, worker graph, inspector.

(function () {
  const { useState, useEffect, useRef } = React;
  const Icon = window.Icon;

  const TASKS = [
    { id: "T-48821", kind: "DECIDE", status: "running", title: "Decide disposition for AL-8821 (perim · Valley Estate)",
      site: "VAL", tags: [{ l: "P1", t: "red" }, { l: "RECOMMEND DISPATCH", t: "brand" }], cost: "0.12¢",
      eta: "1.4s", workers: ["perception","reasoner","policy"], started: "22:41:19",
      think: "Correlating <em>CAM-03 silhouette</em> with <em>fence vibration</em> and <em>thermal track</em>. Not wildlife (gait + body temp profile). Not scheduled maintenance (no work order). Response-04 is nearest unit, 2min. Recommending <em>DISPATCH</em> at 0.94 confidence. Surfacing to human for concurrence.",
      steps: [
        "Ingested 3 signals (CAM-03, FENCE-N3, THERM-N3) within 4.2s window",
        "Ran wildlife-classifier → 0.08 kudu, 0.03 dog, 0.94 human",
        "Checked work-orders for Zone 3 → none active",
        "Checked client travel flags → principal home, staff 2",
        "Proposed <em>DISPATCH</em> · awaiting operator concur",
      ],
      trace: [
        { t: "22:41:18.04", d: "red", body: "Signal correlation window opened", cost: "" },
        { t: "22:41:18.19", d: "brand", body: "Perception · human silhouette 68cm · <span class='mono'>0.94</span>", cost: "0.04¢" },
        { t: "22:41:18.62", d: "brand", body: "Wildlife classifier ruled out · kudu 0.08", cost: "0.02¢" },
        { t: "22:41:19.01", d: "brand", body: "Policy · <span class='mono'>perimeter.p1.dispatch</span>", cost: "0.01¢" },
        { t: "22:41:19.14", d: "amber", body: "Hand-off to Operator (Zaks M.) · concurrence requested", cost: "" },
      ],
    },
    { id: "T-48820", kind: "ASSESS", status: "running", title: "Assess loitering pattern — ZQ 41 FS GP at Ms Vallée",
      site: "MSV", tags: [{l:"P2", t:"amber"},{l:"VERIFY", t:"amber"}], cost: "0.08¢", eta: "3.8s",
      workers: ["perception","memory","reasoner"], started: "22:38:20",
    },
    { id: "T-48819", kind: "CLASSIFY", status: "complete", title: "Classify audio — glass break signature 66%",
      site: "MSV", tags: [{l:"P2", t:"amber"}], cost: "0.05¢", eta: "0.9s",
      workers: ["perception","reasoner"], started: "22:38:07",
    },
    { id: "T-48818", kind: "HANDOFF", status: "handed", title: "Escalated to operator — panic button SMT-01",
      site: "SMT", tags: [{l:"P1", t:"red"},{l:"HANDED", t:"green"}], cost: "0.02¢", eta: "0.1s",
      workers: ["policy"], started: "22:41:58",
    },
    { id: "T-48817", kind: "RECALL", status: "complete", title: "Recall 14d patterns for Zone 3 north fence",
      site: "VAL", tags: [{l:"CONTEXT", t:""}], cost: "0.11¢", eta: "2.1s",
      workers: ["memory"], started: "22:41:20",
    },
    { id: "T-48816", kind: "HOLD", status: "held", title: "Hold for operator — face match outside policy hours",
      site: "EVT", tags: [{l:"P2", t:"amber"},{l:"HELD", t:"amber"}], cost: "0.03¢", eta: "-",
      workers: ["policy","reasoner"], started: "22:36:14",
    },
    { id: "T-48815", kind: "CLOSE", status: "complete", title: "Auto-close wildlife event — kudu cluster EVT",
      site: "EVT", tags: [{l:"CLOSED", t:"green"}], cost: "0.04¢", eta: "1.2s",
      workers: ["perception","reasoner"], started: "22:14:01",
    },
    { id: "T-48814", kind: "CLOSE", status: "complete", title: "Dedupe camera event DKL-9 (double-index)",
      site: "DKL", tags: [{l:"CLOSED", t:"green"}], cost: "0.01¢", eta: "0.2s",
      workers: ["memory"], started: "22:00:30",
    },
    { id: "T-48813", kind: "MONITOR", status: "running", title: "Monitor radio dropout — G-155 patrol",
      site: "BLR", tags: [{l:"P3", t:""},{l:"WATCHING", t:""}], cost: "0.00¢", eta: "…",
      workers: ["perception"], started: "22:28:12",
    },
  ];

  const WORKERS = [
    { id: "perception",  name: "Perception",  sub: "VISION · AUDIO · SENSOR",  state: "hot",  x: 22, y: 28, util: 84, rps: "142/s" },
    { id: "memory",      name: "Memory",      sub: "SITE · PERSON · PATTERN",  state: "warn", x: 22, y: 72, util: 61, rps: "38/s"  },
    { id: "reasoner",    name: "Reasoner",    sub: "CHAIN · CAUSAL · COMPARE", state: "hot",  x: 55, y: 50, util: 72, rps: "22/s"  },
    { id: "policy",      name: "Policy",      sub: "RULES · CLIENT · JURIS.",  state: "on",   x: 80, y: 30, util: 18, rps: "8/s"   },
    { id: "comms",       name: "Comms",       sub: "OPERATOR · GUARD · CLIENT",state: "on",   x: 80, y: 70, util: 12, rps: "4/s"   },
  ];

  const EDGES = [
    { from: "perception", to: "reasoner", lbl: "3 signals" },
    { from: "memory",     to: "reasoner", lbl: "context" },
    { from: "reasoner",   to: "policy",   lbl: "proposal" },
    { from: "policy",     to: "comms",    lbl: "hand-off",  cls: "warn" },
  ];

  function TaskRow({ t, selected, onSelect }) {
    const icon = t.status === "running" ? "cpu" : t.status === "complete" ? "check" : t.status === "held" ? "clock" : "escalate";
    return (
      <div className={"aq-row " + t.status + (selected === t.id ? " sel" : "")} onClick={() => onSelect(t.id)}>
        <div className="aq-row-ic"><Icon name={icon} size={13}/></div>
        <div className="aq-row-body">
          <div className="aq-row-head">
            <span className="aq-row-task-id">{t.id}</span>
            <span>·</span>
            <span className="aq-row-kind">{t.kind}</span>
          </div>
          <div className="aq-row-title">{t.title}</div>
          <div className="aq-row-meta">
            {t.tags.map((tg, i) => <span key={i} className={"aq-tag " + tg.t}>{tg.l}</span>)}
            <span>· {t.workers.join(" → ")}</span>
          </div>
        </div>
        <div className="aq-row-right">
          <span className="t">{t.eta}</span>
          <span>{t.cost}</span>
        </div>
      </div>
    );
  }

  function WorkerGraph() {
    // Center board is an HTML container; compute absolute positions as %.
    const pos = {};
    WORKERS.forEach(w => pos[w.id] = { x: w.x, y: w.y });

    return (
      <div className="aq-board">
        <div className="aq-board-grid"/>
        <svg viewBox="0 0 100 100" preserveAspectRatio="none">
          {EDGES.map((e, i) => {
            const a = pos[e.from], b = pos[e.to];
            const mx = (a.x + b.x)/2, my = (a.y + b.y)/2 - 4;
            return (
              <g key={i}>
                <path d={`M ${a.x} ${a.y} Q ${mx} ${my} ${b.x} ${b.y}`} className={"aq-edge " + (e.cls || "")}/>
                <text x={mx} y={my - 1.5} textAnchor="middle" className="aq-edge-lbl">{e.lbl}</text>
              </g>
            );
          })}
        </svg>
        {WORKERS.map(w => (
          <div key={w.id} className={"aq-worker " + w.state} style={{left: w.x + "%", top: w.y + "%"}}>
            <div className="aq-worker-head">
              <span className="aq-worker-name">{w.name}</span>
              <span className="aq-worker-st">{w.state === "hot" ? "HOT" : w.state === "warn" ? "WARN" : "ON"}</span>
            </div>
            <div className="aq-worker-body">{w.sub}</div>
            <div className="aq-worker-meta">
              <span>UTIL <span className="n">{w.util}%</span></span>
              <span>RATE <span className="n">{w.rps}</span></span>
            </div>
          </div>
        ))}
      </div>
    );
  }

  function Bars({n = 20, seed = 1, tone}) {
    // Deterministic pseudo-random bars
    const bars = [];
    for (let i = 0; i < n; i++) {
      const v = (Math.sin(i * 0.9 + seed) * 0.5 + Math.cos(i * 1.7 + seed * 1.3) * 0.5 + 1) / 2;
      bars.push(Math.max(0.12, v));
    }
    return (
      <div className="bar">
        {bars.map((b, i) => <span key={i} style={{height: (b*100) + "%"}}/>)}
      </div>
    );
  }

  function Inspector({ task }) {
    if (!task) return null;
    const stateLbl = task.status === "running" ? "RUNNING" : task.status === "complete" ? "COMPLETE" : task.status === "held" ? "HELD FOR HUMAN" : "HANDED OFF";
    const stateCls = task.status === "held" ? "held" : task.status === "complete" ? "done" : "";
    return (
      <aside className="aq-right">
        <div className="aq-insp-head">
          <div className="aq-insp-eyebrow">
            <span className={"stat " + stateCls}>{stateLbl}</span>
            <span>{task.kind}</span>
            <span style={{marginLeft: "auto"}}>{task.id}</span>
          </div>
          <div className="aq-insp-title">{task.title}</div>
          <div className="aq-insp-sub">{task.site ? "SITE · " + task.site + " · " : ""}STARTED {task.started}</div>
        </div>
        <div className="aq-insp-body">
          {task.think && (
            <div>
              <div className="aq-sec">ZARA · THINKING</div>
              <div className="aq-think">
                <div dangerouslySetInnerHTML={{__html: task.think}}/>
                {task.steps && (
                  <ol>
                    {task.steps.map((s, i) => <li key={i} dangerouslySetInnerHTML={{__html: s}}/>)}
                  </ol>
                )}
              </div>
            </div>
          )}
          {task.trace && (
            <div>
              <div className="aq-sec">TRACE · {task.trace.length} STEPS</div>
              <div className="aq-trace">
                {task.trace.map((tr, i) => (
                  <div key={i} className="aq-trace-row">
                    <span className="aq-trace-t">{tr.t}</span>
                    <span className="aq-trace-body"><span className={"dot " + tr.d}/> <span dangerouslySetInnerHTML={{__html: tr.body}}/></span>
                    {tr.cost && <span className="aq-trace-cost">{tr.cost}</span>}
                  </div>
                ))}
              </div>
            </div>
          )}
          <div>
            <div className="aq-sec">METADATA</div>
            <div className="aq-kv">
              <span className="k">Task id</span><span className="v"><span className="mono">{task.id}</span></span>
              <span className="k">Kind</span><span className="v">{task.kind}</span>
              <span className="k">Workers</span><span className="v"><span className="mono">{task.workers.join(" · ")}</span></span>
              <span className="k">Cost so far</span><span className="v"><span className="mono">{task.cost}</span></span>
              <span className="k">ETA</span><span className="v"><span className="mono">{task.eta}</span></span>
              <span className="k">Started</span><span className="v"><span className="mono">{task.started}</span></span>
            </div>
          </div>
        </div>
        <div className="aq-insp-act">
          {task.status === "held" && <button className="btn primary"><Icon name="check" size={13}/>Resolve for Zara</button>}
          {task.status === "running" && <button className="btn primary"><Icon name="check" size={13}/>Concur with recommendation</button>}
          <button className="btn"><Icon name="escalate" size={12}/>Take over</button>
          <button className="btn"><Icon name="eye" size={12}/>Open context</button>
        </div>
      </aside>
    );
  }

  function AIQueue() {
    const [selected, setSelected] = useState(TASKS[0].id);
    const task = TASKS.find(t => t.id === selected);
    const [tab, setTab] = useState("graph");

    return (
      <window.Shell active="aiqueue" title="AI Queue" crumb="Zara · Working memory">
        <div className="aq-page">
          <aside className="aq-left">
            <div className="aq-head">
              <div className="aq-head-row">
                <div className="aq-title">
                  <div className="aq-title-ic"/>
                  Live task feed
                </div>
                <span className="aq-live-pill"><span className="d"/> LIVE</span>
              </div>
              <div className="aq-sub">{TASKS.filter(t => t.status === "running").length} running · {TASKS.filter(t => t.status === "held").length} held · median 1.6s · cost 0.42¢/min</div>
            </div>
            <div className="aq-feed">
              {TASKS.map(t => <TaskRow key={t.id} t={t} selected={selected} onSelect={setSelected}/>)}
            </div>
          </aside>

          <div className="aq-center">
            <div className="aq-center-head">
              <div className="aq-center-title">Decision graph · last 60s</div>
              <div className="aq-center-tabs">
                <button className={"aq-center-tab " + (tab === "graph" ? "on" : "")} onClick={() => setTab("graph")}>GRAPH</button>
                <button className={"aq-center-tab " + (tab === "timeline" ? "on" : "")} onClick={() => setTab("timeline")}>TIMELINE</button>
                <button className={"aq-center-tab " + (tab === "cost" ? "on" : "")} onClick={() => setTab("cost")}>COST</button>
              </div>
            </div>
            <WorkerGraph/>
            <div className="aq-meters">
              <div className="aq-meter2 tone-amber">
                <div className="lbl">Signals / sec</div>
                <div className="v"><span className="n">142</span><span className="u">rps · +12% vs avg</span></div>
                <Bars seed={1.2}/>
              </div>
              <div className="aq-meter2">
                <div className="lbl">Decisions / min</div>
                <div className="v"><span className="n">38.4</span><span className="u">p95 2.1s</span></div>
                <Bars seed={2.1}/>
              </div>
              <div className="aq-meter2 tone-green">
                <div className="lbl">Auto-close rate</div>
                <div className="v"><span className="n">61%</span><span className="u">last 24h</span></div>
                <Bars seed={3.4}/>
              </div>
              <div className="aq-meter2 tone-blue">
                <div className="lbl">Cost · last hour</div>
                <div className="v"><span className="n">R 4.82</span><span className="u">0.42¢/decision</span></div>
                <Bars seed={4.2}/>
              </div>
            </div>
          </div>

          <Inspector task={task}/>
        </div>
      </window.Shell>
    );
  }

  ReactDOM.createRoot(document.getElementById("root")).render(<AIQueue/>);
})();
