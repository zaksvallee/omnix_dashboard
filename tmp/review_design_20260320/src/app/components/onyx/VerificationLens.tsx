import React, { useState } from 'react';
import { AlertTriangle, CheckCircle, Eye, EyeOff, ZoomIn, ZoomOut } from 'lucide-react';
import { motion } from 'motion/react';

export interface VerificationLensProps {
  baselineImage: string;
  currentImage: string;
  matchScore: number;
  anomalies?: string[];
  metadata?: {
    baseline: { timestamp: string; gps: string; weather?: string };
    current: { timestamp: string; gps: string; weather?: string };
  };
  onApprove?: () => void;
  onFlag?: () => void;
  onEscalate?: () => void;
}

export function VerificationLens({
  baselineImage,
  currentImage,
  matchScore,
  anomalies = [],
  metadata,
  onApprove,
  onFlag,
  onEscalate
}: VerificationLensProps) {
  const [ghostMode, setGhostMode] = useState(false);
  const [opacity, setOpacity] = useState(50);

  const getScoreColor = (score: number) => {
    if (score >= 95) return 'text-emerald-400';
    if (score >= 60) return 'text-yellow-400';
    return 'text-red-400';
  };

  const getScoreStatus = (score: number) => {
    if (score >= 95) return { text: 'VERIFIED', color: 'emerald' };
    if (score >= 60) return { text: 'REVIEW REQUIRED', color: 'yellow' };
    return { text: 'ANOMALY DETECTED', color: 'red' };
  };

  const status = getScoreStatus(matchScore);

  return (
    <div className="bg-[#0F1419] border border-white/10 rounded-lg overflow-hidden shadow-[inset_0_1px_0_rgba(255,255,255,0.03)]">
      {/* Header */}
      <div className="px-6 py-4 border-b border-white/10 flex items-center justify-between bg-white/[0.02]">
        <h3 className="text-sm font-medium uppercase tracking-wider text-white">Visual Verification</h3>
        <button
          onClick={() => setGhostMode(!ghostMode)}
          className={`flex items-center gap-2 px-3 py-1.5 rounded border transition-all duration-200 ${
            ghostMode
              ? 'bg-cyan-500/20 border-cyan-500/30 text-cyan-400'
              : 'bg-white/5 border-white/10 text-white/60 hover:bg-white/10'
          }`}
        >
          {ghostMode ? <Eye className="w-4 h-4" /> : <EyeOff className="w-4 h-4" />}
          <span className="text-xs font-medium">Ghost Overlay</span>
        </button>
      </div>

      {/* Image Comparison */}
      <div className="p-6">
        {!ghostMode ? (
          // Side-by-side mode
          <div className="grid grid-cols-2 gap-4 mb-6">
            {/* Baseline */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <p className="text-xs uppercase tracking-wider text-white/40">Baseline Norm</p>
                {metadata?.baseline && (
                  <p className="text-xs text-white/40">{metadata.baseline.timestamp}</p>
                )}
              </div>
              <div className="relative aspect-video bg-black/30 rounded-lg overflow-hidden border border-white/10">
                <img src={baselineImage} alt="Baseline" className="w-full h-full object-cover" />
              </div>
              {metadata?.baseline && (
                <div className="mt-2 space-y-1">
                  <p className="text-xs text-white/40">GPS: {metadata.baseline.gps}</p>
                  {metadata.baseline.weather && (
                    <p className="text-xs text-white/40">Weather: {metadata.baseline.weather}</p>
                  )}
                </div>
              )}
            </div>

            {/* Current */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <p className="text-xs uppercase tracking-wider text-white/40">Current State</p>
                {metadata?.current && (
                  <p className="text-xs text-white/40">{metadata.current.timestamp}</p>
                )}
              </div>
              <div className="relative aspect-video bg-black/30 rounded-lg overflow-hidden border border-white/10">
                <img src={currentImage} alt="Current" className="w-full h-full object-cover" />
                {/* Anomaly highlights */}
                {anomalies.length > 0 && (
                  <div className="absolute inset-0 bg-red-500/10">
                    {/* Simulated red overlay zones */}
                  </div>
                )}
              </div>
              {metadata?.current && (
                <div className="mt-2 space-y-1">
                  <p className="text-xs text-white/40">GPS: {metadata.current.gps}</p>
                  {metadata.current.weather && (
                    <p className="text-xs text-white/40">Weather: {metadata.current.weather}</p>
                  )}
                </div>
              )}
            </div>
          </div>
        ) : (
          // Ghost overlay mode
          <div className="mb-6">
            <div className="flex items-center justify-between mb-2">
              <p className="text-xs uppercase tracking-wider text-white/40">Ghost Overlay Mode</p>
              <div className="flex items-center gap-2">
                <span className="text-xs text-white/40">Opacity:</span>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={opacity}
                  onChange={(e) => setOpacity(Number(e.target.value))}
                  className="w-24"
                />
                <span className="text-xs text-white/60 font-mono w-8">{opacity}%</span>
              </div>
            </div>
            <div className="relative aspect-video bg-black/30 rounded-lg overflow-hidden border border-white/10">
              <img src={baselineImage} alt="Baseline" className="w-full h-full object-cover" />
              <img
                src={currentImage}
                alt="Current overlay"
                className="absolute inset-0 w-full h-full object-cover"
                style={{ opacity: opacity / 100 }}
              />
            </div>
          </div>
        )}

        {/* Match Score */}
        <div className={`p-6 rounded-lg border-2 border-${status.color}-500/30 bg-${status.color}-500/5 mb-6`}>
          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-xs uppercase tracking-wider text-white/40 mb-1">Match Score</p>
              <div className="flex items-baseline gap-3">
                <span className={`text-5xl font-light ${getScoreColor(matchScore)}`}>
                  {matchScore}%
                </span>
                <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full bg-${status.color}-500/10 border border-${status.color}-500/20`}>
                  {matchScore >= 95 ? (
                    <CheckCircle className={`w-4 h-4 text-${status.color}-400`} />
                  ) : (
                    <AlertTriangle className={`w-4 h-4 text-${status.color}-400`} />
                  )}
                  <span className={`text-xs font-medium text-${status.color}-400`}>{status.text}</span>
                </div>
              </div>
            </div>

            {/* Circular progress */}
            <div className="relative w-24 h-24">
              <svg className="w-24 h-24 transform -rotate-90">
                <circle
                  cx="48"
                  cy="48"
                  r="40"
                  stroke="rgba(255,255,255,0.1)"
                  strokeWidth="6"
                  fill="none"
                />
                <motion.circle
                  cx="48"
                  cy="48"
                  r="40"
                  stroke={matchScore >= 95 ? '#10B981' : matchScore >= 60 ? '#FACC15' : '#EF4444'}
                  strokeWidth="6"
                  fill="none"
                  strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 40}`}
                  initial={{ strokeDashoffset: 2 * Math.PI * 40 }}
                  animate={{ strokeDashoffset: 2 * Math.PI * 40 * (1 - matchScore / 100) }}
                  transition={{ duration: 1, ease: 'easeOut' }}
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <span className={`text-lg font-bold ${getScoreColor(matchScore)}`}>
                  {matchScore}%
                </span>
              </div>
            </div>
          </div>

          {/* Anomalies */}
          {anomalies.length > 0 && (
            <div className="pt-4 border-t border-white/10">
              <p className="text-xs uppercase tracking-wider text-white/40 mb-2">Detected Anomalies</p>
              <ul className="space-y-1">
                {anomalies.map((anomaly, index) => (
                  <li key={index} className="flex items-center gap-2 text-sm text-red-400">
                    <div className="w-1 h-1 bg-red-400 rounded-full" />
                    {anomaly}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          {matchScore >= 95 && onApprove && (
            <button
              onClick={onApprove}
              className="flex-1 px-6 py-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-lg font-medium shadow-[0_4px_16px_rgba(16,185,129,0.3)] hover:shadow-[0_6px_24px_rgba(16,185,129,0.4)] hover:-translate-y-0.5 active:scale-[0.98] transition-all duration-200"
            >
              Auto-Approve & Close
            </button>
          )}
          {onFlag && (
            <button
              onClick={onFlag}
              className="flex-1 px-6 py-3 border border-yellow-500/20 text-yellow-400 rounded-lg font-medium hover:bg-yellow-500/10 hover:border-yellow-500/30 active:scale-[0.98] transition-all duration-200"
            >
              Flag for Review
            </button>
          )}
          {matchScore < 60 && onEscalate && (
            <button
              onClick={onEscalate}
              className="flex-1 px-6 py-3 bg-gradient-to-r from-red-500 to-red-600 text-white rounded-lg font-medium shadow-[0_4px_16px_rgba(239,68,68,0.3)] hover:shadow-[0_6px_24px_rgba(239,68,68,0.4)] hover:-translate-y-0.5 active:scale-[0.98] transition-all duration-200"
            >
              Escalate to P1
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
