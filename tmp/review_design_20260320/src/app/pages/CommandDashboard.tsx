import React, { useState } from 'react';
import { ActiveIntelligenceLane, ProcessStep } from '../components/onyx/ActiveIntelligenceLane';
import { VerificationLens } from '../components/onyx/VerificationLens';
import { DispatchQueue, Dispatch } from '../components/onyx/DispatchQueue';
import { GuardVigilance, Guard } from '../components/onyx/GuardVigilance';
import { SovereignLedger, LedgerEvent } from '../components/onyx/SovereignLedger';
import { KPICard } from '../components/onyx/KPICard';
import { Phone, Navigation, Camera, Eye, Shield, TrendingUp, TrendingDown, AlertTriangle, Users, Clock } from 'lucide-react';

export function CommandDashboard() {
  // Mock data for Active Intelligence Lane
  const activeIncident: ProcessStep[] = [
    {
      id: '1',
      title: 'AUTO-DISPATCH',
      status: 'complete',
      timestamp: '19:42:03',
      details: 'Guard-1 (Echo-3) dispatched • 2.4km away • ETA: 4m 12s',
      icon: <Navigation className="w-4 h-4" />,
      actions: ['REROUTE']
    },
    {
      id: '2',
      title: 'VOIP-CLIENT',
      status: 'active',
      timestamp: '19:42:06',
      details: 'Calling +27 82 555 1234...',
      liveIndicator: 'Listening for safe word',
      icon: <Phone className="w-4 h-4" />,
      actions: ['TAKE OVER CALL']
    },
    {
      id: '3',
      title: 'CCTV-ACTIVATE',
      status: 'pending',
      details: 'Waiting for VoIP completion...',
      icon: <Camera className="w-4 h-4" />
    },
    {
      id: '4',
      title: 'VISION-VERIFY',
      status: 'pending',
      details: 'Awaiting officer arrival photo',
      icon: <Eye className="w-4 h-4" />
    }
  ];

  // Mock dispatch data
  const [dispatches, setDispatches] = useState<Dispatch[]>([
    {
      id: 'D001',
      priority: 'P1',
      type: 'Armed Breach',
      site: 'Sandton Estate North',
      officer: 'Echo-3',
      eta: '4m 12s',
      status: 'en-route',
      timestamp: '19:42',
      lane: 'manual'
    },
    {
      id: 'D002',
      priority: 'P3',
      type: 'Routine Check',
      site: 'Blue Ridge Security',
      officer: 'Guard-1',
      status: 'on-site',
      timestamp: '19:38',
      autoCloseIn: 120,
      lane: 'auto'
    },
    {
      id: 'D003',
      priority: 'P2',
      type: 'Perimeter Alarm',
      site: 'Waterfall Estate',
      officer: 'Echo-7',
      eta: '8m 30s',
      status: 'dispatched',
      timestamp: '19:40',
      autoCloseIn: 180,
      lane: 'auto'
    }
  ]);

  // Mock guard data
  const guards: Guard[] = [
    {
      id: 'G001',
      name: 'Guard-1',
      site: 'Blue Ridge North',
      lastSync: 2,
      nextExpected: 13,
      gpsStatus: 'ok',
      vigilanceLevel: 4
    },
    {
      id: 'G002',
      name: 'Guard-7',
      site: 'Sandton Estate',
      lastSync: 18,
      nextExpected: 0,
      gpsStatus: 'drift',
      vigilanceLevel: 2,
      nudgeSent: true,
      nudgeTime: 3
    },
    {
      id: 'G003',
      name: 'Guard-4',
      site: 'Waterfall Complex',
      lastSync: 5,
      nextExpected: 10,
      gpsStatus: 'ok',
      vigilanceLevel: 5
    }
  ];

  // Mock ledger events
  const ledgerEvents: LedgerEvent[] = [
    {
      id: 'L001',
      timestamp: '19:42:03',
      type: 'ai-action',
      description: 'AI-Generated Dispatch Created',
      details: 'Guard: Echo-3 • Distance: 2.4km • ETA: 4m 12s',
      hash: 'a7f3e9c2',
      verified: true
    },
    {
      id: 'L002',
      timestamp: '19:42:06',
      type: 'ai-action',
      description: 'Automated VoIP Call Initiated',
      details: 'Client: +27 82 555 1234 • Attempt: 1/3',
      hash: 'b8e41d3f',
      previousHash: 'a7f3e9c2',
      verified: true
    },
    {
      id: 'L003',
      timestamp: '19:42:12',
      type: 'system-event',
      description: 'Safe Word Verification Successful',
      details: 'Client authenticated • Confidence: 98%',
      hash: 'c9f52e4g',
      previousHash: 'b8e41d3f',
      verified: true
    }
  ];

  return (
    <div className="min-h-screen bg-[#0C1220] p-8">
      {/* Page Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">Command Dashboard</h1>
        <p className="text-white/60">Real-time operational control • AI-powered human-parallel execution</p>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-4 gap-6 mb-8">
        <KPICard
          label="Active Incidents"
          value="3"
          trend={{ direction: 'up', value: 12 }}
          icon={<AlertTriangle className="w-6 h-6" />}
          status="critical"
        />
        <KPICard
          label="Guards On-Duty"
          value="24"
          trend={{ direction: 'down', value: 2 }}
          icon={<Users className="w-6 h-6" />}
          status="success"
        />
        <KPICard
          label="Response Time"
          value="3.4m"
          subtitle="Avg last 24h"
          icon={<Clock className="w-6 h-6" />}
          status="normal"
        />
        <KPICard
          label="Triage Posture"
          value="STABLE"
          icon={<Shield className="w-6 h-6" />}
          status="success"
        />
      </div>

      {/* Main Grid Layout */}
      <div className="grid grid-cols-12 gap-6">
        {/* Left Column - Main Content (8 columns) */}
        <div className="col-span-8 space-y-6">
          {/* Active Intelligence Lane */}
          <ActiveIntelligenceLane
            incidentId="INC-2847"
            priority="P1"
            status="investigating"
            site="Sandton North Gate"
            steps={activeIncident}
            onOverride={(id) => console.log('Override step:', id)}
            onEdit={(id) => console.log('Edit step:', id)}
            onAction={(id, action) => console.log('Action:', id, action)}
          />

          {/* Verification Lens */}
          <VerificationLens
            baselineImage="https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&auto=format&fit=crop"
            currentImage="https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&auto=format&fit=crop"
            matchScore={42}
            anomalies={['Gate Status Changed', 'Perimeter Compromised', 'Unauthorized vehicle detected']}
            metadata={{
              baseline: {
                timestamp: '06:00',
                gps: '-26.1076, 28.0567',
                weather: 'Clear'
              },
              current: {
                timestamp: '19:42',
                gps: '-26.1076, 28.0567',
                weather: 'Clear'
              }
            }}
            onApprove={() => console.log('Approved')}
            onFlag={() => console.log('Flagged')}
            onEscalate={() => console.log('Escalated')}
          />

          {/* Sovereign Ledger */}
          <SovereignLedger
            incidentId="INC-2847"
            events={ledgerEvents}
            onVerifyHash={() => console.log('Verify hash')}
            onExport={() => console.log('Export')}
            onShare={() => console.log('Share')}
          />
        </div>

        {/* Right Column - Command Rail (4 columns) */}
        <div className="col-span-4 space-y-6">
          {/* Dispatch Queue */}
          <DispatchQueue
            dispatches={dispatches}
            onView={(id) => console.log('View dispatch:', id)}
            onTakeOver={(id) => {
              console.log('Take over dispatch:', id);
              setDispatches(prevDispatches =>
                prevDispatches.map(d =>
                  d.id === id ? { ...d, lane: 'manual' } : d
                )
              );
            }}
          />

          {/* Guard Vigilance */}
          <GuardVigilance
            guards={guards}
            onNudge={(id) => console.log('Nudge guard:', id)}
            onCall={(id) => console.log('Call guard:', id)}
            onEscalate={(id) => console.log('Escalate guard:', id)}
            onBroadcast={() => console.log('Broadcast to all guards')}
          />
        </div>
      </div>
    </div>
  );
}
