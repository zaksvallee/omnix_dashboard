import React from 'react';
import { TrendingUp, Tag, ChevronUp, ChevronDown, Eye } from 'lucide-react';

interface LearnedStyleCardProps {
  pattern: string;
  confidence: number;
  usageCount: number;
  tags: string[];
  isTop?: boolean;
  onPromote?: () => void;
  onDemote?: () => void;
  onTag?: () => void;
  onView?: () => void;
}

export function LearnedStyleCard({
  pattern,
  confidence,
  usageCount,
  tags,
  isTop = false,
  onPromote,
  onDemote,
  onTag,
  onView
}: LearnedStyleCardProps) {
  return (
    <div className={`
      bg-[#0A0E13] border rounded-xl p-5 hover:border-cyan-500/30 transition-all group
      ${isTop ? 'border-cyan-500/30 bg-gradient-to-br from-cyan-950/20 to-blue-950/20' : 'border-[#21262D]'}
    `}>
      <div className="flex items-start justify-between mb-4">
        <div className="flex-1">
          {isTop && (
            <div className="inline-flex items-center gap-1.5 px-2 py-1 bg-cyan-500/20 text-cyan-400 rounded-md border border-cyan-500/30 text-[10px] font-bold uppercase tracking-wider mb-2">
              <TrendingUp className="w-3 h-3" />
              Top Learned Style
            </div>
          )}
          <p className="text-sm text-white/90 leading-relaxed mb-3">{pattern}</p>
          
          {/* Tags */}
          {tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {tags.map((tag, idx) => (
                <span
                  key={idx}
                  className="px-2 py-0.5 bg-purple-500/10 text-purple-400 text-[10px] font-semibold rounded border border-purple-500/20"
                >
                  {tag}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Metrics */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        <div className="bg-[#0D1117] border border-[#21262D] rounded-lg p-2.5">
          <div className="text-[10px] text-white/40 uppercase tracking-wider font-semibold mb-1">Confidence</div>
          <div className="flex items-center gap-2">
            <div className="flex-1 h-1.5 bg-[#0A0E13] rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-emerald-500 to-teal-500 rounded-full transition-all"
                style={{ width: `${confidence}%` }}
              />
            </div>
            <span className="text-sm font-bold text-emerald-400 tabular-nums">{confidence}%</span>
          </div>
        </div>
        <div className="bg-[#0D1117] border border-[#21262D] rounded-lg p-2.5">
          <div className="text-[10px] text-white/40 uppercase tracking-wider font-semibold mb-1">Usage</div>
          <div className="text-sm font-bold text-white tabular-nums">{usageCount} times</div>
        </div>
      </div>

      {/* Actions */}
      <div className="grid grid-cols-4 gap-2">
        {onDemote && (
          <button
            onClick={onDemote}
            className="px-2 py-1.5 bg-[#0D1117] hover:bg-white/5 text-white/60 hover:text-white rounded-md border border-[#21262D] transition-all flex items-center justify-center gap-1 text-xs font-semibold"
            title="Demote"
          >
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        )}
        {onPromote && (
          <button
            onClick={onPromote}
            className="px-2 py-1.5 bg-[#0D1117] hover:bg-cyan-500/10 text-white/60 hover:text-cyan-400 rounded-md border border-[#21262D] hover:border-cyan-500/30 transition-all flex items-center justify-center gap-1 text-xs font-semibold"
            title="Promote"
          >
            <ChevronUp className="w-3.5 h-3.5" />
          </button>
        )}
        <button
          onClick={onTag}
          className="px-2 py-1.5 bg-[#0D1117] hover:bg-purple-500/10 text-white/60 hover:text-purple-400 rounded-md border border-[#21262D] hover:border-purple-500/30 transition-all flex items-center justify-center gap-1 text-xs font-semibold"
          title="Add tag"
        >
          <Tag className="w-3.5 h-3.5" />
        </button>
        <button
          onClick={onView}
          className="col-span-2 px-2 py-1.5 bg-[#0D1117] hover:bg-white/5 text-white/60 hover:text-white rounded-md border border-[#21262D] transition-all flex items-center justify-center gap-1.5 text-xs font-semibold"
        >
          <Eye className="w-3.5 h-3.5" />
          View Context
        </button>
      </div>
    </div>
  );
}
