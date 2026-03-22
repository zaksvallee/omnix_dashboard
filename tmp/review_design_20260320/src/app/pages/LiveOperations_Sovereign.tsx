import React, { useState } from 'react';

interface Incident {
  id: string;
  time: string;
  site: string;
  siteCode: string;
  type: string;
  status: 'critical' | 'warning' | 'normal';
  assigned: string;
  age: string;
  ageSeconds: number;
}

export default function LiveOperations_Sovereign() {
  const [selectedIncident, setSelectedIncident] = useState<string | null>('INC-2441');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [pollingActive, setPollingActive] = useState(true);

  const incidents: Incident[] = [
    { id: 'INC-2441', time: '03:24:12', site: 'Summit East', siteCode: 'SE-01', type: 'INTRUSION', status: 'critical', assigned: 'G-2441', age: '142s', ageSeconds: 142 },
    { id: 'INC-2442', time: '03:26:08', site: 'Waterfront Plaza', siteCode: 'WF-02', type: 'ALARM', status: 'warning', assigned: 'PENDING', age: '26s', ageSeconds: 26 },
    { id: 'INC-2443', time: '03:21:44', site: 'Bridge Central', siteCode: 'BR-03', type: 'PATROL', status: 'normal', assigned: 'G-2442', age: '14m 28s', ageSeconds: 868 },
    { id: 'INC-2440', time: '03:18:15', site: 'Valley North', siteCode: 'VN-04', type: 'DISPATCH', status: 'normal', assigned: 'RO-1242', age: '17m 57s', ageSeconds: 1077 },
    { id: 'INC-2439', time: '03:15:02', site: 'Summit East', siteCode: 'SE-01', type: 'PATROL', status: 'normal', assigned: 'G-2441', age: '21m 10s', ageSeconds: 1270 },
    { id: 'INC-2438', time: '03:12:44', site: 'Harbor Point', siteCode: 'HP-05', type: 'ALARM', status: 'warning', assigned: 'G-2443', age: '23m 28s', ageSeconds: 1408 },
    { id: 'INC-2437', time: '03:10:21', site: 'Waterfront Plaza', siteCode: 'WF-02', type: 'PATROL', status: 'normal', assigned: 'G-2444', age: '25m 51s', ageSeconds: 1551 },
    { id: 'INC-2436', time: '03:08:05', site: 'Bridge Central', siteCode: 'BR-03', type: 'DISPATCH', status: 'normal', assigned: 'RO-1243', age: '28m 7s', ageSeconds: 1687 },
    { id: 'INC-2435', time: '03:05:42', site: 'Valley North', siteCode: 'VN-04', type: 'INTRUSION', status: 'critical', assigned: 'G-2445', age: '30m 30s', ageSeconds: 1830 },
    { id: 'INC-2434', time: '03:03:18', site: 'Summit East', siteCode: 'SE-01', type: 'PATROL', status: 'normal', assigned: 'G-2441', age: '32m 54s', ageSeconds: 1974 },
    { id: 'INC-2433', time: '03:01:02', site: 'Harbor Point', siteCode: 'HP-05', type: 'ALARM', status: 'warning', assigned: 'G-2443', age: '35m 10s', ageSeconds: 2110 },
    { id: 'INC-2432', time: '02:58:44', site: 'Waterfront Plaza', siteCode: 'WF-02', type: 'PATROL', status: 'normal', assigned: 'G-2444', age: '37m 28s', ageSeconds: 2248 },
    { id: 'INC-2431', time: '02:56:21', site: 'Bridge Central', siteCode: 'BR-03', type: 'DISPATCH', status: 'normal', assigned: 'RO-1242', age: '39m 51s', ageSeconds: 2391 },
    { id: 'INC-2430', time: '02:54:05', site: 'Valley North', siteCode: 'VN-04', type: 'PATROL', status: 'normal', assigned: 'G-2445', age: '42m 7s', ageSeconds: 2527 },
    { id: 'INC-2429', time: '02:51:42', site: 'Summit East', siteCode: 'SE-01', type: 'ALARM', status: 'warning', assigned: 'G-2441', age: '44m 30s', ageSeconds: 2670 },
  ];

  const filteredIncidents = incidents.filter(inc => {
    if (filterStatus === 'all') return true;
    return inc.status === filterStatus;
  });

  const criticalCount = incidents.filter(i => i.status === 'critical').length;
  const warningCount = incidents.filter(i => i.status === 'warning').length;
  const pendingCount = incidents.filter(i => i.assigned === 'PENDING').length;

  const selected = incidents.find(i => i.id === selectedIncident);

  const getStatusSymbol = (status: string) => {
    switch (status) {
      case 'critical': return '●';
      case 'warning': return '⚠';
      case 'normal': return '✓';
      default: return '○';
    }
  };

  const getStatusClass = (status: string) => {
    switch (status) {
      case 'critical': return 'critical';
      case 'warning': return 'warning';
      case 'normal': return 'normal';
      default: return '';
    }
  };

  return (
    <div className="sovereign sovereign-page">
      {/* Status Bar */}
      <div className={`sovereign-status-bar ${criticalCount > 0 ? 'critical' : warningCount > 0 ? 'warning' : 'normal'}`}>
        <div>LIVE OPERATIONS | {incidents.length} ACTIVE | {criticalCount} CRITICAL | {pendingCount} PENDING</div>
        <div>POLL: {pollingActive ? 'ON (2s)' : 'OFF'} | QUEUE: 3 | UTC: 03:36:12</div>
      </div>

      {/* Control Bar */}
      <div className="sovereign-controls">
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <span style={{ color: 'var(--sovereign-text-tertiary)' }}>FILTERS:</span>
          <button 
            className={`sovereign-btn ${filterStatus === 'all' ? 'active' : ''}`}
            onClick={() => setFilterStatus('all')}
          >
            ALL
          </button>
          <button 
            className={`sovereign-btn ${filterStatus === 'critical' ? 'active' : ''}`}
            onClick={() => setFilterStatus('critical')}
          >
            CRITICAL
          </button>
          <button 
            className={`sovereign-btn ${filterStatus === 'warning' ? 'active' : ''}`}
            onClick={() => setFilterStatus('warning')}
          >
            WARNING
          </button>
          <button 
            className={`sovereign-btn ${filterStatus === 'normal' ? 'active' : ''}`}
            onClick={() => setFilterStatus('normal')}
          >
            NORMAL
          </button>
        </div>
        
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <button 
            className={`sovereign-btn ${pollingActive ? 'active' : ''}`}
            onClick={() => setPollingActive(!pollingActive)}
          >
            POLL
          </button>
          <button className="sovereign-btn">MANUAL REFRESH</button>
        </div>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* Main Table */}
        <div className="sovereign-content" style={{ flex: 1 }}>
          <table className="sovereign-table">
            <thead>
              <tr>
                <th style={{ width: '40px' }}>ST</th>
                <th style={{ width: '100px' }}>ID</th>
                <th style={{ width: '80px' }}>TIME</th>
                <th style={{ width: '140px' }}>SITE</th>
                <th style={{ width: '60px' }}>CODE</th>
                <th style={{ width: '110px' }}>TYPE</th>
                <th style={{ width: '80px' }}>ASSIGNED</th>
                <th style={{ width: '90px' }}>AGE</th>
                <th style={{ width: '60px' }}>ACT</th>
              </tr>
            </thead>
            <tbody>
              {filteredIncidents.map((incident) => (
                <tr 
                  key={incident.id}
                  className={selectedIncident === incident.id ? 'selected' : ''}
                  onClick={() => setSelectedIncident(incident.id)}
                  style={{ cursor: 'pointer' }}
                >
                  <td>
                    <span className={`sovereign-status ${getStatusClass(incident.status)}`}>
                      <span className="sovereign-symbol">{getStatusSymbol(incident.status)}</span>
                    </span>
                  </td>
                  <td className="sovereign-mono" style={{ fontWeight: 700 }}>{incident.id}</td>
                  <td className="sovereign-mono">{incident.time}</td>
                  <td>{incident.site}</td>
                  <td className="sovereign-mono">{incident.siteCode}</td>
                  <td className="sovereign-mono">{incident.type}</td>
                  <td className="sovereign-mono">{incident.assigned}</td>
                  <td className="sovereign-mono">{incident.age}</td>
                  <td style={{ textAlign: 'center' }}>→</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Detail Panel */}
        {selected && (
          <div className="sovereign-detail-panel" style={{ width: '320px' }}>
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '10px', color: 'var(--sovereign-text-tertiary)', marginBottom: '4px' }}>INCIDENT DETAIL</div>
              <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--sovereign-text-primary)' }}>{selected.id}</div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <div className="sovereign-metric-label">STATUS</div>
                <div className={`sovereign-status ${getStatusClass(selected.status)}`} style={{ fontSize: '14px', marginTop: '4px' }}>
                  <span className="sovereign-symbol">{getStatusSymbol(selected.status)}</span>
                  <span>{selected.status.toUpperCase()}</span>
                </div>
              </div>

              <div>
                <div className="sovereign-metric-label">SITE</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.site}</div>
                <div className="sovereign-mono" style={{ fontSize: '11px', color: 'var(--sovereign-text-tertiary)', marginTop: '2px' }}>{selected.siteCode}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">TYPE</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.type}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">ASSIGNED</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.assigned}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">OPENED</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.time} UTC</div>
              </div>

              <div>
                <div className="sovereign-metric-label">AGE</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.age}</div>
              </div>

              <div style={{ marginTop: '8px', paddingTop: '12px', borderTop: '1px solid var(--sovereign-border)' }}>
                <div className="sovereign-metric-label">EVIDENCE</div>
                <div className="sovereign-grid" style={{ gridTemplateColumns: '1fr 1fr', marginTop: '4px' }}>
                  <div className="sovereign-grid-header">CCTV</div>
                  <div className="sovereign-grid-header">OB</div>
                  <div className="sovereign-grid-cell">12 clips</div>
                  <div className="sovereign-grid-cell">8 entries</div>
                </div>
              </div>

              <div style={{ marginTop: '8px', paddingTop: '12px', borderTop: '1px solid var(--sovereign-border)' }}>
                <div className="sovereign-metric-label">VERIFICATION</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '4px' }}>
                  <div className="sovereign-indicator normal"></div>
                  <span style={{ fontSize: '11px', color: 'var(--sovereign-normal)' }}>VERIFIED</span>
                </div>
              </div>
            </div>

            <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--sovereign-border)' }}>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW TACTICAL</button>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW EVIDENCE</button>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW LEDGER</button>
              <button className="sovereign-btn critical" style={{ width: '100%' }}>ESCALATE</button>
            </div>
          </div>
        )}
      </div>

      {/* Action Bar */}
      <div className="sovereign-action-bar">
        <div style={{ display: 'flex', gap: '8px' }}>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-tertiary)' }}>SELECTED: </span>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-primary)', fontWeight: 700 }}>{selectedIncident || 'NONE'}</span>
        </div>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span className="sovereign-symbol" style={{ color: 'var(--sovereign-critical)' }}>●</span>
            <span style={{ fontSize: '11px' }}>CRITICAL</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span className="sovereign-symbol" style={{ color: 'var(--sovereign-warning)' }}>⚠</span>
            <span style={{ fontSize: '11px' }}>WARNING</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            <span className="sovereign-symbol" style={{ color: 'var(--sovereign-normal)' }}>✓</span>
            <span style={{ fontSize: '11px' }}>NORMAL</span>
          </div>
        </div>
      </div>
    </div>
  );
}
