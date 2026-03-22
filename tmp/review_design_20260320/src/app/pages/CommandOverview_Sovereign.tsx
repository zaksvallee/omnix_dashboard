import React, { useState } from 'react';

interface AlertSummary {
  critical: number;
  warning: number;
  info: number;
}

export default function CommandOverview_Sovereign() {
  const [currentTime] = useState('03:36:12');

  // AGGREGATED STATUS
  const incidents = {
    total: 15,
    critical: 3,
    warning: 4,
    pending: 5
  };

  const fleet = {
    total: 8,
    ready: 5,
    degraded: 2,
    offline: 1
  };

  const sites = {
    total: 5,
    available: 3,
    limited: 1,
    unavailable: 1
  };

  const systems = {
    total: 6,
    operational: 5,
    degraded: 1,
    critical: 0
  };

  const blockers = {
    total: 5,
    critical: 2,
    warning: 2,
    pending: 3
  };

  // CALCULATE OVERALL STATUS
  const overallStatus = incidents.critical > 0 || fleet.offline > 0 || sites.unavailable > 0 || systems.critical > 0 || blockers.critical > 0
    ? 'critical'
    : incidents.warning > 0 || fleet.degraded > 0 || sites.limited > 0 || systems.degraded > 0 || blockers.warning > 0
    ? 'warning'
    : 'normal';

  // LIVE DATA - COMPACTED
  const criticalIncidents = [
    { id: 'INC-2441', site: 'SE-01', type: 'INTRUSION', age: '142s', assigned: 'G-2441' },
    { id: 'INC-2435', site: 'VN-04', type: 'INTRUSION', age: '30m', assigned: 'G-2445' },
    { id: 'INC-2434', site: 'VN-04', type: 'INTRUSION', age: '32m', assigned: 'G-2445' },
  ];

  const criticalBlockers = [
    { id: 'BLK-001', desc: 'VN-04 watch unavailable 6h' },
    { id: 'BLK-002', desc: 'G-2446 offline - all systems down' },
  ];

  const siteStatus = [
    { code: 'SE-01', status: 'available', cam: '8/8', grd: 2 },
    { code: 'WF-02', status: 'limited', cam: '10/12', grd: 1 },
    { code: 'BR-03', status: 'available', cam: '6/6', grd: 1 },
    { code: 'VN-04', status: 'unavailable', cam: '0/10', grd: 0 },
    { code: 'HP-05', status: 'limited', cam: '7/8', grd: 2 },
  ];

  const fleetStatus = [
    { code: 'G-2441', radio: '✓', wear: '✓', video: '✓' },
    { code: 'G-2442', radio: '✓', wear: '✓', video: '⚠' },
    { code: 'G-2443', radio: '⚠', wear: '✓', video: '✓' },
    { code: 'G-2444', radio: '✓', wear: '⚠', video: '✓' },
    { code: 'RO-1242', radio: '✓', wear: '✓', video: '✓' },
    { code: 'RO-1243', radio: '✓', wear: '✓', video: '✗' },
    { code: 'G-2445', radio: '✓', wear: '✓', video: '✓' },
    { code: 'G-2446', radio: '✗', wear: '✗', video: '✗' },
  ];

  const systemStatus = [
    { sys: 'FSK', status: '✓', uptime: '99.9%' },
    { sys: 'AI', status: '✓', uptime: '99.8%' },
    { sys: 'CCTV', status: '✓', uptime: '99.7%' },
    { sys: 'COMMS', status: '⚠', uptime: '98.2%' },
    { sys: 'LEDGER', status: '✓', uptime: '100%' },
    { sys: 'QUEUE', status: '✓', uptime: '99.9%' },
  ];

  return (
    <div className="sovereign sovereign-page">
      {/* Status Bar - 32px height */}
      <div className={`sovereign-status-bar ${overallStatus}`} style={{ height: '32px', fontSize: '11px', padding: '0 12px' }}>
        <div>COMMAND OVERVIEW | {incidents.critical} CRIT | {blockers.critical} BLOCK | {fleet.offline} OFF | {sites.unavailable} DOWN</div>
        <div>FLEET:{fleet.ready}/{fleet.total} | SITES:{sites.available}/{sites.total} | SYS:{systems.operational}/{systems.total} | UTC:{currentTime}</div>
      </div>

      {/* Main Content - FITS IN 1016px (total with bars = 1080px) - NO SCROLLING */}
      <div style={{ height: 'calc(100vh - 68px)', display: 'flex', flexDirection: 'column', padding: '8px', gap: '6px', overflow: 'hidden' }}>
        
        {/* ROW 1: KPI Summary Cards - 70px height */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '6px', height: '70px' }}>
          
          {/* INCIDENTS */}
          <div className="sovereign-card" style={{ padding: '6px' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '2px' }}>INCIDENTS</div>
            <div style={{ fontSize: '20px', fontWeight: 700, fontFamily: 'var(--sovereign-font-mono)', color: incidents.critical > 0 ? 'var(--sovereign-critical)' : 'var(--sovereign-text-primary)' }}>
              {incidents.total}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '2px', fontSize: '8px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-critical)', fontWeight: 700, fontSize: '11px' }}>{incidents.critical}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>CRIT</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-warning)', fontWeight: 700, fontSize: '11px' }}>{incidents.warning}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>WARN</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-text-secondary)', fontWeight: 700, fontSize: '11px' }}>{incidents.pending}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>PEND</div>
              </div>
            </div>
          </div>

          {/* FLEET */}
          <div className="sovereign-card" style={{ padding: '6px' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '2px' }}>FLEET</div>
            <div style={{ fontSize: '20px', fontWeight: 700, fontFamily: 'var(--sovereign-font-mono)', color: fleet.offline > 0 ? 'var(--sovereign-critical)' : fleet.degraded > 0 ? 'var(--sovereign-warning)' : 'var(--sovereign-normal)' }}>
              {fleet.ready}/{fleet.total}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '2px', fontSize: '8px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-normal)', fontWeight: 700, fontSize: '11px' }}>{fleet.ready}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>RDY</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-warning)', fontWeight: 700, fontSize: '11px' }}>{fleet.degraded}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>DEG</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-critical)', fontWeight: 700, fontSize: '11px' }}>{fleet.offline}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>OFF</div>
              </div>
            </div>
          </div>

          {/* SITES */}
          <div className="sovereign-card" style={{ padding: '6px' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '2px' }}>SITES</div>
            <div style={{ fontSize: '20px', fontWeight: 700, fontFamily: 'var(--sovereign-font-mono)', color: sites.unavailable > 0 ? 'var(--sovereign-critical)' : sites.limited > 0 ? 'var(--sovereign-warning)' : 'var(--sovereign-normal)' }}>
              {sites.available}/{sites.total}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '2px', fontSize: '8px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-normal)', fontWeight: 700, fontSize: '11px' }}>{sites.available}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>AVL</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-warning)', fontWeight: 700, fontSize: '11px' }}>{sites.limited}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>LTD</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-critical)', fontWeight: 700, fontSize: '11px' }}>{sites.unavailable}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>UNV</div>
              </div>
            </div>
          </div>

          {/* SYSTEMS */}
          <div className="sovereign-card" style={{ padding: '6px' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '2px' }}>SYSTEMS</div>
            <div style={{ fontSize: '20px', fontWeight: 700, fontFamily: 'var(--sovereign-font-mono)', color: systems.critical > 0 ? 'var(--sovereign-critical)' : systems.degraded > 0 ? 'var(--sovereign-warning)' : 'var(--sovereign-normal)' }}>
              {systems.operational}/{systems.total}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '2px', fontSize: '8px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-normal)', fontWeight: 700, fontSize: '11px' }}>{systems.operational}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>OPR</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-warning)', fontWeight: 700, fontSize: '11px' }}>{systems.degraded}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>DEG</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-critical)', fontWeight: 700, fontSize: '11px' }}>{systems.critical}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>CRT</div>
              </div>
            </div>
          </div>

          {/* BLOCKERS */}
          <div className="sovereign-card" style={{ padding: '6px' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '2px' }}>BLOCKERS</div>
            <div style={{ fontSize: '20px', fontWeight: 700, fontFamily: 'var(--sovereign-font-mono)', color: blockers.critical > 0 ? 'var(--sovereign-critical)' : blockers.warning > 0 ? 'var(--sovereign-warning)' : 'var(--sovereign-text-primary)' }}>
              {blockers.total}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: '2px', fontSize: '8px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-critical)', fontWeight: 700, fontSize: '11px' }}>{blockers.critical}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>CRIT</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-warning)', fontWeight: 700, fontSize: '11px' }}>{blockers.warning}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>WARN</div>
              </div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--sovereign-text-secondary)', fontWeight: 700, fontSize: '11px' }}>{blockers.pending}</div>
                <div style={{ color: 'var(--sovereign-text-tertiary)' }}>PEND</div>
              </div>
            </div>
          </div>
        </div>

        {/* ROW 2: Critical Alerts - 110px height */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '6px', height: '110px' }}>
          
          {/* CRITICAL INCIDENTS */}
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '3px' }}>CRITICAL INCIDENTS</div>
            <table className="sovereign-table" style={{ fontSize: '10px' }}>
              <thead>
                <tr>
                  <th style={{ width: '24px', padding: '3px 4px' }}>ST</th>
                  <th style={{ width: '70px', padding: '3px 4px' }}>ID</th>
                  <th style={{ width: '50px', padding: '3px 4px' }}>SITE</th>
                  <th style={{ padding: '3px 4px' }}>TYPE</th>
                  <th style={{ width: '50px', padding: '3px 4px' }}>AGE</th>
                  <th style={{ width: '60px', padding: '3px 4px' }}>ASSGN</th>
                </tr>
              </thead>
              <tbody>
                {criticalIncidents.map((inc) => (
                  <tr key={inc.id} style={{ height: '22px' }}>
                    <td style={{ padding: '2px 4px' }}><span className="sovereign-status critical"><span className="sovereign-symbol" style={{ fontSize: '10px' }}>●</span></span></td>
                    <td className="sovereign-mono" style={{ fontWeight: 700, padding: '2px 4px' }}>{inc.id}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{inc.site}</td>
                    <td style={{ padding: '2px 4px' }}>{inc.type}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{inc.age}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{inc.assigned}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* CRITICAL BLOCKERS */}
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '3px' }}>CRITICAL BLOCKERS</div>
            <table className="sovereign-table" style={{ fontSize: '10px' }}>
              <thead>
                <tr>
                  <th style={{ width: '24px', padding: '3px 4px' }}>ST</th>
                  <th style={{ width: '70px', padding: '3px 4px' }}>ID</th>
                  <th style={{ padding: '3px 4px' }}>DESCRIPTION</th>
                </tr>
              </thead>
              <tbody>
                {criticalBlockers.map((blk) => (
                  <tr key={blk.id} style={{ height: '22px' }}>
                    <td style={{ padding: '2px 4px' }}><span className="sovereign-status critical"><span className="sovereign-symbol" style={{ fontSize: '10px' }}>●</span></span></td>
                    <td className="sovereign-mono" style={{ fontWeight: 700, padding: '2px 4px' }}>{blk.id}</td>
                    <td style={{ padding: '2px 4px' }}>{blk.desc}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* ROW 3: Status Grids - Remaining height (flex) */}
        <div style={{ display: 'grid', gridTemplateColumns: '200px 1fr 200px', gap: '6px', flex: 1, minHeight: 0 }}>
          
          {/* SITE STATUS GRID */}
          <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '3px' }}>SITE WATCH</div>
            <table className="sovereign-table" style={{ fontSize: '10px' }}>
              <thead>
                <tr>
                  <th style={{ width: '24px', padding: '3px 4px' }}>ST</th>
                  <th style={{ width: '50px', padding: '3px 4px' }}>CODE</th>
                  <th style={{ width: '45px', padding: '3px 4px' }}>CAM</th>
                  <th style={{ width: '35px', padding: '3px 4px' }}>GRD</th>
                </tr>
              </thead>
              <tbody>
                {siteStatus.map((site) => (
                  <tr key={site.code} style={{ height: '22px' }}>
                    <td style={{ padding: '2px 4px' }}>
                      <span className={`sovereign-status ${site.status === 'available' ? 'normal' : site.status === 'limited' ? 'warning' : 'critical'}`}>
                        <span className="sovereign-symbol" style={{ fontSize: '10px' }}>{site.status === 'available' ? '✓' : site.status === 'limited' ? '⚠' : '✗'}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ fontWeight: 700, padding: '2px 4px' }}>{site.code}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{site.cam}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{site.grd}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* FLEET READINESS GRID */}
          <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '3px' }}>FLEET READINESS MATRIX</div>
            <table className="sovereign-table" style={{ fontSize: '10px' }}>
              <thead>
                <tr>
                  <th style={{ width: '70px', padding: '3px 4px' }}>CODE</th>
                  <th style={{ width: '40px', padding: '3px 4px' }}>RADIO</th>
                  <th style={{ width: '40px', padding: '3px 4px' }}>WEAR</th>
                  <th style={{ width: '40px', padding: '3px 4px' }}>VIDEO</th>
                  <th style={{ width: '40px', padding: '3px 4px' }}>OVRL</th>
                </tr>
              </thead>
              <tbody>
                {fleetStatus.map((off) => {
                  const allReady = off.radio === '✓' && off.wear === '✓' && off.video === '✓';
                  const anyOffline = off.radio === '✗' || off.wear === '✗' || off.video === '✗';
                  const overallStatus = allReady ? 'normal' : anyOffline ? 'critical' : 'warning';
                  const overallSymbol = allReady ? '✓' : anyOffline ? '✗' : '⚠';
                  
                  return (
                    <tr key={off.code} style={{ height: '22px' }}>
                      <td className="sovereign-mono" style={{ fontWeight: 700, padding: '2px 4px' }}>{off.code}</td>
                      <td className={`sovereign-status ${off.radio === '✓' ? 'normal' : off.radio === '⚠' ? 'warning' : 'critical'}`} style={{ padding: '2px 4px' }}>
                        {off.radio}
                      </td>
                      <td className={`sovereign-status ${off.wear === '✓' ? 'normal' : off.wear === '⚠' ? 'warning' : 'critical'}`} style={{ padding: '2px 4px' }}>
                        {off.wear}
                      </td>
                      <td className={`sovereign-status ${off.video === '✓' ? 'normal' : off.video === '⚠' ? 'warning' : 'critical'}`} style={{ padding: '2px 4px' }}>
                        {off.video}
                      </td>
                      <td className={`sovereign-status ${overallStatus}`} style={{ padding: '2px 4px' }}>
                        {overallSymbol}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* SYSTEM STATUS GRID */}
          <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            <div style={{ fontSize: '8px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '3px' }}>SYSTEM HEALTH</div>
            <table className="sovereign-table" style={{ fontSize: '10px' }}>
              <thead>
                <tr>
                  <th style={{ width: '24px', padding: '3px 4px' }}>ST</th>
                  <th style={{ padding: '3px 4px' }}>SYS</th>
                  <th style={{ width: '50px', padding: '3px 4px' }}>UP%</th>
                </tr>
              </thead>
              <tbody>
                {systemStatus.map((sys, idx) => (
                  <tr key={idx} style={{ height: '22px' }}>
                    <td style={{ padding: '2px 4px' }}>
                      <span className={`sovereign-status ${sys.status === '✓' ? 'normal' : sys.status === '⚠' ? 'warning' : 'critical'}`}>
                        <span className="sovereign-symbol" style={{ fontSize: '10px' }}>{sys.status}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{sys.sys}</td>
                    <td className="sovereign-mono" style={{ padding: '2px 4px' }}>{sys.uptime}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

      </div>

      {/* Action Bar - 32px height */}
      <div className="sovereign-action-bar" style={{ height: '32px', padding: '0 12px', fontSize: '9px' }}>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center', fontFamily: 'var(--sovereign-font-mono)' }}>
          <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
            <span style={{ color: 'var(--sovereign-text-tertiary)' }}>STATUS:</span>
            <span className={`sovereign-status ${overallStatus}`} style={{ fontWeight: 700, textTransform: 'uppercase' }}>
              {overallStatus}
            </span>
          </div>
          <div style={{ color: 'var(--sovereign-text-tertiary)' }}>|</div>
          <div>POLL:2s</div>
          <div style={{ color: 'var(--sovereign-text-tertiary)' }}>|</div>
          <div>ALERTS:ON</div>
        </div>
        <div style={{ display: 'flex', gap: '6px' }}>
          <button className="sovereign-btn" style={{ padding: '2px 8px', fontSize: '9px' }}>→ LIVE</button>
          <button className="sovereign-btn" style={{ padding: '2px 8px', fontSize: '9px' }}>→ TACTICAL</button>
          <button className="sovereign-btn" style={{ padding: '2px 8px', fontSize: '9px' }}>→ ADMIN</button>
          <button className="sovereign-btn" style={{ padding: '2px 8px', fontSize: '9px' }}>→ GOV</button>
        </div>
      </div>
    </div>
  );
}