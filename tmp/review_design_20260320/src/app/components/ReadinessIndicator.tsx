import React from 'react';
import { CheckCircle, AlertTriangle, XCircle } from 'lucide-react';

interface ReadinessIndicatorProps {
  label: string;
  state: 'ready' | 'degraded' | 'offline';
  details?: string;
}

export function ReadinessIndicator({ label, state, details }: ReadinessIndicatorProps) {
  const configs = {
    'ready': {
      icon: CheckCircle,
      bg: 'bg-emerald-500/10',
      border: 'border-emerald-500/20',
      text: 'text-emerald-400',
      iconColor: 'text-emerald-400',
      stateLabel: 'Ready',
    },
    'degraded': {
      icon: AlertTriangle,
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/20',
      text: 'text-amber-400',
      iconColor: 'text-amber-400',
      stateLabel: 'Degraded',
    },
    'offline': {
      icon: XCircle,
      bg: 'bg-red-500/10',
      border: 'border-red-500/20',
      text: 'text-red-400',
      iconColor: 'text-red-400',
      stateLabel: 'Offline',
    },
  };

  const config = configs[state];
  const Icon = config.icon;

  return (
    <div className={`${config.bg} ${config.border} rounded-lg border p-4`}>
      <div className="flex items-center justify-between mb-2">
        <span className="text-xs text-white/40 uppercase tracking-wider font-semibold">{label}</span>
        <Icon className={`w-4 h-4 ${config.iconColor}`} strokeWidth={2} />
      </div>
      <div className={`text-sm font-bold ${config.text} mb-0.5`}>{config.stateLabel}</div>
      {details && <div className="text-xs text-white/40">{details}</div>}
    </div>
  );
}
