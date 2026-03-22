import React from 'react';
import { ChevronDown } from 'lucide-react';

interface ControlGroupProps {
  title: string;
  children: React.ReactNode;
  className?: string;
  collapsible?: boolean;
}

export function ControlGroup({ title, children, className = '', collapsible = false }: ControlGroupProps) {
  const [isOpen, setIsOpen] = React.useState(true);

  return (
    <div className={`border border-[var(--onyx-border-subtle)] rounded-lg ${className}`}>
      <button
        onClick={() => collapsible && setIsOpen(!isOpen)}
        className={`w-full flex items-center justify-between gap-2 px-4 py-2.5 text-left ${
          collapsible ? 'cursor-pointer hover:bg-[var(--onyx-bg-hover)]' : ''
        } transition-colors`}
      >
        <span className="text-xs font-semibold text-[var(--onyx-text-secondary)] uppercase tracking-wider">
          {title}
        </span>
        {collapsible && (
          <ChevronDown
            className={`w-3.5 h-3.5 text-[var(--onyx-text-tertiary)] transition-transform ${
              isOpen ? '' : '-rotate-90'
            }`}
          />
        )}
      </button>
      {isOpen && (
        <div className="px-4 pb-3 pt-1">
          {children}
        </div>
      )}
    </div>
  );
}
