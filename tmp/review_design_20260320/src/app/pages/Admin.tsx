import React, { useState } from 'react';
import { 
  Settings, Brain, Users, Building2, Briefcase, Shield, RotateCcw,
  CheckCircle, AlertCircle, Clock, MessageSquare, Eye, TrendingUp,
  Plus, Search, Filter, Download
} from 'lucide-react';
import { LearnedStyleCard } from '../components/LearnedStyleCard';

type TabType = 'entities' | 'system' | 'ai-comms' | 'watch';

export function Admin() {
  const [activeTab, setActiveTab] = useState<TabType>('ai-comms');
  const [resetTipStatus, setResetTipStatus] = useState<'idle' | 'busy' | 'success' | 'failure'>('idle');

  const handleResetTip = () => {
    setResetTipStatus('busy');
    setTimeout(() => {
      setResetTipStatus('success');
      setTimeout(() => setResetTipStatus('idle'), 2000);
    }, 1500);
  };

  const learnedStyles = [
    {
      pattern: 'Include ETA and officer name in dispatch notifications for transparency and reassurance',
      confidence: 94,
      usageCount: 12,
      tags: ['timing', 'reassurance', 'dispatch'],
    },
    {
      pattern: 'Use "reviewing footage" instead of "investigating" to sound less alarming',
      confidence: 89,
      usageCount: 8,
      tags: ['sensitive', 'tone', 'cctv'],
    },
    {
      pattern: 'Always mention next steps explicitly when asking client to standby',
      confidence: 91,
      usageCount: 15,
      tags: ['next-step', 'concise'],
    },
  ];

  const tabs = [
    { id: 'entities' as TabType, label: 'Entity Management', icon: Building2 },
    { id: 'ai-comms' as TabType, label: 'AI Communications', icon: Brain },
    { id: 'system' as TabType, label: 'System Controls', icon: Settings },
    { id: 'watch' as TabType, label: 'Watch & Identity', icon: Shield },
  ];

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-slate-500 via-slate-600 to-gray-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-slate-500/30">
              <Settings className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Administration</h1>
              <p className="text-sm text-white/50">System configuration, AI training, and operational controls</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <Download className="w-4 h-4" />
              Export Config
            </button>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex gap-2 border-b border-[#21262D]">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`
                  flex items-center gap-2 px-4 py-3 border-b-2 transition-all
                  ${isActive 
                    ? 'border-cyan-500 text-cyan-400' 
                    : 'border-transparent text-white/60 hover:text-white/80'
                  }
                `}
              >
                <Icon className="w-4 h-4" strokeWidth={2} />
                <span className="text-sm font-bold uppercase tracking-wider">{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* AI Communications Tab */}
        {activeTab === 'ai-comms' && (
          <div className="space-y-6">
            {/* Learned Approval Styles */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 flex items-center justify-center border border-purple-500/30">
                    <Brain className="w-5 h-5 text-purple-400" strokeWidth={2.5} />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-lg font-bold text-white uppercase tracking-wide">Learned Approval Styles</h2>
                    <p className="text-sm text-white/50 mt-0.5">AI-detected patterns from your review decisions</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="px-3 py-1.5 bg-emerald-500/10 text-emerald-400 rounded-lg border border-emerald-500/20 text-xs font-bold uppercase tracking-wider">
                      {learnedStyles.length} Active Patterns
                    </div>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-4">
                {learnedStyles.map((style, idx) => (
                  <LearnedStyleCard
                    key={idx}
                    pattern={style.pattern}
                    confidence={style.confidence}
                    usageCount={style.usageCount}
                    tags={style.tags}
                    isTop={idx === 0}
                    onPromote={idx > 0 ? () => console.log('Promote') : undefined}
                    onDemote={idx === 0 ? () => console.log('Demote') : undefined}
                    onTag={() => console.log('Tag')}
                    onView={() => console.log('View context')}
                  />
                ))}

                {/* Suggested Tags */}
                <div className="bg-gradient-to-br from-blue-950/30 to-indigo-950/30 border border-blue-500/20 rounded-xl p-5">
                  <div className="flex items-start gap-3 mb-3">
                    <TrendingUp className="w-5 h-5 text-blue-400 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <h3 className="text-sm font-bold text-blue-300 uppercase tracking-wider mb-1">
                        Suggested Tags
                      </h3>
                      <p className="text-xs text-blue-400/70 leading-relaxed mb-3">
                        AI recommends these tags based on common patterns across your approvals
                      </p>
                      <div className="flex flex-wrap gap-2">
                        {['urgency-aware', 'client-centric', 'detail-oriented', 'professional-tone'].map((tag) => (
                          <button
                            key={tag}
                            className="px-3 py-1.5 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 text-xs font-semibold rounded-md border border-blue-500/30 transition-all"
                          >
                            + {tag}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Pending AI Draft Review */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center border border-cyan-500/30">
                    <MessageSquare className="w-5 h-5 text-cyan-400" strokeWidth={2.5} />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-lg font-bold text-white uppercase tracking-wide">Pending AI Draft Review</h2>
                    <p className="text-sm text-white/50 mt-0.5">Client communications awaiting approval</p>
                  </div>
                  <button className="px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 rounded-lg border border-cyan-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                    Jump to Queue
                  </button>
                </div>
              </div>

              <div className="p-6">
                <div className="grid grid-cols-3 gap-4">
                  <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-5 hover:border-amber-500/20 transition-all">
                    <div className="flex items-start justify-between mb-3">
                      <div className="w-10 h-10 rounded-lg bg-amber-500/10 flex items-center justify-center border border-amber-500/20">
                        <Clock className="w-5 h-5 text-amber-400" />
                      </div>
                      <div className="px-2 py-1 bg-amber-500/10 text-amber-400 text-[10px] font-bold rounded uppercase">
                        Pending
                      </div>
                    </div>
                    <div className="text-3xl font-bold text-white tabular-nums mb-1">2</div>
                    <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Awaiting Review</div>
                  </div>

                  <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-5 hover:border-red-500/20 transition-all">
                    <div className="flex items-start justify-between mb-3">
                      <div className="w-10 h-10 rounded-lg bg-red-500/10 flex items-center justify-center border border-red-500/20">
                        <AlertCircle className="w-5 h-5 text-red-400" />
                      </div>
                      <div className="px-2 py-1 bg-red-500/10 text-red-400 text-[10px] font-bold rounded uppercase">
                        High Priority
                      </div>
                    </div>
                    <div className="text-3xl font-bold text-white tabular-nums mb-1">1</div>
                    <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Urgent</div>
                  </div>

                  <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-5 hover:border-emerald-500/20 transition-all">
                    <div className="flex items-start justify-between mb-3">
                      <div className="w-10 h-10 rounded-lg bg-emerald-500/10 flex items-center justify-center border border-emerald-500/20">
                        <CheckCircle className="w-5 h-5 text-emerald-400" />
                      </div>
                      <div className="px-2 py-1 bg-emerald-500/10 text-emerald-400 text-[10px] font-bold rounded uppercase">
                        Today
                      </div>
                    </div>
                    <div className="text-3xl font-bold text-white tabular-nums mb-1">8</div>
                    <div className="text-xs text-white/50 uppercase tracking-wider font-semibold">Approved</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Pinned Voice Controls */}
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500/20 to-purple-500/20 flex items-center justify-center border border-indigo-500/30">
                    <MessageSquare className="w-5 h-5 text-indigo-400" strokeWidth={2.5} />
                  </div>
                  <div>
                    <h2 className="text-lg font-bold text-white uppercase tracking-wide">Pinned Voice / ONYX Mode</h2>
                    <p className="text-sm text-white/50 mt-0.5">Default communication style across all client lanes</p>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <div className="grid grid-cols-4 gap-3">
                  <button className="px-4 py-3 bg-cyan-500/10 text-cyan-400 rounded-lg border border-cyan-500/30 text-sm font-semibold transition-all hover:bg-cyan-500/20">
                    Auto (Pinned)
                  </button>
                  <button className="px-4 py-3 bg-[#0A0E13] hover:bg-white/5 text-white/60 rounded-lg border border-[#21262D] text-sm font-semibold transition-all">
                    Concise
                  </button>
                  <button className="px-4 py-3 bg-[#0A0E13] hover:bg-white/5 text-white/60 rounded-lg border border-[#21262D] text-sm font-semibold transition-all">
                    Reassuring
                  </button>
                  <button className="px-4 py-3 bg-[#0A0E13] hover:bg-white/5 text-white/60 rounded-lg border border-[#21262D] text-sm font-semibold transition-all">
                    Formal
                  </button>
                </div>
                <p className="mt-3 text-xs text-white/40 text-center">
                  This voice profile will be used as default unless overridden per-lane
                </p>
              </div>
            </div>
          </div>
        )}

        {/* System Controls Tab */}
        {activeTab === 'system' && (
          <div className="space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl overflow-hidden">
              <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-amber-500/20 to-orange-500/20 flex items-center justify-center border border-amber-500/30">
                    <Settings className="w-5 h-5 text-amber-400" strokeWidth={2.5} />
                  </div>
                  <div>
                    <h2 className="text-lg font-bold text-white uppercase tracking-wide">System Runtime Controls</h2>
                    <p className="text-sm text-white/50 mt-0.5">Live operations and queue management</p>
                  </div>
                </div>
              </div>

              <div className="p-6 space-y-6">
                {/* Live Ops Queue Hint Reset */}
                <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-5">
                  <div className="flex items-start justify-between mb-3">
                    <div>
                      <h3 className="text-sm font-bold text-white uppercase tracking-wider mb-1">
                        Live Operations Queue Hint
                      </h3>
                      <p className="text-xs text-white/50 leading-relaxed">
                        Reset the first-run queue filtering tutorial for all operators
                      </p>
                    </div>
                  </div>

                  <button
                    onClick={handleResetTip}
                    disabled={resetTipStatus === 'busy'}
                    className={`
                      w-full px-4 py-3 rounded-lg border text-sm font-semibold uppercase tracking-wider transition-all flex items-center justify-center gap-2
                      ${resetTipStatus === 'idle' 
                        ? 'bg-[#0D1117] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 border-[#21262D] hover:border-cyan-500/30'
                        : resetTipStatus === 'busy'
                        ? 'bg-amber-500/10 text-amber-400 border-amber-500/30 cursor-wait'
                        : resetTipStatus === 'success'
                        ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                        : 'bg-red-500/10 text-red-400 border-red-500/30'
                      }
                    `}
                  >
                    {resetTipStatus === 'idle' && (
                      <>
                        <RotateCcw className="w-4 h-4" />
                        Reset Queue Hint
                      </>
                    )}
                    {resetTipStatus === 'busy' && (
                      <>
                        <Clock className="w-4 h-4 animate-spin" />
                        Resetting...
                      </>
                    )}
                    {resetTipStatus === 'success' && (
                      <>
                        <CheckCircle className="w-4 h-4" />
                        Hint Reset Successfully
                      </>
                    )}
                    {resetTipStatus === 'failure' && (
                      <>
                        <AlertCircle className="w-4 h-4" />
                        Reset Failed
                      </>
                    )}
                  </button>
                </div>

                {/* Client Comms Audit */}
                <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-5">
                  <h3 className="text-sm font-bold text-white uppercase tracking-wider mb-4">Client Communications Audit</h3>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                      <span className="text-sm text-white/80">Total messages sent (24h)</span>
                      <span className="text-sm font-bold text-white tabular-nums">23</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                      <span className="text-sm text-white/80">AI auto-approved</span>
                      <span className="text-sm font-bold text-emerald-400 tabular-nums">8 (35%)</span>
                    </div>
                    <div className="flex items-center justify-between py-2 border-b border-white/5">
                      <span className="text-sm text-white/80">Human-reviewed</span>
                      <span className="text-sm font-bold text-cyan-400 tabular-nums">15 (65%)</span>
                    </div>
                    <div className="flex items-center justify-between py-2">
                      <span className="text-sm text-white/80">Avg. review time</span>
                      <span className="text-sm font-bold text-white tabular-nums">42s</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Entity Management Tab */}
        {activeTab === 'entities' && (
          <div className="space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl p-6">
              <div className="flex items-center gap-4 mb-6">
                <Building2 className="w-8 h-8 text-cyan-400" />
                <div>
                  <h2 className="text-lg font-bold text-white uppercase tracking-wide">Entity Management</h2>
                  <p className="text-sm text-white/50">Guards, Sites, Clients CRUD operations</p>
                </div>
              </div>
              
              <div className="grid grid-cols-3 gap-4">
                <button className="p-6 bg-[#0A0E13] hover:bg-cyan-500/5 border border-[#21262D] hover:border-cyan-500/30 rounded-xl transition-all group">
                  <Users className="w-8 h-8 text-cyan-400 mb-3 group-hover:scale-110 transition-transform" />
                  <div className="text-lg font-bold text-white mb-1">Guards</div>
                  <div className="text-sm text-white/50">Manage guard roster</div>
                </button>
                <button className="p-6 bg-[#0A0E13] hover:bg-cyan-500/5 border border-[#21262D] hover:border-cyan-500/30 rounded-xl transition-all group">
                  <Building2 className="w-8 h-8 text-cyan-400 mb-3 group-hover:scale-110 transition-transform" />
                  <div className="text-lg font-bold text-white mb-1">Sites</div>
                  <div className="text-sm text-white/50">Manage site database</div>
                </button>
                <button className="p-6 bg-[#0A0E13] hover:bg-cyan-500/5 border border-[#21262D] hover:border-cyan-500/30 rounded-xl transition-all group">
                  <Briefcase className="w-8 h-8 text-cyan-400 mb-3 group-hover:scale-110 transition-transform" />
                  <div className="text-lg font-bold text-white mb-1">Clients</div>
                  <div className="text-sm text-white/50">Manage client accounts</div>
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Watch & Identity Tab */}
        {activeTab === 'watch' && (
          <div className="space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl p-6">
              <div className="flex items-center gap-4 mb-6">
                <Shield className="w-8 h-8 text-purple-400" />
                <div>
                  <h2 className="text-lg font-bold text-white uppercase tracking-wide">Watch & Identity Controls</h2>
                  <p className="text-sm text-white/50">Fleet watch health and temporary identity approvals</p>
                </div>
              </div>
              
              <div className="bg-gradient-to-br from-purple-950/30 to-pink-950/30 border border-purple-500/20 rounded-xl p-6 text-center">
                <Eye className="w-12 h-12 text-purple-400 mx-auto mb-3" />
                <h3 className="text-lg font-bold text-white mb-2">Watch Controls</h3>
                <p className="text-sm text-white/60">Fleet watch status, recovery actions, and identity policy management</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
