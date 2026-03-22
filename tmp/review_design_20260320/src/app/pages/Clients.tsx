import React, { useState } from 'react';
import { 
  Briefcase, MessageSquare, Shield, Clock, CheckCircle, AlertTriangle,
  X, Phone, Bell, ExternalLink, Eye, TrendingUp, Radio, Users, Building2, Hash
} from 'lucide-react';
import { CommsStateChip } from '../components/CommsStateChip';
import { PushSyncHistory } from '../components/PushSyncHistory';

interface ClientLaneState {
  id: string;
  name: string;
  code: string;
  site: string;
  roomId: string | null;
  threadId: string | null;
  telegramState: 'ready' | 'blocked';
  smsState: 'ready' | 'fallback' | 'idle';
  voipState: 'staging' | 'ready' | 'idle';
  pushState: 'idle' | 'needs-review';
  pendingDrafts: number;
  learnedStyle: string | null;
  pinnedVoice: string;
  backendProbeState: 'healthy' | 'failed' | 'idle';
  lastProbe: string;
  offScopeRouted: boolean;
}

interface IncidentMessage {
  id: string;
  incidentId: string;
  text: string;
  timestamp: string;
  state: 'delivered' | 'queued' | 'blocked' | 'draft';
  channel: 'telegram' | 'sms' | 'voip' | 'push';
}

export function Clients() {
  const [selectedLane, setSelectedLane] = useState('LANE-MS-VALLEY');
  const [showPushHistory, setShowPushHistory] = useState(false);

  const lanes: ClientLaneState[] = [
    {
      id: 'LANE-MS-VALLEY',
      name: 'Ms Valley',
      code: 'CLIENT-MS-VALLEY',
      site: 'Ms Valley Residence',
      roomId: 'ROOM-2441-MS-VALLEY',
      threadId: 'THREAD-DSP-4',
      telegramState: 'ready',
      smsState: 'idle',
      voipState: 'staging',
      pushState: 'idle',
      pendingDrafts: 2,
      learnedStyle: 'Reassuring with ETAs',
      pinnedVoice: 'Auto',
      backendProbeState: 'healthy',
      lastProbe: '5s ago',
      offScopeRouted: false,
    },
    {
      id: 'LANE-WATERFALL-EST',
      name: 'Waterfall Estate Group',
      code: 'CLIENT-WTF-GRP',
      site: 'Waterfall Estate Main',
      roomId: 'ROOM-5512-WTF-EST',
      threadId: null,
      telegramState: 'blocked',
      smsState: 'fallback',
      voipState: 'idle',
      pushState: 'needs-review',
      pendingDrafts: 0,
      learnedStyle: 'Concise and formal',
      pinnedVoice: 'Formal',
      backendProbeState: 'failed',
      lastProbe: '3m ago',
      offScopeRouted: false,
    },
    {
      id: 'LANE-BLUE-RIDGE',
      name: 'Blue Ridge Properties',
      code: 'CLIENT-BLR-PROP',
      site: 'Blue Ridge Residence',
      roomId: 'ROOM-3301-BLR',
      threadId: 'THREAD-INC-ALR-12',
      telegramState: 'ready',
      smsState: 'ready',
      voipState: 'ready',
      pushState: 'idle',
      pendingDrafts: 1,
      learnedStyle: null,
      pinnedVoice: 'Concise',
      backendProbeState: 'healthy',
      lastProbe: '2s ago',
      offScopeRouted: true,
    },
  ];

  const messages: IncidentMessage[] = [
    {
      id: 'MSG-001',
      incidentId: 'INC-DSP-4',
      text: 'Armed response officer Echo-3 has arrived on site and is conducting perimeter verification.',
      timestamp: '23:47 UTC',
      state: 'delivered',
      channel: 'telegram',
    },
    {
      id: 'MSG-002',
      incidentId: 'INC-DSP-4',
      text: 'Officer dispatched. ETA 4 minutes to your location.',
      timestamp: '23:42 UTC',
      state: 'delivered',
      channel: 'telegram',
    },
    {
      id: 'MSG-003',
      incidentId: 'INC-ALR-12',
      text: 'We detected unusual activity near your north gate camera. Reviewing footage now.',
      timestamp: '23:38 UTC',
      state: 'draft',
      channel: 'telegram',
    },
  ];

  const pushSyncEvents = [
    { id: 'PUSH-001', timestamp: '23:45 UTC', status: 'delivered' as const, deviceToken: 'APNs-f8e2...1a4c', message: 'Officer arrived on site' },
    { id: 'PUSH-002', timestamp: '23:42 UTC', status: 'delivered' as const, deviceToken: 'APNs-f8e2...1a4c', message: 'Officer dispatched' },
    { id: 'PUSH-003', timestamp: '23:38 UTC', status: 'queued' as const, deviceToken: 'APNs-f8e2...1a4c', message: 'Alarm activation detected' },
    { id: 'PUSH-004', timestamp: '23:32 UTC', status: 'failed' as const, deviceToken: 'FCM-a1b2...9z8x', message: 'System health check' },
  ];

  const selectedLaneData = lanes.find(l => l.id === selectedLane);

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-blue-500 via-blue-600 to-cyan-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-blue-500/30">
              <Briefcase className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Client Communications</h1>
              <p className="text-sm text-white/50">Lane management and client notification status</p>
            </div>
          </div>
        </div>

        {/* Client Lane Selector */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-6">
          <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-3">Active Lanes</div>
          <div className="grid grid-cols-3 gap-3">
            {lanes.map((lane) => (
              <button
                key={lane.id}
                onClick={() => setSelectedLane(lane.id)}
                className={`
                  p-4 rounded-xl border transition-all text-left
                  ${selectedLane === lane.id 
                    ? 'bg-gradient-to-br from-cyan-950/50 to-blue-950/50 border-cyan-500/30' 
                    : 'bg-[#0A0E13] border-[#21262D] hover:border-cyan-500/20'
                  }
                `}
              >
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <div className="text-sm font-bold text-white mb-0.5">{lane.name}</div>
                    <div className="text-xs text-white/50 font-mono">{lane.code}</div>
                  </div>
                  {lane.pendingDrafts > 0 && (
                    <div className="w-6 h-6 rounded-full bg-amber-500/20 border border-amber-500/30 flex items-center justify-center text-amber-400 text-xs font-bold">
                      {lane.pendingDrafts}
                    </div>
                  )}
                </div>
                <div className="text-xs text-white/40">{lane.site}</div>
                {/* Room/Thread indicator */}
                {lane.roomId && (
                  <div className="mt-2 flex items-center gap-2">
                    <div className="flex items-center gap-1 px-2 py-0.5 bg-purple-500/10 border border-purple-500/20 rounded text-[10px] text-purple-400 font-mono">
                      <Hash className="w-2.5 h-2.5" />
                      {lane.roomId}
                    </div>
                  </div>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Main Content Grid */}
        {selectedLaneData && (
          <div className="grid grid-cols-3 gap-6">
            {/* Left Column - Lane State Detail */}
            <div className="col-span-2 space-y-6">
              {/* Room/Thread Awareness */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                      <MessageSquare className="w-4 h-4 text-purple-400" />
                    </div>
                    <div>
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Room & Thread Context</h2>
                      <p className="text-xs text-white/40 mt-0.5">Active communication channels</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Room ID</div>
                      {selectedLaneData.roomId ? (
                        <div className="flex items-center gap-2 px-3 py-2 bg-purple-500/10 border border-purple-500/20 rounded-lg">
                          <Hash className="w-4 h-4 text-purple-400" />
                          <span className="text-sm font-mono text-purple-300">{selectedLaneData.roomId}</span>
                        </div>
                      ) : (
                        <div className="text-sm text-white/40 italic">No room assigned</div>
                      )}
                    </div>
                    <div>
                      <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Active Thread</div>
                      {selectedLaneData.threadId ? (
                        <div className="flex items-center gap-2 px-3 py-2 bg-cyan-500/10 border border-cyan-500/20 rounded-lg">
                          <Hash className="w-4 h-4 text-cyan-400" />
                          <span className="text-sm font-mono text-cyan-300">{selectedLaneData.threadId}</span>
                        </div>
                      ) : (
                        <div className="text-sm text-white/40 italic">No active thread</div>
                      )}
                    </div>
                  </div>

                  {selectedLaneData.threadId && (
                    <div className="bg-gradient-to-br from-cyan-950/30 to-blue-950/30 border border-cyan-500/20 rounded-lg p-4">
                      <div className="flex items-start gap-3">
                        <CheckCircle className="w-4 h-4 text-cyan-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h4 className="text-sm font-bold text-cyan-300 mb-1">Thread Active</h4>
                          <p className="text-xs text-cyan-400/70 leading-relaxed">
                            All messages are scoped to active incident thread. Client responses routed to this thread.
                          </p>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Communication Channels */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                      <Radio className="w-4 h-4 text-cyan-400" />
                    </div>
                    <div>
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Communication Channels</h2>
                      <p className="text-xs text-white/40 mt-0.5">{selectedLaneData.code}</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-6">
                  {/* Channel States */}
                  <div>
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-3">Active Channels</div>
                    <div className="flex flex-wrap gap-2">
                      <CommsStateChip 
                        channel="telegram" 
                        state={selectedLaneData.telegramState} 
                        size="md"
                      />
                      <CommsStateChip 
                        channel="sms" 
                        state={selectedLaneData.smsState} 
                        size="md"
                      />
                      <CommsStateChip 
                        channel="voip" 
                        state={selectedLaneData.voipState} 
                        size="md"
                      />
                      <CommsStateChip 
                        channel="push" 
                        state={selectedLaneData.pushState} 
                        size="md"
                      />
                    </div>
                  </div>

                  {/* Telegram Blocked State */}
                  {selectedLaneData.telegramState === 'blocked' && (
                    <div className="bg-gradient-to-br from-red-950/50 to-orange-950/50 border border-red-500/20 rounded-xl p-5">
                      <div className="flex items-start gap-3">
                        <AlertTriangle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-red-300 mb-1">Telegram Blocked</h3>
                          <p className="text-xs text-red-400/70 leading-relaxed mb-3">
                            Client has blocked the Telegram bot. SMS fallback is active for critical notifications.
                          </p>
                          <button className="w-full px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                            Contact Client Support
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* SMS Fallback Active */}
                  {selectedLaneData.smsState === 'fallback' && (
                    <div className="bg-gradient-to-br from-amber-950/50 to-orange-950/50 border border-amber-500/20 rounded-xl p-5">
                      <div className="flex items-start gap-3">
                        <Phone className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-amber-300 mb-1">SMS Fallback Active</h3>
                          <p className="text-xs text-amber-400/70 leading-relaxed">
                            Primary channel unavailable. Using SMS for all client communications.
                          </p>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* VoIP Staging */}
                  {selectedLaneData.voipState === 'staging' && (
                    <div className="bg-gradient-to-br from-amber-950/50 to-yellow-950/50 border border-amber-500/20 rounded-xl p-5">
                      <div className="flex items-start gap-3">
                        <Phone className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-amber-300 mb-1">VoIP Call Staged</h3>
                          <p className="text-xs text-amber-400/70 leading-relaxed mb-3">
                            Voice call queued for high-priority incident escalation. Ready to dial.
                          </p>
                          <div className="grid grid-cols-2 gap-2">
                            <button className="px-3 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 rounded-lg border border-amber-500/30 text-xs font-semibold transition-all">
                              Place Call Now
                            </button>
                            <button className="px-3 py-2 bg-[#0A0E13] hover:bg-white/5 text-white/60 rounded-lg border border-[#21262D] text-xs font-semibold transition-all">
                              Cancel Stage
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Push Sync Needs Review */}
                  {selectedLaneData.pushState === 'needs-review' && (
                    <div className="bg-gradient-to-br from-purple-950/50 to-pink-950/50 border border-purple-500/20 rounded-xl p-5">
                      <div className="flex items-start gap-3">
                        <Bell className="w-5 h-5 text-purple-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-purple-300 mb-1">Push Sync Needs Review</h3>
                          <p className="text-xs text-purple-400/70 leading-relaxed mb-3">
                            Push notification delivery status requires manual verification.
                          </p>
                          <button className="w-full px-3 py-2 bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 rounded-lg border border-purple-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                            Review Push History
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Backend Probe Status */}
                  <div>
                    <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-3">Backend Probe</div>
                    <div className={`
                      p-4 rounded-lg border
                      ${selectedLaneData.backendProbeState === 'healthy' ? 'bg-emerald-500/5 border-emerald-500/20' : ''}
                      ${selectedLaneData.backendProbeState === 'failed' ? 'bg-red-500/5 border-red-500/20' : ''}
                      ${selectedLaneData.backendProbeState === 'idle' ? 'bg-white/5 border-white/10' : ''}
                    `}>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          {selectedLaneData.backendProbeState === 'healthy' && <CheckCircle className="w-4 h-4 text-emerald-400" />}
                          {selectedLaneData.backendProbeState === 'failed' && <X className="w-4 h-4 text-red-400" />}
                          {selectedLaneData.backendProbeState === 'idle' && <Clock className="w-4 h-4 text-white/40" />}
                          <div>
                            <div className={`text-sm font-semibold ${
                              selectedLaneData.backendProbeState === 'healthy' ? 'text-emerald-400' :
                              selectedLaneData.backendProbeState === 'failed' ? 'text-red-400' :
                              'text-white/60'
                            }`}>
                              {selectedLaneData.backendProbeState === 'healthy' && 'Healthy'}
                              {selectedLaneData.backendProbeState === 'failed' && 'Failed'}
                              {selectedLaneData.backendProbeState === 'idle' && 'Idle'}
                            </div>
                            <div className="text-xs text-white/40">Last probe: {selectedLaneData.lastProbe}</div>
                          </div>
                        </div>
                        {selectedLaneData.backendProbeState === 'failed' && (
                          <button className="px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-md border border-red-500/30 text-xs font-semibold transition-all">
                            Retry Probe
                          </button>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Off-Scope Routed Lane */}
                  {selectedLaneData.offScopeRouted && (
                    <div className="bg-gradient-to-br from-indigo-950/50 to-purple-950/50 border border-indigo-500/20 rounded-xl p-5">
                      <div className="flex items-start gap-3">
                        <ExternalLink className="w-5 h-5 text-indigo-400 flex-shrink-0 mt-0.5" />
                        <div className="flex-1">
                          <h3 className="text-sm font-bold text-indigo-300 mb-1">Off-Scope Routed Lane</h3>
                          <p className="text-xs text-indigo-400/70 leading-relaxed">
                            This client lane is routed to an off-scope partner for dispatch handling.
                          </p>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Message History */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-blue-500/10 flex items-center justify-center">
                      <MessageSquare className="w-4 h-4 text-blue-400" />
                    </div>
                    <div>
                      <h2 className="text-sm font-bold text-white uppercase tracking-wider">Message History</h2>
                      <p className="text-xs text-white/40 mt-0.5">Recent client communications</p>
                    </div>
                  </div>
                </div>

                <div className="p-6 space-y-3">
                  {messages.map((msg) => (
                    <div key={msg.id} className={`
                      p-4 rounded-xl border
                      ${msg.state === 'delivered' ? 'bg-[#0A0E13] border-[#21262D]' : ''}
                      ${msg.state === 'draft' ? 'bg-amber-500/5 border-amber-500/20' : ''}
                      ${msg.state === 'queued' ? 'bg-cyan-500/5 border-cyan-500/20' : ''}
                      ${msg.state === 'blocked' ? 'bg-red-500/5 border-red-500/20' : ''}
                    `}>
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-mono text-white/80 font-bold">{msg.incidentId}</span>
                          <div className={`
                            px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                            ${msg.state === 'delivered' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                            ${msg.state === 'draft' ? 'bg-amber-500/20 text-amber-400' : ''}
                            ${msg.state === 'queued' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                            ${msg.state === 'blocked' ? 'bg-red-500/20 text-red-400' : ''}
                          `}>
                            {msg.state}
                          </div>
                        </div>
                        <span className="text-xs text-white/40 tabular-nums">{msg.timestamp}</span>
                      </div>
                      <p className="text-sm text-white/80 leading-relaxed">{msg.text}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Right Column - Lane Config */}
            <div className="space-y-6">
              {/* Pending Drafts */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-2">
                    <MessageSquare className="w-4 h-4 text-amber-400" />
                    <h3 className="text-xs font-bold text-white uppercase tracking-wider">Pending AI Drafts</h3>
                  </div>
                </div>
                <div className="p-5">
                  <div className="text-center">
                    <div className="text-4xl font-bold text-amber-400 tabular-nums mb-1">
                      {selectedLaneData.pendingDrafts}
                    </div>
                    <div className="text-xs text-white/50 uppercase tracking-wider font-semibold mb-3">
                      Awaiting Review
                    </div>
                    {selectedLaneData.pendingDrafts > 0 && (
                      <button className="w-full px-4 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 rounded-lg border border-amber-500/30 text-sm font-semibold uppercase tracking-wider transition-all">
                        Review Drafts
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* Learned Style */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-2">
                    <TrendingUp className="w-4 h-4 text-purple-400" />
                    <h3 className="text-xs font-bold text-white uppercase tracking-wider">Learned Style</h3>
                  </div>
                </div>
                <div className="p-5">
                  {selectedLaneData.learnedStyle ? (
                    <div className="bg-gradient-to-br from-purple-950/30 to-pink-950/30 border border-purple-500/20 rounded-lg p-4">
                      <div className="text-sm text-purple-300 leading-relaxed mb-3">
                        "{selectedLaneData.learnedStyle}"
                      </div>
                      <div className="text-xs text-purple-400/60">AI-detected from approval history</div>
                    </div>
                  ) : (
                    <div className="text-center text-sm text-white/40">
                      No learned style yet
                    </div>
                  )}
                </div>
              </div>

              {/* Pinned Voice */}
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                <div className="border-b border-[#21262D] px-5 py-3 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                  <div className="flex items-center gap-2">
                    <Shield className="w-4 h-4 text-cyan-400" />
                    <h3 className="text-xs font-bold text-white uppercase tracking-wider">Pinned Voice</h3>
                  </div>
                </div>
                <div className="p-5">
                  <div className="flex flex-col gap-2">
                    {['Auto', 'Concise', 'Reassuring', 'Formal'].map((voice) => (
                      <button
                        key={voice}
                        className={`
                          px-3 py-2 rounded-lg border text-sm font-semibold transition-all
                          ${selectedLaneData.pinnedVoice === voice
                            ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                            : 'bg-[#0A0E13] text-white/60 border-[#21262D] hover:border-cyan-500/20'
                          }
                        `}
                      >
                        {voice}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}