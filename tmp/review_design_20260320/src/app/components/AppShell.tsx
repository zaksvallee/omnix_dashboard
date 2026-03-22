import React, { useState } from 'react';
import { Outlet, Link, useLocation } from 'react-router';
import { 
  Zap, 
  Brain, 
  Map, 
  Shield, 
  Send, 
  Users, 
  Building2, 
  Activity, 
  BookOpen, 
  FileText,
  Settings,
  Briefcase,
  Bell,
  Search
} from 'lucide-react';

export function AppShell() {
  const location = useLocation();

  const navigation = [
    { name: 'OPERATIONS', path: '/', icon: Zap, badge: null },
    { name: 'AI QUEUE', path: '/ai-queue', icon: Brain, badge: '3' },
    { name: 'TACTICAL', path: '/tactical', icon: Map, badge: null },
    { name: 'GOVERNANCE', path: '/governance', icon: Shield, badge: null },
    { name: 'CLIENTS', path: '/clients', icon: Briefcase, badge: null },
    { name: 'SITES', path: '/sites', icon: Building2, badge: null },
    { name: 'GUARDS', path: '/guards', icon: Users, badge: null },
    { name: 'DISPATCHES', path: '/dispatches', icon: Send, badge: '5' },
    { name: 'EVENTS', path: '/events', icon: Activity, badge: null },
    { name: 'LEDGER', path: '/ledger', icon: BookOpen, badge: null },
    { name: 'REPORTS', path: '/reports', icon: FileText, badge: null },
    { name: 'ADMIN', path: '/admin', icon: Settings, badge: null },
  ];

  const isActive = (path: string) => {
    if (path === '/') return location.pathname === '/';
    return location.pathname.startsWith(path);
  };

  return (
    <div className="h-screen flex bg-[#0A0E13]">
      {/* Compact Sidebar - 72px */}
      <aside className="w-[72px] bg-[#0D1117] border-r border-[#21262D] flex flex-col items-center py-4 gap-1">
        {/* Logo */}
        <div className="w-12 h-12 mb-4 bg-gradient-to-br from-cyan-400 via-cyan-500 to-blue-600 rounded-xl flex items-center justify-center shadow-lg shadow-cyan-500/20">
          <Shield className="w-7 h-7 text-white" strokeWidth={2.5} />
        </div>

        {/* Navigation Icons */}
        <div className="flex-1 w-full space-y-1 px-2">
          {navigation.map((item) => {
            const Icon = item.icon;
            const active = isActive(item.path);
            
            return (
              <Link
                key={item.path}
                to={item.path}
                className={`
                  relative group flex items-center justify-center w-14 h-14 rounded-xl transition-all
                  ${active 
                    ? 'bg-cyan-500/15 text-cyan-400 shadow-lg shadow-cyan-500/10' 
                    : 'text-white/40 hover:text-white/70 hover:bg-white/5'
                  }
                `}
                title={item.name}
              >
                <Icon className="w-5 h-5" strokeWidth={active ? 2.5 : 2} />
                {item.badge && (
                  <div className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 rounded-full flex items-center justify-center text-[10px] font-bold text-white border-2 border-[#0D1117]">
                    {item.badge}
                  </div>
                )}
                {active && (
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-cyan-400 rounded-r-full" />
                )}
                
                {/* Tooltip */}
                <div className="absolute left-full ml-2 px-3 py-2 bg-[#161B22] border border-[#30363D] rounded-lg text-xs font-semibold text-white whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-50 shadow-xl">
                  {item.name}
                  <div className="absolute right-full top-1/2 -translate-y-1/2 border-4 border-transparent border-r-[#161B22]" />
                </div>
              </Link>
            );
          })}
        </div>

        {/* User/Settings at bottom */}
        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-sm font-bold border-2 border-[#21262D] cursor-pointer hover:border-cyan-400 transition-colors">
          OC
        </div>
      </aside>

      {/* Main Content Area with Top Bar */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Top Command Bar */}
        <header className="h-14 bg-[#0D1117] border-b border-[#21262D] flex items-center px-6 gap-4 flex-shrink-0">
          {/* Page Title - Dynamic */}
          <div className="flex items-center gap-3">
            <h1 className="text-sm font-bold text-white/90 uppercase tracking-widest">
              {navigation.find(n => isActive(n.path))?.name || 'ONYX'}
            </h1>
          </div>

          {/* Quick Search */}
          <div className="flex-1 max-w-md">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
              <input 
                type="text"
                placeholder="Quick jump... (⌘K)"
                className="w-full h-9 pl-10 pr-4 bg-[#0A0E13] border border-[#21262D] rounded-lg text-sm text-white placeholder:text-white/30 focus:border-cyan-500/50 focus:outline-none focus:ring-1 focus:ring-cyan-500/30 transition-all"
              />
            </div>
          </div>

          {/* Status Bar */}
          <div className="flex items-center gap-4 ml-auto">
            {/* System Status */}
            <div className="flex items-center gap-2 px-3 py-1.5 bg-emerald-500/10 border border-emerald-500/20 rounded-md">
              <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
              <span className="text-xs font-semibold text-emerald-400 uppercase tracking-wider">SYSTEMS NOMINAL</span>
            </div>

            {/* Notifications */}
            <button className="relative w-9 h-9 flex items-center justify-center rounded-lg text-white/60 hover:text-white hover:bg-white/5 transition-all">
              <Bell className="w-4 h-4" />
              <div className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full border border-[#0D1117]" />
            </button>

            {/* Time */}
            <div className="text-xs font-mono text-white/60 tabular-nums">
              {new Date().toLocaleTimeString('en-US', { hour12: false })}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-hidden bg-[#0A0E13]">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
