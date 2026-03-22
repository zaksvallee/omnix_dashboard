import React from 'react';

interface OnyxPageHeaderProps {
  title: string;
  subtitle?: string;
  actions?: React.ReactNode;
  pills?: React.ReactNode;
}

export function OnyxPageHeader({ title, subtitle, actions, pills }: OnyxPageHeaderProps) {
  return (
    <div className="flex items-start justify-between gap-6 mb-6">
      <div className="flex-1 min-w-0">
        <h1 className="text-[32px] font-bold text-[var(--onyx-text-primary)] leading-tight tracking-tight mb-1">
          {title}
        </h1>
        {subtitle && (
          <p className="text-sm text-[var(--onyx-text-tertiary)]">
            {subtitle}
          </p>
        )}
      </div>
      {(pills || actions) && (
        <div className="flex items-center gap-3">
          {pills}
          {actions}
        </div>
      )}
    </div>
  );
}
