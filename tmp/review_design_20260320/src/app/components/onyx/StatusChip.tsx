import React from 'react';

export type StatusVariant = 'success' | 'warning' | 'critical' | 'danger' | 'intel' | 'info' | 'neutral';

interface StatusChipProps {
  variant: StatusVariant;
  children: React.ReactNode;
  className?: string;
  size?: 'sm' | 'md';
}

export function StatusChip({ variant, children, className = '', size = 'md' }: StatusChipProps) {
  const variantStyles = {
    success: 'bg-[var(--onyx-status-success-bg)] text-[var(--onyx-status-success)] border-[var(--onyx-status-success-border)]',
    warning: 'bg-[var(--onyx-status-warning-bg)] text-[var(--onyx-status-warning)] border-[var(--onyx-status-warning-border)]',
    critical: 'bg-[var(--onyx-status-danger-bg)] text-[var(--onyx-status-danger)] border-[var(--onyx-status-danger-border)]',
    danger: 'bg-[var(--onyx-status-danger-bg)] text-[var(--onyx-status-danger)] border-[var(--onyx-status-danger-border)]',
    intel: 'bg-[var(--onyx-status-intel-bg)] text-[var(--onyx-status-intel)] border-[var(--onyx-status-intel-border)]',
    info: 'bg-[var(--onyx-status-info-bg)] text-[var(--onyx-status-info)] border-[var(--onyx-status-info-border)]',
    neutral: 'bg-[var(--onyx-bg-elevated)] text-[var(--onyx-text-secondary)] border-[var(--onyx-border-default)]',
  };

  const sizeStyles = {
    sm: 'px-2 py-0.5 text-xs',
    md: 'px-2.5 py-1 text-xs',
  };

  return (
    <span
      className={`inline-flex items-center gap-1 rounded border font-medium uppercase tracking-wider ${variantStyles[variant]} ${sizeStyles[size]} ${className}`}
    >
      {children}
    </span>
  );
}