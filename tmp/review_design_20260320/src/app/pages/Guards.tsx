import React, { useState } from 'react';
import { 
  Users, CheckCircle, AlertTriangle, Clock, Phone, Calendar, 
  FileText, MessageSquare, Radio, TrendingUp, ExternalLink, Shield,
  Wifi, WifiOff, XCircle, ChevronRight, User
} from 'lucide-react';

interface Guard {
  id: string;
  name: string;
  guardCode: string;
  status: 'on-duty' | 'off-duty' | 'on-leave';
  site: string | null;
  siteCode: string | null;
  clockedIn: string | null;
  syncHealth: 'healthy' | 'stale' | 'offline';
  lastSync: string;
  performance: {
    obEntries: number;
    incidentsHandled: number;
    avgResponseTime: string;
    rating: number;
  };
  contact: {
    phone: string;
    voipReady: boolean;
  };
}

export function Guards() {
  const [selectedGuard, setSelectedGuard] = useState<string | null>('G-2441');
  const [siteFilter, setSiteFilter] = useState<string | null>(null);

  const guards: Guard[] = [
    {
      id: 'G-2441',
      name: 'T. Nkosi',
      guardCode: 'G-2441',
      status: 'on-duty',
      site: 'Sandton Estate North',
      siteCode: 'SE-01',
      clockedIn: '18:00 UTC',
      syncHealth: 'healthy',
      lastSync: '5s ago',
      performance: {
        obEntries: 24,
        incidentsHandled: 8,
        avgResponseTime: '142s',
        rating: 4.8,
      },
      contact: {
        phone: '+27 82 441 2244',
        voipReady: true,
      },
    },
    {
      id: 'G-2442',
      name: 'J. van Wyk',
      guardCode: 'G-2442',
      status: 'on-duty',
      site: 'Waterfall Estate',
      siteCode: 'WF-02',
      clockedIn: '18:00 UTC',
      syncHealth: 'stale',
      lastSync: '142s ago',
      performance: {
        obEntries: 18,
        incidentsHandled: 5,
        avgResponseTime: '186s',
        rating: 4.5,
      },
      contact: {
        phone: '+27 83 552 3344',
        voipReady: true,
      },
    },
    {
      id: 'G-2443',
      name: 'K. Dlamini',
      guardCode: 'G-2443',
      status: 'on-duty',
      site: 'Blue Ridge Residence',
      siteCode: 'BR-03',
      clockedIn: '18:00 UTC',
      syncHealth: 'healthy',
      lastSync: '3s ago',
      performance: {
        obEntries: 32,
        incidentsHandled: 12,
        avgResponseTime: '98s',
        rating: 4.9,
      },
      contact: {
        phone: '+27 84 663 5566',
        voipReady: true,
      },
    },
    {
      id: 'G-2444',
      name: 'S. Mabaso',
      guardCode: 'G-2444',
      status: 'off-duty',
      site: null,
      siteCode: null,
      clockedIn: null,
      syncHealth: 'offline',
      lastSync: '6h ago',
      performance: {
        obEntries: 16,
        incidentsHandled: 4,
        avgResponseTime: '210s',
        rating: 4.2,
      },
      contact: {
        phone: '+27 85 774 6677',
        voipReady: false,
      },
    },
  ];

  const filteredGuards = siteFilter
    ? guards.filter(g => g.siteCode === siteFilter)
    : guards;

  const selectedGuardData = guards.find(g => g.id === selectedGuard);
  const onDutyCount = guards.filter(g => g.status === 'on-duty').length;
  const syncIssueCount = guards.filter(g => g.syncHealth !== 'healthy' && g.status === 'on-duty').length;

  const sites = [
    { code: 'SE-01', name: 'Sandton Estate North' },
    { code: 'WF-02', name: 'Waterfall Estate' },
    { code: 'BR-03', name: 'Blue Ridge Residence' },
  ];

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-orange-500 via-red-600 to-pink-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-orange-500/30">
              <Users className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Guards & Workforce</h1>
              <p className="text-sm text-white/50">Roster management, performance tracking, and operational readiness</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Reports
            </button>
          </div>
        </div>

        {/* Workforce Summary + Site Filter */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Workforce Status:</div>
              <div className="flex items-center gap-2 px-3 py-2 bg-emerald-500/10 border border-emerald-500/20 rounded-lg">
                <CheckCircle className="w-4 h-4 text-emerald-400" />
                <span className="text-sm font-bold text-emerald-400">{onDutyCount} On Duty</span>
              </div>
              {syncIssueCount > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 bg-amber-500/10 border border-amber-500/20 rounded-lg">
                  <AlertTriangle className="w-4 h-4 text-amber-400" />
                  <span className="text-sm font-bold text-amber-400">{syncIssueCount} Sync Issues</span>
                </div>
              )}
            </div>

            {/* Site Filter */}
            <div className="flex items-center gap-2">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Filter by Site:</div>
              <button
                onClick={() => setSiteFilter(null)}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  siteFilter === null
                    ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                All Sites
              </button>
              {sites.map((site) => (
                <button
                  key={site.code}
                  onClick={() => setSiteFilter(site.code)}
                  className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    siteFilter === site.code
                      ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                      : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                  }`}
                >
                  {site.code}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Guard Roster */}
          <div className="col-span-1 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-orange-500/10 flex items-center justify-center">
                    <Users className="w-4 h-4 text-orange-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Guard Roster</h2>
                    <p className="text-xs text-white/40 mt-0.5">{filteredGuards.length} guards</p>
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2">
                {filteredGuards.map((guard) => (
                  <button
                    key={guard.id}
                    onClick={() => setSelectedGuard(guard.id)}
                    className={`
                      w-full p-4 rounded-xl border transition-all text-left
                      ${selectedGuard === guard.id
                        ? 'bg-gradient-to-br from-orange-950/50 to-red-950/50 border-orange-500/30'
                        : 'bg-[#0A0E13] border-[#21262D] hover:border-orange-500/20'
                      }
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div>
                        <div className="text-sm font-bold text-white mb-0.5">{guard.name}</div>
                        <div className="text-xs text-white/50 font-mono">{guard.guardCode}</div>
                      </div>
                      <div className="flex items-center gap-1.5">
                        {guard.syncHealth === 'healthy' && <Wifi className="w-3.5 h-3.5 text-emerald-400" />}
                        {guard.syncHealth === 'stale' && <AlertTriangle className="w-3.5 h-3.5 text-amber-400" />}
                        {guard.syncHealth === 'offline' && <WifiOff className="w-3.5 h-3.5 text-red-400" />}
                        <div className={`
                          px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                          ${guard.status === 'on-duty' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                          ${guard.status === 'off-duty' ? 'bg-gray-500/20 text-gray-400' : ''}
                          ${guard.status === 'on-leave' ? 'bg-blue-500/20 text-blue-400' : ''}
                        `}>
                          {guard.status.replace('-', ' ')}
                        </div>
                      </div>
                    </div>
                    {guard.site && (
                      <div className="text-xs text-white/60">
                        {guard.siteCode} • {guard.site}
                      </div>
                    )}
                    {!guard.site && (
                      <div className="text-xs text-white/40 italic">No active assignment</div>
                    )}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column - Guard Profile & Actions */}
          <div className="col-span-2 space-y-6">
            {selectedGuardData ? (
              <>
                {/* Guard Profile */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-orange-500 to-red-600 flex items-center justify-center">
                          <User className="w-6 h-6 text-white" />
                        </div>
                        <div>
                          <h2 className="text-lg font-bold text-white mb-1">{selectedGuardData.name}</h2>
                          <div className="flex items-center gap-2">
                            <span className="text-sm text-white/50 font-mono">{selectedGuardData.guardCode}</span>
                            <div className={`
                              px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                              ${selectedGuardData.status === 'on-duty' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                              ${selectedGuardData.status === 'off-duty' ? 'bg-gray-500/20 text-gray-400' : ''}
                              ${selectedGuardData.status === 'on-leave' ? 'bg-blue-500/20 text-blue-400' : ''}
                            `}>
                              {selectedGuardData.status.replace('-', ' ')}
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-2 gap-4 mb-4">
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Current Site</div>
                        {selectedGuardData.site ? (
                          <>
                            <div className="text-sm font-bold text-white">{selectedGuardData.siteCode}</div>
                            <div className="text-xs text-white/60">{selectedGuardData.site}</div>
                          </>
                        ) : (
                          <div className="text-sm text-white/40 italic">Not assigned</div>
                        )}
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Clocked In</div>
                        {selectedGuardData.clockedIn ? (
                          <div className="text-sm font-bold text-white">{selectedGuardData.clockedIn}</div>
                        ) : (
                          <div className="text-sm text-white/40 italic">Not clocked in</div>
                        )}
                      </div>
                    </div>

                    {/* Sync Health Emphasis */}
                    <div className={`
                      p-4 rounded-xl border
                      ${selectedGuardData.syncHealth === 'healthy' ? 'bg-emerald-500/5 border-emerald-500/20' : ''}
                      ${selectedGuardData.syncHealth === 'stale' ? 'bg-amber-500/5 border-amber-500/20' : ''}
                      ${selectedGuardData.syncHealth === 'offline' ? 'bg-red-500/5 border-red-500/20' : ''}
                    `}>
                      <div className="flex items-start justify-between">
                        <div className="flex items-center gap-3">
                          {selectedGuardData.syncHealth === 'healthy' && <Wifi className="w-5 h-5 text-emerald-400" />}
                          {selectedGuardData.syncHealth === 'stale' && <AlertTriangle className="w-5 h-5 text-amber-400" />}
                          {selectedGuardData.syncHealth === 'offline' && <WifiOff className="w-5 h-5 text-red-400" />}
                          <div>
                            <div className="text-sm font-bold text-white mb-1">
                              {selectedGuardData.syncHealth === 'healthy' && 'Sync Healthy'}
                              {selectedGuardData.syncHealth === 'stale' && 'Stale Sync'}
                              {selectedGuardData.syncHealth === 'offline' && 'Sync Offline'}
                            </div>
                            <div className="text-xs text-white/60">Last sync: {selectedGuardData.lastSync}</div>
                          </div>
                        </div>
                        <div className={`
                          px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                          ${selectedGuardData.syncHealth === 'healthy' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : ''}
                          ${selectedGuardData.syncHealth === 'stale' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' : ''}
                          ${selectedGuardData.syncHealth === 'offline' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                        `}>
                          {selectedGuardData.syncHealth}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Performance Panel */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                        <TrendingUp className="w-4 h-4 text-cyan-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Performance Metrics</h2>
                        <p className="text-xs text-white/40 mt-0.5">Current period operational stats</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-4 gap-4">
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">OB Entries</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedGuardData.performance.obEntries}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Incidents</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedGuardData.performance.incidentsHandled}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Avg Response</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedGuardData.performance.avgResponseTime}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Rating</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedGuardData.performance.rating}</div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Action Panel */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                        <Shield className="w-4 h-4 text-purple-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Quick Actions</h2>
                        <p className="text-xs text-white/40 mt-0.5">Operational controls</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 grid grid-cols-2 gap-3">
                    {/* Guard Schedule Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Calendar className="w-4 h-4" />
                        <span>Schedule</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Guard Reports Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-indigo-500/10 text-white/80 hover:text-indigo-400 rounded-lg border border-[#21262D] hover:border-indigo-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <FileText className="w-4 h-4" />
                        <span>Reports</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Open Client Lane Action */}
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-blue-500/10 text-white/80 hover:text-blue-400 rounded-lg border border-[#21262D] hover:border-blue-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <MessageSquare className="w-4 h-4" />
                        <span>Client Lane</span>
                      </div>
                      <ChevronRight className="w-4 h-4" />
                    </button>

                    {/* Stage VoIP Call Action */}
                    <button 
                      disabled={!selectedGuardData.contact.voipReady}
                      className={`
                        px-4 py-3 rounded-lg border text-sm font-semibold flex items-center justify-between transition-all
                        ${selectedGuardData.contact.voipReady
                          ? 'bg-[#0A0E13] hover:bg-emerald-500/10 text-white/80 hover:text-emerald-400 border-[#21262D] hover:border-emerald-500/30'
                          : 'bg-[#0A0E13] text-white/30 border-[#21262D] cursor-not-allowed'
                        }
                      `}
                    >
                      <div className="flex items-center gap-2">
                        <Phone className="w-4 h-4" />
                        <span>Stage VoIP</span>
                      </div>
                      {selectedGuardData.contact.voipReady ? (
                        <ChevronRight className="w-4 h-4" />
                      ) : (
                        <XCircle className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-12 text-center">
                <Users className="w-16 h-16 text-white/20 mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-2">Select a Guard</h3>
                <p className="text-sm text-white/60">Choose a guard from the roster to view profile and actions</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
