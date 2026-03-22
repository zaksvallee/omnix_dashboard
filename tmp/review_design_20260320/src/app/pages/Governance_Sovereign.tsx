import React, { useState } from 'react';

interface Blocker {
  id: string;
  type: 'critical' | 'warning' | 'info';
  category: string;
  description: string;
  source: string;
  timestamp: string;
  status: 'pending' | 'acknowledged' | 'resolved';
}

interface Compliance {
  id: string;
  category: string;
  requirement: string;
  status: 'verified' | 'pending' | 'failed';
  lastCheck: string;
  evidence: string;
}

export default function Governance_Sovereign() {
  const [viewMode, setViewMode] = useState<'morning' | 'blockers' | 'compliance'>('morning');
  const [selectedBlocker, setSelectedBlocker] = useState<string | null>(null);

  const blockers: Blocker[] = [
    { id: 'BLK-001', type: 'critical', category: 'TACTICAL-WATCH', description: 'Valley North watch unavailable for 6h', source: 'VN-04', timestamp: '03:18:05', status: 'pending' },
    { id: 'BLK-002', type: 'critical', category: 'EQUIPMENT', description: 'Officer G-2446 offline - all systems unresponsive', source: 'G-2446', timestamp: '21:42:15', status: 'acknowledged' },
    { id: 'BLK-003', type: 'warning', category: 'CLIENT-COMMS', description: 'Telegram blocked for Valley North client', source: 'CLIENT-VN-04', timestamp: '03:15:44', status: 'pending' },
    { id: 'BLK-004', type: 'warning', category: 'DISPATCH', description: 'INC-2442 pending assignment for 26s', source: 'INC-2442', timestamp: '03:26:08', status: 'pending' },
    { id: 'BLK-005', type: 'info', category: 'SYSTEM', description: 'Client comms degraded - SMS fallback active', source: 'COMMS-SYS', timestamp: '02:44:12', status: 'resolved' },
  ];

  const compliance: Compliance[] = [
    { id: 'C-001', category: 'EVIDENCE', requirement: 'CCTV footage retention 90d', status: 'verified', lastCheck: '12s', evidence: 'EVD-CCTV-2441' },
    { id: 'C-002', category: 'REPORTING', requirement: 'Morning sovereign report generated', status: 'verified', lastCheck: '142s', evidence: 'RPT-MORNING-2024-03-19' },
    { id: 'C-003', category: 'RESPONSE-TIME', requirement: 'Critical incident response <60s', status: 'pending', lastCheck: '8s', evidence: 'INC-2441' },
    { id: 'C-004', category: 'VERIFICATION', requirement: 'Ledger chain integrity check', status: 'verified', lastCheck: '5s', evidence: 'LDG-BLK-2441' },
    { id: 'C-005', category: 'EVIDENCE', requirement: 'Guard OB entry validation', status: 'verified', lastCheck: '24s', evidence: 'OB-G-2441-142' },
    { id: 'C-006', category: 'REPORTING', requirement: 'Partner dispatch documentation', status: 'failed', lastCheck: '142s', evidence: 'DSP-PTR-44' },
  ];

  const criticalBlockers = blockers.filter(b => b.type === 'critical').length;
  const warningBlockers = blockers.filter(b => b.type === 'warning').length;
  const pendingBlockers = blockers.filter(b => b.status === 'pending').length;

  const complianceVerified = compliance.filter(c => c.status === 'verified').length;
  const complianceFailed = compliance.filter(c => c.status === 'failed').length;
  const compliancePending = compliance.filter(c => c.status === 'pending').length;

  const selected = blockers.find(b => b.id === selectedBlocker);

  const getBlockerSymbol = (type: string) => {
    switch (type) {
      case 'critical': return '●';
      case 'warning': return '⚠';
      case 'info': return 'ⓘ';
      default: return '○';
    }
  };

  const getBlockerClass = (type: string) => {
    switch (type) {
      case 'critical': return 'critical';
      case 'warning': return 'warning';
      case 'info': return 'info';
      default: return '';
    }
  };

  const getComplianceSymbol = (status: string) => {
    switch (status) {
      case 'verified': return '✓';
      case 'pending': return '◷';
      case 'failed': return '✗';
      default: return '○';
    }
  };

  const getComplianceClass = (status: string) => {
    switch (status) {
      case 'verified': return 'normal';
      case 'pending': return 'warning';
      case 'failed': return 'critical';
      default: return '';
    }
  };

  return (
    <div className="sovereign sovereign-page">
      {/* Status Bar */}
      <div className={`sovereign-status-bar ${criticalBlockers > 0 || complianceFailed > 0 ? 'critical' : warningBlockers > 0 || compliancePending > 0 ? 'warning' : 'normal'}`}>
        <div>GOVERNANCE | {criticalBlockers} CRITICAL BLOCKERS | {complianceFailed} COMPLIANCE FAILURES | {pendingBlockers} PENDING</div>
        <div>VERIFIED: {complianceVerified}/{compliance.length} | UTC: 03:36:12</div>
      </div>

      {/* Control Bar */}
      <div className="sovereign-controls">
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <button 
            className={`sovereign-btn ${viewMode === 'morning' ? 'active' : ''}`}
            onClick={() => setViewMode('morning')}
          >
            MORNING REPORT
          </button>
          <button 
            className={`sovereign-btn ${viewMode === 'blockers' ? 'active' : ''}`}
            onClick={() => setViewMode('blockers')}
          >
            BLOCKERS
          </button>
          <button 
            className={`sovereign-btn ${viewMode === 'compliance' ? 'active' : ''}`}
            onClick={() => setViewMode('compliance')}
          >
            COMPLIANCE
          </button>
        </div>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <button className="sovereign-btn">GENERATE REPORT</button>
          <button className="sovereign-btn">EXPORT</button>
        </div>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* Main Content */}
        <div className="sovereign-content" style={{ flex: 1 }}>
          {viewMode === 'morning' && (
            <div style={{ padding: '16px' }}>
              <div style={{ fontSize: '11px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '12px' }}>MORNING SOVEREIGN REPORT - 2024-03-19</div>
              
              {/* Executive Summary */}
              <div style={{ marginBottom: '16px' }}>
                <div className="sovereign-card">
                  <div className="sovereign-card-header">EXECUTIVE SUMMARY</div>
                  <div className="sovereign-grid" style={{ gridTemplateColumns: '1fr 1fr 1fr 1fr', marginTop: '8px' }}>
                    <div className="sovereign-grid-header">INCIDENTS</div>
                    <div className="sovereign-grid-header">BLOCKERS</div>
                    <div className="sovereign-grid-header">COMPLIANCE</div>
                    <div className="sovereign-grid-header">UPTIME</div>
                    <div className="sovereign-grid-cell sovereign-mono">15 total</div>
                    <div className="sovereign-grid-cell sovereign-mono">{criticalBlockers} critical</div>
                    <div className="sovereign-grid-cell sovereign-mono">{complianceVerified}/{compliance.length} verified</div>
                    <div className="sovereign-grid-cell sovereign-mono">99.8%</div>
                  </div>
                </div>
              </div>

              {/* Critical Blockers */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{ fontSize: '10px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '8px' }}>CRITICAL BLOCKERS</div>
                <table className="sovereign-table">
                  <thead>
                    <tr>
                      <th style={{ width: '40px' }}>ST</th>
                      <th style={{ width: '90px' }}>ID</th>
                      <th style={{ width: '120px' }}>CATEGORY</th>
                      <th>DESCRIPTION</th>
                      <th style={{ width: '90px' }}>SOURCE</th>
                      <th style={{ width: '80px' }}>TIME</th>
                    </tr>
                  </thead>
                  <tbody>
                    {blockers.filter(b => b.type === 'critical').map((blocker) => (
                      <tr key={blocker.id}>
                        <td>
                          <span className={`sovereign-status ${getBlockerClass(blocker.type)}`}>
                            <span className="sovereign-symbol">{getBlockerSymbol(blocker.type)}</span>
                          </span>
                        </td>
                        <td className="sovereign-mono" style={{ fontWeight: 700 }}>{blocker.id}</td>
                        <td className="sovereign-mono">{blocker.category}</td>
                        <td>{blocker.description}</td>
                        <td className="sovereign-mono">{blocker.source}</td>
                        <td className="sovereign-mono">{blocker.timestamp}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {/* Compliance Summary */}
              <div style={{ marginBottom: '16px' }}>
                <div style={{ fontSize: '10px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '8px' }}>COMPLIANCE STATUS</div>
                <table className="sovereign-table">
                  <thead>
                    <tr>
                      <th style={{ width: '40px' }}>ST</th>
                      <th style={{ width: '120px' }}>CATEGORY</th>
                      <th>REQUIREMENT</th>
                      <th style={{ width: '100px' }}>STATUS</th>
                      <th style={{ width: '120px' }}>EVIDENCE</th>
                    </tr>
                  </thead>
                  <tbody>
                    {compliance.map((item) => (
                      <tr key={item.id}>
                        <td>
                          <span className={`sovereign-status ${getComplianceClass(item.status)}`}>
                            <span className="sovereign-symbol">{getComplianceSymbol(item.status)}</span>
                          </span>
                        </td>
                        <td className="sovereign-mono">{item.category}</td>
                        <td>{item.requirement}</td>
                        <td className={`sovereign-status ${getComplianceClass(item.status)}`} style={{ textTransform: 'uppercase' }}>
                          {item.status}
                        </td>
                        <td className="sovereign-mono" style={{ fontSize: '11px' }}>{item.evidence}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {viewMode === 'blockers' && (
            <table className="sovereign-table">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>ST</th>
                  <th style={{ width: '90px' }}>ID</th>
                  <th style={{ width: '120px' }}>CATEGORY</th>
                  <th>DESCRIPTION</th>
                  <th style={{ width: '100px' }}>SOURCE</th>
                  <th style={{ width: '80px' }}>TIME</th>
                  <th style={{ width: '100px' }}>STATUS</th>
                  <th style={{ width: '50px' }}>ACT</th>
                </tr>
              </thead>
              <tbody>
                {blockers.map((blocker) => (
                  <tr 
                    key={blocker.id}
                    className={selectedBlocker === blocker.id ? 'selected' : ''}
                    onClick={() => setSelectedBlocker(blocker.id)}
                    style={{ cursor: 'pointer' }}
                  >
                    <td>
                      <span className={`sovereign-status ${getBlockerClass(blocker.type)}`}>
                        <span className="sovereign-symbol">{getBlockerSymbol(blocker.type)}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ fontWeight: 700 }}>{blocker.id}</td>
                    <td className="sovereign-mono">{blocker.category}</td>
                    <td>{blocker.description}</td>
                    <td className="sovereign-mono">{blocker.source}</td>
                    <td className="sovereign-mono">{blocker.timestamp}</td>
                    <td className="sovereign-mono" style={{ textTransform: 'uppercase' }}>{blocker.status}</td>
                    <td style={{ textAlign: 'center' }}>→</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          {viewMode === 'compliance' && (
            <table className="sovereign-table">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>ST</th>
                  <th style={{ width: '80px' }}>ID</th>
                  <th style={{ width: '140px' }}>CATEGORY</th>
                  <th>REQUIREMENT</th>
                  <th style={{ width: '100px' }}>STATUS</th>
                  <th style={{ width: '90px' }}>LAST CHECK</th>
                  <th style={{ width: '140px' }}>EVIDENCE</th>
                  <th style={{ width: '50px' }}>ACT</th>
                </tr>
              </thead>
              <tbody>
                {compliance.map((item) => (
                  <tr key={item.id}>
                    <td>
                      <span className={`sovereign-status ${getComplianceClass(item.status)}`}>
                        <span className="sovereign-symbol">{getComplianceSymbol(item.status)}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ fontWeight: 700 }}>{item.id}</td>
                    <td className="sovereign-mono">{item.category}</td>
                    <td>{item.requirement}</td>
                    <td className={`sovereign-status ${getComplianceClass(item.status)}`} style={{ textTransform: 'uppercase' }}>
                      {item.status}
                    </td>
                    <td className="sovereign-mono">{item.lastCheck}</td>
                    <td className="sovereign-mono" style={{ fontSize: '11px' }}>{item.evidence}</td>
                    <td style={{ textAlign: 'center' }}>→</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* Detail Panel */}
        {selected && viewMode === 'blockers' && (
          <div className="sovereign-detail-panel" style={{ width: '300px' }}>
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '10px', color: 'var(--sovereign-text-tertiary)', marginBottom: '4px' }}>BLOCKER DETAIL</div>
              <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--sovereign-text-primary)' }}>{selected.id}</div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <div className="sovereign-metric-label">SEVERITY</div>
                <div className={`sovereign-status ${getBlockerClass(selected.type)}`} style={{ fontSize: '13px', marginTop: '4px' }}>
                  <span className="sovereign-symbol">{getBlockerSymbol(selected.type)}</span>
                  <span style={{ textTransform: 'uppercase' }}>{selected.type}</span>
                </div>
              </div>

              <div>
                <div className="sovereign-metric-label">CATEGORY</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.category}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">DESCRIPTION</div>
                <div style={{ fontSize: '11px', color: 'var(--sovereign-text-secondary)', marginTop: '4px' }}>
                  {selected.description}
                </div>
              </div>

              <div>
                <div className="sovereign-metric-label">SOURCE</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.source}</div>
              </div>

              <div>
                <div className="sovereign-metric-label">DETECTED</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px' }}>{selected.timestamp} UTC</div>
              </div>

              <div>
                <div className="sovereign-metric-label">STATUS</div>
                <div className="sovereign-metric-value" style={{ fontSize: '12px', textTransform: 'uppercase' }}>{selected.status}</div>
              </div>
            </div>

            <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--sovereign-border)' }}>
              {selected.status === 'pending' && (
                <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>ACKNOWLEDGE</button>
              )}
              {selected.type === 'critical' && (
                <button className="sovereign-btn critical" style={{ width: '100%', marginBottom: '6px' }}>ESCALATE</button>
              )}
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW SOURCE</button>
              <button className="sovereign-btn" style={{ width: '100%' }}>RESOLVE</button>
            </div>
          </div>
        )}
      </div>

      {/* Action Bar */}
      <div className="sovereign-action-bar">
        <div style={{ display: 'flex', gap: '8px' }}>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-tertiary)' }}>VIEW: </span>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-primary)', fontWeight: 700, textTransform: 'uppercase' }}>{viewMode}</span>
        </div>
        <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">CRITICAL</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-critical)' }}>{criticalBlockers}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">WARNING</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-warning)' }}>{warningBlockers}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">VERIFIED</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-normal)' }}>{complianceVerified}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
