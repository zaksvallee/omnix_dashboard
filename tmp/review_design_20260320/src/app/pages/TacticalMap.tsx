import React, { useState } from 'react';
import { 
  Map, MapPin, Navigation, Shield, AlertTriangle, ZoomIn, ZoomOut, Crosshair, 
  Camera, Clock, Eye, RotateCcw, ExternalLink, Radio, Users, Building2,
  Wifi, XCircle, CheckCircle, ArrowRight, User
} from 'lucide-react';
import { WatchBadge, LimitedReasonIcon } from '../components/WatchBadge';
import { FleetSummaryChip } from '../components/FleetSummaryChip';

interface SiteWatch {
  id: string;
  name: string;
  code: string;
  lat: number;
  lng: number;
  watchState: 'available' | 'limited' | 'unavailable';
  limitedReason?: 'stale-feed' | 'degraded-connectivity' | 'fetch-failure' | 'manual-verification';
  lastUpdate: string;
  cameraCount: number;
  guardsOnSite: number;
}

interface GuardPing {
  id: string;
  name: string;
  guardId: string;
  site: string;
  lat: number;
  lng: number;
  status: 'active' | 'patrol' | 'sos';
  lastUpdate: string;
}

interface Geofence {
  id: string;
  site: string;
  lat: number;
  lng: number;
  radius: number;
  status: 'safe' | 'breach' | 'warning';
}

interface TemporaryIdentity {
  id: string;
  name: string;
  role: string;
  expiresIn: string;
  site: string;
}

export function TacticalMap() {
  const [selectedSite, setSelectedSite] = useState<string | null>('SITE-SE-01');
  const [selectedGuard, setSelectedGuard] = useState<string | null>(null);
  const [mapMode, setMapMode] = useState<'day' | 'night'>('night');
  const [showFleetFilter, setShowFleetFilter] = useState<'all' | 'available' | 'limited' | 'unavailable'>('all');
  const [showLayer, setShowLayer] = useState({ sites: true, guards: true, geofences: true });

  const sites: SiteWatch[] = [
    { 
      id: 'SITE-SE-01', 
      name: 'Sandton Estate North', 
      code: 'SE-01',
      lat: -26.1076, 
      lng: 28.0567, 
      watchState: 'available', 
      lastUpdate: '5s ago',
      cameraCount: 12,
      guardsOnSite: 2
    },
    { 
      id: 'SITE-WF-02', 
      name: 'Waterfall Estate', 
      code: 'WF-02',
      lat: -26.0254, 
      lng: 28.1123, 
      watchState: 'limited',
      limitedReason: 'stale-feed',
      lastUpdate: '142s ago',
      cameraCount: 8,
      guardsOnSite: 1
    },
    { 
      id: 'SITE-BR-03', 
      name: 'Blue Ridge Residence', 
      code: 'BR-03',
      lat: -26.1234, 
      lng: 28.0890, 
      watchState: 'limited',
      limitedReason: 'manual-verification',
      lastUpdate: '8s ago',
      cameraCount: 6,
      guardsOnSite: 1
    },
    { 
      id: 'SITE-MP-04', 
      name: 'Midrand Park', 
      code: 'MP-04',
      lat: -26.0067, 
      lng: 28.1289, 
      watchState: 'unavailable',
      lastUpdate: '20m ago',
      cameraCount: 10,
      guardsOnSite: 0
    },
  ];

  const guards: GuardPing[] = [
    { id: 'PING-G2441', name: 'T. Nkosi', guardId: 'G-2441', site: 'Sandton Estate North', lat: -26.1080, lng: 28.0570, status: 'active', lastUpdate: '3s ago' },
    { id: 'PING-G2442', name: 'J. van Wyk', guardId: 'G-2442', site: 'Waterfall Estate', lat: -26.0260, lng: 28.1130, status: 'patrol', lastUpdate: '12s ago' },
    { id: 'PING-G2443', name: 'K. Dlamini', guardId: 'G-2443', site: 'Blue Ridge Residence', lat: -26.1240, lng: 28.0895, status: 'sos', lastUpdate: '2s ago' },
  ];

  const geofences: Geofence[] = [
    { id: 'GF-001', site: 'Sandton Estate North', lat: -26.1076, lng: 28.0567, radius: 50, status: 'safe' },
    { id: 'GF-002', site: 'Waterfall Estate', lat: -26.0254, lng: 28.1123, radius: 50, status: 'safe' },
    { id: 'GF-003', site: 'Blue Ridge Residence', lat: -26.1234, lng: 28.0890, radius: 50, status: 'breach' },
  ];

  const tempIdentities: TemporaryIdentity[] = [
    { id: 'TEMP-001', name: 'D. Mokoena', role: 'Contractor', expiresIn: '2h 14m', site: 'Waterfall Estate' },
    { id: 'TEMP-002', name: 'L. Smith', role: 'Maintenance', expiresIn: '45m', site: 'Sandton Estate North' },
  ];

  const filteredSites = showFleetFilter === 'all' 
    ? sites 
    : sites.filter(s => s.watchState === showFleetFilter);

  const availableCount = sites.filter(s => s.watchState === 'available').length;
  const limitedCount = sites.filter(s => s.watchState === 'limited').length;
  const unavailableCount = sites.filter(s => s.watchState === 'unavailable').length;
  const sosCount = guards.filter(g => g.status === 'sos').length;
  const geofenceBreaches = geofences.filter(g => g.status === 'breach').length;

  const selectedSiteData = sites.find(s => s.id === selectedSite);
  const selectedGuardData = guards.find(g => g.id === selectedGuard);

  return (
    <div className="h-full flex flex-col overflow-hidden bg-[#0A0E13]">
      {/* Header */}
      <div className="border-b border-[#21262D] px-6 py-4 bg-[#0D1117] flex-shrink-0">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-purple-500 via-purple-600 to-indigo-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-purple-500/30">
              <Map className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Tactical Command</h1>
              <p className="text-sm text-white/50">Fleet watch monitoring, responder tracking, and geofence verification</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0A0E13] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              Open Dispatches
            </button>
          </div>
        </div>
      </div>

      {/* Fleet Summary + Layer Controls */}
      <div className="border-b border-[#21262D] px-6 py-4 bg-[#0D1117] flex-shrink-0">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Fleet Summary:</div>
            <FleetSummaryChip 
              type="total" 
              count={sites.length} 
              onClick={() => setShowFleetFilter('all')}
            />
            <FleetSummaryChip 
              type="available" 
              count={availableCount}
              onClick={() => setShowFleetFilter('available')}
            />
            <FleetSummaryChip 
              type="limited" 
              count={limitedCount}
              onClick={() => setShowFleetFilter('limited')}
            />
            <FleetSummaryChip 
              type="unavailable" 
              count={unavailableCount}
              onClick={() => setShowFleetFilter('unavailable')}
            />
            {showFleetFilter !== 'all' && (
              <button
                onClick={() => setShowFleetFilter('all')}
                className="ml-2 px-3 py-2 bg-[#0A0E13] hover:bg-white/5 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center gap-2 text-xs font-semibold"
              >
                <RotateCcw className="w-3 h-3" />
                Show All
              </button>
            )}
          </div>

          {/* Layer Toggles */}
          <div className="flex items-center gap-2">
            <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mr-2">Layers:</div>
            <button
              onClick={() => setShowLayer({ ...showLayer, sites: !showLayer.sites })}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                showLayer.sites
                  ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                  : 'bg-[#0A0E13] text-white/40 border-[#21262D]'
              }`}
            >
              Sites
            </button>
            <button
              onClick={() => setShowLayer({ ...showLayer, guards: !showLayer.guards })}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                showLayer.guards
                  ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                  : 'bg-[#0A0E13] text-white/40 border-[#21262D]'
              }`}
            >
              Guards
            </button>
            <button
              onClick={() => setShowLayer({ ...showLayer, geofences: !showLayer.geofences })}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                showLayer.geofences
                  ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                  : 'bg-[#0A0E13] text-white/40 border-[#21262D]'
              }`}
            >
              Geofences
            </button>
          </div>
        </div>
      </div>

      {/* SOS Banner */}
      {sosCount > 0 && (
        <div className="bg-red-500/20 border-b border-red-500/50 px-6 py-3 flex items-center gap-3 flex-shrink-0">
          <AlertTriangle className="w-5 h-5 text-red-400 animate-pulse" />
          <span className="text-sm font-semibold text-red-400">ACTIVE SOS TRIGGER - G-2443 (Blue Ridge Residence)</span>
          <button className="ml-auto px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg text-sm font-bold uppercase tracking-wider transition-all">
            DISPATCH REACTION
          </button>
        </div>
      )}

      {/* Geofence Breach Banner */}
      {geofenceBreaches > 0 && sosCount === 0 && (
        <div className="bg-amber-500/20 border-b border-amber-500/50 px-6 py-3 flex items-center gap-3 flex-shrink-0">
          <AlertTriangle className="w-5 h-5 text-amber-400" />
          <span className="text-sm font-semibold text-amber-400">{geofenceBreaches} GEOFENCE BREACH DETECTED - Blue Ridge Residence</span>
          <button className="ml-auto px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-lg text-sm font-bold uppercase tracking-wider transition-all">
            INVESTIGATE
          </button>
        </div>
      )}

      <div className="flex-1 flex overflow-hidden">
        {/* Left: Map Canvas */}
        <div className="flex-[2] flex flex-col border-r border-[#21262D]">
          {/* Map Canvas */}
          <div className="flex-1 relative bg-[#0A0E14] overflow-hidden">
            {/* Grid Background */}
            <div className="absolute inset-0 opacity-20" style={{
              backgroundImage: `repeating-linear-gradient(0deg, transparent, transparent 35px, rgba(255,255,255,.03) 35px, rgba(255,255,255,.03) 36px),
                               repeating-linear-gradient(90deg, transparent, transparent 35px, rgba(255,255,255,.03) 35px, rgba(255,255,255,.03) 36px)`
            }} />

            {/* Geofence Circles */}
            {showLayer.geofences && geofences.map((fence, idx) => (
              <div
                key={fence.id}
                className="absolute rounded-full border-2 transition-all pointer-events-none"
                style={{
                  width: '140px',
                  height: '140px',
                  left: `${20 + idx * 22}%`,
                  top: `${25 + idx * 18}%`,
                  borderColor: fence.status === 'breach' ? 'rgba(239, 68, 68, 0.6)' : 
                               fence.status === 'warning' ? 'rgba(251, 191, 36, 0.4)' :
                               'rgba(52, 211, 153, 0.3)',
                  backgroundColor: fence.status === 'breach' ? 'rgba(239, 68, 68, 0.1)' : 
                                   fence.status === 'warning' ? 'rgba(251, 191, 36, 0.05)' :
                                   'rgba(52, 211, 153, 0.05)',
                }}
              >
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className={`text-xs font-bold ${
                    fence.status === 'breach' ? 'text-red-400' :
                    fence.status === 'warning' ? 'text-amber-400' :
                    'text-emerald-400'
                  }`}>
                    {fence.radius}m
                  </div>
                </div>
              </div>
            ))}

            {/* Site Pings */}
            {showLayer.sites && filteredSites.map((site, idx) => (
              <button
                key={site.id}
                onClick={() => { setSelectedSite(site.id); setSelectedGuard(null); }}
                className={`absolute group transition-all ${selectedSite === site.id ? 'z-20' : 'z-10'}`}
                style={{
                  left: `${20 + idx * 22}%`,
                  top: `${25 + idx * 18}%`,
                }}
              >
                <div className="relative">
                  {/* Ping Circle */}
                  <div className={`
                    w-12 h-12 rounded-full border-2 flex items-center justify-center transition-all
                    ${site.watchState === 'available' ? 'bg-emerald-500/20 border-emerald-400' : ''}
                    ${site.watchState === 'limited' ? 'bg-amber-500/20 border-amber-400' : ''}
                    ${site.watchState === 'unavailable' ? 'bg-red-500/20 border-red-400' : ''}
                    ${selectedSite === site.id ? 'ring-4 ring-cyan-500/50 scale-110' : ''}
                  `}>
                    <Eye className={`w-6 h-6 ${
                      site.watchState === 'available' ? 'text-emerald-400' :
                      site.watchState === 'limited' ? 'text-amber-400' :
                      'text-red-400'
                    }`} strokeWidth={2} />
                  </div>

                  {/* Status Badge */}
                  <div className={`
                    absolute -top-2 -right-2 w-6 h-6 rounded-full border-2 border-[#0A0E14] flex items-center justify-center
                    ${site.watchState === 'available' ? 'bg-emerald-500' : ''}
                    ${site.watchState === 'limited' ? 'bg-amber-500' : ''}
                    ${site.watchState === 'unavailable' ? 'bg-red-500' : ''}
                  `}>
                    {site.watchState === 'available' && <CheckCircle className="w-3.5 h-3.5 text-white" strokeWidth={2.5} />}
                    {site.watchState === 'limited' && <AlertTriangle className="w-3.5 h-3.5 text-white" strokeWidth={2.5} />}
                    {site.watchState === 'unavailable' && <XCircle className="w-3.5 h-3.5 text-white" strokeWidth={2.5} />}
                  </div>

                  {/* Label */}
                  <div className={`
                    absolute top-14 left-1/2 -translate-x-1/2 whitespace-nowrap px-3 py-2 rounded-lg text-xs font-semibold
                    ${selectedSite === site.id ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}
                    transition-opacity bg-[#0D1117] border border-[#21262D] shadow-xl
                  `}>
                    <div className="text-white font-bold">{site.code}</div>
                    <div className="text-white/50 text-[10px]">{site.name}</div>
                  </div>
                </div>
              </button>
            ))}

            {/* Guard Pings */}
            {showLayer.guards && guards.map((guard, idx) => (
              <button
                key={guard.id}
                onClick={() => { setSelectedGuard(guard.id); setSelectedSite(null); }}
                className={`absolute group transition-all ${selectedGuard === guard.id ? 'z-30' : 'z-15'}`}
                style={{
                  left: `${21 + idx * 22}%`,
                  top: `${27 + idx * 18}%`,
                }}
              >
                <div className={`relative ${guard.status === 'sos' ? 'animate-pulse' : ''}`}>
                  {/* Ping Circle */}
                  <div className={`
                    w-10 h-10 rounded-full border-2 flex items-center justify-center transition-all
                    ${guard.status === 'sos' ? 'bg-red-500 border-red-400 ring-4 ring-red-500/50' : ''}
                    ${guard.status === 'active' ? 'bg-cyan-500/30 border-cyan-400' : ''}
                    ${guard.status === 'patrol' ? 'bg-blue-500/30 border-blue-400' : ''}
                    ${selectedGuard === guard.id ? 'ring-4 ring-white/50 scale-110' : ''}
                  `}>
                    {guard.status === 'sos' ? (
                      <AlertTriangle className="w-5 h-5 text-white" strokeWidth={2.5} />
                    ) : (
                      <User className={`w-5 h-5 ${
                        guard.status === 'active' ? 'text-cyan-300' : 'text-blue-300'
                      }`} strokeWidth={2} />
                    )}
                  </div>

                  {/* Label */}
                  <div className={`
                    absolute top-12 left-1/2 -translate-x-1/2 whitespace-nowrap px-3 py-2 rounded-lg text-xs font-semibold
                    ${selectedGuard === guard.id ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}
                    transition-opacity bg-[#0D1117] border border-[#21262D] shadow-xl z-50
                  `}>
                    <div className="text-white font-bold">{guard.name}</div>
                    <div className="text-white/50 text-[10px]">{guard.guardId}</div>
                  </div>
                </div>
              </button>
            ))}

            {/* Map Controls */}
            <div className="absolute bottom-6 right-6 flex flex-col gap-2">
              <button className="w-10 h-10 bg-[#0D1117] border border-[#21262D] rounded-lg flex items-center justify-center hover:bg-white/5 hover:border-cyan-500/30 transition-all">
                <ZoomIn className="w-5 h-5 text-white/70" />
              </button>
              <button className="w-10 h-10 bg-[#0D1117] border border-[#21262D] rounded-lg flex items-center justify-center hover:bg-white/5 hover:border-cyan-500/30 transition-all">
                <ZoomOut className="w-5 h-5 text-white/70" />
              </button>
              <button className="w-10 h-10 bg-[#0D1117] border border-[#21262D] rounded-lg flex items-center justify-center hover:bg-white/5 hover:border-cyan-500/30 transition-all">
                <Crosshair className="w-5 h-5 text-white/70" />
              </button>
            </div>
          </div>
        </div>

        {/* Right: Detail Panel */}
        <div className="flex-[1] flex flex-col overflow-y-auto bg-[#0D1117]">
          <div className="p-6 space-y-6">
            {/* Site Watch Health Detail */}
            {selectedSiteData && !selectedGuard && (
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-2">
                    <Eye className="w-4 h-4 text-cyan-400" />
                    <h3 className="text-xs font-bold text-white uppercase tracking-wider">Watch Health Detail</h3>
                  </div>
                </div>

                <div className="p-5 space-y-4">
                  {/* Site Info */}
                  <div>
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Site</div>
                    <div className="font-mono text-lg text-white font-bold">{selectedSiteData.code}</div>
                    <div className="text-sm text-white/60">{selectedSiteData.name}</div>
                  </div>

                  {/* Watch Status */}
                  <div>
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Watch Status</div>
                    <WatchBadge 
                      state={selectedSiteData.watchState} 
                      limitedReason={selectedSiteData.limitedReason}
                      size="lg"
                    />
                  </div>

                  {/* Limited Reason Detail */}
                  {selectedSiteData.watchState === 'limited' && selectedSiteData.limitedReason && (
                    <div className="bg-gradient-to-br from-amber-950/50 to-orange-950/50 border border-amber-500/20 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <LimitedReasonIcon reason={selectedSiteData.limitedReason} />
                        <div className="flex-1">
                          <h4 className="text-sm font-bold text-amber-300 mb-1">
                            {selectedSiteData.limitedReason === 'stale-feed' && 'Stale Feed Detected'}
                            {selectedSiteData.limitedReason === 'degraded-connectivity' && 'Degraded Connectivity'}
                            {selectedSiteData.limitedReason === 'fetch-failure' && 'Fetch Failure'}
                            {selectedSiteData.limitedReason === 'manual-verification' && 'Manual Verification Required'}
                          </h4>
                          <p className="text-xs text-amber-400/70 leading-relaxed mb-3">
                            {selectedSiteData.limitedReason === 'stale-feed' && 'Camera feed has not updated in 142s. Verifying connection.'}
                            {selectedSiteData.limitedReason === 'degraded-connectivity' && 'Network latency detected. Watch quality may be reduced.'}
                            {selectedSiteData.limitedReason === 'fetch-failure' && 'Unable to retrieve latest camera frames.'}
                            {selectedSiteData.limitedReason === 'manual-verification' && 'Unusual activity detected. Human verification needed.'}
                          </p>
                          <button className="w-full px-3 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 rounded-lg border border-amber-500/30 text-xs font-semibold uppercase tracking-wider transition-all flex items-center justify-center gap-2">
                            <RotateCcw className="w-3.5 h-3.5" />
                            Recover Watch
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Unavailable State */}
                  {selectedSiteData.watchState === 'unavailable' && (
                    <div className="bg-gradient-to-br from-red-950/50 to-orange-950/50 border border-red-500/20 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <XCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h4 className="text-sm font-bold text-red-300 mb-1">Watch Unavailable</h4>
                          <p className="text-xs text-red-400/70 leading-relaxed mb-3">
                            Site has been offline for 20 minutes. All cameras offline.
                          </p>
                          <button className="w-full px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold uppercase tracking-wider transition-all flex items-center justify-center gap-2">
                            <AlertTriangle className="w-3.5 h-3.5" />
                            Alert Dispatch
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Metrics */}
                  <div className="grid grid-cols-2 gap-3">
                    <div className="bg-[#0D1117] border border-[#21262D] rounded-lg p-3">
                      <div className="text-[10px] text-white/40 uppercase tracking-wider font-semibold mb-1">Cameras</div>
                      <div className="text-lg font-bold text-white tabular-nums">{selectedSiteData.cameraCount}</div>
                    </div>
                    <div className="bg-[#0D1117] border border-[#21262D] rounded-lg p-3">
                      <div className="text-[10px] text-white/40 uppercase tracking-wider font-semibold mb-1">Guards</div>
                      <div className="text-lg font-bold text-white tabular-nums">{selectedSiteData.guardsOnSite}</div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="grid grid-cols-2 gap-2">
                    <button className="px-3 py-2 bg-[#0D1117] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold">
                      <Radio className="w-3.5 h-3.5" />
                      Dispatch
                    </button>
                    <button className="px-3 py-2 bg-[#0D1117] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold">
                      <Map className="w-3.5 h-3.5" />
                      Tactical
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Guard Ping Detail */}
            {selectedGuardData && (
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-2">
                    <User className="w-4 h-4 text-cyan-400" />
                    <h3 className="text-xs font-bold text-white uppercase tracking-wider">Responder Detail</h3>
                  </div>
                </div>

                <div className="p-5 space-y-4">
                  {/* Guard Info */}
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <div>
                        <div className="text-sm font-bold text-white">{selectedGuardData.name}</div>
                        <div className="text-xs text-white/60 font-mono">{selectedGuardData.guardId}</div>
                      </div>
                      <div className={`
                        px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                        ${selectedGuardData.status === 'sos' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                        ${selectedGuardData.status === 'active' ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30' : ''}
                        ${selectedGuardData.status === 'patrol' ? 'bg-blue-500/20 text-blue-400 border-blue-500/30' : ''}
                      `}>
                        {selectedGuardData.status}
                      </div>
                    </div>
                    <div className="text-xs text-white/50">{selectedGuardData.site}</div>
                    <div className="flex items-center gap-2 text-xs text-white/40 mt-2">
                      <Clock className="w-3 h-3" />
                      Last update: {selectedGuardData.lastUpdate}
                    </div>
                  </div>

                  {/* SOS Alert */}
                  {selectedGuardData.status === 'sos' && (
                    <div className="bg-gradient-to-br from-red-950/50 to-orange-950/50 border border-red-500/20 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5 animate-pulse" />
                        <div className="flex-1">
                          <h4 className="text-sm font-bold text-red-300 mb-1">SOS ACTIVE</h4>
                          <p className="text-xs text-red-400/70 leading-relaxed mb-3">
                            Guard has triggered emergency alert. Immediate response required.
                          </p>
                          <button className="w-full px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold uppercase tracking-wider transition-all flex items-center justify-center gap-2">
                            <Radio className="w-3.5 h-3.5" />
                            Dispatch Backup
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Actions */}
                  <div className="grid grid-cols-2 gap-2">
                    <button className="px-3 py-2 bg-[#0D1117] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold">
                      <Radio className="w-3.5 h-3.5" />
                      Radio
                    </button>
                    <button className="px-3 py-2 bg-[#0D1117] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold">
                      <Camera className="w-3.5 h-3.5" />
                      Verify
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* Empty State */}
            {!selectedSiteData && !selectedGuardData && (
              <div className="text-center py-12">
                <Eye className="w-12 h-12 text-white/20 mx-auto mb-3" />
                <p className="text-sm text-white/50">Select a site or guard ping to view details</p>
              </div>
            )}

            {/* Temporary Identity Approvals */}
            <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-2">
                  <Shield className="w-4 h-4 text-purple-400" />
                  <h3 className="text-xs font-bold text-white uppercase tracking-wider">Temporary Identities</h3>
                  <div className="ml-auto px-2 py-0.5 bg-purple-500/20 text-purple-400 rounded text-[10px] font-bold">
                    {tempIdentities.length} Active
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2">
                {tempIdentities.map((identity) => (
                  <div key={identity.id} className="bg-[#0D1117] border border-purple-500/20 rounded-lg p-3 hover:border-purple-500/40 transition-all">
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <div className="text-sm font-bold text-white">{identity.name}</div>
                        <div className="text-xs text-white/50">{identity.role} • {identity.site}</div>
                      </div>
                      <div className="px-2 py-1 bg-amber-500/10 text-amber-400 rounded text-[10px] font-bold">
                        {identity.expiresIn}
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-2">
                      <button className="px-2 py-1.5 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-md border border-[#21262D] hover:border-cyan-500/30 transition-all text-xs font-semibold">
                        Extend
                      </button>
                      <button className="px-2 py-1.5 bg-[#0A0E13] hover:bg-red-500/10 text-white/60 hover:text-red-400 rounded-md border border-[#21262D] hover:border-red-500/30 transition-all text-xs font-semibold">
                        Expire
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}