import React, { useState, useEffect } from 'react';
import { User, MapPin, Clock, AlertCircle, Phone, Bell, ChevronRight } from 'lucide-react';
import { motion } from 'motion/react';

export interface Guard {
  id: string;
  name: string;
  site: string;
  lastSync: number; // minutes ago
  nextExpected: number; // minutes
  gpsStatus: 'ok' | 'drift' | 'offline';
  vigilanceLevel: number; // 1-5
  nudgeSent?: boolean;
  nudgeTime?: number; // minutes ago
}

export interface GuardVigilanceProps {
  guards: Guard[];
  onNudge?: (guardId: string) => void;
  onCall?: (guardId: string) => void;
  onEscalate?: (guardId: string) => void;
  onBroadcast?: () => void;
}

function getVigilanceColor(level: number) {
  if (level >= 4) return 'text-emerald-400';
  if (level >= 3) return 'text-yellow-400';
  return 'text-red-400';
}

function getGpsStatus(status: string) {
  switch (status) {
    case 'ok':
      return { icon: '✓', text: 'GPS OK', color: 'text-emerald-400' };
    case 'drift':
      return { icon: '⚠', text: 'GPS DRIFT', color: 'text-red-400' };
    case 'offline':
      return { icon: '●', text: 'OFFLINE', color: 'text-red-400' };
    default:
      return { icon: '?', text: 'UNKNOWN', color: 'text-white/40' };
  }
}

function GuardCard({ guard, onNudge, onCall, onEscalate }: {
  guard: Guard;
  onNudge?: (id: string) => void;
  onCall?: (id: string) => void;
  onEscalate?: (id: string) => void;
}) {
  const isOverdue = guard.lastSync > 15;
  const gpsInfo = getGpsStatus(guard.gpsStatus);
  const progress = Math.max(0, Math.min(100, (guard.lastSync / 20) * 100));

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className={`p-4 rounded-lg border transition-all duration-200 ${
        isOverdue
          ? 'bg-amber-500/5 border-amber-500/30 animate-pulse-glow shadow-[0_0_20px_rgba(245,158,11,0.2)]'
          : 'bg-[#0F1419] border-white/10 hover:border-white/20'
      }`}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-white/5 rounded-full flex items-center justify-center">
            <User className="w-5 h-5 text-white/60" />
          </div>
          <div>
            <h4 className="text-sm font-medium text-white">{guard.name}</h4>
            <div className="flex items-center gap-2 text-xs text-white/60">
              <MapPin className="w-3 h-3" />
              {guard.site}
            </div>
          </div>
        </div>

        {/* Vigilance dots */}
        <div className="flex gap-1">
          {[1, 2, 3, 4, 5].map(level => (
            <div
              key={level}
              className={`w-1.5 h-1.5 rounded-full ${
                level <= guard.vigilanceLevel
                  ? guard.vigilanceLevel >= 4
                    ? 'bg-emerald-400'
                    : guard.vigilanceLevel >= 3
                    ? 'bg-yellow-400'
                    : 'bg-red-400'
                  : 'bg-white/10'
              }`}
            />
          ))}
        </div>
      </div>

      {/* Status info */}
      <div className="space-y-2 mb-3">
        <div className="flex items-center justify-between text-xs">
          <span className="text-white/60">Last Sync:</span>
          <span className={isOverdue ? 'text-amber-400 font-medium' : 'text-white/70'}>
            {guard.lastSync}m ago {isOverdue && '← OVERDUE'}
          </span>
        </div>

        {/* Progress bar */}
        <div className="relative h-1.5 bg-white/10 rounded-full overflow-hidden">
          <motion.div
            className={`absolute inset-y-0 left-0 rounded-full ${
              progress < 50
                ? 'bg-emerald-400'
                : progress < 75
                ? 'bg-yellow-400'
                : 'bg-red-400'
            }`}
            initial={{ width: 0 }}
            animate={{ width: `${progress}%` }}
            transition={{ duration: 0.5 }}
          />
        </div>

        <div className="flex items-center justify-between text-xs">
          <span className="text-white/60">Next Expected:</span>
          <span className="text-white/70">{guard.nextExpected}m</span>
        </div>

        {/* GPS Status */}
        <div className="flex items-center justify-between">
          <span className={`text-xs font-medium ${gpsInfo.color}`}>
            {gpsInfo.icon} {gpsInfo.text}
          </span>
        </div>
      </div>

      {/* Nudge notification */}
      {guard.nudgeSent && (
        <div className="mb-3 p-2 bg-amber-500/10 border border-amber-500/20 rounded flex items-center gap-2">
          <Bell className="w-3 h-3 text-amber-400" />
          <span className="text-xs text-amber-400">
            Nudge sent {guard.nudgeTime}m ago • No response
          </span>
        </div>
      )}

      {/* Actions */}
      <div className="flex gap-2">
        {!guard.nudgeSent && onNudge && (
          <button
            onClick={() => onNudge(guard.id)}
            className="flex-1 px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200"
          >
            Nudge Now
          </button>
        )}
        {onCall && (
          <button
            onClick={() => onCall(guard.id)}
            className="flex-1 px-3 py-1.5 bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium rounded border border-white/10 hover:border-white/20 transition-all duration-200 flex items-center justify-center gap-1"
          >
            <Phone className="w-3 h-3" />
            Call
          </button>
        )}
        {isOverdue && onEscalate && (
          <button
            onClick={() => onEscalate(guard.id)}
            className="flex-1 px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-medium rounded border border-red-500/20 hover:border-red-500/30 transition-all duration-200"
          >
            Escalate
          </button>
        )}
      </div>
    </motion.div>
  );
}

export function GuardVigilance({ guards, onNudge, onCall, onEscalate, onBroadcast }: GuardVigilanceProps) {
  const onDutyCount = guards.length;
  const overdueCount = guards.filter(g => g.lastSync > 15).length;

  return (
    <div className="bg-[#0F1419] border border-white/10 rounded-lg overflow-hidden shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
      {/* Header */}
      <div className="px-6 py-4 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-medium uppercase tracking-wider text-white">Active Guards</h3>
            <p className="text-xs text-white/60 mt-1">
              {onDutyCount} On-Duty
              {overdueCount > 0 && (
                <span className="text-amber-400 ml-2">• {overdueCount} Overdue</span>
              )}
            </p>
          </div>
          {onBroadcast && (
            <button
              onClick={onBroadcast}
              className="px-4 py-2 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200 flex items-center gap-2"
            >
              <Bell className="w-4 h-4" />
              Broadcast
            </button>
          )}
        </div>
      </div>

      {/* Guard list */}
      <div className="p-6 space-y-3 max-h-[600px] overflow-y-auto">
        {guards.length > 0 ? (
          guards
            .sort((a, b) => b.lastSync - a.lastSync) // Overdue first
            .map(guard => (
              <GuardCard
                key={guard.id}
                guard={guard}
                onNudge={onNudge}
                onCall={onCall}
                onEscalate={onEscalate}
              />
            ))
        ) : (
          <div className="py-12 text-center">
            <User className="w-12 h-12 text-white/20 mx-auto mb-3" />
            <p className="text-sm text-white/40">No guards on duty</p>
          </div>
        )}
      </div>
    </div>
  );
}
