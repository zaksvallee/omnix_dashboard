import React from 'react';
import { Users, AlertTriangle } from 'lucide-react';
import { motion } from 'motion/react';

interface GuardVigilance {
  id: string;
  callsign: string;
  decayLevel: number; // 0-100
  status: 'green' | 'orange' | 'red';
  lastCheckIn: string;
  sparklineData: number[]; // Last 8 check-ins
}

export function VigilancePanel() {
  const guards: GuardVigilance[] = [
    {
      id: 'G001',
      callsign: 'Echo-3',
      decayLevel: 67,
      status: 'green',
      lastCheckIn: '22:12',
      sparklineData: [45, 52, 48, 55, 62, 58, 65, 67]
    },
    {
      id: 'G002',
      callsign: 'Bravo-2',
      decayLevel: 42,
      status: 'green',
      lastCheckIn: '22:10',
      sparklineData: [35, 38, 40, 42, 38, 40, 41, 42]
    },
    {
      id: 'G003',
      callsign: 'Delta-1',
      decayLevel: 89,
      status: 'orange',
      lastCheckIn: '22:02',
      sparklineData: [60, 65, 70, 75, 78, 82, 85, 89]
    },
    {
      id: 'G004',
      callsign: 'Alpha-5',
      decayLevel: 98,
      status: 'red',
      lastCheckIn: '21:45',
      sparklineData: [70, 75, 80, 85, 88, 92, 95, 98]
    },
  ];

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'green':
        return 'bg-emerald-400';
      case 'orange':
        return 'bg-amber-400';
      case 'red':
        return 'bg-red-400';
      default:
        return 'bg-white/20';
    }
  };

  const getStatusBorder = (status: string) => {
    switch (status) {
      case 'green':
        return 'border-emerald-500/30';
      case 'orange':
        return 'border-amber-500/40';
      case 'red':
        return 'border-red-500/40 animate-pulse-glow';
      default:
        return 'border-white/10';
    }
  };

  return (
    <div className="h-full flex flex-col bg-[#0A0D14] border-l border-white/10">
      {/* Header */}
      <div className="flex-shrink-0 px-4 py-3 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4 text-cyan-400" />
            <h3 className="text-xs uppercase tracking-widest text-white/40 font-semibold">
              Guard Vigilance
            </h3>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full" />
            <span className="text-xs text-white/60">8 On Shift</span>
          </div>
        </div>
      </div>

      {/* Guards List */}
      <div className="flex-1 overflow-y-auto p-3 space-y-2">
        {guards.map((guard, index) => (
          <motion.div
            key={guard.id}
            initial={{ opacity: 0, x: 10 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: index * 0.05 }}
            className={`p-3 rounded-lg border bg-[#0F1419] ${getStatusBorder(guard.status)} ${
              guard.status === 'red' ? 'shadow-[0_0_15px_rgba(239,68,68,0.2)]' : ''
            }`}
          >
            {/* Header Row */}
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-2">
                <div className={`w-2 h-2 rounded-full ${getStatusColor(guard.status)} ${
                  guard.status === 'red' ? 'animate-pulse' : ''
                }`} />
                <span className="text-sm font-semibold text-white">{guard.callsign}</span>
              </div>
              <div className="flex items-center gap-2">
                <span className={`text-lg font-light font-mono ${
                  guard.status === 'red' ? 'text-red-400' :
                  guard.status === 'orange' ? 'text-amber-400' :
                  'text-emerald-400'
                }`}>
                  {guard.decayLevel}%
                </span>
              </div>
            </div>

            {/* Sparkline */}
            <div className="flex items-end gap-0.5 h-8 mb-2">
              {guard.sparklineData.map((value, i) => (
                <div
                  key={i}
                  className={`flex-1 rounded-t transition-all duration-300 ${
                    guard.status === 'red' ? 'bg-red-400' :
                    guard.status === 'orange' ? 'bg-amber-400' :
                    'bg-emerald-400'
                  }`}
                  style={{ height: `${value}%` }}
                />
              ))}
            </div>

            {/* Footer */}
            <div className="flex items-center justify-between text-xs">
              <span className="text-white/40">Last check-in:</span>
              <span className="text-white/70 font-mono">{guard.lastCheckIn}</span>
            </div>

            {/* Warning */}
            {guard.status === 'red' && (
              <div className="mt-2 pt-2 border-t border-red-500/30">
                <div className="flex items-center gap-2 text-xs text-red-400">
                  <AlertTriangle className="w-3 h-3" />
                  <span className="font-medium">ESCALATION REQUIRED</span>
                </div>
              </div>
            )}

            {guard.status === 'orange' && (
              <div className="mt-2 pt-2 border-t border-amber-500/30">
                <div className="flex items-center gap-2 text-xs text-amber-400">
                  <AlertTriangle className="w-3 h-3" />
                  <span className="font-medium">NUDGE SENT</span>
                </div>
              </div>
            )}
          </motion.div>
        ))}
      </div>

      {/* Footer Stats */}
      <div className="flex-shrink-0 px-4 py-3 border-t border-white/10 bg-white/[0.02]">
        <div className="grid grid-cols-3 gap-2 text-xs">
          <div className="text-center">
            <div className="w-2 h-2 bg-emerald-400 rounded-full mx-auto mb-1" />
            <span className="text-white/60">2 Green</span>
          </div>
          <div className="text-center">
            <div className="w-2 h-2 bg-amber-400 rounded-full mx-auto mb-1" />
            <span className="text-white/60">1 Orange</span>
          </div>
          <div className="text-center">
            <div className="w-2 h-2 bg-red-400 rounded-full mx-auto mb-1 animate-pulse" />
            <span className="text-white/60">1 Red</span>
          </div>
        </div>
      </div>
    </div>
  );
}
