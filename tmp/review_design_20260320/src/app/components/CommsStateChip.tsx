import React from 'react';
import { CheckCircle, X, Clock, Phone, Bell, AlertTriangle } from 'lucide-react';

type CommsChannel = 'telegram' | 'sms' | 'voip' | 'push';
type CommsState = 'ready' | 'blocked' | 'fallback' | 'staging' | 'idle' | 'needs-review';

interface CommsStateChipProps {
  channel: CommsChannel;
  state: CommsState;
  size?: 'sm' | 'md';
}

export function CommsStateChip({ channel, state, size = 'md' }: CommsStateChipProps) {
  const channelConfigs = {
    'telegram': { label: 'Telegram', icon: CheckCircle },
    'sms': { label: 'SMS', icon: Phone },
    'voip': { label: 'VoIP', icon: Phone },
    'push': { label: 'Push', icon: Bell },
  };

  const stateConfigs = {
    'ready': {
      bg: 'bg-emerald-500/10',
      border: 'border-emerald-500/20',
      text: 'text-emerald-400',
      label: 'Ready',
    },
    'blocked': {
      bg: 'bg-red-500/10',
      border: 'border-red-500/20',
      text: 'text-red-400',
      label: 'Blocked',
    },
    'fallback': {
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/20',
      text: 'text-amber-400',
      label: 'Fallback Active',
    },
    'staging': {
      bg: 'bg-amber-500/10',
      border: 'border-amber-500/20',
      text: 'text-amber-400',
      label: 'Staging',
    },
    'idle': {
      bg: 'bg-white/5',
      border: 'border-white/10',
      text: 'text-white/40',
      label: 'Idle',
    },
    'needs-review': {
      bg: 'bg-purple-500/10',
      border: 'border-purple-500/20',
      text: 'text-purple-400',
      label: 'Needs Review',
    },
  };

  const channelConfig = channelConfigs[channel];
  const stateConfig = stateConfigs[state];
  
  const Icon = state === 'ready' ? CheckCircle : 
               state === 'blocked' ? X : 
               state === 'staging' ? Clock :
               state === 'needs-review' ? AlertTriangle :
               channelConfig.icon;

  const isSm = size === 'sm';

  return (
    <div className={`
      ${stateConfig.bg} ${stateConfig.border} rounded-md border
      flex items-center gap-1.5
      ${isSm ? 'px-2 py-1' : 'px-3 py-1.5'}
    `}>
      <Icon className={`${isSm ? 'w-3 h-3' : 'w-3.5 h-3.5'} ${stateConfig.text}`} strokeWidth={2} />
      <span className={`${isSm ? 'text-[10px]' : 'text-xs'} font-semibold ${stateConfig.text}`}>
        {channelConfig.label}
      </span>
      <span className={`${isSm ? 'text-[10px]' : 'text-xs'} font-semibold ${stateConfig.text} opacity-70`}>
        {stateConfig.label}
      </span>
    </div>
  );
}
