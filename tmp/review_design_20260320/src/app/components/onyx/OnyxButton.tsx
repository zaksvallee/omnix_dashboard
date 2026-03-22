import React from 'react';

type ButtonVariant = 'primary' | 'secondary' | 'tertiary' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface OnyxButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  children: React.ReactNode;
}

export function OnyxButton({ 
  variant = 'secondary', 
  size = 'md', 
  children, 
  className = '',
  ...props 
}: OnyxButtonProps) {
  const variantStyles = {
    primary: 'bg-[var(--onyx-accent-primary)] text-white hover:bg-[var(--onyx-accent-primary-hover)] active:bg-[var(--onyx-accent-primary-active)] border-[var(--onyx-accent-primary)]',
    secondary: 'bg-[var(--onyx-bg-surface)] text-[var(--onyx-text-primary)] hover:bg-[var(--onyx-bg-hover)] border-[var(--onyx-border-default)] hover:border-[var(--onyx-border-medium)]',
    tertiary: 'bg-transparent text-[var(--onyx-text-secondary)] hover:text-[var(--onyx-text-primary)] hover:bg-[var(--onyx-bg-hover)] border-transparent',
    danger: 'bg-[var(--onyx-status-danger-bg)] text-[var(--onyx-status-danger)] hover:bg-[var(--onyx-status-danger)]/10 border-[var(--onyx-status-danger-border)] hover:border-[var(--onyx-status-danger)]',
  };

  const sizeStyles = {
    sm: 'px-3 py-1.5 text-xs',
    md: 'px-4 py-2 text-sm',
    lg: 'px-5 py-2.5 text-sm',
  };

  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-md border font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-[var(--onyx-accent-primary)]/40 disabled:opacity-50 disabled:pointer-events-none ${variantStyles[variant]} ${sizeStyles[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}