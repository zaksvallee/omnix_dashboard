import React from 'react';
import { Shield, Link2, Download, Share2, CheckCircle } from 'lucide-react';
import { motion } from 'motion/react';

export interface LedgerEvent {
  id: string;
  timestamp: string;
  type: 'ai-action' | 'human-action' | 'system-event' | 'escalation';
  description: string;
  details?: string;
  hash: string;
  previousHash?: string;
  verified?: boolean;
}

export interface SovereignLedgerProps {
  incidentId: string;
  events: LedgerEvent[];
  onVerifyHash?: () => void;
  onExport?: () => void;
  onShare?: () => void;
}

const getEventColor = (type: string) => {
  switch (type) {
    case 'ai-action':
      return 'text-cyan-400';
    case 'human-action':
      return 'text-emerald-400';
    case 'system-event':
      return 'text-blue-400';
    case 'escalation':
      return 'text-red-400';
    default:
      return 'text-white/60';
  }
};

const getEventLabel = (type: string) => {
  switch (type) {
    case 'ai-action':
      return 'AI';
    case 'human-action':
      return 'HUMAN';
    case 'system-event':
      return 'SYSTEM';
    case 'escalation':
      return 'ALERT';
    default:
      return 'EVENT';
  }
};

export function SovereignLedger({ incidentId, events, onVerifyHash, onExport, onShare }: SovereignLedgerProps) {
  return (
    <div className="bg-[#0F1419] border border-white/10 rounded-lg overflow-hidden shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
      {/* Header */}
      <div className="px-6 py-4 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-cyan-500/10 rounded-lg">
              <Shield className="w-5 h-5 text-cyan-400" />
            </div>
            <div>
              <h3 className="text-sm font-medium uppercase tracking-wider text-white">Sovereign Ledger</h3>
              <p className="text-xs text-white/60 mt-0.5">
                Incident <span className="font-mono">#{incidentId}</span> • Immutable Audit Trail
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {onVerifyHash && (
              <button
                onClick={onVerifyHash}
                className="px-3 py-1.5 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 text-xs font-medium rounded border border-emerald-500/20 hover:border-emerald-500/30 transition-all duration-200 flex items-center gap-1"
              >
                <CheckCircle className="w-3 h-3" />
                Verify Hash
              </button>
            )}
            {onExport && (
              <button
                onClick={onExport}
                className="p-1.5 hover:bg-white/5 rounded transition-colors text-white/60 hover:text-white"
                title="Export"
              >
                <Download className="w-4 h-4" />
              </button>
            )}
            {onShare && (
              <button
                onClick={onShare}
                className="p-1.5 hover:bg-white/5 rounded transition-colors text-white/60 hover:text-white"
                title="Share"
              >
                <Share2 className="w-4 h-4" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Event timeline */}
      <div className="p-6 space-y-1 max-h-[500px] overflow-y-auto">
        {events.map((event, index) => (
          <motion.div
            key={event.id}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: index * 0.05 }}
            className="relative group"
          >
            {/* Connecting line */}
            {index < events.length - 1 && (
              <div className="absolute left-[10px] top-10 bottom-0 w-px bg-gradient-to-b from-cyan-500/30 to-transparent" />
            )}

            <div className="relative p-4 rounded-lg hover:bg-white/[0.02] transition-colors">
              <div className="flex items-start gap-4">
                {/* Timeline dot */}
                <div className="flex-shrink-0 relative z-10">
                  <div className={`w-5 h-5 rounded-full border-2 ${
                    event.type === 'ai-action' ? 'border-cyan-500 bg-cyan-500/20' :
                    event.type === 'human-action' ? 'border-emerald-500 bg-emerald-500/20' :
                    event.type === 'escalation' ? 'border-red-500 bg-red-500/20' :
                    'border-blue-500 bg-blue-500/20'
                  } flex items-center justify-center`}>
                    <div className={`w-2 h-2 rounded-full ${
                      event.type === 'ai-action' ? 'bg-cyan-400' :
                      event.type === 'human-action' ? 'bg-emerald-400' :
                      event.type === 'escalation' ? 'bg-red-400' :
                      'bg-blue-400'
                    }`} />
                  </div>
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0">
                  {/* Timestamp and type */}
                  <div className="flex items-center gap-3 mb-1">
                    <span className="text-xs text-white/40 font-mono">{event.timestamp}</span>
                    <span className={`px-2 py-0.5 rounded text-xs font-bold ${getEventColor(event.type)}`}>
                      {getEventLabel(event.type)}
                    </span>
                  </div>

                  {/* Description */}
                  <p className="text-sm text-white/90 mb-1">{event.description}</p>

                  {/* Details */}
                  {event.details && (
                    <p className="text-xs text-white/60 mb-2">{event.details}</p>
                  )}

                  {/* Hash chain */}
                  <div className="flex items-center gap-2 mt-2 p-2 bg-black/20 rounded border border-white/5">
                    <Link2 className="w-3 h-3 text-cyan-400/60 flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-white/40">Hash:</span>
                        <code className="text-xs text-cyan-400/80 font-mono truncate">{event.hash}</code>
                        {event.verified && (
                          <CheckCircle className="w-3 h-3 text-emerald-400 flex-shrink-0" />
                        )}
                      </div>
                      {event.previousHash && (
                        <div className="flex items-center gap-2 mt-1 opacity-0 group-hover:opacity-100 transition-opacity">
                          <span className="text-xs text-white/30">→</span>
                          <code className="text-xs text-white/40 font-mono truncate">{event.previousHash}</code>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>

      {/* Footer */}
      <div className="px-6 py-4 border-t border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between text-xs">
          <span className="text-white/40">
            {events.length} events • Chain verified
          </span>
          <div className="flex gap-2">
            {onExport && (
              <button
                onClick={onExport}
                className="px-3 py-1.5 bg-white/5 hover:bg-white/10 text-white/70 hover:text-white font-medium rounded border border-white/10 hover:border-white/20 transition-all duration-200"
              >
                Export Timeline
              </button>
            )}
            {onShare && (
              <button
                onClick={onShare}
                className="px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200"
              >
                Share with Client
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
