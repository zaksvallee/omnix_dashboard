import React from 'react';
import { Filter, AlertTriangle, Clock, Shield, CheckCircle } from 'lucide-react';

type QueueState = 'full' | 'high-priority' | 'timing' | 'sensitive' | 'validation';

interface QueueStateChipProps {
  state: QueueState;
  count?: number;
  active?: boolean;
  onClick?: () => void;
}

export function QueueStateChip({ state, count, active = false, onClick }: QueueStateChipProps) {
  const configs = {
    'full': {
      label: 'Full Queue',
      icon: Filter,
      color: 'cyan',
      bgActive: 'bg-cyan-500/20',
      bgInactive: 'bg-[#0A0E13]',
      borderActive: 'border-cyan-500/50',
      borderInactive: 'border-[#21262D]',
      textActive: 'text-cyan-400',
      textInactive: 'text-white/60',
    },
    'high-priority': {
      label: 'High Priority',
      icon: AlertTriangle,
      color: 'red',
      bgActive: 'bg-red-500/20',
      bgInactive: 'bg-[#0A0E13]',
      borderActive: 'border-red-500/50',
      borderInactive: 'border-[#21262D]',
      textActive: 'text-red-400',
      textInactive: 'text-white/60',
    },
    'timing': {
      label: 'Timing Only',
      icon: Clock,
      color: 'amber',
      bgActive: 'bg-amber-500/20',
      bgInactive: 'bg-[#0A0E13]',
      borderActive: 'border-amber-500/50',
      borderInactive: 'border-[#21262D]',
      textActive: 'text-amber-400',
      textInactive: 'text-white/60',
    },
    'sensitive': {
      label: 'Sensitive Only',
      icon: Shield,
      color: 'purple',
      bgActive: 'bg-purple-500/20',
      bgInactive: 'bg-[#0A0E13]',
      borderActive: 'border-purple-500/50',
      borderInactive: 'border-[#21262D]',
      textActive: 'text-purple-400',
      textInactive: 'text-white/60',
    },
    'validation': {
      label: 'Validation Only',
      icon: CheckCircle,
      color: 'emerald',
      bgActive: 'bg-emerald-500/20',
      bgInactive: 'bg-[#0A0E13]',
      borderActive: 'border-emerald-500/50',
      borderInactive: 'border-[#21262D]',
      textActive: 'text-emerald-400',
      textInactive: 'text-white/60',
    },
  };

  const config = configs[state];
  const Icon = config.icon;

  return (
    <button
      onClick={onClick}
      className={`
        group flex items-center gap-2 px-3 py-1.5 rounded-lg border transition-all
        ${active ? `${config.bgActive} ${config.borderActive}` : `${config.bgInactive} ${config.borderInactive} hover:border-${config.color}-500/30`}
        ${onClick ? 'cursor-pointer' : 'cursor-default'}
      `}
    >
      <Icon className={`w-3.5 h-3.5 ${active ? config.textActive : config.textInactive}`} strokeWidth={2} />
      <span className={`text-xs font-semibold uppercase tracking-wider ${active ? config.textActive : config.textInactive}`}>
        {config.label}
      </span>
      {count !== undefined && (
        <div className={`
          ml-1 w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold
          ${active ? `bg-${config.color}-500/30 ${config.textActive}` : 'bg-white/5 text-white/40'}
        `}>
          {count}
        </div>
      )}
    </button>
  );
}
