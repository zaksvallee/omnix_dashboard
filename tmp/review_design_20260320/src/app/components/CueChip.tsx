import React from 'react';
import { Clock, Shield, CheckCircle, FileText, Heart, Zap, ArrowRight, FileCheck } from 'lucide-react';

type CueType = 'timing' | 'sensitive' | 'validation' | 'detail' | 'reassurance' | 'concise' | 'next-step' | 'formal';

interface CueChipProps {
  type: CueType;
  size?: 'sm' | 'md';
}

export function CueChip({ type, size = 'sm' }: CueChipProps) {
  const configs = {
    'timing': {
      label: 'Timing',
      icon: Clock,
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/30',
      text: 'text-amber-400',
    },
    'sensitive': {
      label: 'Sensitive',
      icon: Shield,
      bg: 'bg-purple-500/10',
      border: 'border-purple-500/30',
      text: 'text-purple-400',
    },
    'validation': {
      label: 'Validation',
      icon: CheckCircle,
      bg: 'bg-emerald-500/10',
      border: 'border-emerald-500/30',
      text: 'text-emerald-400',
    },
    'detail': {
      label: 'Detail',
      icon: FileText,
      bg: 'bg-blue-500/10',
      border: 'border-blue-500/30',
      text: 'text-blue-400',
    },
    'reassurance': {
      label: 'Reassurance',
      icon: Heart,
      bg: 'bg-pink-500/10',
      border: 'border-pink-500/30',
      text: 'text-pink-400',
    },
    'concise': {
      label: 'Concise',
      icon: Zap,
      bg: 'bg-cyan-500/10',
      border: 'border-cyan-500/30',
      text: 'text-cyan-400',
    },
    'next-step': {
      label: 'Next Step',
      icon: ArrowRight,
      bg: 'bg-indigo-500/10',
      border: 'border-indigo-500/30',
      text: 'text-indigo-400',
    },
    'formal': {
      label: 'Formal',
      icon: FileCheck,
      bg: 'bg-slate-500/10',
      border: 'border-slate-500/30',
      text: 'text-slate-400',
    },
  };

  const config = configs[type];
  const Icon = config.icon;
  const isMd = size === 'md';

  return (
    <div className={`
      inline-flex items-center gap-1.5 rounded-md border
      ${config.bg} ${config.border}
      ${isMd ? 'px-2.5 py-1.5' : 'px-2 py-1'}
    `}>
      <Icon className={`${isMd ? 'w-3.5 h-3.5' : 'w-3 h-3'} ${config.text}`} strokeWidth={2} />
      <span className={`${isMd ? 'text-xs' : 'text-[10px]'} font-semibold uppercase tracking-wider ${config.text}`}>
        {config.label}
      </span>
    </div>
  );
}
