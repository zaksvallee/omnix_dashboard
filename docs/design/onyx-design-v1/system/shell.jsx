// ONYX — shared shell (rail + topbar + heartbeat)
// Usage: <Shell page="command" title="Command Center" crumb="Perimeter Alerts">...</Shell>

const NAV = [
  { id: "zara",      name: "Zara", icon: "agent",   href: "index.html" },
  { id: "command",   name: "Command Center", icon: "command", href: "command.html" },
  { id: "alarms",    name: "Alarms", icon: "alarm", href: "alarms.html" },
  { id: "aiqueue",   name: "AI Queue", icon: "cpu", href: "aiqueue.html" },
  { id: "track",     name: "Track", icon: "map", href: "track.html" },
  { id: "intel",     name: "Intel", icon: "intel", href: "intel.html" },
  { id: "vip",       name: "VIP", icon: "vip", href: "vip.html" },
  { id: "governance",name: "Governance", icon: "shield", href: "governance.html" },
  { id: "clients",   name: "Clients", icon: "clients", href: "clients.html" },
  { id: "sites",     name: "Sites", icon: "sites", href: "sites.html" },
  { id: "guards",    name: "Guards", icon: "guards", href: "guards.html" },
  { id: "dispatches",name: "Dispatches", icon: "dispatch", href: "dispatches.html" },
  { id: "events",    name: "Events", icon: "events", href: "events.html" },
  { id: "ledger",    name: "Ledger", icon: "ledger", href: "ledger.html" },
  { id: "reports",   name: "Reports", icon: "reports", href: "reports.html" },
  { id: "admin",     name: "Admin", icon: "admin", href: "admin.html" },
];

function Rail({ active }) {
  const Icon = window.Icon;
  return (
    <aside className="rail" role="navigation" aria-label="Primary">
      <a href="index.html" className="logo" aria-label="ONYX home">
        <svg viewBox="0 0 40 40" fill="none">
          <defs>
            <linearGradient id="lgOnyx" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stopColor="#E4CFFF"/>
              <stop offset="1" stopColor="#9D4BFF"/>
            </linearGradient>
          </defs>
          {/* ONYX mark — crown + pillars */}
          <g stroke="url(#lgOnyx)" strokeWidth="2" strokeLinejoin="round" fill="none">
            <path d="M8 6 L20 14 L32 6 L32 16 L20 24 L8 16 Z"/>
            <path d="M10 18 L10 30 M14 20 L14 32 M18 22 L18 34 M22 22 L22 34 M26 20 L26 32 M30 18 L30 30"/>
          </g>
        </svg>
      </a>
      <div className="sep"/>
      {NAV.map(n => (
        <a key={n.id}
           href={n.href || "#"}
           className={"nav-item" + (active === n.id ? " active" : "")}
           data-tip={n.name}
           aria-current={active === n.id ? "page" : undefined}
        >
          <Icon name={n.icon}/>
        </a>
      ))}
      <div className="avatar" title="Zaks · Controller">ZK</div>
    </aside>
  );
}

function Topbar({ title, crumb, clock }) {
  const Icon = window.Icon;
  return (
    <header className="topbar">
      <div className="breadcrumb">
        <span className="cur">{title}</span>
        {crumb && <><span className="sep">/</span><span>{crumb}</span></>}
      </div>
      <div className="search">
        <Icon name="search" size={14}/>
        <span>Quick jump</span>
        <kbd>⌘K</kbd>
      </div>
      <div className="top-right">
        <span className="watch-pill"><span className="dot"/>ELEVATED WATCH</span>
        <span className="watch-pill eventstore"><span className="dot"/>EVENTSTORE LIVE</span>
        <button className="lifecycle-btn"><Icon name="activity" size={13}/>Lifecycle</button>
        <div className="shift-pill">
          <span className="dot green"/>
          <span className="name">Zaks M.</span>
          <span className="shift">ADMIN · {clock}</span>
        </div>
        <span className="ready-toggle"><span className="dot green"/>READY</span>
        <button className="btn ghost icon" aria-label="Notifications"><Icon name="bell" size={16}/></button>
      </div>
    </header>
  );
}

function Heartbeat({ visible = true }) {
  if (!visible) return null;
  return (
    <a href="index.html" className="heartbeat" title="Return to Zara Home">
      <span className="hb-dot"/>
      <span>ZARA · WATCHING</span>
    </a>
  );
}

function ScaledStage({ children }) {
  const stageRef = React.useRef(null);
  const [tx, setTx] = React.useState({scale: 1, dx: 0, dy: 0});
  React.useEffect(() => {
    const DW = 1440, DH = 900;
    const update = () => {
      const vw = window.innerWidth, vh = window.innerHeight;
      const scale = Math.min(vw / DW, vh / DH, 1);
      const w = DW * scale, h = DH * scale;
      setTx({scale, dx: (vw - w) / 2, dy: (vh - h) / 2});
    };
    update();
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }, []);
  return (
    <div style={{position:'fixed', inset:0, background:'#000', overflow:'hidden'}}>
      <div ref={stageRef} style={{
        position: 'absolute',
        width: 1440, height: 900,
        top: 0, left: 0,
        transform: `translate(${tx.dx}px, ${tx.dy}px) scale(${tx.scale})`,
        transformOrigin: '0 0',
      }}>
        {children}
      </div>
    </div>
  );
}

window.Shell = function Shell({ active, title, crumb, children, showHeartbeat = true, clock }) {
  const [now, setNow] = React.useState(clock || livingClock());
  React.useEffect(() => {
    if (clock) return;
    const t = setInterval(() => setNow(livingClock()), 1000);
    return () => clearInterval(t);
  }, [clock]);
  return (
    <ScaledStage>
      <div className="shell">
        <Rail active={active}/>
        <Topbar title={title} crumb={crumb} clock={now}/>
        <main className="page">{children}</main>
        <Heartbeat visible={showHeartbeat}/>
      </div>
    </ScaledStage>
  );
};

function livingClock() {
  const d = new Date();
  const pad = n => String(n).padStart(2, "0");
  return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())} SAST`;
}

window.NAV = NAV;
window.Rail = Rail;
window.Topbar = Topbar;
window.Heartbeat = Heartbeat;
