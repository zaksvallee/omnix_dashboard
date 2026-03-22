import React, { useState } from 'react';
import { MapPin, Phone, Shield, Clock, AlertTriangle, Eye, Volume2 } from 'lucide-react';
import { motion } from 'motion/react';

export interface IncidentContextProps {
  site: {
    name: string;
    address: string;
    coordinates: string;
    riskRating: number;
    slaTier: string;
  };
  client: {
    name: string;
    contact: string;
    phone: string;
    safeWordStatus?: 'VERIFIED' | 'FAILED' | 'PENDING';
  };
  duressDetected?: boolean;
  visualNorm?: {
    matchScore: number;
    anomalies: string[];
  };
  voipTranscript?: Array<{
    speaker: 'AI' | 'CLIENT';
    message: string;
    timestamp: string;
  }>;
}

export function IncidentContext({ site, client, duressDetected, visualNorm, voipTranscript }: IncidentContextProps) {
  const [activeTab, setActiveTab] = useState<'details' | 'voip' | 'visual'>('details');

  return (
    <div className="h-full flex flex-col bg-[#0A0D14] border-l border-white/10">
      {/* Header */}
      <div className="flex-shrink-0 px-4 py-4 border-b border-white/10 bg-white/[0.02]">
        <h2 className="text-xs uppercase tracking-widest text-white/40 font-semibold mb-3">
          Incident Context
        </h2>

        {/* Tabs */}
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('details')}
            className={`flex-1 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-200 ${
              activeTab === 'details'
                ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                : 'bg-white/5 text-white/60 hover:bg-white/10'
            }`}
          >
            Details
          </button>
          <button
            onClick={() => setActiveTab('voip')}
            className={`flex-1 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-200 ${
              activeTab === 'voip'
                ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                : 'bg-white/5 text-white/60 hover:bg-white/10'
            }`}
          >
            VoIP
          </button>
          <button
            onClick={() => setActiveTab('visual')}
            className={`flex-1 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-200 ${
              activeTab === 'visual'
                ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                : 'bg-white/5 text-white/60 hover:bg-white/10'
            }`}
          >
            Vision
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-4">
        {activeTab === 'details' && (
          <div className="space-y-4">
            {/* Site Info */}
            <div className="p-4 bg-[#0F1419] border border-white/10 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <MapPin className="w-4 h-4 text-cyan-400" />
                <h3 className="text-xs uppercase tracking-wider text-white/60 font-semibold">Site</h3>
              </div>
              <div className="space-y-2">
                <div>
                  <p className="text-sm font-medium text-white">{site.name}</p>
                  <p className="text-xs text-white/60">{site.address}</p>
                </div>
                <div className="flex items-center gap-3 text-xs">
                  <span className="text-white/40">GPS:</span>
                  <code className="text-cyan-400 font-mono">{site.coordinates}</code>
                </div>
                <div className="flex items-center justify-between pt-2 border-t border-white/10">
                  <div>
                    <p className="text-xs text-white/40 mb-1">Risk Rating</p>
                    <div className="flex gap-1">
                      {[1, 2, 3, 4, 5].map(level => (
                        <div
                          key={level}
                          className={`w-2 h-2 rounded-full ${
                            level <= site.riskRating ? 'bg-amber-400' : 'bg-white/10'
                          }`}
                        />
                      ))}
                    </div>
                  </div>
                  <div>
                    <p className="text-xs text-white/40 mb-1">SLA Tier</p>
                    <span className="text-xs font-medium text-cyan-400">{site.slaTier}</span>
                  </div>
                </div>
              </div>
            </div>

            {/* Client Info */}
            <div className="p-4 bg-[#0F1419] border border-white/10 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Shield className="w-4 h-4 text-cyan-400" />
                <h3 className="text-xs uppercase tracking-wider text-white/60 font-semibold">Client</h3>
              </div>
              <div className="space-y-2">
                <div>
                  <p className="text-sm font-medium text-white">{client.name}</p>
                  <p className="text-xs text-white/60">{client.contact}</p>
                </div>
                <div className="flex items-center gap-2 text-xs">
                  <Phone className="w-3 h-3 text-white/40" />
                  <code className="text-cyan-400 font-mono">{client.phone}</code>
                </div>
                {client.safeWordStatus && (
                  <div className={`mt-3 px-3 py-2 rounded border ${
                    client.safeWordStatus === 'VERIFIED'
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                      : client.safeWordStatus === 'FAILED'
                      ? 'bg-red-500/10 border-red-500/30 text-red-400'
                      : 'bg-cyan-500/10 border-cyan-500/30 text-cyan-400'
                  }`}>
                    <p className="text-xs font-medium">
                      Safe Word: {client.safeWordStatus}
                    </p>
                  </div>
                )}
              </div>
            </div>

            {/* Silent Duress Warning */}
            {duressDetected && (
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                className="p-4 bg-red-500/10 border-2 border-red-500/40 rounded-lg animate-pulse-glow shadow-[0_0_20px_rgba(239,68,68,0.3)]"
              >
                <div className="flex items-center gap-2 mb-2">
                  <AlertTriangle className="w-5 h-5 text-red-400" />
                  <h3 className="text-sm font-bold text-red-400">SILENT DURESS DETECTED</h3>
                </div>
                <p className="text-xs text-red-400/80 mb-3">
                  Voice stress analysis indicates potential duress situation
                </p>
                <button className="w-full px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded-lg font-medium text-sm transition-all duration-200">
                  FORCED DISPATCH
                </button>
              </motion.div>
            )}
          </div>
        )}

        {activeTab === 'voip' && (
          <div className="space-y-3">
            {/* VoIP Status */}
            <div className="p-3 bg-cyan-500/10 border border-cyan-500/20 rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <Volume2 className="w-4 h-4 text-cyan-400" />
                <span className="text-xs font-medium text-cyan-400">VoIP Call Active</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 bg-cyan-400 rounded-full animate-pulse-dot" />
                <span className="text-xs text-white/60">Recording in progress</span>
              </div>
            </div>

            {/* Transcript */}
            <div className="space-y-2">
              {voipTranscript?.map((entry, index) => (
                <div
                  key={index}
                  className={`p-3 rounded-lg ${
                    entry.speaker === 'AI'
                      ? 'bg-cyan-500/5 border-l-2 border-cyan-500/40'
                      : 'bg-white/5 border-l-2 border-white/20'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className={`text-xs font-bold ${
                      entry.speaker === 'AI' ? 'text-cyan-400' : 'text-white/80'
                    }`}>
                      {entry.speaker}
                    </span>
                    <span className="text-xs text-white/40 font-mono">{entry.timestamp}</span>
                  </div>
                  <p className="text-sm text-white/90">{entry.message}</p>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'visual' && visualNorm && (
          <div className="space-y-4">
            {/* Match Score */}
            <div className="p-4 bg-[#0F1419] border border-white/10 rounded-lg">
              <div className="flex items-center gap-2 mb-3">
                <Eye className="w-4 h-4 text-cyan-400" />
                <h3 className="text-xs uppercase tracking-wider text-white/60 font-semibold">
                  Visual Verification
                </h3>
              </div>
              
              <div className="flex items-center justify-between mb-4">
                <div>
                  <p className="text-xs text-white/40 mb-1">Match Score</p>
                  <p className={`text-3xl font-light ${
                    visualNorm.matchScore >= 95 ? 'text-emerald-400' :
                    visualNorm.matchScore >= 60 ? 'text-yellow-400' :
                    'text-red-400'
                  }`}>
                    {visualNorm.matchScore}%
                  </p>
                </div>
                <div className="relative w-16 h-16">
                  <svg className="w-16 h-16 transform -rotate-90">
                    <circle
                      cx="32"
                      cy="32"
                      r="28"
                      stroke="rgba(255,255,255,0.1)"
                      strokeWidth="4"
                      fill="none"
                    />
                    <circle
                      cx="32"
                      cy="32"
                      r="28"
                      stroke={
                        visualNorm.matchScore >= 95 ? '#10B981' :
                        visualNorm.matchScore >= 60 ? '#FACC15' :
                        '#EF4444'
                      }
                      strokeWidth="4"
                      fill="none"
                      strokeDasharray={`${2 * Math.PI * 28}`}
                      strokeDashoffset={2 * Math.PI * 28 * (1 - visualNorm.matchScore / 100)}
                      strokeLinecap="round"
                    />
                  </svg>
                </div>
              </div>

              {visualNorm.anomalies.length > 0 && (
                <div className="pt-3 border-t border-white/10">
                  <p className="text-xs text-white/40 mb-2">Detected Anomalies</p>
                  <ul className="space-y-1">
                    {visualNorm.anomalies.map((anomaly, index) => (
                      <li key={index} className="flex items-center gap-2 text-sm text-red-400">
                        <div className="w-1 h-1 bg-red-400 rounded-full" />
                        {anomaly}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
