import React from 'react';

interface OnyxInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
}

export function OnyxInput({ label, className = '', ...props }: OnyxInputProps) {
  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label className="text-xs text-[var(--onyx-text-secondary)] font-medium">
          {label}
        </label>
      )}
      <input
        className={`bg-[var(--onyx-bg-surface)] text-[var(--onyx-text-primary)] border border-[var(--onyx-border-default)] rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--onyx-accent-primary)]/50 hover:bg-[var(--onyx-bg-hover)] transition-colors placeholder:text-[var(--onyx-text-disabled)] ${className}`}
        {...props}
      />
    </div>
  );
}
