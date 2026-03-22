import React from 'react';

export function LiveIndicator() {
  return (
    <div className="flex items-center gap-2">
      <div className="relative flex items-center justify-center">
        <div className="absolute w-2 h-2 bg-[var(--onyx-status-success)] rounded-full animate-ping opacity-75" />
        <div className="relative w-2 h-2 bg-[var(--onyx-status-success)] rounded-full" />
      </div>
      <span className="text-xs font-semibold text-[var(--onyx-status-success)] uppercase tracking-wider">
        Live
      </span>
    </div>
  );
}
