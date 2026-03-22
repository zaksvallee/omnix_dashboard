import React from 'react';

interface OnyxSummaryStatProps {
  label: string;
  value: string | number;
  trend?: React.ReactNode;
  icon?: React.ReactNode;
  status?: React.ReactNode;
  className?: string;
}

export function OnyxSummaryStat({ 
  label, 
  value, 
  trend, 
  icon, 
  status,
  className = '' 
}: OnyxSummaryStatProps) {
  return (
    <div className={`${className}`}>
      <div className="flex items-start justify-between gap-2 mb-2">
        <div className="flex items-center gap-2">
          {icon && (
            <div className="text-[var(--onyx-accent-primary)] opacity-70">
              {icon}
            </div>
          )}
          <div className="text-[10px] text-[var(--onyx-text-tertiary)] uppercase tracking-widest font-semibold">
            {label}
          </div>
        </div>
        {status && <div>{status}</div>}
      </div>
      
      <div className="text-[24px] font-bold text-[var(--onyx-text-primary)] tabular-nums leading-none mb-1">
        {value}
      </div>
      
      {trend && (
        <div className="text-xs text-[var(--onyx-text-tertiary)]">
          {trend}
        </div>
      )}
    </div>
  );
}
