import React, { useState } from 'react';
import { Check, Loader2, Circle, X, AlertTriangle, Phone, Camera, Shield, Navigation } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

export interface LadderStep {
  id: string;
  name: string;
  status: 'completed' | 'active' | 'thinking' | 'pending' | 'blocked';
  timestamp?: string;
  details?: string;
  metadata?: {
    officer?: string;
    distance?: string;
    eta?: string;
    phone?: string;
    confidence?: number;
  };
  thinkingMessage?: string;
}

export interface ActionLadderProps {
  incidentId: string;
  priority: string;
  site: string;
  steps: LadderStep[];
  onOverride?: (stepId: string, reasonCode: string) => void;
  onInterrupt?: (stepId: string) => void;
}

const getStepIcon = (name: string) => {
  if (name.includes('DISPATCH')) return Navigation;
  if (name.includes('VOIP') || name.includes('CALL')) return Phone;
  if (name.includes('CCTV') || name.includes('VISION')) return Camera;
  if (name.includes('VERIFICATION')) return Shield;
  return Circle;
};

export function ActionLadder({ incidentId, priority, site, steps, onOverride, onInterrupt }: ActionLadderProps) {
  const [showOverrideModal, setShowOverrideModal] = useState(false);
  const [selectedStep, setSelectedStep] = useState<string | null>(null);
  const [reasonCode, setReasonCode] = useState('');

  const handleOverrideClick = (stepId: string) => {
    setSelectedStep(stepId);
    setShowOverrideModal(true);
  };

  const handleOverrideSubmit = () => {
    if (selectedStep && reasonCode && onOverride) {
      onOverride(selectedStep, reasonCode);
      setShowOverrideModal(false);
      setReasonCode('');
      setSelectedStep(null);
    }
  };

  const reasonCodes = [
    'DUPLICATE_SIGNAL',
    'FALSE_ALARM',
    'TEST_EVENT',
    'CLIENT_VERIFIED_SAFE',
    'HARDWARE_FAULT'
  ];

  return (
    <div className="h-full flex flex-col bg-[#0D1117]">
      {/* Header */}
      <div className="flex-shrink-0 px-6 py-4 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between mb-2">
          <div>
            <h2 className="text-xs uppercase tracking-widest text-white/40 font-semibold mb-1">
              Action Ladder
            </h2>
            <p className="text-sm text-white/80">
              <span className="text-cyan-400 font-mono">#{incidentId}</span>
              <span className="text-white/40 mx-2">•</span>
              <span className="text-white/70">{site}</span>
            </p>
          </div>
          <div className={`px-3 py-1.5 rounded-full text-xs font-bold ${
            priority === 'P1-CRITICAL' ? 'bg-red-500/20 text-red-400 border-2 border-red-500/40' :
            priority === 'P2-HIGH' ? 'bg-amber-500/20 text-amber-400 border-2 border-amber-500/40' :
            'bg-blue-500/20 text-blue-400 border-2 border-blue-500/40'
          }`}>
            {priority}
          </div>
        </div>
      </div>

      {/* Ladder Steps */}
      <div className="flex-1 overflow-y-auto p-6">
        <div className="space-y-1 relative">
          {/* Connecting line */}
          <div className="absolute left-[18px] top-6 bottom-6 w-px bg-gradient-to-b from-cyan-500/30 via-cyan-500/20 to-transparent" />

          {steps.map((step, index) => {
            const StepIcon = getStepIcon(step.name);
            
            return (
              <motion.div
                key={step.id}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                className="relative"
              >
                <div className={`p-4 rounded-lg transition-all duration-300 ${
                  step.status === 'active' 
                    ? 'bg-cyan-500/5 border-l-2 border-cyan-400 shadow-[0_0_15px_rgba(34,211,238,0.1)]' 
                    : step.status === 'completed'
                    ? 'bg-white/[0.02] opacity-70'
                    : 'bg-transparent'
                } ${step.status === 'blocked' ? 'opacity-50' : ''}`}>
                  
                  <div className="flex items-start gap-4">
                    {/* Status indicator */}
                    <div className="flex-shrink-0 relative z-10">
                      <div className={`w-9 h-9 rounded-full flex items-center justify-center border-2 ${
                        step.status === 'completed' 
                          ? 'bg-emerald-500/20 border-emerald-500'
                          : step.status === 'active'
                          ? 'bg-cyan-500/20 border-cyan-500'
                          : step.status === 'thinking'
                          ? 'bg-cyan-500/10 border-cyan-500/50'
                          : step.status === 'blocked'
                          ? 'bg-red-500/20 border-red-500'
                          : 'bg-white/5 border-white/20'
                      }`}>
                        {step.status === 'completed' && <Check className="w-4 h-4 text-emerald-400" />}
                        {step.status === 'active' && <Loader2 className="w-4 h-4 text-cyan-400 animate-spin" />}
                        {step.status === 'thinking' && <Loader2 className="w-4 h-4 text-cyan-400/60 animate-spin" />}
                        {step.status === 'blocked' && <X className="w-4 h-4 text-red-400" />}
                        {step.status === 'pending' && <Circle className="w-4 h-4 text-white/30" />}
                      </div>
                    </div>

                    {/* Content */}
                    <div className="flex-1 min-w-0 pt-1">
                      {/* Step header */}
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-3">
                          <StepIcon className="w-4 h-4 text-white/60" />
                          <h3 className="text-sm font-semibold text-white uppercase tracking-wider">
                            {step.name}
                          </h3>
                        </div>
                        {step.timestamp && (
                          <span className="text-xs text-white/40 font-mono">{step.timestamp}</span>
                        )}
                      </div>

                      {/* Details */}
                      {step.details && (
                        <p className="text-sm text-white/70 mb-2">{step.details}</p>
                      )}

                      {/* Metadata */}
                      {step.metadata && (
                        <div className="flex flex-wrap gap-3 text-xs text-white/60 mb-2">
                          {step.metadata.officer && (
                            <span>Officer: <span className="text-cyan-400">{step.metadata.officer}</span></span>
                          )}
                          {step.metadata.distance && (
                            <span>Distance: <span className="text-white/80">{step.metadata.distance}</span></span>
                          )}
                          {step.metadata.eta && (
                            <span>ETA: <span className="text-amber-400">{step.metadata.eta}</span></span>
                          )}
                          {step.metadata.confidence && (
                            <span>Confidence: <span className="text-emerald-400">{step.metadata.confidence}%</span></span>
                          )}
                        </div>
                      )}

                      {/* Thinking state */}
                      {step.status === 'thinking' && step.thinkingMessage && (
                        <div className="flex items-center gap-2 text-xs text-cyan-400/80 mb-3 animate-pulse">
                          <Loader2 className="w-3 h-3 animate-spin" />
                          <span>{step.thinkingMessage}</span>
                        </div>
                      )}

                      {/* Action buttons */}
                      {(step.status === 'active' || step.status === 'thinking') && (
                        <div className="flex gap-2 mt-3">
                          <button
                            onClick={() => handleOverrideClick(step.id)}
                            className="px-3 py-1.5 bg-red-500/10 hover:bg-red-500/20 text-red-400 text-xs font-medium rounded border border-red-500/30 hover:border-red-500/40 transition-all duration-200"
                          >
                            Override
                          </button>
                          {onInterrupt && (
                            <button
                              onClick={() => onInterrupt(step.id)}
                              className="px-3 py-1.5 bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium rounded border border-white/10 hover:border-white/20 transition-all duration-200"
                            >
                              Pause
                            </button>
                          )}
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>

      {/* Override Modal */}
      <AnimatePresence>
        {showOverrideModal && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="absolute inset-0 bg-black/80 flex items-center justify-center z-50 p-6"
            onClick={() => setShowOverrideModal(false)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              onClick={(e) => e.stopPropagation()}
              className="bg-[#0F1419] border border-red-500/30 rounded-lg p-6 max-w-md w-full"
            >
              <div className="flex items-center gap-3 mb-4">
                <div className="p-2 bg-red-500/20 rounded-lg">
                  <AlertTriangle className="w-5 h-5 text-red-400" />
                </div>
                <h3 className="text-lg font-semibold text-white">Override Required</h3>
              </div>

              <p className="text-sm text-white/70 mb-4">
                All manual overrides must include a valid reason code for ledger compliance.
              </p>

              <div className="space-y-2 mb-6">
                {reasonCodes.map(code => (
                  <button
                    key={code}
                    onClick={() => setReasonCode(code)}
                    className={`w-full text-left px-4 py-3 rounded-lg border transition-all duration-200 ${
                      reasonCode === code
                        ? 'bg-cyan-500/20 border-cyan-500/40 text-cyan-400'
                        : 'bg-white/5 border-white/10 text-white/70 hover:bg-white/10 hover:border-white/20'
                    }`}
                  >
                    <span className="text-sm font-medium">{code.replace(/_/g, ' ')}</span>
                  </button>
                ))}
              </div>

              <div className="flex gap-3">
                <button
                  onClick={() => setShowOverrideModal(false)}
                  className="flex-1 px-4 py-2 bg-white/5 hover:bg-white/10 text-white/70 hover:text-white rounded-lg border border-white/10 hover:border-white/20 transition-all duration-200"
                >
                  Cancel
                </button>
                <button
                  onClick={handleOverrideSubmit}
                  disabled={!reasonCode}
                  className="flex-1 px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
                >
                  Confirm Override
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
