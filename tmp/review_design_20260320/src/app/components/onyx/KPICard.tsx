import React from 'react';
import { StatusChip, StatusVariant } from './StatusChip';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { motion } from 'motion/react';

interface KPICardProps {
  label: string;
  value: string | number;
  status?: 'success' | 'warning' | 'critical' | 'normal';
  statusText?: string;
  trend?: { direction: 'up' | 'down' | 'neutral'; value: number };
  subtitle?: string;
  className?: string;
  icon?: React.ReactNode;
}

export function KPICard({ label, value, status, statusText, trend, subtitle, className = '', icon }: KPICardProps) {
  const getStatusColor = () => {
    switch (status) {
      case 'success':
        return 'bg-emerald-500/10 border-emerald-500/20';
      case 'warning':
        return 'bg-amber-500/10 border-amber-500/20';
      case 'critical':
        return 'bg-red-500/10 border-red-500/20';
      default:
        return 'bg-white/5 border-white/10';
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className={`bg-[#0F1419] border border-white/10 rounded-lg p-8 hover:border-white/20 transition-all duration-300 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)] ${className}`}
    >
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div className="flex-1">
          <p className="text-xs uppercase tracking-wider text-white/40 mb-1">{label}</p>
          <div className="flex items-baseline gap-3">
            <motion.span 
              className="text-5xl font-light text-white animate-count"
              key={value}
            >
              {value}
            </motion.span>
            {trend && (
              <span className={`text-sm flex items-center gap-1 ${
                trend.direction === 'up' ? 'text-emerald-400' : 
                trend.direction === 'down' ? 'text-red-400' : 
                'text-white/40'
              }`}>
                {trend.direction === 'up' ? <TrendingUp className="w-4 h-4" /> :
                 trend.direction === 'down' ? <TrendingDown className="w-4 h-4" /> :
                 <Minus className="w-4 h-4" />}
                {trend.direction === 'up' ? '+' : trend.direction === 'down' ? '-' : ''}{trend.value}%
              </span>
            )}
          </div>
          {subtitle && (
            <p className="text-xs text-white/40 mt-2">{subtitle}</p>
          )}
        </div>
        {icon && (
          <div className={`p-3 rounded-lg ${getStatusColor()}`}>
            <div className={status === 'success' ? 'text-emerald-400' : 
                          status === 'warning' ? 'text-amber-400' : 
                          status === 'critical' ? 'text-red-400' : 
                          'text-cyan-400'}>
              {icon}
            </div>
          </div>
        )}
      </div>
    </motion.div>
  );
}