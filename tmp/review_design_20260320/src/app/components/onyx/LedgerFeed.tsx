import React from 'react';
import { Shield, Zap, User, AlertCircle, Link2 } from 'lucide-react';
import { motion } from 'motion/react';

export interface LedgerEntry {
  id: string;
  timestamp: string;
  type: 'AI_ACTION' | 'HUMAN_OVERRIDE' | 'SYSTEM_EVENT' | 'ESCALATION';
  description: string;
  actor?: string;
  reasonCode?: string;
  hash: string;
  verified: boolean;
}

export interface LedgerFeedProps {
  entries: LedgerEntry[];
  onVerifyChain?: () => void;
}

const getEntryConfig = (type: string) => {
  switch (type) {
    case 'AI_ACTION':
      return {
        icon: Zap,
        color: 'text-cyan-400',
        bgColor: 'bg-cyan-500/10',
        borderColor: 'border-cyan-500/30'
      };
    case 'HUMAN_OVERRIDE':
      return {
        icon: User,
        color: 'text-emerald-400',
        bgColor: 'bg-emerald-500/10',
        borderColor: 'border-emerald-500/30'
      };
    case 'ESCALATION':
      return {
        icon: AlertCircle,
        color: 'text-red-400',
        bgColor: 'bg-red-500/10',
        borderColor: 'border-red-500/30'
      };
    default:
      return {
        icon: Shield,
        color: 'text-blue-400',
        bgColor: 'bg-blue-500/10',
        borderColor: 'border-blue-500/30'
      };
  }
};

export function LedgerFeed({ entries, onVerifyChain }: LedgerFeedProps) {
  return (
    <div className="h-full flex flex-col bg-[#0A0D14] border-t border-white/10">
      {/* Header */}
      <div className="flex-shrink-0 px-4 py-3 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Shield className="w-4 h-4 text-cyan-400" />
            <h3 className="text-xs uppercase tracking-widest text-white/40 font-semibold">
              Sovereign Ledger
            </h3>
            <div className="px-2 py-0.5 bg-emerald-500/20 text-emerald-400 rounded text-xs font-medium border border-emerald-500/30">
              VERIFIED
            </div>
          </div>
          {onVerifyChain && (
            <button
              onClick={onVerifyChain}
              className="px-3 py-1 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200"
            >
              Verify Chain
            </button>
          )}
        </div>
      </div>

      {/* Feed */}
      <div className="flex-1 overflow-y-auto p-3">
        <div className="space-y-2">
          {entries.map((entry, index) => {
            const config = getEntryConfig(entry.type);
            const Icon = config.icon;

            return (
              <motion.div
                key={entry.id}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.03 }}
                className="group"
              >
                <div className="p-3 rounded-lg bg-[#0F1419] border border-white/10 hover:border-white/20 transition-all duration-200">
                  {/* Header */}
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <div className={`p-1.5 rounded ${config.bgColor}`}>
                        <Icon className={`w-3 h-3 ${config.color}`} />
                      </div>
                      <span className={`text-xs font-bold ${config.color}`}>
                        {entry.type.replace(/_/g, ' ')}
                      </span>
                    </div>
                    <span className="text-xs text-white/40 font-mono">{entry.timestamp}</span>
                  </div>

                  {/* Description */}
                  <p className="text-sm text-white/90 mb-2">{entry.description}</p>

                  {/* Metadata */}
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3 text-xs text-white/60">
                      {entry.actor && (
                        <span>
                          Actor: <span className="text-white/80">{entry.actor}</span>
                        </span>
                      )}
                      {entry.reasonCode && (
                        <span className={`px-2 py-0.5 rounded ${config.bgColor} ${config.color}`}>
                          {entry.reasonCode}
                        </span>
                      )}
                    </div>
                    {entry.verified && (
                      <div className="opacity-0 group-hover:opacity-100 transition-opacity flex items-center gap-1 text-xs text-emerald-400">
                        <Link2 className="w-3 h-3" />
                        <code className="font-mono">{entry.hash}</code>
                      </div>
                    )}
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>

      {/* Footer Stats */}
      <div className="flex-shrink-0 px-4 py-3 border-t border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between text-xs">
          <span className="text-white/40">{entries.length} events recorded</span>
          <div className="flex items-center gap-2 text-emerald-400">
            <Shield className="w-3 h-3" />
            <span>Chain intact</span>
          </div>
        </div>
      </div>
    </div>
  );
}
