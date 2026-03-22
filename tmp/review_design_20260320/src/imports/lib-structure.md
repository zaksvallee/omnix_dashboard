Last login: Mon Mar  9 21:07:40 on ttys005
zaks@Muhammeds-MBP omnix_dashboard % tree lib
lib
├── application
│   ├── app_state.dart
│   ├── client_conversation_repository.dart
│   ├── dispatch_application_service.dart
│   ├── dispatch_benchmark_presenter.dart
│   ├── dispatch_clipboard_service.dart
│   ├── dispatch_persistence_service.dart
│   ├── dispatch_snapshot_file_service_stub.dart
│   ├── dispatch_snapshot_file_service_web.dart
│   ├── dispatch_snapshot_file_service.dart
│   ├── email_bridge_service_stub.dart
│   ├── email_bridge_service_web.dart
│   ├── email_bridge_service.dart
│   ├── guard_media_capture_service.dart
│   ├── guard_ops_repository.dart
│   ├── guard_performance_service.dart
│   ├── guard_sync_repository.dart
│   ├── guard_telemetry_bridge_writer.dart
│   ├── guard_telemetry_ingestion_adapter.dart
│   ├── guard_telemetry_replay_fixture_service.dart
│   ├── intake_stress_service.dart
│   ├── models
│   │   └── site_performance_summary.dart
│   ├── morning_sovereign_report_service.dart
│   ├── report_generation_service.dart
│   ├── runtime_config.dart
│   ├── text_share_service_stub.dart
│   ├── text_share_service_web.dart
│   └── text_share_service.dart
├── domain
│   ├── aggregate
│   │   └── dispatch_aggregate.dart
│   ├── authority
│   │   ├── authority_token.dart
│   │   ├── onyx_route.dart
│   │   └── operator_context.dart
│   ├── crm
│   │   ├── client_aggregate.dart
│   │   ├── client_contact.dart
│   │   ├── client.dart
│   │   ├── crm_event.dart
│   │   ├── crm_service.dart
│   │   ├── export
│   │   │   ├── pdf_report_exporter.dart
│   │   │   ├── plain_text_report_exporter.dart
│   │   │   └── report_export.dart
│   │   ├── reporting
│   │   │   ├── dispatch_performance_projection.dart
│   │   │   ├── escalation_trend_projection.dart
│   │   │   ├── escalation_trend.dart
│   │   │   ├── executive_summary_generator.dart
│   │   │   ├── executive_summary.dart
│   │   │   ├── monthly_report_projection.dart
│   │   │   ├── monthly_report.dart
│   │   │   ├── multi_site_comparison_projection.dart
│   │   │   ├── report_audience.dart
│   │   │   ├── report_bundle_assembler.dart
│   │   │   ├── report_bundle_canonicalizer.dart
│   │   │   ├── report_bundle.dart
│   │   │   ├── report_sections.dart
│   │   │   ├── site_performance.dart
│   │   │   ├── sla_dashboard_projection.dart
│   │   │   └── sla_dashboard_summary.dart
│   │   ├── site.dart
│   │   ├── sla_profile.dart
│   │   ├── sla_tier_factory.dart
│   │   ├── sla_tier_projection.dart
│   │   ├── sla_tier_service.dart
│   │   ├── sla_tier.dart
│   │   └── store
│   │       └── crm_event_log.dart
│   ├── events
│   │   ├── decision_created.dart
│   │   ├── dispatch_decided_event.dart
│   │   ├── dispatch_event.dart
│   │   ├── execution_completed_event.dart
│   │   ├── execution_completed.dart
│   │   ├── execution_denied.dart
│   │   ├── guard_checked_in.dart
│   │   ├── incident_closed.dart
│   │   ├── intelligence_received.dart
│   │   ├── patrol_completed.dart
│   │   ├── report_generated.dart
│   │   └── response_arrived.dart
│   ├── evidence
│   │   ├── client_ledger_repository.dart
│   │   └── client_ledger_service.dart
│   ├── guard
│   │   ├── guard_event_contract.dart
│   │   ├── guard_mobile_ops.dart
│   │   ├── guard_ops_event.dart
│   │   ├── guard_sync_coaching_policy.dart
│   │   ├── guard_sync_selection_scope.dart
│   │   ├── operational_tiers.dart
│   │   └── outcome_label_governance.dart
│   ├── incidents
│   │   ├── client
│   │   │   ├── client_incident_log_projection.dart
│   │   │   └── client_incident_log.dart
│   │   ├── incident_enums.dart
│   │   ├── incident_event.dart
│   │   ├── incident_projection.dart
│   │   ├── incident_record.dart
│   │   ├── incident_service.dart
│   │   ├── risk
│   │   │   ├── incident_risk_projection.dart
│   │   │   ├── risk_tag.dart
│   │   │   ├── sla_breach_evaluator.dart
│   │   │   ├── sla_clock.dart
│   │   │   ├── sla_policy.dart
│   │   │   └── sla_weighting_policy.dart
│   │   ├── store
│   │   │   └── incident_event_log.dart
│   │   └── timeline
│   │       ├── incident_timeline_builder.dart
│   │       └── timeline_entry.dart
│   ├── integration
│   │   └── incident_to_crm_mapper.dart
│   ├── intelligence
│   │   ├── decision_service.dart
│   │   ├── intel_ingestion.dart
│   │   ├── news_item.dart
│   │   ├── risk_policy.dart
│   │   └── triage_policy.dart
│   ├── log
│   │   └── event_log.dart
│   ├── logging
│   │   ├── event_log.dart
│   │   └── execution_event.dart
│   ├── models
│   │   ├── action_status.dart
│   │   └── dispatch_action.dart
│   ├── policy
│   │   └── risk_policy.dart
│   ├── projection
│   │   ├── dashboard_overview_projection.dart
│   │   ├── dispatch_aggregate.dart
│   │   ├── dispatch_projection.dart
│   │   ├── execution_projection.dart
│   │   ├── guard_performance_projection.dart
│   │   └── operations_health_projection.dart
│   ├── risk
│   │   └── risk_policy.dart
│   ├── store
│   │   ├── event_store.dart
│   │   └── in_memory_event_store.dart
│   └── testing
│       ├── guard_performance_runner.dart
│       ├── incident_performance_runner.dart
│       ├── patrol_performance_runner.dart
│       ├── replay_consistency_verifier.dart
│       └── response_performance_runner.dart
├── engine
│   ├── dispatch
│   │   ├── action_status.dart
│   │   ├── dispatch_action.dart
│   │   └── dispatch_state_machine.dart
│   ├── execution
│   │   └── execution_engine.dart
│   └── vertical_slice_runner.dart
├── infrastructure
│   ├── events
│   │   ├── in_memory_client_ledger_repository.dart
│   │   └── supabase_client_ledger_repository.dart
│   ├── intelligence
│   │   ├── configured_live_feed_service.dart
│   │   ├── generic_feed_adapter.dart
│   │   └── news_intelligence_service.dart
│   └── persistence
│       ├── event_log_rotation_guard.dart
│       └── local_event_storage.dart
├── main.dart
├── presentation
│   ├── incidents
│   │   └── manual_incident_page.dart
│   ├── incidents_page.dart
│   ├── operations_page.dart
│   ├── overview_page.dart
│   ├── reports
│   │   ├── report_preview_page.dart
│   │   └── report_test_harness.dart
│   └── reports_page.dart
├── ui
│   ├── app_shell.dart
│   ├── client_app_page.dart
│   ├── dashboard_page.dart
│   ├── dispatch_models.dart
│   ├── dispatch_page_dialog_support.dart
│   ├── dispatch_page_filter_presets.dart
│   ├── dispatch_page_preset_import.dart
│   ├── dispatch_page_snapshot_inspector.dart
│   ├── dispatch_page.dart
│   ├── events_page.dart
│   ├── guard_mobile_shell_page.dart
│   ├── guards_page.dart
│   ├── ledger_page.dart
│   ├── onyx_surface.dart
│   └── sites_page.dart
└── vertical_slice_test.dart

39 directories, 161 files
zaks@Muhammeds-MBP omnix_dashboard % 
