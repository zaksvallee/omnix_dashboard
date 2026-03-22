import React, { useState } from 'react';
import { 
  Building2, Eye, AlertTriangle, CheckCircle, XCircle, Shield, Users,
  Camera, Map, Settings, ChevronRight, Clock, TrendingUp, Radio,
  Wifi, WifiOff, ExternalLink
} from 'lucide-react';

interface Site {
  id: string;
  name: string;
  code: string;
  posture: 'strong' | 'at-risk' | 'critical';
  watchHealth: 'available' | 'limited' | 'unavailable';
  limitedReason?: 'stale-feed' | 'degraded-connectivity' | 'manual-verification';
  guardsOnSite: number;
  cameraCount: number;
  activeCameras: number;
  lastIncident: string | null;
  incidentCount24h: number;
  avgResponseTime: string;
}

export function Sites() {
  const [selectedSite, setSelectedSite] = useState<string | null>('SITE-SE-01');
  const [postureFilter, setPostureFilter] = useState<string | null>(null);

  const sites: Site[] = [
    {
      id: 'SITE-SE-01',
      name: 'Sandton Estate North',
      code: 'SE-01',
      posture: 'strong',
      watchHealth: 'available',
      guardsOnSite: 2,
      cameraCount: 12,
      activeCameras: 12,
      lastIncident: '2h ago',
      incidentCount24h: 3,
      avgResponseTime: '142s',
    },
    {
      id: 'SITE-WF-02',
      name: 'Waterfall Estate',
      code: 'WF-02',
      posture: 'at-risk',
      watchHealth: 'limited',
      limitedReason: 'stale-feed',
      guardsOnSite: 1,
      cameraCount: 8,
      activeCameras: 7,
      lastIncident: '45m ago',
      incidentCount24h: 5,
      avgResponseTime: '186s',
    },
    {
      id: 'SITE-BR-03',
      name: 'Blue Ridge Residence',
      code: 'BR-03',
      posture: 'at-risk',
      watchHealth: 'limited',
      limitedReason: 'manual-verification',
      guardsOnSite: 1,
      cameraCount: 6,
      activeCameras: 6,
      lastIncident: '12m ago',
      incidentCount24h: 8,
      avgResponseTime: '98s',
    },
    {
      id: 'SITE-MP-04',
      name: 'Midrand Park',
      code: 'MP-04',
      posture: 'critical',
      watchHealth: 'unavailable',
      guardsOnSite: 0,
      cameraCount: 10,
      activeCameras: 0,
      lastIncident: null,
      incidentCount24h: 0,
      avgResponseTime: 'N/A',
    },
  ];

  const filteredSites = postureFilter
    ? sites.filter(s => s.posture === postureFilter)
    : sites;

  const selectedSiteData = sites.find(s => s.id === selectedSite);
  const strongCount = sites.filter(s => s.posture === 'strong').length;
  const atRiskCount = sites.filter(s => s.posture === 'at-risk').length;
  const criticalCount = sites.filter(s => s.posture === 'critical').length;

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-cyan-500 via-blue-600 to-indigo-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-cyan-500/30">
              <Building2 className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Sites & Deployment</h1>
              <p className="text-sm text-white/50">Site management, watch posture, and operational readiness</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Tactical
            </button>
          </div>
        </div>

        {/* Site Posture Summary + Filter */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Site Posture:</div>
              <button
                onClick={() => setPostureFilter(null)}
                className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-all ${
                  postureFilter === null
                    ? 'bg-white/5 border-white/10'
                    : 'bg-transparent border-transparent hover:bg-white/5 hover:border-white/10'
                }`}
              >
                <span className="text-sm font-bold text-white/80">{sites.length} Total</span>
              </button>
              <button
                onClick={() => setPostureFilter('strong')}
                className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-all ${
                  postureFilter === 'strong'
                    ? 'bg-emerald-500/10 border-emerald-500/20'
                    : 'bg-emerald-500/5 border-emerald-500/10 hover:bg-emerald-500/10 hover:border-emerald-500/20'
                }`}
              >
                <CheckCircle className="w-4 h-4 text-emerald-400" />
                <span className="text-sm font-bold text-emerald-400">{strongCount} Strong</span>
              </button>
              <button
                onClick={() => setPostureFilter('at-risk')}
                className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-all ${
                  postureFilter === 'at-risk'
                    ? 'bg-amber-500/10 border-amber-500/20'
                    : 'bg-amber-500/5 border-amber-500/10 hover:bg-amber-500/10 hover:border-amber-500/20'
                }`}
              >
                <AlertTriangle className="w-4 h-4 text-amber-400" />
                <span className="text-sm font-bold text-amber-400">{atRiskCount} At-Risk</span>
              </button>
              {criticalCount > 0 && (
                <button
                  onClick={() => setPostureFilter('critical')}
                  className={`flex items-center gap-2 px-3 py-2 rounded-lg border transition-all ${
                    postureFilter === 'critical'
                      ? 'bg-red-500/10 border-red-500/20'
                      : 'bg-red-500/5 border-red-500/10 hover:bg-red-500/10 hover:border-red-500/20'
                  }`}
                >
                  <XCircle className="w-4 h-4 text-red-400" />
                  <span className="text-sm font-bold text-red-400">{criticalCount} Critical</span>
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Site Roster */}
          <div className="col-span-1 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                    <Building2 className="w-4 h-4 text-cyan-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Site Roster</h2>
                    <p className="text-xs text-white/40 mt-0.5">{filteredSites.length} sites</p>
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2">
                {filteredSites.map((site) => (
                  <button
                    key={site.id}
                    onClick={() => setSelectedSite(site.id)}
                    className={`
                      w-full p-4 rounded-xl border transition-all text-left
                      ${selectedSite === site.id
                        ? 'bg-gradient-to-br from-cyan-950/50 to-blue-950/50 border-cyan-500/30'
                        : 'bg-[#0A0E13] border-[#21262D] hover:border-cyan-500/20'
                      }
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <div className="text-sm font-bold text-white mb-0.5">{site.code}</div>
                        <div className="text-xs text-white/50">{site.name}</div>
                      </div>
                      <div className="flex items-center gap-1.5">
                        {site.watchHealth === 'available' && <Eye className="w-3.5 h-3.5 text-emerald-400" />}
                        {site.watchHealth === 'limited' && <AlertTriangle className="w-3.5 h-3.5 text-amber-400" />}
                        {site.watchHealth === 'unavailable' && <XCircle className="w-3.5 h-3.5 text-red-400" />}
                        <div className={`
                          px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                          ${site.posture === 'strong' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                          ${site.posture === 'at-risk' ? 'bg-amber-500/20 text-amber-400' : ''}
                          ${site.posture === 'critical' ? 'bg-red-500/20 text-red-400' : ''}
                        `}>
                          {site.posture}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 text-[10px] text-white/40">
                      <div>{site.guardsOnSite} guards</div>
                      <div>{site.activeCameras}/{site.cameraCount} cams</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column - Site Detail & Actions */}
          <div className="col-span-2 space-y-6">
            {selectedSiteData ? (
              <>
                {/* Site Posture Overview */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-4">
                        <div className={`
                          w-12 h-12 rounded-xl flex items-center justify-center
                          ${selectedSiteData.posture === 'strong' ? 'bg-gradient-to-br from-emerald-500 to-teal-600' : ''}
                          ${selectedSiteData.posture === 'at-risk' ? 'bg-gradient-to-br from-amber-500 to-orange-600' : ''}
                          ${selectedSiteData.posture === 'critical' ? 'bg-gradient-to-br from-red-500 to-orange-600' : ''}
                        `}>
                          <Building2 className="w-6 h-6 text-white" />
                        </div>
                        <div>
                          <h2 className="text-lg font-bold text-white mb-1">{selectedSiteData.name}</h2>
                          <div className="flex items-center gap-2">
                            <span className="text-sm text-white/50 font-mono">{selectedSiteData.code}</span>
                            <div className={`
                              px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                              ${selectedSiteData.posture === 'strong' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                              ${selectedSiteData.posture === 'at-risk' ? 'bg-amber-500/20 text-amber-400' : ''}
                              ${selectedSiteData.posture === 'critical' ? 'bg-red-500/20 text-red-400' : ''}
                            `}>
                              {selectedSiteData.posture} POSTURE
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-4 gap-4">
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Guards On-Site</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedSiteData.guardsOnSite}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Cameras Active</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedSiteData.activeCameras}/{selectedSiteData.cameraCount}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">24h Incidents</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedSiteData.incidentCount24h}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Avg Response</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedSiteData.avgResponseTime}</div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Watch Health Detail */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                        <Eye className="w-4 h-4 text-purple-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Watch Health Status</h2>
                        <p className="text-xs text-white/40 mt-0.5">Camera feed and verification state</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    {/* Watch State Indicator */}
                    <div className={`
                      p-4 rounded-xl border mb-4
                      ${selectedSiteData.watchHealth === 'available' ? 'bg-emerald-500/5 border-emerald-500/20' : ''}
                      ${selectedSiteData.watchHealth === 'limited' ? 'bg-amber-500/5 border-amber-500/20' : ''}
                      ${selectedSiteData.watchHealth === 'unavailable' ? 'bg-red-500/5 border-red-500/20' : ''}
                    `}>
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          {selectedSiteData.watchHealth === 'available' && <Wifi className="w-5 h-5 text-emerald-400" />}
                          {selectedSiteData.watchHealth === 'limited' && <AlertTriangle className="w-5 h-5 text-amber-400" />}
                          {selectedSiteData.watchHealth === 'unavailable' && <WifiOff className="w-5 h-5 text-red-400" />}
                          <div>
                            <div className="text-sm font-bold text-white mb-1">
                              {selectedSiteData.watchHealth === 'available' && 'Watch Available'}
                              {selectedSiteData.watchHealth === 'limited' && 'Watch Limited'}
                              {selectedSiteData.watchHealth === 'unavailable' && 'Watch Unavailable'}
                            </div>
                            {selectedSiteData.limitedReason && (
                              <div className="text-xs text-white/60">
                                {selectedSiteData.limitedReason === 'stale-feed' && 'Feed has not updated recently'}
                                {selectedSiteData.limitedReason === 'degraded-connectivity' && 'Network latency detected'}
                                {selectedSiteData.limitedReason === 'manual-verification' && 'Requires manual verification'}
                              </div>
                            )}
                          </div>
                        </div>
                        <div className={`
                          px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                          ${selectedSiteData.watchHealth === 'available' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : ''}
                          ${selectedSiteData.watchHealth === 'limited' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' : ''}
                          ${selectedSiteData.watchHealth === 'unavailable' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                        `}>
                          {selectedSiteData.watchHealth}
                        </div>
                      </div>
                    </div>

                    {/* Posture Status Variants */}
                    {selectedSiteData.posture === 'strong' && (
                      <div className="bg-gradient-to-br from-emerald-950/30 to-teal-950/30 border border-emerald-500/20 rounded-xl p-4">
                        <div className="flex items-start gap-3">
                          <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-sm font-bold text-emerald-300 mb-1">Strong Site Posture</h4>
                            <p className="text-xs text-emerald-400/70 leading-relaxed">
                              All systems operational. Guards present. Watch available. No immediate concerns.
                            </p>
                          </div>
                        </div>
                      </div>
                    )}

                    {selectedSiteData.posture === 'at-risk' && (
                      <div className="bg-gradient-to-br from-amber-950/30 to-orange-950/30 border border-amber-500/20 rounded-xl p-4">
                        <div className="flex items-start gap-3">
                          <AlertTriangle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-sm font-bold text-amber-300 mb-1">At-Risk Site Posture</h4>
                            <p className="text-xs text-amber-400/70 leading-relaxed mb-3">
                              Limited watch capability or operational concerns detected. Monitoring required.
                            </p>
                            <button className="w-full px-3 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 rounded-lg border border-amber-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                              Review Status
                            </button>
                          </div>
                        </div>
                      </div>
                    )}

                    {selectedSiteData.posture === 'critical' && (
                      <div className="bg-gradient-to-br from-red-950/30 to-orange-950/30 border border-red-500/20 rounded-xl p-4">
                        <div className="flex items-start gap-3">
                          <XCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-sm font-bold text-red-300 mb-1">Critical Site Posture</h4>
                            <p className="text-xs text-red-400/70 leading-relaxed mb-3">
                              Severe operational degradation. Watch unavailable. Immediate action required.
                            </p>
                            <button className="w-full px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold uppercase tracking-wider transition-all flex items-center justify-center gap-2">
                              <Radio className="w-3.5 h-3.5" />
                              Dispatch Response
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                {/* Site Actions */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                        <Shield className="w-4 h-4 text-indigo-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Site Operations</h2>
                        <p className="text-xs text-white/40 mt-0.5">Management and operational controls</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 grid grid-cols-2 gap-3">
                    {/* Tactical Map Open Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-purple-500/10 text-white/80 hover:text-purple-400 rounded-lg border border-[#21262D] hover:border-purple-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Map className="w-4 h-4" />
                        <span>Tactical Map</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Site Settings Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Settings className="w-4 h-4" />
                        <span>Site Settings</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Guard Roster Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-orange-500/10 text-white/80 hover:text-orange-400 rounded-lg border border-[#21262D] hover:border-orange-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Users className="w-4 h-4" />
                        <span>Guard Roster</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Camera Feed */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-indigo-500/10 text-white/80 hover:text-indigo-400 rounded-lg border border-[#21262D] hover:border-indigo-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Camera className="w-4 h-4" />
                        <span>Camera Feed</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-12 text-center">
                <Building2 className="w-16 h-16 text-white/20 mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-2">No Site Selected</h3>
                <p className="text-sm text-white/60">Choose a site from the roster to view details</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
