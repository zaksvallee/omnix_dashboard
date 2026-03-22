import React from 'react';
import { Eye, AlertTriangle, XCircle, Clock, Wifi, Camera, Shield } from 'lucide-react';

type WatchState = 'available' | 'limited' | 'unavailable';
type LimitedReason = 'stale-feed' | 'degraded-connectivity' | 'fetch-failure' | 'manual-verification';

interface WatchBadgeProps {
  state: WatchState;
  limitedReason?: LimitedReason;
  size?: 'sm' | 'md' | 'lg';
  showLabel?: boolean;
}

export function WatchBadge({ state, limitedReason, size = 'md', showLabel = true }: WatchBadgeProps) {
  const configs = {
    'available': {
      label: 'Available',
      sublabel: 'Full Coverage',
      icon: Eye,
      bg: 'bg-emerald-500/10',
      border: 'border-emerald-500/30',
      text: 'text-emerald-400',
      iconBg: 'bg-emerald-500/20',
    },
    'limited': {
      label: 'Limited',
      sublabel: getLimitedSublabel(limitedReason),
      icon: AlertTriangle,
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/30',
      text: 'text-amber-400',
      iconBg: 'bg-amber-500/20',
    },
    'unavailable': {
      label: 'Unavailable',
      sublabel: 'No Coverage',
      icon: XCircle,
      bg: 'bg-red-500/10',
      border: 'border-red-500/30',
      text: 'text-red-400',
      iconBg: 'bg-red-500/20',
    },
  };

  function getLimitedSublabel(reason?: LimitedReason): string {
    switch (reason) {
      case 'stale-feed': return 'Stale Feed';
      case 'degraded-connectivity': return 'Degraded Connection';
      case 'fetch-failure': return 'Fetch Failed';
      case 'manual-verification': return 'Manual Verification';
      default: return 'Limited Coverage';
    }
  }

  const config = configs[state];
  const Icon = config.icon;
  
  const sizeClasses = {
    sm: { wrapper: 'px-2 py-1', icon: 'w-3 h-3', text: 'text-[10px]' },
    md: { wrapper: 'px-3 py-1.5', icon: 'w-3.5 h-3.5', text: 'text-xs' },
    lg: { wrapper: 'px-4 py-2', icon: 'w-4 h-4', text: 'text-sm' },
  };

  const sizes = sizeClasses[size];

  if (!showLabel) {
    return (
      <div className={`
        ${sizes.wrapper} ${config.bg} ${config.border} rounded-md border
        flex items-center justify-center
      `}>
        <Icon className={`${sizes.icon} ${config.text}`} strokeWidth={2} />
      </div>
    );
  }

  return (
    <div className={`
      ${sizes.wrapper} ${config.bg} ${config.border} rounded-md border
      flex items-center gap-2
    `}>
      <Icon className={`${sizes.icon} ${config.text}`} strokeWidth={2} />
      <div className="flex flex-col">
        <span className={`${sizes.text} font-bold uppercase tracking-wider ${config.text}`}>
          {config.label}
        </span>
        {state === 'limited' && limitedReason && (
          <span className="text-[10px] text-amber-400/60">
            {config.sublabel}
          </span>
        )}
      </div>
    </div>
  );
}

export function LimitedReasonIcon({ reason }: { reason: LimitedReason }) {
  const icons = {
    'stale-feed': Clock,
    'degraded-connectivity': Wifi,
    'fetch-failure': XCircle,
    'manual-verification': Shield,
  };

  const Icon = icons[reason];
  return <Icon className="w-4 h-4 text-amber-400" strokeWidth={2} />;
}
