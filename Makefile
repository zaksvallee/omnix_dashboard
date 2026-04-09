.PHONY: run-web analyze test smoke-ui preflight preflight-smoke guard-auto guard-predevice guard-pilot validation-bundle-cert cctv-validate cctv-readiness cctv-mock-artifacts cctv-capture-pack cctv-pilot-gate cctv-field-gate cctv-signoff cctv-release-gate cctv-release-trend dvr-validate dvr-readiness dvr-mock-artifacts dvr-capture-pack dvr-pilot-gate dvr-field-gate dvr-release-gate dvr-release-trend dvr-signoff listener-bench listener-baseline-promote listener-parity listener-parity-trend listener-validation-trend listener-cutover-decision listener-cutover-trend listener-release-gate listener-release-trend listener-capture-pack listener-validate listener-readiness listener-mock-artifacts listener-field-gate listener-parity-readiness listener-pilot-gate listener-signoff

CONFIG ?= config/onyx.local.json
ACTION ?= com.onyx.fsk.SDK_HEARTBEAT
SAMPLES ?= 3
MAX_REPORT_AGE_HOURS ?= 24

run-web:
	./scripts/run_onyx_chrome_local.sh --config $(CONFIG)

analyze:
	flutter analyze

test:
	flutter test

smoke-ui:
	./scripts/ui_compact_smoke.sh

preflight:
	./scripts/onyx_ops_preflight.sh --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

preflight-smoke:
	./scripts/onyx_ops_preflight.sh --smoke-ui --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-auto:
	./scripts/guard_gate_auto.sh --action $(ACTION) --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-predevice:
	./scripts/guard_predevice_gate.sh --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-pilot:
	./scripts/guard_android_pilot_gate.sh --action $(ACTION) --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

validation-bundle-cert:
	./scripts/onyx_validation_bundle_certificate.sh

cctv-validate:
	./scripts/onyx_cctv_field_validation.sh

cctv-readiness:
	./scripts/onyx_cctv_pilot_readiness_check.sh

cctv-mock-artifacts:
	./scripts/onyx_cctv_mock_validation_artifacts.sh

cctv-capture-pack:
	./scripts/onyx_cctv_capture_pack_init.sh

cctv-pilot-gate:
	./scripts/onyx_cctv_pilot_gate.sh

cctv-field-gate:
	./scripts/onyx_cctv_field_gate.sh

cctv-signoff:
	./scripts/onyx_cctv_signoff_generate.sh

cctv-release-gate:
	./scripts/onyx_cctv_release_gate.sh

cctv-release-trend:
	./scripts/onyx_cctv_release_trend_check.sh

dvr-validate:
	./scripts/onyx_dvr_field_validation.sh

dvr-readiness:
	./scripts/onyx_dvr_pilot_readiness_check.sh

dvr-mock-artifacts:
	./scripts/onyx_dvr_mock_validation_artifacts.sh

dvr-capture-pack:
	./scripts/onyx_dvr_capture_pack_init.sh

dvr-pilot-gate:
	./scripts/onyx_dvr_pilot_gate.sh

dvr-field-gate:
	./scripts/onyx_dvr_field_gate.sh

dvr-release-gate:
	./scripts/onyx_dvr_release_gate.sh

dvr-release-trend:
	./scripts/onyx_dvr_release_trend_check.sh

dvr-signoff:
	./scripts/onyx_dvr_signoff_generate.sh

listener-bench:
	./scripts/onyx_listener_serial_bench.sh --input tmp/listener_serial_capture/sample.txt

listener-baseline-promote:
	./scripts/onyx_listener_bench_baseline_promote.sh

listener-parity:
	./scripts/onyx_listener_parity_report.sh --serial tmp/listener_serial_bench/parsed.json --legacy tmp/listener_legacy_export/accepted.json

listener-parity-trend:
	./scripts/onyx_listener_parity_trend_check.sh

listener-validation-trend:
	./scripts/onyx_listener_validation_trend_check.sh

listener-cutover-decision:
	./scripts/onyx_listener_cutover_decision.sh

listener-cutover-trend:
	./scripts/onyx_listener_cutover_trend_check.sh

listener-release-gate:
	./scripts/onyx_listener_release_gate.sh

listener-release-trend:
	./scripts/onyx_listener_release_trend_check.sh

listener-capture-pack:
	./scripts/onyx_listener_capture_pack_init.sh

listener-validate:
	./scripts/onyx_listener_field_validation.sh

listener-readiness:
	./scripts/onyx_listener_pilot_readiness_check.sh

listener-mock-artifacts:
	./scripts/onyx_listener_mock_validation_artifacts.sh

listener-field-gate:
	./scripts/onyx_listener_field_gate.sh

listener-parity-readiness:
	./scripts/onyx_listener_parity_readiness_check.sh

listener-pilot-gate:
	./scripts/onyx_listener_pilot_gate.sh

listener-signoff:
	./scripts/onyx_listener_signoff_generate.sh
