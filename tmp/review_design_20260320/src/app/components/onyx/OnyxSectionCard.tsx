import React from 'react';

interface OnyxSectionCardProps {
  title?: string;
  subtitle?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  noPadding?: boolean;
  compact?: boolean;
}

export function OnyxSectionCard({ 
  title, 
  subtitle, 
  action, 
  children, 
  className = '',
  noPadding = false,
  compact = false
}: OnyxSectionCardProps) {
  return (
    <div 
      className={`bg-[var(--onyx-bg-elevated)] border border-[var(--onyx-border-default)] rounded-lg ${className}`}
      style={{ boxShadow: 'var(--onyx-shadow-sm)' }}
    >
      {(title || action) && (
        <div className="flex items-center justify-between gap-4 px-3 py-3 border-b border-[var(--onyx-border-subtle)]">
          <div className="flex-1 min-w-0">
            {title && (
              <h3 className="text-[21px] font-semibold text-[var(--onyx-text-primary)] leading-tight">
                {title}
              </h3>
            )}
            {subtitle && (
              <p className="text-xs text-[var(--onyx-text-tertiary)] mt-0.5">
                {subtitle}
              </p>
            )}
          </div>
          {action && <div className="flex-shrink-0">{action}</div>}
        </div>
      )}
      <div className={noPadding ? '' : (compact ? 'p-3' : 'p-3')}>
        {children}
      </div>
    </div>
  );
}
