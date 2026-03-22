import React, { useState, useEffect } from 'react';
import { 
  Shield, MessageSquare, Clock, AlertTriangle, ChevronRight,
  Radio, Zap, Eye, CheckCircle, X, ExternalLink, TrendingUp,
  Activity, Bell, Lock, Filter, RotateCcw, Info
} from 'lucide-react';
import { QueueStateChip } from '../components/QueueStateChip';
import { DraftCard } from '../components/DraftCard';
import { RefineDialog } from '../components/RefineDialog';

type QueueMode = 'full' | 'high-priority' | 'timing' | 'sensitive' | 'validation';

export function LiveOperations() {
  const [queueMode, setQueueMode] = useState<QueueMode>('full');
  const [showRefineDialog, setShowRefineDialog] = useState(false);
  const [showFirstRunHint, setShowFirstRunHint] = useState(false);
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(interval);
  }, []);

  // Mock data
  const drafts = [
    {
      id: 'INC-8932-1X',
      text: 'Client notification: Armed response officer Echo-3 has been dispatched to Sandton Estate North following perimeter breach detection at 23:42. Estimated arrival 4 minutes. Officer will verify scene and provide update.',
      cues: ['timing' as const, 'detail' as const],
      priority: 'high' as const,
    },
    {
      id: 'INC-8838-2Z',
      text: 'Security update: We detected unusual activity near the north gate camera feed at 23:38. Our team is reviewing footage and will call you shortly to verify safe-word protocol. No immediate action required.',
      cues: ['sensitive' as const, 'reassurance' as const, 'next-step' as const],
      priority: 'sensitive' as const,
    },
  ];

  const filteredDrafts = queueMode === 'full' 
    ? drafts 
    : queueMode === 'high-priority'
    ? drafts.filter(d => d.priority === 'high')
    : queueMode === 'timing'
    ? drafts.filter(d => d.cues.includes('timing'))
    : queueMode === 'sensitive'
    ? drafts.filter(d => d.priority === 'sensitive' || d.cues.includes('sensitive'))
    : drafts.filter(d => d.cues.includes('validation'));

  return (
    <div className="h-full flex flex-col overflow-hidden">
      {/* Critical Alert Banner - Only shows when there are critical items */}
      <div className="bg-gradient-to-r from-red-950 to-red-900 border-b-2 border-red-500 px-6 py-2.5 flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-400 animate-pulse" />
            <span className="text-xs font-bold text-red-200 uppercase tracking-wider">CRITICAL ALERT</span>
          </div>
          <div className="h-4 w-px bg-red-500/30" />
          <span className="text-sm text-red-100">INC-DSP-4 • Armed response dispatched • Ms Valley Residence</span>
          <div className="ml-auto flex items-center gap-2">
            <span className="text-xs font-mono text-red-300 tabular-nums">CLEARED 23:38:38</span>
            <button className="px-3 py-1 bg-red-500/20 hover:bg-red-500/30 text-red-200 text-xs font-semibold rounded border border-red-500/30 transition-colors">
              VIEW DETAILS
            </button>
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        <div className="p-6 max-w-[1800px] mx-auto space-y-6">
          {/* Command Overview Grid */}
          <div className="grid grid-cols-4 gap-4">
            {/* Active Incidents */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-5 hover:border-cyan-500/30 transition-all group">
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-red-500/20 to-orange-500/20 flex items-center justify-center border border-red-500/30">
                  <Activity className="w-5 h-5 text-red-400" />
                </div>
                <div className="px-2 py-1 bg-red-500/10 text-red-400 text-[10px] font-bold rounded uppercase tracking-wider">
                  Live
                </div>
              </div>
              <div className="mb-1">
                <div className="text-4xl font-bold text-white tabular-nums tracking-tight">2</div>
              </div>
              <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Active Incidents</div>
              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center gap-2 text-xs text-white/60">
                  <TrendingUp className="w-3 h-3 text-emerald-400" />
                  <span>5 cleared today</span>
                </div>
              </div>
            </div>

            {/* Pending Replies */}
            <div className="bg-[#0D1117] border border-amber-500/20 rounded-xl p-5 hover:border-amber-500/30 transition-all group">
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center border border-amber-500/30">
                  <Clock className="w-5 h-5 text-amber-400" />
                </div>
                <div className="px-2 py-1 bg-amber-500/10 text-amber-400 text-[10px] font-bold rounded uppercase tracking-wider">
                  Queue
                </div>
              </div>
              <div className="mb-1">
                <div className="text-4xl font-bold text-white tabular-nums tracking-tight">{filteredDrafts.length}</div>
              </div>
              <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Pending Replies</div>
              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center gap-2 text-xs">
                  <div className="w-1.5 h-1.5 bg-red-400 rounded-full animate-pulse" />
                  <span className="text-red-400 font-semibold">1 High Priority</span>
                </div>
              </div>
            </div>

            {/* Client Comms */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-5 hover:border-cyan-500/30 transition-all group">
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center border border-cyan-500/30">
                  <MessageSquare className="w-5 h-5 text-cyan-400" />
                </div>
                <div className="px-2 py-1 bg-cyan-500/10 text-cyan-400 text-[10px] font-bold rounded uppercase tracking-wider">
                  Ready
                </div>
              </div>
              <div className="mb-1">
                <div className="text-4xl font-bold text-white tabular-nums tracking-tight">1</div>
              </div>
              <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Active Lanes</div>
              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center gap-2 text-xs text-white/60">
                  <CheckCircle className="w-3 h-3 text-emerald-400" />
                  <span>Telegram ready</span>
                </div>
              </div>
            </div>

            {/* Watch Status */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-5 hover:border-cyan-500/30 transition-all group">
              <div className="flex items-start justify-between mb-3">
                <div className="w-10 h-10 rounded-lg bg-gradient-to-br from-emerald-500/20 to-teal-500/20 flex items-center justify-center border border-emerald-500/30">
                  <Eye className="w-5 h-5 text-emerald-400" />
                </div>
                <div className="px-2 py-1 bg-emerald-500/10 text-emerald-400 text-[10px] font-bold rounded uppercase tracking-wider">
                  Active
                </div>
              </div>
              <div className="mb-1">
                <div className="text-4xl font-bold text-white tabular-nums tracking-tight">1</div>
              </div>
              <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Sites Under Watch</div>
              <div className="mt-3 pt-3 border-t border-white/5">
                <div className="flex items-center gap-2 text-xs text-white/60">
                  <Shield className="w-3 h-3 text-emerald-400" />
                  <span>Full coverage</span>
                </div>
              </div>
            </div>
          </div>

          {/* Active Scope Banner */}
          <div className="bg-gradient-to-r from-cyan-950/50 to-blue-950/50 border border-cyan-500/30 rounded-xl p-4">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl bg-cyan-500/10 flex items-center justify-center border border-cyan-500/30">
                <Lock className="w-6 h-6 text-cyan-400" />
              </div>
              <div className="flex-1">
                <div className="text-xs text-cyan-400/70 uppercase tracking-wider font-semibold mb-1">Scope Focus Active</div>
                <div className="font-mono text-lg text-cyan-300 font-bold tracking-tight">
                  CLIENT-MS-VALLEY <span className="text-cyan-500/50">/</span> SITE-MS-VALLEY-RESIDENCE
                </div>
              </div>
              <button className="px-4 py-2 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-sm font-semibold rounded-lg border border-cyan-500/30 transition-all">
                Change Scope
              </button>
            </div>
          </div>

          {/* Main Content Grid - 2 columns */}
          <div className="grid grid-cols-3 gap-6">
            {/* Left Column - Control Inbox */}
            <div className="col-span-2 space-y-6">
              {/* Control Inbox */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                      <MessageSquare className="w-4 h-4 text-cyan-400" />
                    </div>
                    <div className="flex-1">
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Control Inbox</h2>
                      <p className="text-xs text-white/40 mt-0.5">Client communication review queue</p>
                    </div>
                    <button 
                      onClick={() => setShowFirstRunHint(!showFirstRunHint)}
                      className="w-8 h-8 rounded-lg hover:bg-white/5 text-white/40 hover:text-cyan-400 transition-all flex items-center justify-center"
                      title="Show queue help"
                    >
                      <Info className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Queue State Filters */}
                  <div className="flex items-center gap-2 flex-wrap">
                    <QueueStateChip 
                      state="full" 
                      count={drafts.length}
                      active={queueMode === 'full'}
                      onClick={() => setQueueMode('full')}
                    />
                    <QueueStateChip 
                      state="high-priority" 
                      count={drafts.filter(d => d.priority === 'high').length}
                      active={queueMode === 'high-priority'}
                      onClick={() => setQueueMode('high-priority')}
                    />
                    <QueueStateChip 
                      state="timing" 
                      count={drafts.filter(d => d.cues.includes('timing')).length}
                      active={queueMode === 'timing'}
                      onClick={() => setQueueMode('timing')}
                    />
                    <QueueStateChip 
                      state="sensitive" 
                      count={drafts.filter(d => d.priority === 'sensitive' || d.cues.includes('sensitive')).length}
                      active={queueMode === 'sensitive'}
                      onClick={() => setQueueMode('sensitive')}
                    />
                    <QueueStateChip 
                      state="validation" 
                      count={drafts.filter(d => d.cues.includes('validation')).length}
                      active={queueMode === 'validation'}
                      onClick={() => setQueueMode('validation')}
                    />
                    
                    {queueMode !== 'full' && (
                      <button
                        onClick={() => setQueueMode('full')}
                        className="ml-2 px-3 py-1.5 bg-[#0A0E13] hover:bg-white/5 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center gap-2 text-xs font-semibold"
                      >
                        <RotateCcw className="w-3 h-3" />
                        Show All
                      </button>
                    )}
                  </div>

                  {/* First Run Hint */}
                  {showFirstRunHint && (
                    <div className="mt-4 bg-gradient-to-br from-blue-950/50 to-indigo-950/50 border border-blue-500/30 rounded-xl p-4">
                      <div className="flex items-start gap-3">
                        <Info className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-blue-300 mb-2">Queue Filtering Tips</h3>
                          <ul className="text-xs text-blue-400/80 space-y-1 leading-relaxed">
                            <li>• <strong>High Priority:</strong> Time-sensitive or escalated communications</li>
                            <li>• <strong>Timing Only:</strong> Messages flagged for specific delivery windows</li>
                            <li>• <strong>Sensitive Only:</strong> Requires careful tone or contains PII</li>
                            <li>• <strong>Validation Only:</strong> Needs fact-checking or approval</li>
                          </ul>
                        </div>
                        <button
                          onClick={() => setShowFirstRunHint(false)}
                          className="w-6 h-6 rounded hover:bg-blue-500/20 text-blue-400/60 hover:text-blue-400 transition-all flex items-center justify-center flex-shrink-0"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  )}
                </div>

                <div className="p-6 space-y-4">
                  {filteredDrafts.length === 0 ? (
                    <div className="bg-gradient-to-br from-emerald-950/30 to-teal-950/30 border border-emerald-500/20 rounded-xl p-6 text-center">
                      <div className="w-16 h-16 mx-auto mb-4 rounded-2xl bg-emerald-500/10 flex items-center justify-center border border-emerald-500/20">
                        <CheckCircle className="w-8 h-8 text-emerald-400" />
                      </div>
                      <h3 className="text-lg font-bold text-white mb-2">
                        {queueMode === 'full' ? 'No Pending Client Replies' : `No ${queueMode.replace('-', ' ')} items`}
                      </h3>
                      <p className="text-sm text-white/60 mb-1">Queue is clear for this filter</p>
                      {queueMode !== 'full' && (
                        <button
                          onClick={() => setQueueMode('full')}
                          className="mt-3 px-4 py-2 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-sm font-semibold rounded-lg border border-emerald-500/30 transition-all inline-flex items-center gap-2"
                        >
                          <Filter className="w-4 h-4" />
                          View Full Queue
                        </button>
                      )}
                    </div>
                  ) : (
                    <>
                      {filteredDrafts.map((draft) => (
                        <DraftCard
                          key={draft.id}
                          incidentId={draft.id}
                          draftText={draft.text}
                          cues={draft.cues}
                          priority={draft.priority}
                          onRefine={() => setShowRefineDialog(true)}
                          onApprove={() => console.log('Approved:', draft.id)}
                          onDismiss={() => console.log('Dismissed:', draft.id)}
                        />
                      ))}
                    </>
                  )}
                </div>
              </div>

              {/* Client Lane Watch */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-blue-500/10 flex items-center justify-center">
                      <Radio className="w-4 h-4 text-blue-400" />
                    </div>
                    <div>
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Client Lane Watch</h2>
                      <p className="text-xs text-white/40 mt-0.5">Real-time communication monitoring • Ms Valley Residence</p>
                    </div>
                    <div className="ml-auto flex items-center gap-2">
                      <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
                      <span className="text-xs text-emerald-400 font-semibold">Lane Active</span>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-4">
                  {/* Status Grid */}
                  <div className="grid grid-cols-3 gap-3">
                    <div className="bg-[#0A0E13] border border-emerald-500/20 rounded-lg p-3">
                      <div className="text-xs text-emerald-400/70 uppercase tracking-wider font-semibold mb-1">Incident</div>
                      <div className="text-sm font-mono text-emerald-400 font-bold">INC-DSP-4</div>
                    </div>
                    <div className="bg-[#0A0E13] border border-cyan-500/20 rounded-lg p-3">
                      <div className="text-xs text-cyan-400/70 uppercase tracking-wider font-semibold mb-1">Status</div>
                      <div className="text-sm text-cyan-400 font-bold">Lane Open</div>
                    </div>
                    <div className="bg-[#0A0E13] border border-purple-500/20 rounded-lg p-3">
                      <div className="text-xs text-purple-400/70 uppercase tracking-wider font-semibold mb-1">Voice</div>
                      <div className="text-sm text-purple-400 font-bold">Auto</div>
                    </div>
                  </div>

                  {/* Communication Channels */}
                  <div className="space-y-2">
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Communication Channels</div>
                    <div className="flex flex-wrap gap-2">
                      <div className="px-3 py-1.5 bg-emerald-500/10 text-emerald-400 text-xs font-semibold rounded-md border border-emerald-500/20 flex items-center gap-1.5">
                        <CheckCircle className="w-3 h-3" />
                        Telegram Ready
                      </div>
                      <div className="px-3 py-1.5 bg-white/5 text-white/40 text-xs font-semibold rounded-md border border-white/10 flex items-center gap-1.5">
                        <X className="w-3 h-3" />
                        SMS Unconfigured
                      </div>
                      <div className="px-3 py-1.5 bg-amber-500/10 text-amber-400 text-xs font-semibold rounded-md border border-amber-500/20 flex items-center gap-1.5">
                        <Clock className="w-3 h-3" />
                        VoIP Staging
                      </div>
                      <div className="px-3 py-1.5 bg-white/5 text-white/40 text-xs font-semibold rounded-md border border-white/10 flex items-center gap-1.5">
                        Push Idle
                      </div>
                    </div>
                  </div>

                  {/* Voice Profiles */}
                  <div>
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Quick Voice Profiles</div>
                    <div className="flex gap-2">
                      <button className="px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-semibold rounded-md border border-cyan-500/30 transition-all">
                        Auto
                      </button>
                      <button className="px-3 py-1.5 bg-[#0A0E13] hover:bg-white/5 text-white/60 text-xs font-semibold rounded-md border border-white/10 transition-all">
                        Concise
                      </button>
                      <button className="px-3 py-1.5 bg-[#0A0E13] hover:bg-white/5 text-white/60 text-xs font-semibold rounded-md border border-white/10 transition-all">
                        Reassuring
                      </button>
                      <button className="px-3 py-1.5 bg-[#0A0E13] hover:bg-white/5 text-white/60 text-xs font-semibold rounded-md border border-white/10 transition-all">
                        Formal
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Right Column - Sovereign Ledger */}
            <div className="space-y-6">
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                      <Shield className="w-4 h-4 text-purple-400" />
                    </div>
                    <div>
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Sovereign Ledger</h2>
                      <p className="text-xs text-white/40 mt-0.5">Immutable event chain</p>
                    </div>
                  </div>
                </div>

                <div className="p-4 space-y-2 max-h-[600px] overflow-y-auto">
                  {/* Event Entry */}
                  <div className="bg-[#0A0E13] border border-blue-500/20 rounded-lg p-3 hover:border-blue-500/40 transition-all cursor-pointer">
                    <div className="flex items-start gap-3">
                      <div className="w-6 h-6 rounded bg-blue-500/10 flex items-center justify-center flex-shrink-0">
                        <Shield className="w-3 h-3 text-blue-400" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="px-2 py-0.5 bg-blue-500/20 text-blue-400 text-[10px] font-bold rounded uppercase tracking-wider">
                            System
                          </span>
                          <span className="text-[10px] text-white/30 font-mono tabular-nums">23:38:38</span>
                        </div>
                        <p className="text-xs text-white/80 leading-relaxed">Incident closed for DSP-4</p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-[#0A0E13] border border-emerald-500/20 rounded-lg p-3 hover:border-emerald-500/40 transition-all cursor-pointer">
                    <div className="flex items-start gap-3">
                      <div className="w-6 h-6 rounded bg-emerald-500/10 flex items-center justify-center flex-shrink-0">
                        <CheckCircle className="w-3 h-3 text-emerald-400" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="px-2 py-0.5 bg-emerald-500/20 text-emerald-400 text-[10px] font-bold rounded uppercase tracking-wider">
                            Dispatch
                          </span>
                          <span className="text-[10px] text-white/30 font-mono tabular-nums">23:12:15</span>
                        </div>
                        <p className="text-xs text-white/80 leading-relaxed">Officer arrived on site</p>
                      </div>
                    </div>
                  </div>

                  <div className="bg-[#0A0E13] border border-amber-500/20 rounded-lg p-3 hover:border-amber-500/40 transition-all cursor-pointer">
                    <div className="flex items-start gap-3">
                      <div className="w-6 h-6 rounded bg-amber-500/10 flex items-center justify-center flex-shrink-0">
                        <AlertTriangle className="w-3 h-3 text-amber-400" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="px-2 py-0.5 bg-amber-500/20 text-amber-400 text-[10px] font-bold rounded uppercase tracking-wider">
                            Alert
                          </span>
                          <span className="text-[10px] text-white/30 font-mono tabular-nums">23:01:42</span>
                        </div>
                        <p className="text-xs text-white/80 leading-relaxed">Perimeter breach detected</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Refine Dialog */}
      {showRefineDialog && (
        <RefineDialog
          incidentId="INC-8932-1X"
          originalDraft={drafts[0].text}
          cues={drafts[0].cues}
          onClose={() => setShowRefineDialog(false)}
          onApprove={(text) => {
            console.log('Approved refined:', text);
            setShowRefineDialog(false);
          }}
        />
      )}
    </div>
  );
}
