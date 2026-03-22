import React, { useState } from 'react';

interface Officer {
  id: string;
  code: string;
  name: string;
  role: string;
  radio: 'ready' | 'degraded' | 'offline';
  wearable: 'ready' | 'degraded' | 'offline';
  video: 'ready' | 'degraded' | 'offline';
  location: 'on-site' | 'mobile' | 'unknown';
  lastSync: string;
}

interface SystemStatus {
  system: string;
  status: 'operational' | 'degraded' | 'critical';
  uptime: string;
  lastCheck: string;
}

export default function Admin_Sovereign() {
  const [selectedOfficer, setSelectedOfficer] = useState<string | null>('G-2441');

  const officers: Officer[] = [
    { id: '1', code: 'G-2441', name: 'Martinez, J.', role: 'GUARD', radio: 'ready', wearable: 'ready', video: 'ready', location: 'on-site', lastSync: '5s' },
    { id: '2', code: 'G-2442', name: 'Chen, L.', role: 'GUARD', radio: 'ready', wearable: 'ready', video: 'degraded', location: 'on-site', lastSync: '12s' },
    { id: '3', code: 'G-2443', name: 'Johnson, M.', role: 'GUARD', radio: 'degraded', wearable: 'ready', video: 'ready', location: 'on-site', lastSync: '8s' },
    { id: '4', code: 'G-2444', name: 'Williams, K.', role: 'GUARD', radio: 'ready', wearable: 'degraded', video: 'ready', location: 'mobile', lastSync: '15s' },
    { id: '5', code: 'RO-1242', name: 'Davis, R.', role: 'REACTION', radio: 'ready', wearable: 'ready', video: 'ready', location: 'mobile', lastSync: '7s' },
    { id: '6', code: 'RO-1243', name: 'Brown, S.', role: 'REACTION', radio: 'ready', wearable: 'ready', video: 'offline', location: 'mobile', lastSync: '142s' },
    { id: '7', code: 'G-2445', name: 'Taylor, A.', role: 'GUARD', radio: 'ready', wearable: 'ready', video: 'ready', location: 'on-site', lastSync: '4s' },
    { id: '8', code: 'G-2446', name: 'Anderson, P.', role: 'GUARD', radio: 'offline', wearable: 'offline', video: 'offline', location: 'unknown', lastSync: '6h' },
  ];

  const systems: SystemStatus[] = [
    { system: 'FSK HARDWARE', status: 'operational', uptime: '99.9%', lastCheck: '12s' },
    { system: 'AI PIPELINE', status: 'operational', uptime: '99.8%', lastCheck: '8s' },
    { system: 'CCTV INGEST', status: 'operational', uptime: '99.7%', lastCheck: '5s' },
    { system: 'CLIENT COMMS', status: 'degraded', uptime: '98.2%', lastCheck: '15s' },
    { system: 'LEDGER SYNC', status: 'operational', uptime: '100%', lastCheck: '3s' },
    { system: 'DISPATCH QUEUE', status: 'operational', uptime: '99.9%', lastCheck: '10s' },
  ];

  const selected = officers.find(o => o.code === selectedOfficer);

  const getReadinessSymbol = (status: string) => {
    switch (status) {
      case 'ready': return '✓';
      case 'degraded': return '⚠';
      case 'offline': return '✗';
      default: return '○';
    }
  };

  const getReadinessClass = (status: string) => {
    switch (status) {
      case 'ready': return 'normal';
      case 'degraded': return 'warning';
      case 'offline': return 'critical';
      default: return '';
    }
  };

  const getSystemClass = (status: string) => {
    switch (status) {
      case 'operational': return 'normal';
      case 'degraded': return 'warning';
      case 'critical': return 'critical';
      default: return '';
    }
  };

  const readyCount = officers.filter(o => o.radio === 'ready' && o.wearable === 'ready' && o.video === 'ready').length;
  const degradedCount = officers.filter(o => o.radio === 'degraded' || o.wearable === 'degraded' || o.video === 'degraded').length;
  const offlineCount = officers.filter(o => o.radio === 'offline' || o.wearable === 'offline' || o.video === 'offline').length;

  const systemCritical = systems.filter(s => s.status === 'critical').length;
  const systemDegraded = systems.filter(s => s.status === 'degraded').length;

  return (
    <div className="sovereign sovereign-page">
      {/* Status Bar */}
      <div className={`sovereign-status-bar ${offlineCount > 0 || systemCritical > 0 ? 'critical' : degradedCount > 0 || systemDegraded > 0 ? 'warning' : 'normal'}`}>
        <div>ADMIN | {officers.length} OFFICERS | {readyCount} READY | {degradedCount} DEGRADED | {offlineCount} OFFLINE</div>
        <div>SYSTEMS: {systemCritical} CRITICAL | {systemDegraded} DEGRADED | UTC: 03:36:12</div>
      </div>

      {/* Control Bar */}
      <div className="sovereign-controls">
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <button className="sovereign-btn active">FLEET READINESS</button>
          <button className="sovereign-btn">SYSTEM STATUS</button>
          <button className="sovereign-btn">AUDIT LOG</button>
        </div>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <button className="sovereign-btn">REFRESH</button>
          <button className="sovereign-btn">DIAGNOSTICS</button>
        </div>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* Main Content */}
        <div className="sovereign-content" style={{ flex: 1, padding: '16px' }}>
          {/* Fleet Readiness Matrix */}
          <div style={{ marginBottom: '24px' }}>
            <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '8px' }}>FLEET READINESS MATRIX</div>
            <table className="sovereign-table">
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>CODE</th>
                  <th style={{ width: '150px' }}>NAME</th>
                  <th style={{ width: '80px' }}>ROLE</th>
                  <th style={{ width: '60px' }}>RADIO</th>
                  <th style={{ width: '80px' }}>WEARABLE</th>
                  <th style={{ width: '60px' }}>VIDEO</th>
                  <th style={{ width: '80px' }}>LOCATION</th>
                  <th style={{ width: '70px' }}>SYNC</th>
                  <th style={{ width: '50px' }}>ACT</th>
                </tr>
              </thead>
              <tbody>
                {officers.map((officer) => (
                  <tr 
                    key={officer.id}
                    className={selectedOfficer === officer.code ? 'selected' : ''}
                    onClick={() => setSelectedOfficer(officer.code)}
                    style={{ cursor: 'pointer' }}
                  >
                    <td className="sovereign-mono" style={{ fontWeight: 700 }}>{officer.code}</td>
                    <td>{officer.name}</td>
                    <td className="sovereign-mono">{officer.role}</td>
                    <td>
                      <span className={`sovereign-status ${getReadinessClass(officer.radio)}`}>
                        <span className="sovereign-symbol">{getReadinessSymbol(officer.radio)}</span>
                      </span>
                    </td>
                    <td>
                      <span className={`sovereign-status ${getReadinessClass(officer.wearable)}`}>
                        <span className="sovereign-symbol">{getReadinessSymbol(officer.wearable)}</span>
                      </span>
                    </td>
                    <td>
                      <span className={`sovereign-status ${getReadinessClass(officer.video)}`}>
                        <span className="sovereign-symbol">{getReadinessSymbol(officer.video)}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ textTransform: 'uppercase', fontSize: '11px' }}>{officer.location}</td>
                    <td className="sovereign-mono">{officer.lastSync}</td>
                    <td style={{ textAlign: 'center' }}>→</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* System Status Grid */}
          <div>
            <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '8px' }}>SYSTEM STATUS</div>
            <table className="sovereign-table">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>ST</th>
                  <th style={{ width: '200px' }}>SYSTEM</th>
                  <th style={{ width: '120px' }}>STATUS</th>
                  <th style={{ width: '100px' }}>UPTIME</th>
                  <th style={{ width: '100px' }}>LAST CHECK</th>
                  <th style={{ width: '80px' }}>ACT</th>
                </tr>
              </thead>
              <tbody>
                {systems.map((sys, idx) => (
                  <tr key={idx}>
                    <td>
                      <span className={`sovereign-status ${getSystemClass(sys.status)}`}>
                        <span className="sovereign-symbol">{getReadinessSymbol(sys.status === 'operational' ? 'ready' : sys.status === 'degraded' ? 'degraded' : 'offline')}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ fontWeight: 700 }}>{sys.system}</td>
                    <td className={`sovereign-status ${getSystemClass(sys.status)}`} style={{ textTransform: 'uppercase' }}>
                      {sys.status}
                    </td>
                    <td className="sovereign-mono">{sys.uptime}</td>
                    <td className="sovereign-mono">{sys.lastCheck}</td>
                    <td style={{ textAlign: 'center' }}>→</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Detail Panel */}
        {selected && (
          <div className="sovereign-detail-panel" style={{ width: '300px' }}>
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '10px', color: 'var(--sovereign-text-tertiary)', marginBottom: '4px' }}>OFFICER DETAIL</div>
              <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--sovereign-text-primary)' }}>{selected.code}</div>
              <div style={{ fontSize: '12px', color: 'var(--sovereign-text-secondary)', marginTop: '2px' }}>{selected.name}</div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <div className="sovereign-metric-label">ROLE</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.role}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">LOCATION</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px', textTransform: 'uppercase' }}>{selected.location}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">LAST SYNC</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.lastSync} ago</div>
              </div>

              <div style={{ marginTop: '8px', paddingTop: '12px', borderTop: '1px solid var(--sovereign-border)' }}>
                <div className="sovereign-metric-label">EQUIPMENT READINESS</div>
                <div className="sovereign-grid" style={{ gridTemplateColumns: '1fr', marginTop: '8px', gap: '1px' }}>
                  <div className="sovereign-grid-header">RADIO</div>
                  <div className="sovereign-grid-cell">
                    <span className={`sovereign-status ${getReadinessClass(selected.radio)}`}>
                      <span className="sovereign-symbol">{getReadinessSymbol(selected.radio)}</span>
                      <span style={{ textTransform: 'uppercase' }}>{selected.radio}</span>
                    </span>
                  </div>
                  
                  <div className="sovereign-grid-header">WEARABLE</div>
                  <div className="sovereign-grid-cell">
                    <span className={`sovereign-status ${getReadinessClass(selected.wearable)}`}>
                      <span className="sovereign-symbol">{getReadinessSymbol(selected.wearable)}</span>
                      <span style={{ textTransform: 'uppercase' }}>{selected.wearable}</span>
                    </span>
                  </div>
                  
                  <div className="sovereign-grid-header">VIDEO</div>
                  <div className="sovereign-grid-cell">
                    <span className={`sovereign-status ${getReadinessClass(selected.video)}`}>
                      <span className="sovereign-symbol">{getReadinessSymbol(selected.video)}</span>
                      <span style={{ textTransform: 'uppercase' }}>{selected.video}</span>
                    </span>
                  </div>
                </div>
              </div>

              <div style={{ marginTop: '8px', paddingTop: '12px', borderTop: '1px solid var(--sovereign-border)' }}>
                <div className="sovereign-metric-label">OVERALL STATUS</div>
                {selected.radio === 'ready' && selected.wearable === 'ready' && selected.video === 'ready' ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                    <div className="sovereign-indicator normal"></div>
                    <span style={{ fontSize: '11px', color: 'var(--sovereign-normal)', fontWeight: 700 }}>FULLY OPERATIONAL</span>
                  </div>
                ) : selected.radio === 'offline' || selected.wearable === 'offline' || selected.video === 'offline' ? (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                    <div className="sovereign-indicator critical"></div>
                    <span style={{ fontSize: '11px', color: 'var(--sovereign-critical)', fontWeight: 700 }}>EQUIPMENT OFFLINE</span>
                  </div>
                ) : (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                    <div className="sovereign-indicator warning"></div>
                    <span style={{ fontSize: '11px', color: 'var(--sovereign-warning)', fontWeight: 700 }}>DEGRADED CAPACITY</span>
                  </div>
                )}
              </div>
            </div>

            <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--sovereign-border)' }}>
              {(selected.radio !== 'ready' || selected.wearable !== 'ready' || selected.video !== 'ready') && (
                <button className="sovereign-btn critical" style={{ width: '100%', marginBottom: '6px' }}>RUN DIAGNOSTICS</button>
              )}
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW SCHEDULE</button>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW INCIDENTS</button>
              <button className="sovereign-btn" style={{ width: '100%' }}>CONTACT OFFICER</button>
            </div>
          </div>
        )}
      </div>

      {/* Action Bar */}
      <div className="sovereign-action-bar">
        <div style={{ display: 'flex', gap: '8px' }}>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-tertiary)' }}>SELECTED: </span>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-primary)', fontWeight: 700 }}>{selectedOfficer || 'NONE'}</span>
        </div>
        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">READY</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-normal)' }}>{readyCount}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">DEGRADED</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-warning)' }}>{degradedCount}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">OFFLINE</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-critical)' }}>{offlineCount}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
