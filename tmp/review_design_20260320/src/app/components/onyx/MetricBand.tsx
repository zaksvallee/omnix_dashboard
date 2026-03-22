import React from 'react';

interface MetricBandProps {
  metrics: {
    label: string;
    value: string | number;
    unit?: string;
  }[];
  className?: string;
}

export function MetricBand({ metrics, className = '' }: MetricBandProps) {
  return (
    <div className={`flex items-center gap-6 ${className}`}>
      {metrics.map((metric, index) => (
        <div key={metric.label} className="flex items-center gap-6">
          <div className="flex items-baseline gap-2">
            <span className="text-xs text-[var(--onyx-text-tertiary)] uppercase tracking-wide">
              {metric.label}
            </span>
            <span className="text-base font-semibold text-[var(--onyx-text-primary)] tabular-nums">
              {metric.value}
              {metric.unit && (
                <span className="text-xs text-[var(--onyx-text-secondary)] ml-1 font-normal">
                  {metric.unit}
                </span>
              )}
            </span>
          </div>
          {index < metrics.length - 1 && (
            <div className="w-px h-4 bg-[var(--onyx-border-default)]" />
          )}
        </div>
      ))}
    </div>
  );
}