import React, { useState } from 'react';
import { 
  FileText, Play, CheckCircle, Clock, XCircle, Eye, Download, 
  ExternalLink, AlertTriangle, Camera, Shield, Hash, Filter,
  ChevronRight, RefreshCw, Sparkles
} from 'lucide-react';

interface Report {
  id: string;
  type: 'morning-sovereign' | 'incident' | 'site-audit' | 'partner-scope';
  title: string;
  date: string;
  status: 'verified' | 'pending' | 'failed' | 'generating';
  linkedIncidents: number;
  linkedEvents: number;
  evidenceCount: number;
  scope: 'internal' | 'partner';
}

interface ReportPreview {
  id: string;
  sections: {
    title: string;
    status: 'complete' | 'incomplete';
    items: number;
  }[];
}

export function Reports() {
  const [selectedReport, setSelectedReport] = useState<string | null>('RPT-2024-03-18');
  const [scopeFilter, setScopeFilter] = useState<'all' | 'internal' | 'partner'>('all');
  const [showPreview, setShowPreview] = useState(true);

  const reports: Report[] = [
    {
      id: 'RPT-2024-03-18',
      type: 'morning-sovereign',
      title: 'Morning Sovereign Report - 18 March 2024',
      date: '2024-03-18',
      status: 'pending',
      linkedIncidents: 12,
      linkedEvents: 47,
      evidenceCount: 89,
      scope: 'internal',
    },
    {
      id: 'RPT-INC-DSP-4',
      type: 'incident',
      title: 'Incident Report - DSP-4 (Sandton Estate)',
      date: '2024-03-17',
      status: 'verified',
      linkedIncidents: 1,
      linkedEvents: 8,
      evidenceCount: 14,
      scope: 'internal',
    },
    {
      id: 'RPT-PARTNER-OFF-12',
      type: 'partner-scope',
      title: 'Partner Handoff Report - INC-OFF-SCOPE-12',
      date: '2024-03-17',
      status: 'verified',
      linkedIncidents: 1,
      linkedEvents: 3,
      evidenceCount: 6,
      scope: 'partner',
    },
    {
      id: 'RPT-SITE-WF-02',
      type: 'site-audit',
      title: 'Site Audit - Waterfall Estate (WF-02)',
      date: '2024-03-16',
      status: 'generating',
      linkedIncidents: 4,
      linkedEvents: 18,
      evidenceCount: 32,
      scope: 'internal',
    },
    {
      id: 'RPT-FAILED-001',
      type: 'incident',
      title: 'Incident Report - INC-BR-03 (Blue Ridge)',
      date: '2024-03-16',
      status: 'failed',
      linkedIncidents: 1,
      linkedEvents: 2,
      evidenceCount: 0,
      scope: 'internal',
    },
  ];

  const previewData: ReportPreview = {
    id: 'RPT-2024-03-18',
    sections: [
      { title: 'Executive Summary', status: 'complete', items: 1 },
      { title: 'Incident Overview', status: 'complete', items: 12 },
      { title: 'Response Performance', status: 'complete', items: 8 },
      { title: 'Evidence Chain', status: 'incomplete', items: 47 },
      { title: 'Compliance Status', status: 'complete', items: 6 },
      { title: 'Readiness Assessment', status: 'incomplete', items: 4 },
    ],
  };

  const filteredReports = scopeFilter === 'all' 
    ? reports 
    : reports.filter(r => r.scope === scopeFilter);

  const selectedReportData = reports.find(r => r.id === selectedReport);
  const verifiedCount = reports.filter(r => r.status === 'verified').length;
  const pendingCount = reports.filter(r => r.status === 'pending').length;
  const failedCount = reports.filter(r => r.status === 'failed').length;

  return (
    <div className="h-full overflow-y-auto bg-[#0A0E13]">
      <div className="p-6 max-w-[1800px] mx-auto space-y-6">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-gradient-to-br from-indigo-500 via-purple-600 to-pink-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-indigo-500/30">
              <FileText className="w-9 h-9 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white mb-1 tracking-tight">Reports & Documentation</h1>
              <p className="text-sm text-white/50">Sovereign reporting, incident documentation, and evidence compilation</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <button className="px-4 py-2 bg-[#0D1117] hover:bg-white/5 text-white/80 rounded-xl border border-[#21262D] flex items-center gap-2 text-sm font-semibold transition-all">
              <ExternalLink className="w-4 h-4" />
              View Governance
            </button>
            <button className="px-4 py-2 bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 rounded-xl border border-indigo-500/30 flex items-center gap-2 text-sm font-semibold transition-all">
              <Sparkles className="w-4 h-4" />
              Generate New Report
            </button>
          </div>
        </div>

        {/* Status Summary + Scope Filter */}
        <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Report Status:</div>
              <div className="flex items-center gap-2 px-3 py-2 bg-emerald-500/10 border border-emerald-500/20 rounded-lg">
                <CheckCircle className="w-4 h-4 text-emerald-400" />
                <span className="text-sm font-bold text-emerald-400">{verifiedCount} Verified</span>
              </div>
              <div className="flex items-center gap-2 px-3 py-2 bg-amber-500/10 border border-amber-500/20 rounded-lg">
                <Clock className="w-4 h-4 text-amber-400" />
                <span className="text-sm font-bold text-amber-400">{pendingCount} Pending</span>
              </div>
              {failedCount > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 bg-red-500/10 border border-red-500/20 rounded-lg">
                  <XCircle className="w-4 h-4 text-red-400" />
                  <span className="text-sm font-bold text-red-400">{failedCount} Failed</span>
                </div>
              )}
            </div>

            {/* Scope Filter */}
            <div className="flex items-center gap-2">
              <div className="text-xs text-white/40 uppercase tracking-wider font-semibold">Scope:</div>
              <button
                onClick={() => setScopeFilter('all')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'all'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                All
              </button>
              <button
                onClick={() => setScopeFilter('internal')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'internal'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Internal
              </button>
              <button
                onClick={() => setScopeFilter('partner')}
                className={`px-3 py-1.5 rounded-lg border text-xs font-semibold transition-all ${
                  scopeFilter === 'partner'
                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/30'
                    : 'bg-[#0A0E13] text-white/60 border-[#21262D]'
                }`}
              >
                Partner-Scope
              </button>
            </div>
          </div>
        </div>

        {/* Main Grid */}
        <div className="grid grid-cols-3 gap-6">
          {/* Left Column - Report List */}
          <div className="col-span-1 space-y-6">
            <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
              <div className="border-b border-[#21262D] px-5 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center">
                    <FileText className="w-4 h-4 text-indigo-400" />
                  </div>
                  <div className="flex-1">
                    <h2 className="text-sm font-bold text-white uppercase tracking-wider">Report Workbench</h2>
                    <p className="text-xs text-white/40 mt-0.5">{filteredReports.length} reports</p>
                  </div>
                </div>
              </div>

              <div className="p-4 space-y-2">
                {filteredReports.map((report) => (
                  <button
                    key={report.id}
                    onClick={() => setSelectedReport(report.id)}
                    className={`
                      w-full p-4 rounded-xl border transition-all text-left
                      ${selectedReport === report.id
                        ? 'bg-gradient-to-br from-indigo-950/50 to-purple-950/50 border-indigo-500/30'
                        : 'bg-[#0A0E13] border-[#21262D] hover:border-indigo-500/20'
                      }
                    `}
                  >
                    <div className="flex items-start justify-between mb-2">
                      <div className={`
                        px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider
                        ${report.status === 'verified' ? 'bg-emerald-500/20 text-emerald-400' : ''}
                        ${report.status === 'pending' ? 'bg-amber-500/20 text-amber-400' : ''}
                        ${report.status === 'failed' ? 'bg-red-500/20 text-red-400' : ''}
                        ${report.status === 'generating' ? 'bg-cyan-500/20 text-cyan-400' : ''}
                      `}>
                        {report.status}
                      </div>
                      {report.scope === 'partner' && (
                        <div className="px-2 py-0.5 bg-purple-500/20 text-purple-400 rounded text-[10px] font-bold uppercase">
                          Partner
                        </div>
                      )}
                    </div>
                    <div className="text-sm font-bold text-white mb-1">{report.title}</div>
                    <div className="text-xs text-white/50 mb-2">{report.date}</div>
                    <div className="flex items-center gap-3 text-[10px] text-white/40">
                      <div>{report.linkedIncidents} incidents</div>
                      <div>{report.linkedEvents} events</div>
                      <div>{report.evidenceCount} evidence</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* Right Column - Report Preview/Details */}
          <div className="col-span-2 space-y-6">
            {selectedReportData ? (
              <>
                {/* Report Header */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2">
                          <FileText className="w-5 h-5 text-indigo-400" />
                          <h2 className="text-lg font-bold text-white">{selectedReportData.title}</h2>
                        </div>
                        <div className="flex items-center gap-3">
                          <div className={`
                            px-3 py-1.5 rounded-lg border text-xs font-bold uppercase tracking-wider
                            ${selectedReportData.status === 'verified' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' : ''}
                            ${selectedReportData.status === 'pending' ? 'bg-amber-500/20 text-amber-400 border-amber-500/30' : ''}
                            ${selectedReportData.status === 'failed' ? 'bg-red-500/20 text-red-400 border-red-500/30' : ''}
                            ${selectedReportData.status === 'generating' ? 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30' : ''}
                          `}>
                            {selectedReportData.status === 'generating' && <RefreshCw className="w-3 h-3 inline mr-1 animate-spin" />}
                            {selectedReportData.status}
                          </div>
                          <div className="text-sm text-white/50">{selectedReportData.date}</div>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        {selectedReportData.status === 'verified' && (
                          <button className="px-4 py-2 bg-indigo-500/10 hover:bg-indigo-500/20 text-indigo-400 rounded-lg border border-indigo-500/30 text-sm font-semibold transition-all flex items-center gap-2">
                            <Download className="w-4 h-4" />
                            Download
                          </button>
                        )}
                        {selectedReportData.status === 'pending' && (
                          <button className="px-4 py-2 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 rounded-lg border border-emerald-500/30 text-sm font-semibold transition-all flex items-center gap-2">
                            <CheckCircle className="w-4 h-4" />
                            Verify Report
                          </button>
                        )}
                        {selectedReportData.status === 'failed' && (
                          <button className="px-4 py-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 rounded-lg border border-red-500/30 text-sm font-semibold transition-all flex items-center gap-2">
                            <RefreshCw className="w-4 h-4" />
                            Regenerate
                          </button>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-3 gap-4">
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Linked Incidents</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedReportData.linkedIncidents}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Linked Events</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedReportData.linkedEvents}</div>
                      </div>
                      <div className="bg-[#0A0E13] border border-[#21262D] rounded-lg p-4">
                        <div className="text-xs text-white/40 uppercase tracking-wider font-semibold mb-2">Evidence Items</div>
                        <div className="text-2xl font-bold text-white tabular-nums">{selectedReportData.evidenceCount}</div>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Report Preview/Shell */}
                {showPreview && selectedReportData.status !== 'failed' && (
                  <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                    <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-lg bg-cyan-500/10 flex items-center justify-center">
                          <Eye className="w-4 h-4 text-cyan-400" />
                        </div>
                        <div className="flex-1">
                          <h2 className="text-sm font-bold text-white uppercase tracking-wider">Report Preview</h2>
                          <p className="text-xs text-white/40 mt-0.5">Section completion status</p>
                        </div>
                      </div>
                    </div>

                    <div className="p-6 space-y-3">
                      {previewData.sections.map((section, idx) => (
                        <div
                          key={idx}
                          className={`
                            p-4 rounded-xl border
                            ${section.status === 'complete' 
                              ? 'bg-emerald-500/5 border-emerald-500/20' 
                              : 'bg-amber-500/5 border-amber-500/20'
                            }
                          `}
                        >
                          <div className="flex items-start justify-between">
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                {section.status === 'complete' ? (
                                  <CheckCircle className="w-4 h-4 text-emerald-400" />
                                ) : (
                                  <Clock className="w-4 h-4 text-amber-400" />
                                )}
                                <h3 className="text-sm font-bold text-white">{section.title}</h3>
                              </div>
                              <div className="text-xs text-white/50">{section.items} items</div>
                            </div>
                            <div className={`
                              px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider
                              ${section.status === 'complete' 
                                ? 'bg-emerald-500/20 text-emerald-400' 
                                : 'bg-amber-500/20 text-amber-400'
                              }
                            `}>
                              {section.status}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Scene Review / Evidence Context */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-purple-500/10 flex items-center justify-center">
                        <Camera className="w-4 h-4 text-purple-400" />
                      </div>
                      <div className="flex-1">
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Evidence Context</h2>
                        <p className="text-xs text-white/40 mt-0.5">Scene review and supporting materials</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6">
                    <div className="grid grid-cols-2 gap-3">
                      <button className="p-4 bg-[#0A0E13] hover:bg-purple-500/10 border border-[#21262D] hover:border-purple-500/30 rounded-lg transition-all text-left">
                        <div className="flex items-center gap-2 mb-2">
                          <Camera className="w-4 h-4 text-purple-400" />
                          <span className="text-sm font-bold text-white">CCTV Footage</span>
                        </div>
                        <div className="text-xs text-white/50">12 clips archived</div>
                      </button>
                      <button className="p-4 bg-[#0A0E13] hover:bg-cyan-500/10 border border-[#21262D] hover:border-cyan-500/30 rounded-lg transition-all text-left">
                        <div className="flex items-center gap-2 mb-2">
                          <Shield className="w-4 h-4 text-cyan-400" />
                          <span className="text-sm font-bold text-white">Guard Reports</span>
                        </div>
                        <div className="text-xs text-white/50">8 OB entries</div>
                      </button>
                    </div>
                  </div>
                </div>

                {/* Drilldown Actions */}
                <div className="bg-[#0D1117] border border-[#21262D] rounded-xl overflow-hidden">
                  <div className="border-b border-[#21262D] px-6 py-4 bg-gradient-to-r from-[#0D1117] to-[#0A0E13]">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center">
                        <ExternalLink className="w-4 h-4 text-emerald-400" />
                      </div>
                      <div>
                        <h2 className="text-sm font-bold text-white uppercase tracking-wider">Related Views</h2>
                        <p className="text-xs text-white/40 mt-0.5">Navigate to related data</p>
                      </div>
                    </div>
                  </div>

                  <div className="p-6 grid grid-cols-2 gap-3">
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-emerald-500/10 text-white/80 hover:text-emerald-400 rounded-lg border border-[#21262D] hover:border-emerald-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <span>View Governance</span>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                    <button className="px-4 py-3 bg-[#0A0E13] hover:bg-cyan-500/10 text-white/80 hover:text-cyan-400 rounded-lg border border-[#21262D] hover:border-cyan-500/30 transition-all text-sm font-semibold flex items-center justify-between">
                      <span>View Events</span>
                      <ChevronRight className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div className="bg-[#0D1117] border border-[#21262D] rounded-xl p-12 text-center">
                <FileText className="w-16 h-16 text-white/20 mx-auto mb-4" />
                <h3 className="text-lg font-bold text-white mb-2">Select a Report</h3>
                <p className="text-sm text-white/60">Choose a report from the workbench to view details</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
