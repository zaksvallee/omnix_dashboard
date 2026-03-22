import React from 'react';
import { AlertTriangle, Clock, Shield, Flame } from 'lucide-react';
import { motion } from 'motion/react';

export interface Incident {
  id: string;
  priority: 'P1-CRITICAL' | 'P2-HIGH' | 'P3-MEDIUM' | 'P4-LOW';
  type: string;
  site: string;
  timestamp: string;
  status: 'TRIAGING' | 'DISPATCHED' | 'INVESTIGATING' | 'RESOLVED';
  isActive?: boolean;
}

export interface IncidentQueueProps {
  incidents: Incident[];
  activeIncidentId?: string;
  onSelectIncident: (id: string) => void;
}

const getPriorityConfig = (priority: string) => {
  switch (priority) {
    case 'P1-CRITICAL':
      return { 
        color: 'border-red-500/40 bg-red-500/5 hover:bg-red-500/10', 
        textColor: 'text-red-400',
        icon: Flame,
        glow: 'shadow-[0_0_20px_rgba(239,68,68,0.3)]'
      };
    case 'P2-HIGH':
      return { 
        color: 'border-amber-500/40 bg-amber-500/5 hover:bg-amber-500/10', 
        textColor: 'text-amber-400',
        icon: AlertTriangle,
        glow: ''
      };
    case 'P3-MEDIUM':
      return { 
        color: 'border-yellow-500/30 bg-yellow-500/5 hover:bg-yellow-500/10', 
        textColor: 'text-yellow-400',
        icon: Clock,
        glow: ''
      };
    default:
      return { 
        color: 'border-blue-500/30 bg-blue-500/5 hover:bg-blue-500/10', 
        textColor: 'text-blue-400',
        icon: Shield,
        glow: ''
      };
  }
};

export function IncidentQueue({ incidents, activeIncidentId, onSelectIncident }: IncidentQueueProps) {
  return (
    <div className="h-full flex flex-col bg-[#0A0D14] border-r border-white/10">
      {/* Header */}
      <div className="flex-shrink-0 px-4 py-4 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-xs uppercase tracking-widest text-white/40 font-semibold">Incident Queue</h2>
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse-dot" />
            <span className="text-xs text-white/60">Live</span>
          </div>
        </div>
        <div className="flex items-center gap-4 text-xs">
          <div className="flex items-center gap-1.5">
            <div className="w-1.5 h-1.5 bg-red-400 rounded-full" />
            <span className="text-white/60">{incidents.filter(i => i.priority === 'P1-CRITICAL').length} Critical</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-1.5 h-1.5 bg-amber-400 rounded-full" />
            <span className="text-white/60">{incidents.filter(i => i.priority === 'P2-HIGH').length} High</span>
          </div>
        </div>
      </div>

      {/* Queue List */}
      <div className="flex-1 overflow-y-auto">
        <div className="p-3 space-y-2">
          {incidents.map((incident, index) => {
            const config = getPriorityConfig(incident.priority);
            const Icon = config.icon;
            const isActive = incident.id === activeIncidentId;

            return (
              <motion.button
                key={incident.id}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: index * 0.05 }}
                onClick={() => onSelectIncident(incident.id)}
                className={`w-full text-left p-3 rounded-lg border-2 transition-all duration-200 ${
                  isActive 
                    ? 'border-cyan-500/60 bg-cyan-500/10 shadow-[0_0_20px_rgba(34,211,238,0.2)]' 
                    : config.color
                } ${incident.priority === 'P1-CRITICAL' && !isActive ? 'animate-pulse-glow ' + config.glow : ''}`}
              >
                {/* Header row */}
                <div className="flex items-start justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <Icon className={`w-4 h-4 ${config.textColor} flex-shrink-0`} />
                    <span className={`text-xs font-bold ${config.textColor}`}>
                      {incident.priority.split('-')[0]}
                    </span>
                  </div>
                  <span className="text-xs text-white/40 font-mono">{incident.timestamp}</span>
                </div>

                {/* Incident info */}
                <div className="space-y-1">
                  <p className="text-sm font-medium text-white">{incident.type}</p>
                  <p className="text-xs text-white/60">{incident.site}</p>
                </div>

                {/* Status badge */}
                <div className="mt-2 flex items-center gap-2">
                  <div className={`px-2 py-0.5 rounded text-xs font-medium ${
                    incident.status === 'TRIAGING' ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30' :
                    incident.status === 'DISPATCHED' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30' :
                    incident.status === 'INVESTIGATING' ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30' :
                    'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                  }`}>
                    {incident.status}
                  </div>
                  {incident.id === activeIncidentId && (
                    <div className="flex items-center gap-1 text-xs text-cyan-400">
                      <div className="w-1.5 h-1.5 bg-cyan-400 rounded-full animate-pulse" />
                      Active
                    </div>
                  )}
                </div>
              </motion.button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
