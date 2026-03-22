import React, { useState } from 'react';
import { 
  Shield, FileCheck, AlertTriangle, CheckCircle, Clock, ExternalLink,
  Eye, TrendingUp, Users, Building2, Radio, FileText, Hash, Filter,
  Calendar, ChevronRight, XCircle, Info
} from 'lucide-react';

interface BlockerItem {
  id: string;
  type: 'blocker' | 'non-blocker';
  severity: 'critical' | 'warning' | 'info';
  message: string;
  source: string;
  timestamp: string;
  resolved: boolean;
}

interface PartnerChainItem {
  id: string;
  partnerId: string;
  partnerName: string;
  incidentId: string;
  routedAt: string;
  status: 'pending' | 'acknowledged' | 'completed';
}

interface ComplianceItem {
  id: string;
  category: 'evidence' | 'reporting' | 'response-time' | 'verification';
  status: 'verified' | 'pending' | 'failed';
  message: string;
  linkedEvent?: string;
  linkedReport?: string;
}

export function Governance() {
  const [reportView, setReportView] = useState<'morning' | 'historical'>('morning');
  const [scopeFilter, setsScopeFilter] = useState<'all' | 'partner' | 'internal'>('all');
  const [selectedBlocker, setSelectedBlocker] = useState<string | null>('BLOCK-001');

  const blockers: BlockerItem[] = [
    {
      id: 'BLOCK-001',
      type: 'blocker',
      severity: 'critical',
      message: 'CCTV verification failed for INC-DSP-4 - footage gap detected',
      source: 'Tactical Watch',
      timestamp: '23:45 UTC',
      resolved: false,
    },
    {
      id: 'BLOCK-002',
      type: 'blocker',
      severity: 'warning',
      message: 'Client notification delivery delayed by 142s (SLA breach)',
      source: 'Client Comms',
      timestamp: '23:38 UTC',
      resolved: false,
    },
    {
      id: 'NON-BLOCK-001',
      type: 'non-blocker',
      severity: 'info',
      message: 'Guard G-2441 late clock-in by 4 minutes',
      source: 'Guards',
      timestamp: '22:14 UTC',
      resolved: true,
    },
  ];

  const partnerChain: PartnerChainItem[] = [
    {
      id: 'CHAIN-001',
      partnerId: 'PARTNER-VIGILANT',
      partnerName: 'Vigilant Response Co.',
      incidentId: 'INC-OFF-SCOPE-12',
      routedAt: '23:22 UTC',
      status: 'acknowledged',
    },
    {
      id: 'CHAIN-002',
      partnerId: 'PARTNER-SENTINEL',
      partnerName: 'Sentinel Security',
      incidentId: 'INC-OFF-SCOPE-09',
      routedAt: '21:45 UTC',
      status: 'completed',
    },
  ];

  const compliance: ComplianceItem[] = [
    { id: 'COMP-001', category: 'evidence', status: 'verified', message: 'CCTV footage archived for 12 incidents', linkedEvent: 'EVT-2441' },
    { id: 'COMP-002', category: 'reporting', status: 'pending', message: 'Morning sovereign report awaiting final verification', linkedReport: 'RPT-2024-03-18' },
    { id: 'COMP-003', category: 'response-time', status: 'verified', message: 'All P1 incidents responded within 240s SLA' },
    { id: 'COMP-004', category: 'verification', status: 'failed', message: 'Manual verification incomplete for 2 limited-watch sites', linkedEvent: 'EVT-WF-02' },
  ];

  const activeBlockers = blockers.filter(b => b.type === 'blocker' && !b.resolved);
  const nonBlockers = blockers.filter(b => b.type === 'non-blocker');

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-green-500 via-emerald-600 to-teal-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-emerald-500/30">
              <Shield className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Governance & Compliance</h1>
              <p className="text-sm text-white/50">Sovereign reporting, readiness monitoring, and evidence compliance</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Events
            </button>
            <button className="px-4 py-2 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 rounded-xl border border-emerald-500/30 flex items-center gap-2 text-sm font-semibold transition-all">
              <FileText className="w-4 h-4" />
              Generate Report
            </button>
          </div>
        </div>

        {/* Report View Toggle */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Report View:</div>
              <div className="flex gap-2">
                <button
                  onClick={() => setReportView('morning')}
                  className={`px-4 py-2 rounded-lg border text-sm font-semibold transition-all ${
                    reportView === 'morning'
                      ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                      : 'bg-[#0A0E13] text-white/60 border-[#21262D] hover:border-emerald-500/20'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <Calendar className="w-4 h-4" />
                    Morning Sovereign
                  </div>
                </button>
                <button
                  onClick={() => setReportView('historical')}
                  className={`px-4 py-2 rounded-lg border text-sm font-semibold transition-all ${
                    reportView === 'historical'
                      ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                      : 'bg-[#0A0E13] text-white/60 border-[#21262D] hover:border-cyan-500/20'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <Clock className="w-4 h-4" />
                    Historical
                  </div>
                </button>
              </div>
            </div>

            {/* Scope Filter */}
            <div className="flex items-center gap-2">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Scope:</div>
              <button
                onClick={() => setsScopeFilter('all')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'all'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setsScopeFilter('internal')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'internal'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Internal
              </button>
              <button
                onClick={() => setsScopeFilter('partner')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'partner'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Partner-Scope
              </button>
            </div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Blockers */}
          <div className="col-span-2 space-y-6">
            {/* Active Blockers */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-red-500/10 flex items-center justify-center">
                    <AlertTriangle className="w-4 h-4 text-red-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Readiness Blockers</h2>
                    <p className="text-xs text-white/40 mt-0.5">{activeBlockers.length} active blockers requiring resolution</p>
                  </div>
                  {activeBlockers.length > 0 && (
                    <div className="px-3 py-1.5 bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-bold uppercase tracking-wider">
                      Action Required
                    </div>
                  )}
                </div>
              </div>

              <div className="p-6 space-y-3">
                {activeBlockers.length === 0 ? (
                  <div className="bg-gradient-to-br from-emerald-950/30 to-teal-950/30 border border-emerald-500/20 rounded-xl p-8 text-center">
                    <CheckCircle className="w-12 h-12 text-emerald-400 mx-auto mb-3" />
                    <h3 className="text-lg font-bold text-white mb-2">No Active Blockers</h3>
                    <p className="text-sm text-white/60">All systems ready for sovereign reporting</p>
                  </div>
                ) : (
                  activeBlockers.map((blocker) => (
                    <button
                      key={blocker.id}
                      onClick={() => setSelectedBlocker(blocker.id)}
                      className={`
                        w-full p-5 rounded-xl border transition-all text-left
                        ${selectedBlocker === blocker.id
                          ? 'bg-gradient-to-br from-red-950/50 to-orange-950/50 border-red-500/30'
                          : 'bg-[#0A0E13] border-red-500/20 hover:border-red-500/40'
                        }
                      `}
                    >
                      <div className="flex items-start justify-between mb-3">
                        <div className="flex items-center gap-2">
                          <AlertTriangle className="w-4 h-4 text-red-400" />
                          <div className={`
                            px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                            ${blocker.severity === 'critical' ? 'bg-red-500/20 text-red-400' : ''}
                            ${blocker.severity === 'warning' ? 'bg-amber-500/20 text-amber-400' : ''}
                          `}>
                            {blocker.severity}
                          </div>
                        </div>
                        <div className="text-xs text-white/40 tabular-nums">{blocker.timestamp}</div>
                      </div>
                      <p className="text-sm text-white/90 leading-relaxed mb-2">{blocker.message}</p>
                      <div className="flex items-center justify-between">
                        <div className="text-xs text-white/50">{blocker.source}</div>
                        <button className="px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                          Resolve
                        </button>
                      </div>
                    </button>
                  ))
                )}
              </div>
            </div>

            {/* Non-Blockers */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-amber-500/10 flex items-center justify-center">
                    <Info className="w-4 h-4 text-amber-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Non-Blockers</h2>
                    <p className="text-xs text-white/40 mt-0.5">{nonBlockers.length} items for awareness</p>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-2">
                {nonBlockers.map((item) => (
                  <div
                    key={item.id}
                    className="p-4 rounded-lg bg-[#0A0E13] border border-amber-500/20"
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <Info className="w-3.5 h-3.5 text-amber-400" />
                        <div className="px-2 py-0.5 bg-amber-500/20 text-amber-400 rounded text-[10px] font-bold uppercase tracking-wider">
                          {item.severity}
                        </div>
                      </div>
                      <div className="text-xs text-white/40 tabular-nums">{item.timestamp}</div>
                    </div>
                    <p className="text-xs text-white/80 leading-relaxed mb-2">{item.message}</p>
                    <div className="text-xs text-white/50">{item.source}</div>
                  </div>
                ))}
              </div>
            </div>

            {/* Partner Dispatch Chain */}
            {scopeFilter !== 'internal' && (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                      <ExternalLink className="w-4 h-4 text-purple-400" />
                    </div>
                    <div className="flex-1">
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Partner Dispatch Chain</h2>
                      <p className="text-xs text-white/40 mt-0.5">{partnerChain.length} off-scope incidents routed to partners</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-3">
                  {partnerChain.map((chain) => (
                    <div
                      key={chain.id}
                      className="p-4 rounded-xl bg-[#0A0E13] border border-purple-500/20 hover:border-purple-500/40 transition-all"
                    >
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <div className="text-sm font-bold text-white mb-1">{chain.partnerName}</div>
                          <div className="text-xs text-white/50 font-mono">{chain.partnerId}</div>
                        </div>
                        <div className={`
                          px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider
                          ${chain.status === 'completed' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                          ${chain.status === 'acknowledged' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                          ${chain.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : ''}
                        `}>
                          {chain.status}
                        </div>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-white/60">
                        <div className="flex items-center gap-1.5">
                          <Hash className="w-3 h-3" />
                          <span>{chain.incidentId}</span>
                        </div>
                        <div className="flex items-center gap-1.5">
                          <Clock className="w-3 h-3" />
                          <span>{chain.routedAt}</span>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>

          {/* Right Column - Compliance Summary */}
          <div className="space-y-6">
            {/* Compliance Status */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-2">
                  <FileCheck className="w-4 h-4 text-emerald-400" />
                  <h3 className="text-xs font-bold text-white uppercase tracking-wider">Compliance Summary</h3>
                </div>
              </div>

              <div className="p-5 space-y-3">
                {compliance.map((item) => (
                  <div
                    key={item.id}
                    className={`
                      p-3 rounded-lg border
                      ${item.status === 'verified' ? 'bg-emerald-500/5 border-emerald-500/20' : ''}
                      ${item.status === 'pending' ? 'bg-amber-500/5 border-amber-500/20' : ''}
                      ${item.status === 'failed' ? 'bg-red-500/5 border-red-500/20' : ''}
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className={`
                        px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                        ${item.status === 'verified' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                        ${item.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : ''}
                        ${item.status === 'failed' ? 'bg-red-500/20 text-red-400' : ''}
                      `}>
                        {item.status}
                      </div>
                      {item.status === 'verified' && <CheckCircle className="w-3.5 h-3.5 text-emerald-400" />}
                      {item.status === 'pending' && <Clock className="w-3.5 h-3.5 text-amber-400" />}
                      {item.status === 'failed' && <XCircle className="w-3.5 h-3.5 text-red-400" />}
                    </div>
                    <p className="text-xs text-white/80 leading-relaxed mb-2">{item.message}</p>
                    <div className="flex items-center gap-2">
                      <div className="px-2 py-0.5 bg-white/5 text-white/50 rounded text-[10px] font-semibold uppercase tracking-wider">
                        {item.category}
                      </div>
                    </div>
                    {/* Drilldown Actions */}
                    {item.linkedEvent && (
                      <button className="mt-2 w-full px-3 py-1.5 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded border border-[#21262D] hover:border-cyan-500/30 transition-all text-[10px] font-semibold uppercase tracking-wider flex items-center justify-center gap-1.5">
                        <Eye className="w-3 h-3" />
                        View Event {item.linkedEvent}
                      </button>
                    )}
                    {item.linkedReport && (
                      <button className="mt-2 w-full px-3 py-1.5 bg-[#0A0E13] hover:bg-emerald-500/10 text-white/60 hover:text-emerald-400 rounded border border-[#21262D] hover:border-emerald-500/30 transition-all text-[10px] font-semibold uppercase tracking-wider flex items-center justify-center gap-1.5">
                        <FileText className="w-3 h-3" />
                        View Report {item.linkedReport}
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-cyan-400" />
                  <h3 className="text-xs font-bold text-white uppercase tracking-wider">Quick Actions</h3>
                </div>
              </div>

              <div className="p-5 space-y-2">
                <button className="w-full px-4 py-3 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                  <span>View All Events</span>
                  <ChevronRight className="w-4 h-4" />
                </button>
                <button className="w-full px-4 py-3 bg-[#0A0E13] hover:bg-emerald-500/10 text-white/80 hover:text-emerald-400 rounded-lg border border-[#21262D] hover:border-emerald-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                  <span>View All Reports</span>
                  <ChevronRight className="w-4 h-4" />
                </button>
                <button className="w-full px-4 py-3 bg-[#0A0E13] hover:bg-purple-500/10 text-white/80 hover:text-purple-400 rounded-lg border border-[#21262D] hover:border-purple-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                  <span>View Ledger</span>
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
