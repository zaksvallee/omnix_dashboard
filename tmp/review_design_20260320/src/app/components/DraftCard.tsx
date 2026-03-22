import React from 'react';
import { MessageSquare, Edit2, Check, X, AlertTriangle } from 'lucide-react';
import { CueChip } from './CueChip';

interface DraftCardProps {
  incidentId: string;
  draftText: string;
  cues: Array<'timing' | 'sensitive' | 'validation' | 'detail' | 'reassurance' | 'concise' | 'next-step' | 'formal'>;
  priority?: 'high' | 'sensitive' | 'normal';
  onRefine?: () => void;
  onApprove?: () => void;
  onDismiss?: () => void;
}

export function DraftCard({ 
  incidentId, 
  draftText, 
  cues, 
  priority = 'normal',
  onRefine,
  onApprove,
  onDismiss
}: DraftCardProps) {
  const priorityConfig = {
    'high': {
      bg: 'bg-gradient-to-br from-red-950/50 to-orange-950/50',
      border: 'border-red-500/30',
      badge: 'High Priority',
      badgeBg: 'bg-red-500/20',
      badgeText: 'text-red-400',
      badgeBorder: 'border-red-500/30',
      icon: AlertTriangle,
    },
    'sensitive': {
      bg: 'bg-gradient-to-br from-purple-950/50 to-pink-950/50',
      border: 'border-purple-500/30',
      badge: 'Sensitive Reply',
      badgeBg: 'bg-purple-500/20',
      badgeText: 'text-purple-400',
      badgeBorder: 'border-purple-500/30',
      icon: AlertTriangle,
    },
    'normal': {
      bg: 'bg-[#0D1117]',
      border: 'border-[#21262D]',
      badge: null,
      badgeBg: '',
      badgeText: '',
      badgeBorder: '',
      icon: MessageSquare,
    },
  };

  const config = priorityConfig[priority];
  const Icon = config.icon;

  return (
    <div className={`
      ${config.bg} border ${config.border} rounded-xl p-5 
      hover:border-cyan-500/30 transition-all group
    `}>
      {/* Header */}
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <div className={`
            w-10 h-10 rounded-lg flex items-center justify-center border
            ${priority === 'normal' ? 'bg-cyan-500/10 border-cyan-500/30' : `${config.badgeBg} ${config.badgeBorder}`}
          `}>
            <Icon className={`w-5 h-5 ${priority === 'normal' ? 'text-cyan-400' : config.badgeText}`} strokeWidth={2} />
          </div>
          <div>
            <div className="font-mono text-sm text-white/90 font-bold">{incidentId}</div>
            <div className="text-xs text-white/40 mt-0.5">AI Draft Ready</div>
          </div>
        </div>
        {config.badge && (
          <div className={`
            px-3 py-1.5 ${config.badgeBg} ${config.badgeText} rounded-lg border ${config.badgeBorder}
            text-xs font-bold uppercase tracking-wider
          `}>
            {config.badge}
          </div>
        )}
      </div>

      {/* Draft Text */}
      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4 mb-4">
        <p className="text-sm text-white/80 leading-relaxed">{draftText}</p>
      </div>

      {/* Cues */}
      {cues.length > 0 && (
        <div className="mb-4">
          <div className="text-[10px] text-white/40 uppercase tracking-wider font-semibold mb-2">
            Review Cues
          </div>
          <div className="flex flex-wrap gap-2">
            {cues.map((cue, idx) => (
              <CueChip key={idx} type={cue} size="sm" />
            ))}
          </div>
        </div>
      )}

      {/* Actions */}
      <div className="grid grid-cols-3 gap-2">
        <button
          onClick={onDismiss}
          className="px-3 py-2 bg-[#0A0E13] hover:bg-red-500/10 text-white/60 hover:text-red-400 rounded-lg border border-[#21262D] hover:border-red-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold"
        >
          <X className="w-3.5 h-3.5" />
          Dismiss
        </button>
        <button
          onClick={onRefine}
          className="px-3 py-2 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-2 text-xs font-semibold"
        >
          <Edit2 className="w-3.5 h-3.5" />
          Refine
        </button>
        <button
          onClick={onApprove}
          className="px-3 py-2 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 rounded-lg border border-emerald-500/30 hover:border-emerald-500/50 transition-all flex items-center justify-center gap-2 text-xs font-semibold"
        >
          <Check className="w-3.5 h-3.5" />
          Approve
        </button>
      </div>
    </div>
  );
}
