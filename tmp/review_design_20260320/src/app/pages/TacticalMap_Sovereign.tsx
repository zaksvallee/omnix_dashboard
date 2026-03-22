import React, { useState } from 'react';

interface Site {
  id: string;
  code: string;
  name: string;
  lat: number;
  lng: number;
  watchStatus: 'available' | 'limited' | 'unavailable';
  watchReason?: string;
  cameras: number;
  camerasActive: number;
  guards: number;
}

interface Guard {
  id: string;
  code: string;
  name: string;
  site: string;
  siteCode: string;
  lat: number;
  lng: number;
  status: 'active' | 'patrol' | 'sos';
  lastUpdate: string;
}

export default function TacticalMap_Sovereign() {
  const [selectedSite, setSelectedSite] = useState<string | null>('SE-01');
  const [watchFilter, setWatchFilter] = useState<string>('all');

  const sites: Site[] = [
    { id: '1', code: 'SE-01', name: 'Summit East', lat: 34.052, lng: -118.243, watchStatus: 'available', cameras: 8, camerasActive: 8, guards: 2 },
    { id: '2', code: 'WF-02', name: 'Waterfront Plaza', lat: 34.048, lng: -118.250, watchStatus: 'limited', watchReason: 'STALE-FEED', cameras: 12, camerasActive: 10, guards: 1 },
    { id: '3', code: 'BR-03', name: 'Bridge Central', lat: 34.055, lng: -118.245, watchStatus: 'available', cameras: 6, camerasActive: 6, guards: 1 },
    { id: '4', code: 'VN-04', name: 'Valley North', lat: 34.058, lng: -118.248, watchStatus: 'unavailable', watchReason: 'OFFLINE', cameras: 10, camerasActive: 0, guards: 0 },
    { id: '5', code: 'HP-05', name: 'Harbor Point', lat: 34.045, lng: -118.255, watchStatus: 'limited', watchReason: 'DEGRADED-CONN', cameras: 8, camerasActive: 7, guards: 2 },
  ];

  const guards: Guard[] = [
    { id: '1', code: 'G-2441', name: 'Martinez', site: 'Summit East', siteCode: 'SE-01', lat: 34.052, lng: -118.243, status: 'active', lastUpdate: '5s' },
    { id: '2', code: 'G-2442', name: 'Chen', site: 'Bridge Central', siteCode: 'BR-03', lat: 34.055, lng: -118.245, status: 'patrol', lastUpdate: '12s' },
    { id: '3', code: 'G-2443', name: 'Johnson', site: 'Harbor Point', siteCode: 'HP-05', lat: 34.045, lng: -118.255, status: 'active', lastUpdate: '8s' },
    { id: '4', code: 'G-2444', name: 'Williams', site: 'Waterfront Plaza', siteCode: 'WF-02', lat: 34.048, lng: -118.250, status: 'patrol', lastUpdate: '15s' },
    { id: '5', code: 'G-2445', name: 'Davis', site: 'Summit East', siteCode: 'SE-01', lat: 34.052, lng: -118.244, status: 'sos', lastUpdate: '2s' },
  ];

  const filteredSites = sites.filter(site => {
    if (watchFilter === 'all') return true;
    return site.watchStatus === watchFilter;
  });

  const availableCount = sites.filter(s => s.watchStatus === 'available').length;
  const limitedCount = sites.filter(s => s.watchStatus === 'limited').length;
  const unavailableCount = sites.filter(s => s.watchStatus === 'unavailable').length;

  const selected = sites.find(s => s.code === selectedSite);

  const getWatchSymbol = (status: string) => {
    switch (status) {
      case 'available': return '✓';
      case 'limited': return '⚠';
      case 'unavailable': return '✗';
      default: return '○';
    }
  };

  const getWatchClass = (status: string) => {
    switch (status) {
      case 'available': return 'normal';
      case 'limited': return 'warning';
      case 'unavailable': return 'critical';
      default: return '';
    }
  };

  const getGuardSymbol = (status: string) => {
    switch (status) {
      case 'active': return '▲';
      case 'patrol': return '▶';
      case 'sos': return '◆';
      default: return '○';
    }
  };

  const getGuardClass = (status: string) => {
    switch (status) {
      case 'active': return 'normal';
      case 'patrol': return 'info';
      case 'sos': return 'critical';
      default: return '';
    }
  };

  return (
    <div className="sovereign sovereign-page">
      {/* Status Bar */}
      <div className={`sovereign-status-bar ${unavailableCount > 0 ? 'critical' : limitedCount > 0 ? 'warning' : 'normal'}`}>
        <div>TACTICAL MAP | {sites.length} SITES | {guards.length} GUARDS | {unavailableCount} UNAVAILABLE</div>
        <div>FLEET: {availableCount}A / {limitedCount}L / {unavailableCount}U | UTC: 03:36:12</div>
      </div>

      {/* Control Bar */}
      <div className="sovereign-controls">
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <span style={{ color: 'var(--sovereign-text-tertiary)' }}>WATCH:</span>
          <button 
            className={`sovereign-btn ${watchFilter === 'all' ? 'active' : ''}`}
            onClick={() => setWatchFilter('all')}
          >
            ALL
          </button>
          <button 
            className={`sovereign-btn ${watchFilter === 'available' ? 'active' : ''}`}
            onClick={() => setWatchFilter('available')}
          >
            AVAILABLE
          </button>
          <button 
            className={`sovereign-btn ${watchFilter === 'limited' ? 'active' : ''}`}
            onClick={() => setWatchFilter('limited')}
          >
            LIMITED
          </button>
          <button 
            className={`sovereign-btn ${watchFilter === 'unavailable' ? 'active' : ''}`}
            onClick={() => setWatchFilter('unavailable')}
          >
            UNAVAILABLE
          </button>
        </div>
        
        <div style={{ display: 'flex', gap: '8px' }}>
          <button className="sovereign-btn active">SITES</button>
          <button className="sovereign-btn active">GUARDS</button>
          <button className="sovereign-btn">GEOFENCES</button>
        </div>
      </div>

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        {/* Left Panel - Site Table */}
        <div className="sovereign-content" style={{ width: '500px', borderRight: '2px solid var(--sovereign-border)' }}>
          <table className="sovereign-table">
            <thead>
              <tr>
                <th style={{ width: '40px' }}>ST</th>
                <th style={{ width: '70px' }}>CODE</th>
                <th style={{ width: '150px' }}>SITE</th>
                <th style={{ width: '70px' }}>CAM</th>
                <th style={{ width: '60px' }}>GRD</th>
                <th style={{ width: '50px' }}>ACT</th>
              </tr>
            </thead>
            <tbody>
              {filteredSites.map((site) => (
                <tr 
                  key={site.id}
                  className={selectedSite === site.code ? 'selected' : ''}
                  onClick={() => setSelectedSite(site.code)}
                  style={{ cursor: 'pointer' }}
                >
                  <td>
                    <span className={`sovereign-status ${getWatchClass(site.watchStatus)}`}>
                      <span className="sovereign-symbol">{getWatchSymbol(site.watchStatus)}</span>
                    </span>
                  </td>
                  <td className="sovereign-mono" style={{ fontWeight: 700 }}>{site.code}</td>
                  <td>{site.name}</td>
                  <td className="sovereign-mono">{site.camerasActive}/{site.cameras}</td>
                  <td className="sovereign-mono">{site.guards}</td>
                  <td style={{ textAlign: 'center' }}>→</td>
                </tr>
              ))}
            </tbody>
          </table>

          <div style={{ marginTop: '16px', padding: '0 16px' }}>
            <div style={{ fontSize: '10px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '8px' }}>GUARDS ON DUTY</div>
            <table className="sovereign-table">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>ST</th>
                  <th style={{ width: '70px' }}>CODE</th>
                  <th style={{ width: '100px' }}>NAME</th>
                  <th style={{ width: '70px' }}>SITE</th>
                  <th style={{ width: '60px' }}>SYNC</th>
                </tr>
              </thead>
              <tbody>
                {guards.map((guard) => (
                  <tr key={guard.id}>
                    <td>
                      <span className={`sovereign-status ${getGuardClass(guard.status)}`}>
                        <span className="sovereign-symbol">{getGuardSymbol(guard.status)}</span>
                      </span>
                    </td>
                    <td className="sovereign-mono" style={{ fontWeight: 700 }}>{guard.code}</td>
                    <td>{guard.name}</td>
                    <td className="sovereign-mono">{guard.siteCode}</td>
                    <td className="sovereign-mono">{guard.lastUpdate}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Center - Map Display */}
        <div style={{ 
          flex: 1, 
          background: '#0A0A0A',
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}>
          {/* Simplified Map Grid */}
          <div style={{ 
            width: '100%', 
            height: '100%',
            background: 'repeating-linear-gradient(0deg, var(--sovereign-border) 0px, transparent 1px, transparent 40px), repeating-linear-gradient(90deg, var(--sovereign-border) 0px, transparent 1px, transparent 40px)',
            position: 'relative'
          }}>
            {/* Site Markers */}
            {sites.map((site, idx) => (
              <div
                key={site.id}
                onClick={() => setSelectedSite(site.code)}
                style={{
                  position: 'absolute',
                  left: `${20 + idx * 18}%`,
                  top: `${30 + (idx % 2) * 20}%`,
                  cursor: 'pointer',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                <div style={{
                  width: '24px',
                  height: '24px',
                  borderRadius: '50%',
                  border: `3px solid ${
                    site.watchStatus === 'available' ? 'var(--sovereign-normal)' :
                    site.watchStatus === 'limited' ? 'var(--sovereign-warning)' :
                    'var(--sovereign-critical)'
                  }`,
                  background: 'var(--sovereign-bg-surface)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontFamily: 'var(--sovereign-font-mono)',
                  fontSize: '14px',
                  fontWeight: 700,
                  color: site.watchStatus === 'available' ? 'var(--sovereign-normal)' :
                        site.watchStatus === 'limited' ? 'var(--sovereign-warning)' :
                        'var(--sovereign-critical)',
                  boxShadow: selectedSite === site.code ? `0 0 12px ${
                    site.watchStatus === 'available' ? 'var(--sovereign-normal)' :
                    site.watchStatus === 'limited' ? 'var(--sovereign-warning)' :
                    'var(--sovereign-critical)'
                  }` : 'none'
                }}>
                  {getWatchSymbol(site.watchStatus)}
                </div>
                <div style={{
                  fontFamily: 'var(--sovereign-font-mono)',
                  fontSize: '9px',
                  color: 'var(--sovereign-text-secondary)',
                  fontWeight: 700
                }}>
                  {site.code}
                </div>
              </div>
            ))}

            {/* Guard Markers */}
            {guards.map((guard, idx) => {
              const guardSite = sites.find(s => s.code === guard.siteCode);
              const siteIdx = sites.findIndex(s => s.code === guard.siteCode);
              return (
                <div
                  key={guard.id}
                  style={{
                    position: 'absolute',
                    left: `${20 + siteIdx * 18 + (idx % 2) * 3}%`,
                    top: `${30 + (siteIdx % 2) * 20 + 5 + (idx % 2) * 3}%`,
                    width: '16px',
                    height: '16px',
                    color: guard.status === 'active' ? 'var(--sovereign-normal)' :
                          guard.status === 'patrol' ? 'var(--sovereign-info)' :
                          'var(--sovereign-critical)',
                    fontFamily: 'var(--sovereign-font-mono)',
                    fontSize: '12px',
                    fontWeight: 700,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                >
                  {getGuardSymbol(guard.status)}
                </div>
              );
            })}
          </div>

          {/* Map Legend */}
          <div style={{
            position: 'absolute',
            bottom: '16px',
            left: '16px',
            background: 'var(--sovereign-bg-surface)',
            border: '1px solid var(--sovereign-border)',
            padding: '8px 12px'
          }}>
            <div style={{ fontSize: '9px', fontWeight: 700, color: 'var(--sovereign-text-tertiary)', marginBottom: '6px' }}>LEGEND</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', fontSize: '10px', fontFamily: 'var(--sovereign-font-mono)' }}>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ color: 'var(--sovereign-normal)' }}>✓</span>
                <span>WATCH AVAILABLE</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ color: 'var(--sovereign-warning)' }}>⚠</span>
                <span>WATCH LIMITED</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ color: 'var(--sovereign-critical)' }}>✗</span>
                <span>WATCH UNAVAILABLE</span>
              </div>
              <div style={{ borderTop: '1px solid var(--sovereign-border)', marginTop: '4px', paddingTop: '4px' }}>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <span style={{ color: 'var(--sovereign-normal)' }}>▲</span>
                  <span>GUARD ACTIVE</span>
                </div>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <span style={{ color: 'var(--sovereign-info)' }}>▶</span>
                  <span>GUARD PATROL</span>
                </div>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <span style={{ color: 'var(--sovereign-critical)' }}>◆</span>
                  <span>GUARD SOS</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Panel - Detail */}
        {selected && (
          <div className="sovereign-detail-panel" style={{ width: '300px' }}>
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '10px', color: 'var(--sovereign-text-tertiary)', marginBottom: '4px' }}>SITE DETAIL</div>
              <div style={{ fontSize: '16px', fontWeight: 700, color: 'var(--sovereign-text-primary)' }}>{selected.code}</div>
              <div style={{ fontSize: '12px', color: 'var(--sovereign-text-secondary)', marginTop: '2px' }}>{selected.name}</div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div>
                <div className="sovereign-metric-label">WATCH STATUS</div>
                <div className={`sovereign-status ${getWatchClass(selected.watchStatus)}`} style={{ fontSize: '13px', marginTop: '4px' }}>
                  <span className="sovereign-symbol">{getWatchSymbol(selected.watchStatus)}</span>
                  <span>{selected.watchStatus.toUpperCase()}</span>
                </div>
                {selected.watchReason && (
                  <div className="sovereign-mono" style={{ fontSize: '10px', color: 'var(--sovereign-text-tertiary)', marginTop: '4px' }}>
                    REASON: {selected.watchReason}
                  </div>
                )}
              </div>

              <div className="sovereign-grid" style={{ gridTemplateColumns: '1fr 1fr' }}>
                <div className="sovereign-grid-header">CAMERAS</div>
                <div className="sovereign-grid-header">GUARDS</div>
                <div className="sovereign-grid-cell sovereign-mono">{selected.camerasActive}/{selected.cameras}</div>
                <div className="sovereign-grid-cell sovereign-mono">{selected.guards}</div>
              </div>

              {selected.watchStatus === 'limited' && (
                <button className="sovereign-btn" style={{ width: '100%' }}>RECOVER WATCH</button>
              )}

              {selected.watchStatus === 'unavailable' && (
                <button className="sovereign-btn critical" style={{ width: '100%' }}>DISPATCH RESPONSE</button>
              )}

              <div style={{ marginTop: '8px', paddingTop: '12px', borderTop: '1px solid var(--sovereign-border)' }}>
                <div className="sovereign-metric-label">COORDINATES</div>
                <div className="sovereign-mono" style={{ fontSize: '11px', color: 'var(--sovereign-text-secondary)', marginTop: '4px' }}>
                  LAT: {selected.lat.toFixed(6)}
                </div>
                <div className="sovereign-mono" style={{ fontSize: '11px', color: 'var(--sovereign-text-secondary)' }}>
                  LNG: {selected.lng.toFixed(6)}
                </div>
              </div>
            </div>

            <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--sovereign-border)' }}>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW CAMERAS</button>
              <button className="sovereign-btn" style={{ width: '100%', marginBottom: '6px' }}>VIEW GUARDS</button>
              <button className="sovereign-btn" style={{ width: '100%' }}>VIEW INCIDENTS</button>
            </div>
          </div>
        )}
      </div>

      {/* Action Bar */}
      <div className="sovereign-action-bar">
        <div style={{ display: 'flex', gap: '8px' }}>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-tertiary)' }}>SELECTED: </span>
          <span className="sovereign-mono" style={{ color: 'var(--sovereign-text-primary)', fontWeight: 700 }}>{selectedSite || 'NONE'}</span>
        </div>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">AVAILABLE</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-normal)' }}>{availableCount}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">LIMITED</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-warning)' }}>{limitedCount}</div>
          </div>
          <div className="sovereign-metric">
            <div className="sovereign-metric-label">UNAVAILABLE</div>
            <div className="sovereign-metric-value" style={{ color: 'var(--sovereign-critical)' }}>{unavailableCount}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
