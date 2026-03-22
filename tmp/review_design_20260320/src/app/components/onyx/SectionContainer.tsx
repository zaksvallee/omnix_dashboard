import React from 'react';

interface SectionContainerProps {
  title?: string;
  subtitle?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  noPadding?: boolean;
}

export function SectionContainer({ 
  title, 
  subtitle, 
  action, 
  children, 
  className = '',
  noPadding = false
}: SectionContainerProps) {
  return (
    <div 
      className={`bg-[var(--onyx-bg-elevated)] border border-[var(--onyx-border-default)] rounded-lg ${className}`}
      style={{ boxShadow: 'var(--onyx-shadow-sm)' }}
    >
      {(title || action) && (
        <div className="flex items-center justify-between gap-4 px-6 py-4 border-b border-[var(--onyx-border-subtle)]">
          <div className="flex-1 min-w-0">
            {title && (
              <h3 className="text-sm font-semibold text-[var(--onyx-text-primary)] uppercase tracking-wide">
                {title}
              </h3>
            )}
            {subtitle && (
              <p className="text-xs text-[var(--onyx-text-tertiary)] mt-1">
                {subtitle}
              </p>
            )}
          </div>
          {action && <div className="flex-shrink-0">{action}</div>}
        </div>
      )}
      <div className={noPadding ? '' : 'p-6'}>
        {children}
      </div>
    </div>
  );
}