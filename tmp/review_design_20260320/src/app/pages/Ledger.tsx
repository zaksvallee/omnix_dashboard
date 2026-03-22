import React, { useState } from 'react';
import { 
  Database, Shield, CheckCircle, AlertTriangle, XCircle, Hash, Clock,
  Eye, ChevronRight, ExternalLink, FileText, Activity, Lock, Link
} from 'lucide-react';

interface LedgerEntry {
  id: string;
  blockHeight: number;
  timestamp: string;
  eventId: string;
  eventType: string;
  hash: string;
  previousHash: string;
  verificationState: 'verified' | 'pending' | 'compromised';
  linkedIncident?: string;
  linkedEvidence?: string[];
}

export function Ledger() {
  const [selectedEntry, setSelectedEntry] = useState<string | null>('BLOCK-2441');
  const [viewMode, setViewMode] = useState<'chain' | 'incident-focused'>('chain');
  const [focusedIncident, setFocusedIncident] = useState<string | null>(null);

  const entries: LedgerEntry[] = [
    {
      id: 'BLOCK-2441',
      blockHeight: 2441,
      timestamp: '2024-03-18 23:47:14 UTC',
      eventId: 'EVT-2441',
      eventType: 'DISPATCH_OFFICER_ARRIVED',
      hash: 'a7f3e9d2c1b4f8a6',
      previousHash: '8e2f4a9d1c6b7e3f',
      verificationState: 'verified',
      linkedIncident: 'INC-DSP-4',
      linkedEvidence: ['EVD-CCTV-2441', 'EVD-GPS-2441'],
    },
    {
      id: 'BLOCK-2440',
      blockHeight: 2440,
      timestamp: '2024-03-18 23:45:22 UTC',
      eventId: 'EVT-2442',
      eventType: 'WATCH_STATE_CHANGED',
      hash: '8e2f4a9d1c6b7e3f',
      previousHash: '3d9a7e2f4c1b8e6a',
      verificationState: 'verified',
      linkedEvidence: ['EVD-CAM-WF-02'],
    },
    {
      id: 'BLOCK-2439',
      blockHeight: 2439,
      timestamp: '2024-03-18 23:42:08 UTC',
      eventId: 'EVT-2443',
      eventType: 'CLIENT_NOTIFIED',
      hash: '3d9a7e2f4c1b8e6a',
      previousHash: '1f6c8a4e9d2b7e3a',
      verificationState: 'verified',
      linkedIncident: 'INC-DSP-4',
      linkedEvidence: ['EVD-MSG-001'],
    },
    {
      id: 'BLOCK-2438',
      blockHeight: 2438,
      timestamp: '2024-03-18 23:38:45 UTC',
      eventId: 'EVT-2444',
      eventType: 'ALARM_TRIGGERED',
      hash: '1f6c8a4e9d2b7e3a',
      previousHash: '7b3e9f1a4d8c2e6f',
      verificationState: 'verified',
      linkedIncident: 'INC-DSP-4',
      linkedEvidence: ['EVD-ALARM-SE-01-NG-04', 'EVD-CCTV-2438'],
    },
    {
      id: 'BLOCK-2437',
      blockHeight: 2437,
      timestamp: '2024-03-18 23:32:12 UTC',
      eventId: 'EVT-2445',
      eventType: 'OB_ENTRY_CREATED',
      hash: '7b3e9f1a4d8c2e6f',
      previousHash: '9e4a2f7c1d6b8e3a',
      verificationState: 'pending',
      linkedEvidence: ['EVD-OB-G2441-2437'],
    },
  ];

  const filteredEntries = viewMode === 'incident-focused' && focusedIncident
    ? entries.filter(e => e.linkedIncident === focusedIncident)
    : entries;

  const selectedEntryData = entries.find(e => e.id === selectedEntry);
  const verifiedCount = entries.filter(e => e.verificationState === 'verified').length;
  const pendingCount = entries.filter(e => e.verificationState === 'pending').length;
  const compromisedCount = entries.filter(e => e.verificationState === 'compromised').length;

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-emerald-500 via-teal-600 to-cyan-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-emerald-500/30">
              <Database className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Sovereign Ledger</h1>
              <p className="text-sm text-white/50">Immutable event chain, provenance tracking, and integrity verification</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Events
            </button>
          </div>
        </div>

        {/* Integrity Summary + View Mode */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Chain Integrity:</div>
              <div className="flex items-center gap-2 px-3 py-2 bg-emerald-500/10 border border-emerald-500/20 rounded-lg">
                <CheckCircle className="w-4 h-4 text-emerald-400" />
                <span className="text-sm font-bold text-emerald-400">{verifiedCount} Verified</span>
              </div>
              {pendingCount > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 bg-amber-500/10 border border-amber-500/20 rounded-lg">
                  <Clock className="w-4 h-4 text-amber-400" />
                  <span className="text-sm font-bold text-amber-400">{pendingCount} Pending</span>
                </div>
              )}
              {compromisedCount > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 bg-red-500/10 border border-red-500/20 rounded-lg">
                  <XCircle className="w-4 h-4 text-red-400" />
                  <span className="text-sm font-bold text-red-400">{compromisedCount} Compromised</span>
                </div>
              )}
            </div>

            {/* View Mode Toggle */}
            <div className="flex items-center gap-2">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">View Mode:</div>
              <button
                onClick={() => { setViewMode('chain'); setFocusedIncident(null); }}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  viewMode === 'chain'
                    ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Full Chain
              </button>
              <button
                onClick={() => { setViewMode('incident-focused'); setFocusedIncident('INC-DSP-4'); }}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  viewMode === 'incident-focused'
                    ? 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Incident: INC-DSP-4
              </button>
            </div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Ledger Timeline */}
          <div className="col-span-1 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                    <Database className="w-4 h-4 text-emerald-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Ledger Chain</h2>
                    <p className="text-xs text-white/40 mt-0.5">{filteredEntries.length} blocks</p>
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2 max-h-[800px] overflow-y-auto">
                {filteredEntries.map((entry, idx) => (
                  <div key={entry.id}>
                    <button
                      onClick={() => setSelectedEntry(entry.id)}
                      className={`
                        w-full p-4 rounded-xl border transition-all text-left
                        ${selectedEntry === entry.id
                          ? 'bg-gradient-to-br from-emerald-950/50 to-teal-950/50 border-emerald-500/30'
                          : 'bg-[#0A0E13] border-[#21262D] hover:border-emerald-500/20'
                        }
                      `}
                    >
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <Lock className="w-3.5 h-3.5 text-emerald-400" />
                          <span className="text-xs font-mono text-white/80">Block {entry.blockHeight}</span>
                        </div>
                        {entry.verificationState === 'verified' && <CheckCircle className="w-3.5 h-3.5 text-emerald-400" />}
                        {entry.verificationState === 'pending' && <Clock className="w-3.5 h-3.5 text-amber-400" />}
                        {entry.verificationState === 'compromised' && <XCircle className="w-3.5 h-3.5 text-red-400" />}
                      </div>
                      <div className="text-sm font-bold text-white mb-1">{entry.eventType.replace(/_/g, ' ')}</div>
                      <div className="text-xs text-white/50 mb-2">{entry.timestamp}</div>
                      <div className="text-xs text-white/40 font-mono truncate">{entry.hash}</div>
                    </button>

                    {/* Chain Link Indicator */}
                    {idx < filteredEntries.length - 1 && (
                      <div className="flex justify-center py-1">
                        <Link className="w-3 h-3 text-emerald-500/30" />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column - Block Detail */}
          <div className="col-span-2 space-y-6">
            {selectedEntryData ? (
              <>
                {/* Block Header */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center">
                          <Lock className="w-6 h-6 text-white" />
                        </div>
                        <div>
                          <h2 className="text-lg font-bold text-white">Block {selectedEntryData.blockHeight}</h2>
                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-sm text-white/50 font-mono">{selectedEntryData.id}</span>
                            <div className={`
                              px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                              ${selectedEntryData.verificationState === 'verified' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                              ${selectedEntryData.verificationState === 'pending' ? 'bg-amber-500/20 text-amber-400' : ''}
                              ${selectedEntryData.verificationState === 'compromised' ? 'bg-red-500/20 text-red-400' : ''}
                            `}>
                              {selectedEntryData.verificationState}
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Timestamp</div>
                        <div className="text-sm text-white font-mono">{selectedEntryData.timestamp}</div>
                      </div>
                      <div>
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Event</div>
                        <div className="text-sm text-white">{selectedEntryData.eventType.replace(/_/g, ' ')}</div>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-2 gap-4">
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Event ID</div>
                        <div className="text-sm font-mono text-white">{selectedEntryData.eventId}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Block Height</div>
                        <div className="text-sm font-mono text-white">{selectedEntryData.blockHeight}</div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Provenance & Hash Chain */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                        <Hash className="w-4 h-4 text-cyan-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Provenance Chain</h2>
                        <p className="text-xs text-white/40 mt-0.5">Cryptographic hash verification</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 space-y-4">
                    <div>
                      <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Current Block Hash</div>
                      <div className="bg-[#0A0E13] border border-emerald-500/20 rounded-lg p-3">
                        <div className="text-sm font-mono text-emerald-400">{selectedEntryData.hash}</div>
                      </div>
                    </div>

                    <div className="flex justify-center">
                      <Link className="w-5 h-5 text-emerald-500/50" />
                    </div>

                    <div>
                      <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Previous Block Hash</div>
                      <div className="bg-[#0A0E13] border border-cyan-500/20 rounded-lg p-3">
                        <div className="text-sm font-mono text-cyan-400">{selectedEntryData.previousHash}</div>
                      </div>
                    </div>

                    {/* Verification State Detail */}
                    {selectedEntryData.verificationState === 'verified' && (
                      <div className="bg-gradient-to-br from-emerald-950/30 to-teal-950/30 border border-emerald-500/20 rounded-xl p-4">
                        <div className="flex items-start gap-3">
                          <CheckCircle className="w-5 h-5 text-emerald-400 flex-shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-sm font-bold text-emerald-300 mb-1">Chain Integrity Verified</h4>
                            <p className="text-xs text-emerald-400/70 leading-relaxed">
                              Block hash matches expected value. Previous block link confirmed. No tampering detected.
                            </p>
                          </div>
                        </div>
                      </div>
                    )}

                    {selectedEntryData.verificationState === 'pending' && (
                      <div className="bg-gradient-to-br from-amber-950/30 to-orange-950/30 border border-amber-500/20 rounded-xl p-4">
                        <div className="flex items-start gap-3">
                          <Clock className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-sm font-bold text-amber-300 mb-1">Verification Pending</h4>
                            <p className="text-xs text-amber-400/70 leading-relaxed mb-3">
                              Block awaiting cryptographic verification. Consensus not yet achieved.
                            </p>
                            <button className="w-full px-3 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 rounded-lg border border-amber-500/30 text-xs font-semibold uppercase tracking-wider transition-all">
                              Verify Now
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                {/* Evidence Chain Links */}
                {selectedEntryData.linkedEvidence && selectedEntryData.linkedEvidence.length > 0 && (
                  <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                    <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                          <Shield className="w-4 h-4 text-purple-400" />
                        </div>
                        <div>
                          <h2 className="text-sm font-bold text-white uppercase tracking-wider">Evidence Chain</h2>
                          <p className="text-xs text-white/40 mt-0.5">{selectedEntryData.linkedEvidence.length} linked evidence items</p>
                        </div>
                      </div>
                    </div>

                    <div className="p-6 space-y-2">
                      {selectedEntryData.linkedEvidence.map((evidence, idx) => (
                        <div
                          key={idx}
                          className="p-3 bg-[#0A0E13] border border-purple-500/20 rounded-lg flex items-center justify-between hover:border-purple-500/40 transition-all"
                        >
                          <div className="flex items-center gap-3">
                            <Shield className="w-4 h-4 text-purple-400" />
                            <div className="text-sm font-mono text-white">{evidence}</div>
                          </div>
                          <button className="px-2 py-1 bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 rounded border border-purple-500/30 text-xs font-semibold transition-all flex items-center gap-1.5">
                            <Eye className="w-3 h-3" />
                            View
                          </button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Drilldown Actions */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                        <ExternalLink className="w-4 h-4 text-indigo-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Navigate</h2>
                        <p className="text-xs text-white/40 mt-0.5">View related systems</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 grid grid-cols-2 gap-3">
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-violet-500/10 text-white/80 hover:text-violet-400 rounded-lg border border-[#21262D] hover:border-violet-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <span>View Event</span>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                    {selectedEntryData.linkedIncident && (
                      <button className="px-4 py-3 bg-[#0A0E13] hover:bg-red-500/10 text-white/80 hover:text-red-400 rounded-lg border border-[#21262D] hover:border-red-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                        <span>View Incident</span>
                        <ChevronRight className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-12 text-center">
                <Database className="w-16 h-16 text-white/20 mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-2">Select a Block</h3>
                <p className="text-sm text-white/60">Choose a block from the ledger to view provenance details</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
