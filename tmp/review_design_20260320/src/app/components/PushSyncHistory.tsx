import React from 'react';
import { Bell, CheckCircle, Clock, X, AlertTriangle } from 'lucide-react';

interface PushSyncEvent {
  id: string;
  timestamp: string;
  status: 'delivered' | 'queued' | 'failed' | 'pending';
  deviceToken: string;
  message: string;
}

interface PushSyncHistoryProps {
  events: PushSyncEvent[];
}

export function PushSyncHistory({ events }: PushSyncHistoryProps) {
  return (
    <div className="space-y-2">
      {events.map((event) => (
        <div
          key={event.id}
          className={`
            p-3 rounded-lg border
            ${event.status === 'delivered' ? 'bg-emerald-500/5 border-emerald-500/20' : ''}
            ${event.status === 'queued' ? 'bg-cyan-500/5 border-cyan-500/20' : ''}
            ${event.status === 'failed' ? 'bg-red-500/5 border-red-500/20' : ''}
            ${event.status === 'pending' ? 'bg-amber-500/5 border-amber-500/20' : ''}
          `}
        >
          <div className="flex items-start justify-between mb-2">
            <div className="flex items-center gap-2">
              {event.status === 'delivered' && <CheckCircle className="w-3.5 h-3.5 text-emerald-400" strokeWidth={2} />}
              {event.status === 'queued' && <Clock className="w-3.5 h-3.5 text-cyan-400" strokeWidth={2} />}
              {event.status === 'failed' && <X className="w-3.5 h-3.5 text-red-400" strokeWidth={2} />}
              {event.status === 'pending' && <AlertTriangle className="w-3.5 h-3.5 text-amber-400" strokeWidth={2} />}
              <div className={`
                px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                ${event.status === 'delivered' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                ${event.status === 'queued' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                ${event.status === 'failed' ? 'bg-red-500/20 text-red-400' : ''}
                ${event.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : ''}
              `}>
                {event.status}
              </div>
            </div>
            <span className="text-xs text-white/40 tabular-nums">{event.timestamp}</span>
          </div>
          <p className="text-xs text-white/70 mb-1">{event.message}</p>
          <div className="text-[10px] text-white/40 font-mono">Token: {event.deviceToken}</div>
        </div>
      ))}
    </div>
  );
}
