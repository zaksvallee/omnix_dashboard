import React from 'react';
import { 
  Activity, 
  AlertTriangle, 
  Shield, 
  TrendingUp,
  Users,
  MapPin,
  Clock,
  Zap,
  CheckCircle2,
  AlertOctagon,
  Target
} from 'lucide-react';
import { OnyxPageHeader } from '../components/onyx/OnyxPageHeader';
import { OnyxSectionCard } from '../components/onyx/OnyxSectionCard';
import { OnyxSummaryStat } from '../components/onyx/OnyxSummaryStat';
import { OnyxPill } from '../components/onyx/OnyxPill';
import { StatusChip } from '../components/onyx/StatusChip';
import { OnyxButton } from '../components/onyx/OnyxButton';

export function Dashboard() {
  return (
    <div className="p-6">
      {/* Top Bar */}
      <OnyxPageHeader
        title="Operational Dashboard"
        subtitle="Executive operational visibility and command posture"
        pills={
          <>
            <OnyxPill label="Last Event" value="2m ago" variant="info" />
            <OnyxPill label="Pressure" value="Normal" variant="success" />
            <OnyxPill label="Threat" value="Level 3" variant="warning" />
          </>
        }
      />

      {/* Desktop Layout: Left Content + Right Rail */}
      <div className="flex gap-6">
        {/* Left Content */}
        <div className="flex-1 space-y-6">
          {/* Operational Summary */}
          <OnyxSectionCard title="Operational Summary">
            <div className="grid grid-cols-4 gap-6">
              <OnyxSummaryStat
                label="Active Sites"
                value={47}
                icon={<MapPin className="w-4 h-4" />}
                trend="3 new this week"
              />
              <OnyxSummaryStat
                label="On-Duty Guards"
                value={142}
                icon={<Users className="w-4 h-4" />}
                trend="12 shifts active"
              />
              <OnyxSummaryStat
                label="Open Dispatches"
                value={8}
                icon={<Zap className="w-4 h-4" />}
                status={<StatusChip variant="warning" size="sm">Review</StatusChip>}
              />
              <OnyxSummaryStat
                label="Avg Response"
                value="2.4s"
                icon={<Clock className="w-4 h-4" />}
                status={<StatusChip variant="success" size="sm">Normal</StatusChip>}
              />
            </div>
          </OnyxSectionCard>

          {/* Live Signals + Dispatch Feed */}
          <div className="grid grid-cols-2 gap-6">
            <OnyxSectionCard 
              title="Live Signals"
              action={<OnyxButton variant="tertiary" size="sm">View All</OnyxButton>}
            >
              <div className="space-y-3">
                <SignalItem
                  title="Guard check-in completed"
                  time="2 minutes ago"
                  location="Site Alpha-7"
                  type="success"
                />
                <SignalItem
                  title="Motion sensor triggered"
                  time="8 minutes ago"
                  location="Site Bravo-3"
                  type="warning"
                />
                <SignalItem
                  title="Patrol route completed"
                  time="12 minutes ago"
                  location="Site Charlie-9"
                  type="success"
                />
                <SignalItem
                  title="Access control event"
                  time="18 minutes ago"
                  location="Site Delta-5"
                  type="info"
                />
              </div>
            </OnyxSectionCard>

            <OnyxSectionCard 
              title="Dispatch Feed"
              action={<OnyxButton variant="tertiary" size="sm">View All</OnyxButton>}
            >
              <div className="space-y-3">
                <DispatchItem
                  title="Emergency response"
                  guard="Unit Delta-4"
                  site="Site Alpha-7"
                  eta="4 min"
                  status="critical"
                />
                <DispatchItem
                  title="Routine patrol"
                  guard="Unit Echo-2"
                  site="Site Bravo-8"
                  eta="Arrived"
                  status="success"
                />
                <DispatchItem
                  title="Investigation required"
                  guard="Unit Foxtrot-1"
                  site="Site Charlie-3"
                  eta="8 min"
                  status="warning"
                />
              </div>
            </OnyxSectionCard>
          </div>

          {/* Site Posture */}
          <OnyxSectionCard 
            title="Site Posture"
            subtitle="Security status by operational site"
            action={<OnyxButton variant="tertiary" size="sm">View Map</OnyxButton>}
          >
            <div className="space-y-2">
              <SitePostureRow
                name="Site Alpha-7"
                status="Critical"
                guards={3}
                incidents={2}
                statusVariant="critical"
              />
              <SitePostureRow
                name="Site Bravo-3"
                status="Normal"
                guards={2}
                incidents={0}
                statusVariant="success"
              />
              <SitePostureRow
                name="Site Charlie-9"
                status="Elevated"
                guards={4}
                incidents={1}
                statusVariant="warning"
              />
              <SitePostureRow
                name="Site Delta-5"
                status="Normal"
                guards={2}
                incidents={0}
                statusVariant="success"
              />
              <SitePostureRow
                name="Site Echo-2"
                status="Normal"
                guards={3}
                incidents={0}
                statusVariant="success"
              />
            </div>
          </OnyxSectionCard>
        </div>

        {/* Right Rail - 328px */}
        <div className="flex-shrink-0 space-y-6" style={{ width: '328px' }}>
          {/* Threat Readout */}
          <OnyxSectionCard title="Threat Readout" compact>
            <div className="space-y-4">
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-[var(--onyx-text-secondary)]">
                    Current Level
                  </span>
                  <StatusChip variant="warning" size="sm">Level 3</StatusChip>
                </div>
                <div className="h-2 bg-[var(--onyx-bg-surface)] rounded-full overflow-hidden">
                  <div className="h-full w-[60%] bg-[var(--onyx-status-warning)] rounded-full" />
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-3">
                <div className="text-center p-3 bg-[var(--onyx-bg-surface)] rounded border border-[var(--onyx-border-subtle)]">
                  <div className="text-xl font-bold text-[var(--onyx-text-primary)] tabular-nums">
                    14
                  </div>
                  <div className="text-xs text-[var(--onyx-text-tertiary)] mt-1">
                    Active Threats
                  </div>
                </div>
                <div className="text-center p-3 bg-[var(--onyx-bg-surface)] rounded border border-[var(--onyx-border-subtle)]">
                  <div className="text-xl font-bold text-[var(--onyx-text-primary)] tabular-nums">
                    3
                  </div>
                  <div className="text-xs text-[var(--onyx-text-tertiary)] mt-1">
                    Critical
                  </div>
                </div>
              </div>
            </div>
          </OnyxSectionCard>

          {/* Operational Mix */}
          <OnyxSectionCard title="Operational Mix" compact>
            <div className="space-y-3">
              <MixItem label="Routine Patrol" value={24} total={47} color="var(--onyx-status-success)" />
              <MixItem label="Active Response" value={8} total={47} color="var(--onyx-status-warning)" />
              <MixItem label="Investigation" value={5} total={47} color="var(--onyx-status-info)" />
              <MixItem label="Standby" value={10} total={47} color="var(--onyx-text-tertiary)" />
            </div>
          </OnyxSectionCard>

          {/* Guard Sync Health */}
          <OnyxSectionCard title="Guard Sync Health" compact>
            <div className="space-y-3">
              <HealthMetric label="Check-In Rate" value="98.2%" status="success" />
              <HealthMetric label="GPS Accuracy" value="95.7%" status="success" />
              <HealthMetric label="Comm Quality" value="89.4%" status="warning" />
              <HealthMetric label="Response Time" value="2.4s" status="success" />
            </div>
          </OnyxSectionCard>

          {/* Command Notes */}
          <OnyxSectionCard 
            title="Command Notes"
            action={<OnyxButton variant="tertiary" size="sm">Add</OnyxButton>}
            compact
          >
            <div className="space-y-3">
              <NoteItem
                author="J. Doe"
                time="14:32"
                note="Elevated patrol frequency in Sector 7-B per threat assessment"
              />
              <NoteItem
                author="M. Smith"
                time="12:15"
                note="Weather alert issued for operational zones - monitoring conditions"
              />
            </div>
          </OnyxSectionCard>
        </div>
      </div>
    </div>
  );
}

// Helper Components

interface SignalItemProps {
  title: string;
  time: string;
  location: string;
  type: 'success' | 'warning' | 'info';
}

function SignalItem({ title, time, location, type }: SignalItemProps) {
  const iconColors = {
    success: 'text-[var(--onyx-status-success)]',
    warning: 'text-[var(--onyx-status-warning)]',
    info: 'text-[var(--onyx-status-info)]',
  };

  return (
    <div className="flex items-start gap-3 pb-3 border-b border-[var(--onyx-border-subtle)] last:border-b-0">
      <CheckCircle2 className={`w-4 h-4 mt-0.5 flex-shrink-0 ${iconColors[type]}`} />
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium text-[var(--onyx-text-primary)] mb-0.5">
          {title}
        </div>
        <div className="text-xs text-[var(--onyx-text-tertiary)]">
          {location} • {time}
        </div>
      </div>
    </div>
  );
}

interface DispatchItemProps {
  title: string;
  guard: string;
  site: string;
  eta: string;
  status: 'critical' | 'warning' | 'success';
}

function DispatchItem({ title, guard, site, eta, status }: DispatchItemProps) {
  return (
    <div className="p-3 bg-[var(--onyx-bg-surface)] rounded border border-[var(--onyx-border-subtle)]">
      <div className="flex items-start justify-between gap-2 mb-2">
        <div className="text-sm font-medium text-[var(--onyx-text-primary)]">
          {title}
        </div>
        <StatusChip variant={status} size="sm">
          {eta}
        </StatusChip>
      </div>
      <div className="text-xs text-[var(--onyx-text-tertiary)]">
        {guard} → {site}
      </div>
    </div>
  );
}

interface SitePostureRowProps {
  name: string;
  status: string;
  guards: number;
  incidents: number;
  statusVariant: 'success' | 'warning' | 'critical';
}

function SitePostureRow({ name, status, guards, incidents, statusVariant }: SitePostureRowProps) {
  return (
    <div className="flex items-center justify-between p-3 bg-[var(--onyx-bg-surface)] rounded border border-[var(--onyx-border-subtle)] hover:border-[var(--onyx-border-medium)] transition-colors">
      <div className="flex items-center gap-3">
        <Shield className="w-4 h-4 text-[var(--onyx-accent-primary)]" />
        <div>
          <div className="text-sm font-medium text-[var(--onyx-text-primary)]">
            {name}
          </div>
          <div className="text-xs text-[var(--onyx-text-tertiary)]">
            {guards} guards • {incidents} incidents
          </div>
        </div>
      </div>
      <StatusChip variant={statusVariant} size="sm">
        {status}
      </StatusChip>
    </div>
  );
}

interface MixItemProps {
  label: string;
  value: number;
  total: number;
  color: string;
}

function MixItem({ label, value, total, color }: MixItemProps) {
  const percentage = (value / total) * 100;
  
  return (
    <div>
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-xs text-[var(--onyx-text-secondary)]">{label}</span>
        <span className="text-xs font-semibold text-[var(--onyx-text-primary)] tabular-nums">
          {value}
        </span>
      </div>
      <div className="h-1.5 bg-[var(--onyx-bg-surface)] rounded-full overflow-hidden">
        <div 
          className="h-full rounded-full transition-all" 
          style={{ width: `${percentage}%`, backgroundColor: color }}
        />
      </div>
    </div>
  );
}

interface HealthMetricProps {
  label: string;
  value: string;
  status: 'success' | 'warning';
}

function HealthMetric({ label, value, status }: HealthMetricProps) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-xs text-[var(--onyx-text-secondary)]">{label}</span>
      <div className="flex items-center gap-2">
        <span className="text-sm font-semibold text-[var(--onyx-text-primary)] tabular-nums">
          {value}
        </span>
        <div 
          className={`w-2 h-2 rounded-full ${
            status === 'success' ? 'bg-[var(--onyx-status-success)]' : 'bg-[var(--onyx-status-warning)]'
          }`}
        />
      </div>
    </div>
  );
}

interface NoteItemProps {
  author: string;
  time: string;
  note: string;
}

function NoteItem({ author, time, note }: NoteItemProps) {
  return (
    <div className="pb-3 border-b border-[var(--onyx-border-subtle)] last:border-b-0">
      <div className="text-xs text-[var(--onyx-text-tertiary)] mb-1">
        {author} • {time}
      </div>
      <div className="text-sm text-[var(--onyx-text-primary)]">
        {note}
      </div>
    </div>
  );
}
