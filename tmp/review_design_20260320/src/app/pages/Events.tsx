import React, { useState } from 'react';
import { 
  Activity, Eye, Filter, Hash, Clock, Shield, FileText, ChevronRight,
  ExternalLink, Camera, Radio, User, Building2, AlertTriangle, CheckCircle,
  Database
} from 'lucide-react';

interface Event {
  id: string;
  timestamp: string;
  type: 'incident' | 'guard-action' | 'system' | 'client-comms' | 'watch' | 'dispatch';
  severity: 'critical' | 'warning' | 'info';
  actor: string;
  action: string;
  subject: string;
  payload: any;
  verified: boolean;
  linkedIncident?: string;
  linkedSite?: string;
}

export function Events() {
  const [selectedEvent, setSelectedEvent] = useState<string | null>('EVT-2441');
  const [typeFilter, setTypeFilter] = useState<string | null>(null);
  const [scopeFilter, setScopeFilter] = useState<'all' | 'incident' | 'site'>('all');
  const [scopeValue, setScopeValue] = useState<string | null>(null);

  const events: Event[] = [
    {
      id: 'EVT-2441',
      timestamp: '2024-03-18 23:47:14 UTC',
      type: 'dispatch',
      severity: 'critical',
      actor: 'CONTROLLER-002',
      action: 'DISPATCH_OFFICER_ARRIVED',
      subject: 'DSP-004',
      payload: {
        officer: 'Echo-3',
        site: 'Sandton Estate North',
        coordinates: { lat: -26.1076, lng: 28.0567 }
      },
      verified: true,
      linkedIncident: 'INC-DSP-4',
      linkedSite: 'SE-01',
    },
    {
      id: 'EVT-2442',
      timestamp: '2024-03-18 23:45:22 UTC',
      type: 'watch',
      severity: 'warning',
      actor: 'TACTICAL_WATCH',
      action: 'WATCH_STATE_CHANGED',
      subject: 'SITE-WF-02',
      payload: {
        previousState: 'available',
        newState: 'limited',
        reason: 'stale-feed',
        cameraId: 'CAM-WF-02-NORTH'
      },
      verified: true,
      linkedSite: 'WF-02',
    },
    {
      id: 'EVT-2443',
      timestamp: '2024-03-18 23:42:08 UTC',
      type: 'client-comms',
      severity: 'info',
      actor: 'ONYX_AI',
      action: 'CLIENT_NOTIFIED',
      subject: 'CLIENT-MS-VALLEY',
      payload: {
        channel: 'telegram',
        messageId: 'MSG-001',
        deliveryState: 'delivered',
        content: 'Officer dispatched to your location'
      },
      verified: true,
      linkedIncident: 'INC-DSP-4',
    },
    {
      id: 'EVT-2444',
      timestamp: '2024-03-18 23:38:45 UTC',
      type: 'incident',
      severity: 'critical',
      actor: 'FSK_ALARM',
      action: 'ALARM_TRIGGERED',
      subject: 'SITE-SE-01',
      payload: {
        alarmType: 'perimeter-breach',
        zone: 'North Gate',
        sensorId: 'SENSOR-SE-01-NG-04'
      },
      verified: true,
      linkedIncident: 'INC-DSP-4',
      linkedSite: 'SE-01',
    },
    {
      id: 'EVT-2445',
      timestamp: '2024-03-18 23:32:12 UTC',
      type: 'guard-action',
      severity: 'info',
      actor: 'G-2441',
      action: 'OB_ENTRY_CREATED',
      subject: 'SITE-SE-01',
      payload: {
        entryType: 'patrol-log',
        guardName: 'T. Nkosi',
        notes: 'Perimeter check complete - all clear'
      },
      verified: true,
      linkedSite: 'SE-01',
    },
    {
      id: 'EVT-2446',
      timestamp: '2024-03-18 22:14:03 UTC',
      type: 'system',
      severity: 'warning',
      actor: 'SYSTEM',
      action: 'SYNC_STALE_DETECTED',
      subject: 'G-2442',
      payload: {
        guardName: 'J. van Wyk',
        lastSync: '142s ago',
        expectedInterval: '30s'
      },
      verified: false,
    },
  ];

  const filteredEvents = events.filter(e => {
    if (typeFilter && e.type !== typeFilter) return false;
    if (scopeFilter === 'incident' && scopeValue && e.linkedIncident !== scopeValue) return false;
    if (scopeFilter === 'site' && scopeValue && e.linkedSite !== scopeValue) return false;
    return true;
  });

  const selectedEventData = events.find(e => e.id === selectedEvent);

  const eventTypeColors: Record<string, string> = {
    incident: 'red',
    dispatch: 'orange',
    'guard-action': 'blue',
    'client-comms': 'cyan',
    watch: 'purple',
    system: 'gray',
  };

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-violet-500 via-purple-600 to-indigo-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-violet-500/30">
              <Activity className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Events & Forensic Timeline</h1>
              <p className="text-sm text-white/50">Immutable event log with forensic filtering and audit trails</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Governance
            </button>
            <button className="px-4 py-2 bg-violet-500/10 hover:bg-violet-500/20 text-violet-400 rounded-xl border border-violet-500/30 flex items-center gap-2 text-sm font-semibold transition-all">
              <Database className="w-4 h-4" />
              View Ledger
            </button>
          </div>
        </div>

        {/* Filter Strip */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Event Type:</div>
              <div className="flex gap-2">
                <button
                  onClick={() => setTypeFilter(null)}
                  className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                    typeFilter === null
                      ? 'bg-white/5 text-white border-white/10'
                      : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                  }`}
                >
                  All
                </button>
                {['incident', 'dispatch', 'guard-action', 'client-comms', 'watch', 'system'].map((type) => (
                  <button
                    key={type}
                    onClick={() => setTypeFilter(type)}
                    className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                      typeFilter === type
                        ? `bg-${eventTypeColors[type]}-500/10 text-${eventTypeColors[type]}-400 border-${eventTypeColors[type]}-500/30`
                        : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                    }`}
                  >
                    {type.replace('-', ' ')}
                  </button>
                ))}
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Scope Filter:</div>
            <button
              onClick={() => { setScopeFilter('all'); setScopeValue(null); }}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                scopeFilter === 'all'
                  ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                  : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
              }`}
            >
              All Events
            </button>
            <button
              onClick={() => { setScopeFilter('incident'); setScopeValue('INC-DSP-4'); }}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                scopeFilter === 'incident'
                  ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                  : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
              }`}
            >
              Incident: INC-DSP-4
            </button>
            <button
              onClick={() => { setScopeFilter('site'); setScopeValue('SE-01'); }}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                scopeFilter === 'site'
                  ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                  : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
              }`}
            >
              Site: SE-01
            </button>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Event Timeline */}
          <div className="col-span-1 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-violet-500/10 flex items-center justify-center">
                    <Activity className="w-4 h-4 text-violet-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Event Timeline</h2>
                    <p className="text-xs text-white/40 mt-0.5">{filteredEvents.length} events</p>
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2 max-h-[800px] overflow-y-auto">
                {filteredEvents.map((event) => (
                  <button
                    key={event.id}
                    onClick={() => setSelectedEvent(event.id)}
                    className={`
                      w-full p-4 rounded-xl border transition-all text-left
                      ${selectedEvent === event.id
                        ? 'bg-gradient-to-br from-violet-950/50 to-purple-950/50 border-violet-500/30'
                        : 'bg-[#0A0E13] border-[#21262D] hover:border-violet-500/20'
                      }
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className={`
                        px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                        ${event.type === 'incident' ? 'bg-red-500/20 text-red-400' : ''}
                        ${event.type === 'dispatch' ? 'bg-orange-500/20 text-orange-400' : ''}
                        ${event.type === 'guard-action' ? 'bg-blue-500/20 text-blue-400' : ''}
                        ${event.type === 'client-comms' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                        ${event.type === 'watch' ? 'bg-purple-500/20 text-purple-400' : ''}
                        ${event.type === 'system' ? 'bg-gray-500/20 text-gray-400' : ''}
                      `}>
                        {event.type.replace('-', ' ')}
                      </div>
                      {event.verified && <CheckCircle className="w-3.5 h-3.5 text-emerald-400" />}
                    </div>
                    <div className="text-sm font-bold text-white mb-1">{event.action.replace(/_/g, ' ')}</div>
                    <div className="text-xs text-white/50 mb-2">{event.timestamp}</div>
                    <div className="text-xs text-white/40">{event.actor} → {event.subject}</div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column - Event Detail */}
          <div className="col-span-2 space-y-6">
            {selectedEventData ? (
              <>
                {/* Event Header */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <Activity className="w-5 h-5 text-violet-400" />
                        <div>
                          <h2 className="text-lg font-bold text-white">{selectedEventData.action.replace(/_/g, ' ')}</h2>
                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-sm text-white/50 font-mono">{selectedEventData.id}</span>
                            <div className={`
                              px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                              ${selectedEventData.type === 'incident' ? 'bg-red-500/20 text-red-400' : ''}
                              ${selectedEventData.type === 'dispatch' ? 'bg-orange-500/20 text-orange-400' : ''}
                              ${selectedEventData.type === 'guard-action' ? 'bg-blue-500/20 text-blue-400' : ''}
                              ${selectedEventData.type === 'client-comms' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                              ${selectedEventData.type === 'watch' ? 'bg-purple-500/20 text-purple-400' : ''}
                              ${selectedEventData.type === 'system' ? 'bg-gray-500/20 text-gray-400' : ''}
                            `}>
                              {selectedEventData.type.replace('-', ' ')}
                            </div>
                            {selectedEventData.verified && (
                              <div className="px-2 py-0.5 bg-emerald-500/20 text-emerald-400 rounded text-[10px] font-bold uppercase">
                                Verified
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                      <div className={`
                        px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                        ${selectedEventData.severity === 'critical' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                        ${selectedEventData.severity === 'warning' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' : ''}
                        ${selectedEventData.severity === 'info' ? 'bg-blue-500/20 text-blue-400 border-blue-500/30' : ''}
                      `}>
                        {selectedEventData.severity}
                      </div>
                    </div>

                    <div className="grid grid-cols-3 gap-4">
                      <div>
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Timestamp</div>
                        <div className="text-sm text-white font-mono">{selectedEventData.timestamp}</div>
                      </div>
                      <div>
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Actor</div>
                        <div className="text-sm text-white">{selectedEventData.actor}</div>
                      </div>
                      <div>
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-1">Subject</div>
                        <div className="text-sm text-white">{selectedEventData.subject}</div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Forensic Payload Detail */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                        <Database className="w-4 h-4 text-cyan-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Event Payload</h2>
                        <p className="text-xs text-white/40 mt-0.5">Forensic detail and metadata</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4 font-mono text-xs">
                      <pre className="text-cyan-300 whitespace-pre-wrap overflow-auto">
{JSON.stringify(selectedEventData.payload, null, 2)}
                      </pre>
                    </div>
                  </div>
                </div>

                {/* Linked Resources */}
                {(selectedEventData.linkedIncident || selectedEventData.linkedSite) && (
                  <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                    <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                          <Hash className="w-4 h-4 text-purple-400" />
                        </div>
                        <div>
                          <h2 className="text-sm font-bold text-white uppercase tracking-wider">Linked Resources</h2>
                          <p className="text-xs text-white/40 mt-0.5">Related entities and evidence chain</p>
                        </div>
                      </div>
                    </div>

                    <div className="p-6 space-y-2">
                      {selectedEventData.linkedIncident && (
                        <div className="p-4 bg-[#0A0E13] border border-red-500/20 rounded-lg flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <AlertTriangle className="w-4 h-4 text-red-400" />
                            <div>
                              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-0.5">Linked Incident</div>
                              <div className="text-sm font-bold text-white font-mono">{selectedEventData.linkedIncident}</div>
                            </div>
                          </div>
                          <button className="px-3 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-xs font-semibold transition-all flex items-center gap-2">
                            <Eye className="w-3 h-3" />
                            View Incident
                          </button>
                        </div>
                      )}

                      {selectedEventData.linkedSite && (
                        <div className="p-4 bg-[#0A0E13] border border-cyan-500/20 rounded-lg flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <Building2 className="w-4 h-4 text-cyan-400" />
                            <div>
                              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-0.5">Linked Site</div>
                              <div className="text-sm font-bold text-white font-mono">{selectedEventData.linkedSite}</div>
                            </div>
                          </div>
                          <button className="px-3 py-2 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-400 rounded-lg border border-cyan-500/30 text-xs font-semibold transition-all flex items-center gap-2">
                            <Eye className="w-3 h-3" />
                            View Site
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                )}

                {/* Drilldown Actions */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                        <ExternalLink className="w-4 h-4 text-emerald-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Navigate</h2>
                        <p className="text-xs text-white/40 mt-0.5">View related systems</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 grid grid-cols-2 gap-3">
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-emerald-500/10 text-white/80 hover:text-emerald-400 rounded-lg border border-[#21262D] hover:border-emerald-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <span>Governance</span>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-violet-500/10 text-white/80 hover:text-violet-400 rounded-lg border border-[#21262D] hover:border-violet-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <span>Ledger</span>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-12 text-center">
                <Activity className="w-16 h-16 text-white/20 mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-2">Select an Event</h3>
                <p className="text-sm text-white/60">Choose an event from the timeline to view forensic details</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
