import React from 'react';

interface OnyxPillProps {
  label: string;
  value: string | number;
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'info';
  className?: string;
}

export function OnyxPill({ label, value, variant = 'default', className = '' }: OnyxPillProps) {
  const variantStyles = {
    default: 'bg-[var(--onyx-bg-elevated)] border-[var(--onyx-border-default)] text-[var(--onyx-text-primary)]',
    success: 'bg-[var(--onyx-status-success-bg)] border-[var(--onyx-status-success-border)] text-[var(--onyx-status-success)]',
    warning: 'bg-[var(--onyx-status-warning-bg)] border-[var(--onyx-status-warning-border)] text-[var(--onyx-status-warning)]',
    danger: 'bg-[var(--onyx-status-danger-bg)] border-[var(--onyx-status-danger-border)] text-[var(--onyx-status-danger)]',
    info: 'bg-[var(--onyx-status-info-bg)] border-[var(--onyx-status-info-border)] text-[var(--onyx-status-info)]',
  };

  return (
    <div className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full border ${variantStyles[variant]} ${className}`}>
      <span className="text-[10px] uppercase tracking-wider font-semibold opacity-70">
        {label}
      </span>
      <span className="text-sm font-bold tabular-nums">
        {value}
      </span>
    </div>
  );
}
