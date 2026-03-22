import React from 'react';
import { Eye, AlertTriangle, XCircle, CheckCircle } from 'lucide-react';

interface FleetSummaryChipProps {
  type: 'available' | 'limited' | 'unavailable' | 'total';
  count: number;
  onClick?: () => void;
}

export function FleetSummaryChip({ type, count, onClick }: FleetSummaryChipProps) {
  const configs = {
    'total': {
      label: 'Total Sites',
      icon: Eye,
      bg: 'bg-cyan-500/10',
      border: 'border-cyan-500/20',
      text: 'text-cyan-400',
      hoverBorder: 'hover:border-cyan-500/40',
    },
    'available': {
      label: 'Available',
      icon: CheckCircle,
      bg: 'bg-emerald-500/10',
      border: 'border-emerald-500/20',
      text: 'text-emerald-400',
      hoverBorder: 'hover:border-emerald-500/40',
    },
    'limited': {
      label: 'Limited',
      icon: AlertTriangle,
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/20',
      text: 'text-amber-400',
      hoverBorder: 'hover:border-amber-500/40',
    },
    'unavailable': {
      label: 'Unavailable',
      icon: XCircle,
      bg: 'bg-red-500/10',
      border: 'border-red-500/20',
      text: 'text-red-400',
      hoverBorder: 'hover:border-red-500/40',
    },
  };

  const config = configs[type];
  const Icon = config.icon;

  return (
    <button
      onClick={onClick}
      className={`
        ${config.bg} ${config.border} ${onClick ? config.hoverBorder : ''}
        px-3 py-2 rounded-lg border transition-all
        flex items-center gap-3
        ${onClick ? 'cursor-pointer' : 'cursor-default'}
      `}
    >
      <div className="flex items-center gap-2">
        <Icon className={`w-4 h-4 ${config.text}`} strokeWidth={2} />
        <span className={`text-xs font-bold uppercase tracking-wider ${config.text}`}>
          {config.label}
        </span>
      </div>
      <div className={`
        ml-auto px-2 py-0.5 rounded-md bg-white/5
        text-sm font-bold ${config.text} tabular-nums
      `}>
        {count}
      </div>
    </button>
  );
}
