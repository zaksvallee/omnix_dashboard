import React from 'react';

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="flex h-screen bg-[var(--onyx-bg-primary)]">
      {/* Sidebar - 252px */}
      <aside 
        className="flex-shrink-0 bg-[var(--onyx-bg-secondary)] border-r border-[var(--onyx-border-default)] flex flex-col"
        style={{ width: '252px', boxShadow: 'var(--onyx-shadow-md)' }}
      >
        {/* Brand Card */}
        <div className="p-4 border-b border-[var(--onyx-border-subtle)]">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded bg-[var(--onyx-accent-primary)] flex items-center justify-center">
              <div className="w-5 h-5 border-2 border-white rounded-sm" />
            </div>
            <div>
              <div className="text-base font-bold text-[var(--onyx-text-primary)] tracking-tight">
                ONYX
              </div>
              <div className="text-xs text-[var(--onyx-text-tertiary)]">
                Command Platform
              </div>
            </div>
          </div>
        </div>

        {/* Operational Fabric Card */}
        <div className="p-4 border-b border-[var(--onyx-border-subtle)]">
          <div className="text-[10px] text-[var(--onyx-text-tertiary)] uppercase tracking-widest font-semibold mb-2">
            Operational Fabric
          </div>
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--onyx-text-secondary)]">Region</span>
              <span className="text-[var(--onyx-text-primary)] font-medium">North America</span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--onyx-text-secondary)]">Sites</span>
              <span className="text-[var(--onyx-text-primary)] font-medium">47 Active</span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-[var(--onyx-text-secondary)]">Guards</span>
              <span className="text-[var(--onyx-text-primary)] font-medium">142 On Duty</span>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 p-3 overflow-y-auto">
          <div className="space-y-1">
            <NavItem label="Dashboard" active />
            <NavItem label="Dispatch Command" />
            <NavItem label="Events" />
            <NavItem label="Sites" />
            <NavItem label="Guards" />
            <NavItem label="Intelligence" />
            <NavItem label="Ledger" />
            <NavItem label="Reports" />
            <NavItem label="Client Portal" />
          </div>
        </nav>

        {/* Footer Card */}
        <div className="p-4 border-t border-[var(--onyx-border-subtle)]">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-[var(--onyx-bg-elevated)] border border-[var(--onyx-border-default)] flex items-center justify-center text-xs font-semibold text-[var(--onyx-text-primary)]">
              JD
            </div>
            <div className="flex-1 min-w-0">
              <div className="text-sm font-medium text-[var(--onyx-text-primary)] truncate">
                John Doe
              </div>
              <div className="text-xs text-[var(--onyx-text-tertiary)]">
                Command Operator
              </div>
            </div>
          </div>
        </div>
      </aside>

      {/* Content with gradient panel */}
      <main className="flex-1 overflow-auto bg-gradient-to-br from-[var(--onyx-bg-primary)] to-[var(--onyx-bg-base)]">
        {children}
      </main>
    </div>
  );
}

interface NavItemProps {
  label: string;
  active?: boolean;
}

function NavItem({ label, active }: NavItemProps) {
  return (
    <button
      className={`w-full px-3 py-2 rounded-md text-sm font-medium text-left transition-colors ${
        active
          ? 'bg-[var(--onyx-accent-primary)] text-white'
          : 'text-[var(--onyx-text-secondary)] hover:bg-[var(--onyx-bg-hover)] hover:text-[var(--onyx-text-primary)]'
      }`}
    >
      {label}
    </button>
  );
}
