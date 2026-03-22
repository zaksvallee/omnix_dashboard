import React, { useState, useEffect } from 'react';
import { Brain, Zap, AlertCircle, CheckCircle, Pause, X, Play, FastForward, Shield, Map, Phone } from 'lucide-react';

export function AIQueue() {
  const [countdown, setCountdown] = useState(26);
  const [isPaused, setIsPaused] = useState(false);

  useEffect(() => {
    if (isPaused || countdown <= 0) return;
    
    const interval = setInterval(() => {
      setCountdown((prev) => Math.max(0, prev - 1));
    }, 1000);

    return () => clearInterval(interval);
  }, [isPaused, countdown]);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  };

  const progressPercent = ((30 - countdown) / 30) * 100;
  const isUrgent = countdown <= 10;

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-purple-500 via-purple-600 to-indigo-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-purple-500/30">
              <Brain className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">AI Automation Queue</h1>
              <p className="text-sm text-white/50">Human-parallel execution supervision with 30s intervention window</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="px-4 py-2 bg-emerald-500/10 text-emerald-400 rounded-xl border border-emerald-500/30 flex items-center gap-2 shadow-lg shadow-emerald-500/10">
              <div className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
              <span className="text-sm font-bold uppercase tracking-wider">AI Engine Active</span>
            </div>
            <div className="px-4 py-2 bg-[#0D1117] border border-[#21262D] rounded-xl">
              <div className="text-xs text-white/40 uppercase tracking-wider">Total Queue</div>
              <div className="text-2xl font-bold text-white tabular-nums">3</div>
            </div>
          </div>
        </div>

        {/* Active Automation - Featured Card */}
        <div className={`
          bg-gradient-to-br from-[#0D1117] to-[#0A0E13] border-2 rounded-2xl overflow-hidden shadow-2xl transition-all
          ${isUrgent ? 'border-red-500/50 shadow-red-500/20' : 'border-cyan-500/30 shadow-cyan-500/10'}
        `}>
          {/* Card Header */}
          <div className={`
            px-6 py-4 border-b transition-colors
            ${isUrgent ? 'bg-gradient-to-r from-red-950/50 to-orange-950/50 border-red-500/30' : 'bg-gradient-to-r from-cyan-950/30 to-blue-950/30 border-cyan-500/20'}
          `}>
            <div className="flex items-center gap-3">
              <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${isUrgent ? 'bg-red-500/20 border border-red-500/30' : 'bg-cyan-500/10 border border-cyan-500/30'}`}>
                <Zap className={`w-5 h-5 ${isUrgent ? 'text-red-400' : 'text-cyan-400'}`} strokeWidth={2.5} />
              </div>
              <div className="flex-1">
                <h2 className="text-lg font-bold text-white uppercase tracking-wide">Active Automation</h2>
                <p className="text-sm text-white/50">AI preparing to execute • intervention window active</p>
              </div>
              <div className={`
                px-4 py-2 rounded-lg font-bold text-sm uppercase tracking-wider border
                ${isUrgent 
                  ? 'bg-red-500/20 text-red-400 border-red-500/30 animate-pulse' 
                  : 'bg-purple-500/20 text-purple-400 border-purple-500/30'}
              `}>
                {isUrgent ? 'URGENT' : 'AUTO-DISPATCH'}
              </div>
            </div>
          </div>

          <div className="p-8">
            {/* Incident Details Grid */}
            <div className="grid grid-cols-4 gap-4 mb-8">
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-4">
                <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Incident ID</div>
                <div className="font-mono text-lg text-white font-bold">INC-8932-0X</div>
              </div>
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-4">
                <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Target Site</div>
                <div className="text-lg text-white font-bold">Sandton Estate North</div>
              </div>
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-4">
                <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Assigned Officer</div>
                <div className="text-lg text-cyan-400 font-bold">Echo-3</div>
              </div>
              <div className="bg-[#0A0E13] border border-[#21262D] rounded-xl p-4">
                <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Estimated ETA</div>
                <div className="text-lg text-emerald-400 font-bold tabular-nums">4m 12s</div>
              </div>
            </div>

            {/* Action Description */}
            <div className="bg-[#0A0E13] border border-cyan-500/20 rounded-xl p-6 mb-8">
              <div className="text-xs text-cyan-400/70 uppercase tracking-wider font-semibold mb-3">Proposed Action</div>
              <p className="text-white/90 text-lg mb-4 leading-relaxed">
                Dispatch reaction officer <span className="font-bold text-white">Echo-3</span> to site based on proximity analysis and threat assessment.
              </p>
              <div className="grid grid-cols-3 gap-4">
                <div className="flex items-center gap-3 px-4 py-3 bg-[#0D1117] border border-[#21262D] rounded-lg">
                  <Shield className="w-5 h-5 text-blue-400 flex-shrink-0" />
                  <div>
                    <div className="text-xs text-white/40">Officer Status</div>
                    <div className="text-sm font-semibold text-white">Available</div>
                  </div>
                </div>
                <div className="flex items-center gap-3 px-4 py-3 bg-[#0D1117] border border-[#21262D] rounded-lg">
                  <Map className="w-5 h-5 text-cyan-400 flex-shrink-0" />
                  <div>
                    <div className="text-xs text-white/40">Distance</div>
                    <div className="text-sm font-semibold text-cyan-400 tabular-nums">2.4km</div>
                  </div>
                </div>
                <div className="flex items-center gap-3 px-4 py-3 bg-[#0D1117] border border-[#21262D] rounded-lg">
                  <Zap className="w-5 h-5 text-emerald-400 flex-shrink-0" />
                  <div>
                    <div className="text-xs text-white/40">Confidence</div>
                    <div className="text-sm font-semibold text-emerald-400">98%</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Countdown Timer - Massive */}
            <div className="mb-8">
              <div className="flex items-end justify-between mb-4">
                <div>
                  <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Intervention Window</div>
                  <div className="text-sm text-white/60">Auto-executes when timer reaches zero</div>
                </div>
                <div className={`
                  text-8xl font-bold tabular-nums tracking-tighter transition-colors
                  ${isUrgent ? 'text-red-400' : 'text-cyan-400'}
                `}>
                  {formatTime(countdown)}
                </div>
              </div>
              
              {/* Progress Bar */}
              <div className="relative h-3 bg-[#0A0E13] rounded-full overflow-hidden border border-[#21262D]">
                <div 
                  className={`
                    absolute inset-y-0 left-0 transition-all duration-1000 ease-linear
                    ${isUrgent 
                      ? 'bg-gradient-to-r from-red-500 to-orange-500' 
                      : 'bg-gradient-to-r from-cyan-500 to-blue-500'}
                  `}
                  style={{ width: `${progressPercent}%` }}
                />
              </div>

              {isUrgent && (
                <div className="mt-3 flex items-center gap-2 text-red-400 animate-pulse">
                  <AlertCircle className="w-4 h-4" />
                  <span className="text-sm font-semibold">INTERVENTION WINDOW CLOSING</span>
                </div>
              )}
            </div>

            {/* Action Buttons */}
            <div className="grid grid-cols-3 gap-4">
              <button className="group px-6 py-4 bg-gradient-to-br from-red-500/10 to-red-600/10 hover:from-red-500/20 hover:to-red-600/20 text-red-400 rounded-xl border border-red-500/30 hover:border-red-500/50 transition-all flex items-center justify-center gap-3 font-bold uppercase tracking-wider text-sm shadow-lg hover:shadow-red-500/20">
                <X className="w-5 h-5 group-hover:scale-110 transition-transform" strokeWidth={2.5} />
                Cancel Action
              </button>
              <button 
                onClick={() => setIsPaused(!isPaused)}
                className="group px-6 py-4 bg-[#0D1117] hover:bg-[#161B22] text-white rounded-xl border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-3 font-bold uppercase tracking-wider text-sm"
              >
                {isPaused ? (
                  <>
                    <Play className="w-5 h-5 group-hover:scale-110 transition-transform" strokeWidth={2.5} />
                    Resume
                  </>
                ) : (
                  <>
                    <Pause className="w-5 h-5 group-hover:scale-110 transition-transform" strokeWidth={2.5} />
                    Pause
                  </>
                )}
              </button>
              <button className="group px-6 py-4 bg-gradient-to-br from-emerald-500/10 to-teal-500/10 hover:from-emerald-500/20 hover:to-teal-500/20 text-emerald-400 rounded-xl border border-emerald-500/30 hover:border-emerald-500/50 transition-all flex items-center justify-center gap-3 font-bold uppercase tracking-wider text-sm shadow-lg hover:shadow-emerald-500/20">
                <CheckCircle className="w-5 h-5 group-hover:scale-110 transition-transform" strokeWidth={2.5} />
                Approve Now
              </button>
            </div>
          </div>
        </div>

        {/* Queued Actions */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl overflow-hidden">
          <div className="px-6 py-4 border-b border-[#21262D] bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
            <div className="flex items-center gap-3">
              <AlertCircle className="w-5 h-5 text-amber-400" />
              <h2 className="text-lg font-bold text-white uppercase tracking-wide">Queued Actions</h2>
              <div className="w-8 h-8 bg-amber-500/20 text-amber-400 rounded-full flex items-center justify-center text-sm font-bold border border-amber-500/30">
                2
              </div>
            </div>
          </div>

          <div className="p-6 space-y-4">
            {/* Queue Item 1 */}
            <div className="bg-[#0A0E13] border border-[#21262D] hover:border-cyan-500/30 rounded-xl p-5 transition-all group cursor-pointer">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500/20 to-indigo-500/20 border border-blue-500/30 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform">
                  <Phone className="w-6 h-6 text-blue-400" strokeWidth={2.5} />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <h3 className="text-white font-bold text-lg">VOIP CLIENT CALL</h3>
                    <span className="px-2 py-1 bg-blue-500/20 text-blue-400 text-xs font-bold rounded uppercase tracking-wider">
                      INC-8838-9Z
                    </span>
                  </div>
                  <p className="text-sm text-white/60 mb-3">Initiate safe-word verification call with client contact.</p>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4 text-xs text-white/40">
                      <span>Confidence: <span className="text-emerald-400 font-semibold">94%</span></span>
                      <span>•</span>
                      <span>Priority: <span className="text-amber-400 font-semibold">Medium</span></span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="text-xs text-white/40">Executes in</div>
                      <div className="text-cyan-400 font-mono font-bold text-lg tabular-nums">08:45</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            {/* Queue Item 2 */}
            <div className="bg-[#0A0E13] border border-[#21262D] hover:border-cyan-500/30 rounded-xl p-5 transition-all group cursor-pointer">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500/20 to-pink-500/20 border border-purple-500/30 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform">
                  <Zap className="w-6 h-6 text-purple-400" strokeWidth={2.5} />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-2">
                    <h3 className="text-white font-bold text-lg">CCTV ACTIVATION</h3>
                    <span className="px-2 py-1 bg-purple-500/20 text-purple-400 text-xs font-bold rounded uppercase tracking-wider">
                      INC-8937-PX
                    </span>
                  </div>
                  <p className="text-sm text-white/60 mb-3">Request CCTV stream from perimeter cameras for visual verification.</p>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4 text-xs text-white/40">
                      <span>Confidence: <span className="text-emerald-400 font-semibold">97%</span></span>
                      <span>•</span>
                      <span>Priority: <span className="text-emerald-400 font-semibold">High</span></span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="text-xs text-white/40">Executes in</div>
                      <div className="text-cyan-400 font-mono font-bold text-lg tabular-nums">01:12</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Queue Statistics */}
        <div className="grid grid-cols-4 gap-6">
          <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-6 hover:border-cyan-500/20 transition-all">
            <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-3">Total Actions Today</div>
            <div className="text-5xl font-bold text-white tabular-nums mb-2">5</div>
            <div className="text-xs text-white/60">Across all incidents</div>
          </div>
          <div className="bg-[#0D1117] border border-emerald-500/20 rounded-xl p-6 hover:border-emerald-500/30 transition-all">
            <div className="text-xs text-emerald-400/70 uppercase tracking-wider font-semibold mb-3">Executed</div>
            <div className="text-5xl font-bold text-emerald-400 tabular-nums mb-2">0</div>
            <div className="text-xs text-emerald-400/60">Successfully completed</div>
          </div>
          <div className="bg-[#0D1117] border border-amber-500/20 rounded-xl p-6 hover:border-amber-500/30 transition-all">
            <div className="text-xs text-amber-400/70 uppercase tracking-wider font-semibold mb-3">Overridden</div>
            <div className="text-5xl font-bold text-amber-400 tabular-nums mb-2">0</div>
            <div className="text-xs text-amber-400/60">Human intervention</div>
          </div>
          <div className="bg-[#0D1117] border border-cyan-500/20 rounded-xl p-6 hover:border-cyan-500/30 transition-all">
            <div className="text-xs text-cyan-400/70 uppercase tracking-wider font-semibold mb-3">Approval Rate</div>
            <div className="text-5xl font-bold text-cyan-400 tabular-nums mb-2">0%</div>
            <div className="text-xs text-cyan-400/60">Last 24 hours</div>
          </div>
        </div>
      </div>
    </div>
  );
}
