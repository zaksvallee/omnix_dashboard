import React, { useState } from 'react';
import { 
  Radio, Activity, Zap, Eye, Clock, BarChart3, Play, Pause, 
  RefreshCw, AlertTriangle, CheckCircle, Users, Camera, Phone,
  Watch, ExternalLink, FileText, TrendingUp, X, Gauge, Map
} from 'lucide-react';
import { ReadinessIndicator } from '../components/ReadinessIndicator';

interface Dispatch {
  id: string;
  site: string;
  priority: 'P1-CRITICAL' | 'P2-HIGH' | 'P3-MEDIUM';
  type: string;
  officer: string;
  dispatched: string;
  status: 'ACTIVE' | 'EN_ROUTE' | 'ON_SITE' | 'CLEARED';
}

interface IntelligenceItem {
  id: string;
  type: 'weather' | 'traffic' | 'threat' | 'resource';
  message: string;
  severity: 'info' | 'warning' | 'critical';
  pinned: boolean;
  dismissed: boolean;
}

export function Dispatches() {
  const [selectedDispatch, setSelectedDispatch] = useState<string | null>('DSP-004');
  const [ingestActive, setIngestActive] = useState(false);
  const [livePollActive, setLivePollActive] = useState(true);
  const [radioQueueActive, setRadioQueueActive] = useState(true);
  const [telemetryView, setTelemetryView] = useState<'normal' | 'heavy'>('normal');
  const [stressTestActive, setStressTestActive] = useState(false);
  const [soakTestActive, setSoakTestActive] = useState(false);
  const [showFleetWatch, setShowFleetWatch] = useState(false);

  const dispatches: Dispatch[] = [
    {
      id: 'DSP-004',
      site: 'Sandton Estate North',
      priority: 'P1-CRITICAL',
      type: 'Armed Response',
      officer: 'Echo-3',
      dispatched: '23:42 UTC',
      status: 'ON_SITE'
    },
    {
      id: 'DSP-003',
      site: 'Waterfall Estate',
      priority: 'P2-HIGH',
      type: 'Perimeter Breach',
      officer: 'Delta-1',
      dispatched: '23:15 UTC',
      status: 'CLEARED'
    },
  ];

  const intelligence: IntelligenceItem[] = [
    {
      id: 'INT-001',
      type: 'threat',
      message: 'High crime activity reported in Midrand sector - increase patrols',
      severity: 'warning',
      pinned: true,
      dismissed: false,
    },
    {
      id: 'INT-002',
      type: 'traffic',
      message: 'M1 Highway southbound congestion - expect 8min delay',
      severity: 'info',
      pinned: false,
      dismissed: false,
    },
    {
      id: 'INT-003',
      type: 'resource',
      message: '3 reaction officers available in Sandton zone',
      severity: 'info',
      pinned: false,
      dismissed: true,
    },
  ];

  const activeIntelligence = intelligence.filter(i => !i.dismissed);
  const activeDispatches = dispatches.filter(d => d.status !== 'CLEARED');

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-red-500 via-red-600 to-orange-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-red-500/30">
              <Radio className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Dispatch Command</h1>
              <p className="text-sm text-white/50">Real-time response coordination and fleet telemetry</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <FileText className="w-4 h-4" />
              Open Report
            </button>
          </div>
        </div>

        {/* Control Panel */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
          <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                <Activity className="w-4 h-4 text-cyan-400" />
              </div>
              <div>
                <h2 className="text-sm font-bold text-white uppercase tracking-wider">System Controls</h2>
                <p className="text-xs text-white/40 mt-0.5">Ingest, polling, radio queue, and telemetry</p>
              </div>
            </div>
          </div>

          <div className="p-6 grid grid-cols-4 gap-4">
            {/* Ingest Controls */}
            <button
              onClick={() => setIngestActive(!ingestActive)}
              className={`
                p-4 rounded-xl border transition-all text-left
                ${ingestActive 
                  ? 'bg-gradient-to-br from-emerald-950/50 to-teal-950/50 border-emerald-500/30' 
                  : 'bg-[#0A0E13] border-[#21262D] hover:border-emerald-500/20'
                }
              `}
            >
              <div className="flex items-center gap-3 mb-3">
                <div className={`
                  w-10 h-10 rounded-lg flex items-center justify-center
                  ${ingestActive ? 'bg-emerald-500/20' : 'bg-white/5'}
                `}>
                  <Zap className={`w-5 h-5 ${ingestActive ? 'text-emerald-400' : 'text-white/40'}`} />
                </div>
                {ingestActive && (
                  <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
                )}
              </div>
              <div className={`text-sm font-bold uppercase tracking-wider mb-1 ${ingestActive ? 'text-emerald-400' : 'text-white/60'}`}>
                Ingest
              </div>
              <div className="text-xs text-white/40">
                {ingestActive ? 'Active' : 'Paused'}
              </div>
            </button>

            {/* Live Polling */}
            <button
              onClick={() => setLivePollActive(!livePollActive)}
              className={`
                p-4 rounded-xl border transition-all text-left
                ${livePollActive
                  ? 'bg-gradient-to-br from-cyan-950/50 to-blue-950/50 border-cyan-500/30'
                  : 'bg-[#0A0E13] border-[#21262D] hover:border-cyan-500/20'
                }
              `}
            >
              <div className="flex items-center gap-3 mb-3">
                <div className={`
                  w-10 h-10 rounded-lg flex items-center justify-center
                  ${livePollActive ? 'bg-cyan-500/20' : 'bg-white/5'}
                `}>
                  <RefreshCw className={`w-5 h-5 ${livePollActive ? 'text-cyan-400 animate-spin' : 'text-white/40'}`} />
                </div>
                {livePollActive && (
                  <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse" />
                )}
              </div>
              <div className={`text-sm font-bold uppercase tracking-wider mb-1 ${livePollActive ? 'text-cyan-400' : 'text-white/60'}`}>
                Live Poll
              </div>
              <div className="text-xs text-white/40">
                {livePollActive ? '2s interval' : 'Paused'}
              </div>
            </button>

            {/* Radio Queue */}
            <button
              onClick={() => setRadioQueueActive(!radioQueueActive)}
              className={`
                p-4 rounded-xl border transition-all text-left
                ${radioQueueActive
                  ? 'bg-gradient-to-br from-purple-950/50 to-pink-950/50 border-purple-500/30'
                  : 'bg-[#0A0E13] border-[#21262D] hover:border-purple-500/20'
                }
              `}
            >
              <div className="flex items-center gap-3 mb-3">
                <div className={`
                  w-10 h-10 rounded-lg flex items-center justify-center
                  ${radioQueueActive ? 'bg-purple-500/20' : 'bg-white/5'}
                `}>
                  <Radio className={`w-5 h-5 ${radioQueueActive ? 'text-purple-400' : 'text-white/40'}`} />
                </div>
                {radioQueueActive && (
                  <div className="w-2 h-2 bg-purple-400 rounded-full animate-pulse" />
                )}
              </div>
              <div className={`text-sm font-bold uppercase tracking-wider mb-1 ${radioQueueActive ? 'text-purple-400' : 'text-white/60'}`}>
                Radio Queue
              </div>
              <div className="text-xs text-white/40">
                {radioQueueActive ? 'Listening' : 'Paused'}
              </div>
            </button>

            {/* Telemetry */}
            <button
              onClick={() => setTelemetryView(telemetryView === 'normal' ? 'heavy' : 'normal')}
              className={`
                p-4 rounded-xl border transition-all text-left
                ${telemetryView === 'heavy'
                  ? 'bg-gradient-to-br from-amber-950/50 to-orange-950/50 border-amber-500/30'
                  : 'bg-[#0A0E13] border-[#21262D] hover:border-amber-500/20'
                }
              `}
            >
              <div className="flex items-center gap-3 mb-3">
                <div className={`
                  w-10 h-10 rounded-lg flex items-center justify-center
                  ${telemetryView === 'heavy' ? 'bg-amber-500/20' : 'bg-white/5'}
                `}>
                  <BarChart3 className={`w-5 h-5 ${telemetryView === 'heavy' ? 'text-amber-400' : 'text-white/40'}`} />
                </div>
              </div>
              <div className={`text-sm font-bold uppercase tracking-wider mb-1 ${telemetryView === 'heavy' ? 'text-amber-400' : 'text-white/60'}`}>
                Telemetry
              </div>
              <div className="text-xs text-white/40">
                {telemetryView === 'heavy' ? 'Heavy View' : 'Normal'}
              </div>
            </button>
          </div>
        </div>

        {/* Readiness Row */}
        <div className="grid grid-cols-3 gap-4">
          <ReadinessIndicator label="Wearable Readiness" state="ready" details="8 devices online" />
          <ReadinessIndicator label="Radio Readiness" state="ready" details="All channels clear" />
          <ReadinessIndicator label="Video Readiness" state="degraded" details="1 feed degraded" />
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Active Dispatches */}
          <div className="col-span-2 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-red-500/10 flex items-center justify-center">
                    <Radio className="w-4 h-4 text-red-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Active Dispatch Queue</h2>
                    <p className="text-xs text-white/40 mt-0.5">{activeDispatches.length} active, {dispatches.length - activeDispatches.length} cleared</p>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-3">
                {dispatches.length === 0 ? (
                  <div className="bg-gradient-to-br from-emerald-950/30 to-teal-950/30 border border-emerald-500/20 rounded-xl p-8 text-center">
                    <CheckCircle className="w-12 h-12 text-emerald-400 mx-auto mb-3" />
                    <h3 className="text-lg font-bold text-white mb-2">Queue Clear</h3>
                    <p className="text-sm text-white/60">No active dispatches. All units available.</p>
                  </div>
                ) : (
                  dispatches.map((dispatch) => (
                    <button
                      key={dispatch.id}
                      onClick={() => setSelectedDispatch(dispatch.id)}
                      className={`
                        w-full p-5 rounded-xl border transition-all text-left
                        ${selectedDispatch === dispatch.id
                          ? 'bg-gradient-to-br from-cyan-950/50 to-blue-950/50 border-cyan-500/30'
                          : 'bg-[#0A0E13] border-[#21262D] hover:border-cyan-500/20'
                        }
                      `}
                    >
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <div className="flex items-center gap-2 mb-1">
                            <span className="text-sm font-mono text-white font-bold">{dispatch.id}</span>
                            <div className={`
                              px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                              ${dispatch.status === 'ACTIVE' ? 'bg-red-500/20 text-red-400' : ''}
                              ${dispatch.status === 'EN_ROUTE' ? 'bg-amber-500/20 text-amber-400' : ''}
                              ${dispatch.status === 'ON_SITE' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                              ${dispatch.status === 'CLEARED' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                            `}>
                              {dispatch.status.replace('_', ' ')}
                            </div>
                          </div>
                          <div className="text-sm text-white/80 font-semibold mb-1">{dispatch.type}</div>
                          <div className="text-xs text-white/50">{dispatch.site}</div>
                        </div>
                        <div className={`
                          px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                          ${dispatch.priority === 'P1-CRITICAL' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                          ${dispatch.priority === 'P2-HIGH' ? 'bg-orange-500/20 text-orange-400 border-orange-500/30' : ''}
                          ${dispatch.priority === 'P3-MEDIUM' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' : ''}
                        `}>
                          {dispatch.priority}
                        </div>
                      </div>

                      <div className="flex items-center gap-4 text-xs text-white/60">
                        <div className="flex items-center gap-1.5">
                          <Users className="w-3 h-3" />
                          <span>{dispatch.officer}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                          <Clock className="w-3 h-3" />
                          <span>{dispatch.dispatched}</span>
                        </div>
                      </div>
                    </button>
                  ))
                )}
              </div>
            </div>
          </div>

          {/* Intelligence & Filters */}
          <div className="space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-blue-400" />
                  <h3 className="text-xs font-bold text-white uppercase tracking-wider">Intelligence</h3>
                  <div className="ml-auto px-2 py-0.5 bg-blue-500/20 text-blue-400 rounded text-[10px] font-bold">
                    {activeIntelligence.length}
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2">
                {activeIntelligence.map((intel) => (
                  <div
                    key={intel.id}
                    className={`
                      p-3 rounded-lg border
                      ${intel.severity === 'critical' ? 'bg-red-500/5 border-red-500/20' : ''}
                      ${intel.severity === 'warning' ? 'bg-amber-500/5 border-amber-500/20' : ''}
                      ${intel.severity === 'info' ? 'bg-blue-500/5 border-blue-500/20' : ''}
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className={`
                        px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                        ${intel.severity === 'critical' ? 'bg-red-500/20 text-red-400' : ''}
                        ${intel.severity === 'warning' ? 'bg-amber-500/20 text-amber-400' : ''}
                        ${intel.severity === 'info' ? 'bg-blue-500/20 text-blue-400' : ''}
                      `}>
                        {intel.severity}
                      </div>
                      {intel.pinned && (
                        <div className="px-2 py-0.5 bg-purple-500/20 text-purple-400 rounded text-[10px] font-bold uppercase">
                          Pinned
                        </div>
                      )}
                    </div>
                    <p className="text-xs text-white/80 leading-relaxed mb-2">{intel.message}</p>
                    <div className="flex gap-2">
                      <button className="flex-1 px-2 py-1 bg-[#0A0E13] hover:bg-white/5 text-white/60 text-[10px] font-semibold rounded border border-[#21262D] transition-all">
                        {intel.pinned ? 'Unpin' : 'Pin'}
                      </button>
                      <button className="flex-1 px-2 py-1 bg-[#0A0E13] hover:bg-red-500/10 text-white/60 hover:text-red-400 text-[10px] font-semibold rounded border border-[#21262D] hover:border-red-500/30 transition-all">
                        Dismiss
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Partner Dispatch */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-2">
                  <ExternalLink className="w-4 h-4 text-purple-400" />
                  <h3 className="text-xs font-bold text-white uppercase tracking-wider">Partner Dispatch</h3>
                </div>
              </div>
              <div className="p-5">
                <p className="text-xs text-white/60 mb-3">Route to partner for off-scope handling</p>
                <button className="w-full px-4 py-2 bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 rounded-lg border border-purple-500/30 text-sm font-semibold uppercase tracking-wider transition-all">
                  Route Dispatch
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}