import React from 'react';
import { ChevronDown } from 'lucide-react';

interface SelectOption {
  value: string;
  label: string;
}

interface OnyxSelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  options?: SelectOption[];
  children?: React.ReactNode;
  placeholder?: string;
  className?: string;
}

export function OnyxSelect({ options, value, onChange, placeholder, className = '', children, ...props }: OnyxSelectProps) {
  return (
    <div className={`relative ${className}`}>
      <select
        value={value}
        onChange={onChange}
        className="w-full appearance-none bg-[var(--onyx-bg-surface)] text-[var(--onyx-text-primary)] border border-[var(--onyx-border-default)] rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-[var(--onyx-accent-primary)]/50 hover:bg-[var(--onyx-bg-hover)] transition-colors cursor-pointer pr-8"
        {...props}
      >
        {placeholder && <option value="">{placeholder}</option>}
        {options && Array.isArray(options) ? (
          options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))
        ) : (
          children
        )}
      </select>
      <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--onyx-text-tertiary)] pointer-events-none" />
    </div>
  );
}
