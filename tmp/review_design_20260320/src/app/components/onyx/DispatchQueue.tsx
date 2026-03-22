import React, { useState } from 'react';
import { AlertTriangle, Clock, MapPin, User, ChevronRight, GripVertical } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

export interface Dispatch {
  id: string;
  priority: 'P1' | 'P2' | 'P3' | 'P4';
  type: string;
  site: string;
  officer?: string;
  eta?: string;
  status: 'queued' | 'dispatched' | 'en-route' | 'on-site';
  timestamp: string;
  autoCloseIn?: number; // seconds
  lane: 'auto' | 'manual';
}

export interface DispatchQueueProps {
  dispatches: Dispatch[];
  onDragToLane?: (dispatchId: string, lane: 'auto' | 'manual') => void;
  onView?: (dispatchId: string) => void;
  onTakeOver?: (dispatchId: string) => void;
}

const getPriorityColor = (priority: string) => {
  switch (priority) {
    case 'P1':
      return { bg: 'bg-red-500/10', text: 'text-red-400', border: 'border-red-500/30', glow: 'shadow-[0_0_20px_rgba(239,68,68,0.3)]' };
    case 'P2':
      return { bg: 'bg-amber-500/10', text: 'text-amber-400', border: 'border-amber-500/30', glow: '' };
    case 'P3':
      return { bg: 'bg-yellow-500/10', text: 'text-yellow-400', border: 'border-yellow-500/30', glow: '' };
    case 'P4':
      return { bg: 'bg-blue-500/10', text: 'text-blue-400', border: 'border-blue-500/30', glow: '' };
    default:
      return { bg: 'bg-cyan-500/10', text: 'text-cyan-400', border: 'border-cyan-500/30', glow: '' };
  }
};

function DispatchCard({ dispatch, onView, onTakeOver }: { 
  dispatch: Dispatch; 
  onView?: (id: string) => void;
  onTakeOver?: (id: string) => void;
}) {
  const colors = getPriorityColor(dispatch.priority);

  return (
    <motion.div
      layout
      initial={{ opacity: 0, scale: 0.9 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.9 }}
      className={`group relative p-4 ${colors.bg} border ${colors.border} rounded-lg cursor-move hover:border-white/20 transition-all duration-200 ${
        dispatch.priority === 'P1' ? 'animate-pulse-glow ' + colors.glow : ''
      }`}
    >
      {/* Drag handle */}
      <div className="absolute left-2 top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-40 transition-opacity">
        <GripVertical className="w-4 h-4 text-white" />
      </div>

      <div className="pl-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-2">
            <span className={`px-2 py-0.5 ${colors.bg} ${colors.text} rounded text-xs font-bold`}>
              {dispatch.priority}
            </span>
            <span className="text-sm font-medium text-white">{dispatch.type}</span>
            {dispatch.priority === 'P1' && (
              <div className="w-2 h-2 bg-red-400 rounded-full animate-pulse-dot" />
            )}
          </div>
          <span className="text-xs text-white/40 font-mono">{dispatch.timestamp}</span>
        </div>

        {/* Details */}
        <div className="space-y-2 mb-3">
          <div className="flex items-center gap-2 text-sm text-white/70">
            <MapPin className="w-4 h-4 text-white/40" />
            {dispatch.site}
          </div>
          {dispatch.officer && (
            <div className="flex items-center gap-2 text-sm text-white/70">
              <User className="w-4 h-4 text-white/40" />
              {dispatch.officer}
              {dispatch.eta && (
                <span className="text-cyan-400">• ETA {dispatch.eta}</span>
              )}
            </div>
          )}
        </div>

        {/* Auto-close countdown */}
        {dispatch.autoCloseIn && dispatch.lane === 'auto' && (
          <div className="mb-3 p-2 bg-cyan-500/5 border border-cyan-500/20 rounded">
            <div className="flex items-center justify-between text-xs">
              <span className="text-white/60">Auto-closing in</span>
              <span className="text-cyan-400 font-mono font-medium">{dispatch.autoCloseIn}s</span>
            </div>
            <div className="mt-1 h-1 bg-white/10 rounded-full overflow-hidden">
              <motion.div
                className="h-full bg-cyan-400"
                initial={{ width: '100%' }}
                animate={{ width: '0%' }}
                transition={{ duration: dispatch.autoCloseIn, ease: 'linear' }}
              />
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-2">
          {onView && (
            <button
              onClick={() => onView(dispatch.id)}
              className="flex-1 px-3 py-1.5 bg-white/5 hover:bg-white/10 text-white/70 hover:text-white text-xs font-medium rounded border border-white/10 hover:border-white/20 transition-all duration-200"
            >
              View
            </button>
          )}
          {dispatch.lane === 'auto' && onTakeOver && (
            <button
              onClick={() => onTakeOver(dispatch.id)}
              className="flex-1 px-3 py-1.5 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 text-xs font-medium rounded border border-cyan-500/20 hover:border-cyan-500/30 transition-all duration-200"
            >
              Take Over
            </button>
          )}
        </div>
      </div>
    </motion.div>
  );
}

export function DispatchQueue({ dispatches, onDragToLane, onView, onTakeOver }: DispatchQueueProps) {
  const [activeTab, setActiveTab] = useState<'auto' | 'manual'>('auto');

  const autoDispatches = dispatches.filter(d => d.lane === 'auto').sort((a, b) => {
    const priorityOrder = { P1: 0, P2: 1, P3: 2, P4: 3 };
    return priorityOrder[a.priority] - priorityOrder[b.priority];
  });

  const manualDispatches = dispatches.filter(d => d.lane === 'manual').sort((a, b) => {
    const priorityOrder = { P1: 0, P2: 1, P3: 2, P4: 3 };
    return priorityOrder[a.priority] - priorityOrder[b.priority];
  });

  return (
    <div className="bg-[#0F1419] border border-white/10 rounded-lg overflow-hidden shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
      {/* Header with tabs */}
      <div className="px-6 py-4 border-b border-white/10 bg-white/[0.02]">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-medium uppercase tracking-wider text-white">Dispatch Queue</h3>
          <div className="flex items-center gap-2">
            <span className="text-xs text-white/40">
              {autoDispatches.length} Auto • {manualDispatches.length} Manual
            </span>
          </div>
        </div>

        {/* Tab selector */}
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('auto')}
            className={`flex-1 px-4 py-2 rounded-lg font-medium text-sm transition-all duration-200 ${
              activeTab === 'auto'
                ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                : 'bg-white/5 text-white/60 border border-white/10 hover:bg-white/10'
            }`}
          >
            Auto Lane ({autoDispatches.length})
          </button>
          <button
            onClick={() => setActiveTab('manual')}
            className={`flex-1 px-4 py-2 rounded-lg font-medium text-sm transition-all duration-200 ${
              activeTab === 'manual'
                ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                : 'bg-white/5 text-white/60 border border-white/10 hover:bg-white/10'
            }`}
          >
            Manual Lane ({manualDispatches.length})
          </button>
        </div>
      </div>

      {/* Queue content */}
      <div className="p-6">
        <AnimatePresence mode="wait">
          {activeTab === 'auto' ? (
            <motion.div
              key="auto"
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: 20 }}
              className="space-y-3"
            >
              {autoDispatches.length > 0 ? (
                autoDispatches.map(dispatch => (
                  <DispatchCard
                    key={dispatch.id}
                    dispatch={dispatch}
                    onView={onView}
                    onTakeOver={onTakeOver}
                  />
                ))
              ) : (
                <div className="py-12 text-center">
                  <Clock className="w-12 h-12 text-white/20 mx-auto mb-3" />
                  <p className="text-sm text-white/40">No auto-managed dispatches</p>
                </div>
              )}
            </motion.div>
          ) : (
            <motion.div
              key="manual"
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              className="space-y-3"
            >
              {manualDispatches.length > 0 ? (
                manualDispatches.map(dispatch => (
                  <DispatchCard
                    key={dispatch.id}
                    dispatch={dispatch}
                    onView={onView}
                    onTakeOver={onTakeOver}
                  />
                ))
              ) : (
                <div className="py-12 text-center">
                  <User className="w-12 h-12 text-white/20 mx-auto mb-3" />
                  <p className="text-sm text-white/40">No manual dispatches</p>
                  <p className="text-xs text-white/30 mt-1">Drag from Auto lane to take control</p>
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
