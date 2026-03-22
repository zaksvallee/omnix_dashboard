import React, { useState } from 'react';
import { X, Send, Sparkles, AlertCircle } from 'lucide-react';
import { CueChip } from './CueChip';

interface RefineDialogProps {
  incidentId: string;
  originalDraft: string;
  cues: Array<'timing' | 'sensitive' | 'validation' | 'detail' | 'reassurance' | 'concise' | 'next-step' | 'formal'>;
  onClose: () => void;
  onApprove: (refinedText: string) => void;
}

export function RefineDialog({ incidentId, originalDraft, cues, onClose, onApprove }: RefineDialogProps) {
  const [draftText, setDraftText] = useState(originalDraft);
  const [liveCues, setLiveCues] = useState(cues);

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-6">
      <div className="bg-[#0D1117] border border-[#21262D] rounded-2xl w-full max-w-3xl shadow-2xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="border-b border-[#21262D] px-6 py-4 flex items-center justify-between flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center border border-cyan-500/30">
              <Sparkles className="w-5 h-5 text-cyan-400" strokeWidth={2} />
            </div>
            <div>
              <h2 className="text-lg font-bold text-white uppercase tracking-wide">Refine Draft</h2>
              <p className="text-sm text-white/50 mt-0.5 font-mono">{incidentId}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-9 h-9 rounded-lg hover:bg-white/5 text-white/60 hover:text-white transition-all flex items-center justify-center"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Live Review Cues */}
          <div className="bg-gradient-to-br from-purple-950/30 to-pink-950/30 border border-purple-500/20 rounded-xl p-5">
            <div className="flex items-start gap-3 mb-3">
              <AlertCircle className="w-5 h-5 text-purple-400 flex-shrink-0 mt-0.5" />
              <div className="flex-1">
                <h3 className="text-sm font-bold text-purple-300 uppercase tracking-wider mb-1">
                  Live Review Cues
                </h3>
                <p className="text-xs text-purple-400/70 leading-relaxed">
                  These cues update as you edit. AI detects timing sensitivity, reassurance needs, and detail requirements.
                </p>
              </div>
            </div>
            <div className="flex flex-wrap gap-2">
              {liveCues.map((cue, idx) => (
                <CueChip key={idx} type={cue} size="md" />
              ))}
            </div>
          </div>

          {/* Draft Editor */}
          <div>
            <label className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2 block">
              Draft Message
            </label>
            <textarea
              value={draftText}
              onChange={(e) => setDraftText(e.target.value)}
              className="w-full h-48 px-4 py-3 bg-[#0A0E13] border border-[#21262D] rounded-xl text-white placeholder:text-white/30 focus:border-cyan-500/50 focus:outline-none focus:ring-1 focus:ring-cyan-500/30 transition-all resize-none text-sm leading-relaxed"
              placeholder="Edit the AI-generated draft..."
            />
            <div className="mt-2 flex items-center justify-between text-xs text-white/40">
              <span>Edit freely - AI will re-analyze cues</span>
              <span className="font-mono tabular-nums">{draftText.length} chars</span>
            </div>
          </div>

          {/* Quick Voice Adjustments */}
          <div>
            <label className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2 block">
              Quick Voice Adjustments
            </label>
            <div className="grid grid-cols-2 gap-2">
              <button className="px-3 py-2 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-xs font-semibold">
                Make More Concise
              </button>
              <button className="px-3 py-2 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-xs font-semibold">
                Add Reassurance
              </button>
              <button className="px-3 py-2 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-xs font-semibold">
                More Formal
              </button>
              <button className="px-3 py-2 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-xs font-semibold">
                Add Next Steps
              </button>
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="border-t border-[#21262D] px-6 py-4 flex items-center justify-between flex-shrink-0 bg-[#0A0E13]">
          <button
            onClick={onClose}
            className="px-4 py-2 text-white/60 hover:text-white text-sm font-semibold transition-colors"
          >
            Cancel
          </button>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-lg border border-[#21262D] text-sm font-semibold transition-all">
              Save as Draft
            </button>
            <button
              onClick={() => onApprove(draftText)}
              className="px-5 py-2 bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white rounded-lg shadow-lg shadow-emerald-500/20 text-sm font-bold uppercase tracking-wider transition-all flex items-center gap-2"
            >
              <Send className="w-4 h-4" />
              Approve & Send
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
