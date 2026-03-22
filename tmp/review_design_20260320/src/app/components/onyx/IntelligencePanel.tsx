import React from 'react';
import { StatusChip, StatusVariant } from './StatusChip';

export interface IntelligenceItem {
  id: string;
  title: string;
  source: string;
  timestamp: string;
  priority: StatusVariant;
  priorityLabel: string;
  category?: string;
}

interface IntelligencePanelProps {
  items: IntelligenceItem[];
  maxHeight?: string;
  className?: string;
}

export function IntelligencePanel({ items, maxHeight = '400px', className = '' }: IntelligencePanelProps) {
  return (
    <div 
      className={`overflow-y-auto ${className}`}
      style={{ maxHeight }}
    >
      {items.map((item, index) => (
        <div
          key={item.id}
          className={`bg-[var(--onyx-bg-surface)] hover:bg-[var(--onyx-bg-hover)] border-b border-[var(--onyx-border-subtle)] last:border-b-0 p-4 cursor-pointer transition-colors ${
            item.priority === 'critical' || item.priority === 'danger' ? 'border-l-2 border-l-[var(--onyx-status-danger)]' : ''
          }`}
        >
          <div className="flex items-start justify-between gap-3 mb-2">
            <h4 className="text-sm font-medium text-[var(--onyx-text-primary)] line-clamp-2 flex-1">
              {item.title}
            </h4>
            <StatusChip variant={item.priority} size="sm">{item.priorityLabel}</StatusChip>
          </div>
          <div className="flex items-center gap-2 text-xs text-[var(--onyx-text-tertiary)]">
            <span className="font-medium text-[var(--onyx-accent-steel)]">{item.source}</span>
            <span>•</span>
            <span className="tabular-nums">{item.timestamp}</span>
            {item.category && (
              <>
                <span>•</span>
                <span className="uppercase tracking-wide">{item.category}</span>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}