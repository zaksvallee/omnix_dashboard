import React, { useState, useEffect } from 'react';
import { CheckCircle, Circle, Loader2, X, Edit3, Navigation, Phone, Camera, Eye } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

export interface ProcessStep {
  id: string;
  title: string;
  status: 'complete' | 'active' | 'pending' | 'thinking';
  timestamp?: string;
  details?: string;
  liveIndicator?: string;
  actions?: string[];
  icon?: React.ReactNode;
}

export interface ActiveIntelligenceProps {
  incidentId: string;
  priority: 'P1' | 'P2' | 'P3' | 'P4';
  status: 'investigating' | 'dispatched' | 'resolved' | 'escalated';
  site: string;
  steps: ProcessStep[];
  onOverride?: (stepId: string) => void;
  onEdit?: (stepId: string) => void;
  onAction?: (stepId: string, action: string) => void;
}

const getStatusIcon = (status: ProcessStep['status']) => {
  switch (status) {
    case 'complete':
      return <CheckCircle className="w-5 h-5 text-emerald-400" />;
    case 'active':
      return <Loader2 className="w-5 h-5 text-cyan-400 animate-spin" />;
    case 'thinking':
      return <Loader2 className="w-5 h-5 text-cyan-400/60 animate-spin" />;
    case 'pending':
      return <Circle className="w-5 h-5 text-white/20" />;
  }
};

const getPriorityColor = (priority: string) => {
  switch (priority) {
    case 'P1':
      return 'bg-red-500/10 text-red-400 border-red-500/30';
    case 'P2':
      return 'bg-amber-500/10 text-amber-400 border-amber-500/30';
    case 'P3':
      return 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30';
    case 'P4':
      return 'bg-blue-500/10 text-blue-400 border-blue-500/30';
    default:
      return 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30';
  }
};

export function ActiveIntelligenceLane({
  incidentId,
  priority,
  status,
  site,
  steps,
  onOverride,
  onEdit,
  onAction
}: ActiveIntelligenceProps) {
  const [thinkingSteps, setThinkingSteps] = useState<Set<string>>(new Set());

  // Simulate thinking delay
  useEffect(() => {
    steps.forEach(step => {
      if (step.status === 'thinking') {
        setThinkingSteps(prev => new Set(prev).add(step.id));
        setTimeout(() => {
          setThinkingSteps(prev => {
            const next = new Set(prev);
            next.delete(step.id);
            return next;
          });
        }, 2500);
      }
    });
  }, [steps]);

  return (
    <div className="space-y-4">
      {/* Intent Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className={`px-6 py-4 rounded-lg border-2 ${getPriorityColor(priority)} ${
          priority === 'P1' ? 'animate-pulse-glow' : ''
        }`}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className={`px-3 py-1 rounded-full text-xs font-bold ${getPriorityColor(priority)}`}>
              {priority}
            </div>
            <div>
              <p className="text-lg font-medium text-white">
                ONYX is {status} {priority === 'P1' ? 'Critical' : priority === 'P2' ? 'High Priority' : ''} Incident
              </p>
              <p className="text-sm text-white/60">
                Site: <span className="text-cyan-400">{site}</span> • Incident{' '}
                <span className="font-mono text-white/80">#{incidentId}</span>
              </p>
            </div>
          </div>
          {priority === 'P1' && (
            <div className="w-3 h-3 bg-red-400 rounded-full animate-pulse-dot" />
          )}
        </div>
      </motion.div>

      {/* Process Ladder */}
      <div className="bg-[#0F1419] border border-white/10 rounded-lg p-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
        <div className="space-y-1">
          <AnimatePresence>
            {steps.map((step, index) => (
              <motion.div
                key={step.id}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                transition={{ delay: index * 0.1 }}
                className="group relative"
              >
                {/* Connecting line */}
                {index < steps.length - 1 && (
                  <div className="absolute left-[10px] top-10 bottom-0 w-px bg-white/10" />
                )}

                <div className={`relative p-4 rounded-lg transition-all duration-200 ${
                  step.status === 'active' ? 'bg-cyan-500/5 border-l-2 border-cyan-400' : ''
                } ${step.status === 'complete' ? 'opacity-60' : ''} hover:bg-white/[0.02]`}>
                  <div className="flex items-start gap-4">
                    {/* Status Icon */}
                    <div className="flex-shrink-0 mt-0.5 relative z-10">
                      {getStatusIcon(step.status)}
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-3">
                          {step.icon && <span className="text-white/60">{step.icon}</span>}
                          <h4 className="text-sm font-medium uppercase tracking-wider text-white">
                            {step.title}
                          </h4>
                          {step.timestamp && (
                            <span className="text-xs text-white/40 font-mono">{step.timestamp}</span>
                          )}
                        </div>

                        {/* Action buttons - show on hover for active/complete */}
                        {(step.status === 'active' || step.status === 'complete') && (
                          <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                            {onOverride && (
                              <button
                                onClick={() => onOverride(step.id)}
                                className="p-1.5 hover:bg-red-500/10 rounded transition-colors text-red-400"
                                title="Override"
                              >
                                <X className="w-4 h-4" />
                              </button>
                            )}
                            {onEdit && (
                              <button
                                onClick={() => onEdit(step.id)}
                                className="p-1.5 hover:bg-white/5 rounded transition-colors text-white/60"
                                title="Edit"
                              >
                                <Edit3 className="w-4 h-4" />
                              </button>
                            )}
                          </div>
                        )}
                      </div>

                      {/* Details */}
                      {step.details && (
                        <p className="text-sm text-white/70 mb-2">{step.details}</p>
                      )}

                      {/* Live Indicator */}
                      {step.liveIndicator && step.status === 'active' && (
                        <div className="flex items-center gap-2 text-xs text-cyan-400 mb-2">
                          <div className="w-1.5 h-1.5 bg-cyan-400 rounded-full animate-pulse" />
                          {step.liveIndicator}
                        </div>
                      )}

                      {/* Thinking state */}
                      {step.status === 'thinking' && (
                        <div className="flex items-center gap-2 text-xs text-white/40 animate-pulse">
                          <span>AI is analyzing</span>
                          <span className="inline-flex gap-1">
                            <span className="animate-bounce" style={{ animationDelay: '0ms' }}>.</span>
                            <span className="animate-bounce" style={{ animationDelay: '150ms' }}>.</span>
                            <span className="animate-bounce" style={{ animationDelay: '300ms' }}>.</span>
                          </span>
                        </div>
                      )}

                      {/* Action Buttons */}
                      {step.actions && step.actions.length > 0 && (
                        <div className="flex flex-wrap gap-2 mt-3">
                          {step.actions.map(action => (
                            <button
                              key={action}
                              onClick={() => onAction?.(step.id, action)}
                              className="px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200"
                            >
                              {action}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}
