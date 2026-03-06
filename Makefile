.PHONY: run-web analyze test smoke-ui preflight guard-auto guard-predevice guard-pilot

CONFIG ?= config/onyx.local.json
ACTION ?= com.onyx.fsk.SDK_HEARTBEAT
SAMPLES ?= 3
MAX_REPORT_AGE_HOURS ?= 24

run-web:
	flutter run -d chrome --dart-define-from-file=$(CONFIG)

analyze:
	flutter analyze

test:
	flutter test

smoke-ui:
	./scripts/ui_compact_smoke.sh

preflight:
	./scripts/onyx_ops_preflight.sh --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-auto:
	./scripts/guard_gate_auto.sh --action $(ACTION) --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-predevice:
	./scripts/guard_predevice_gate.sh --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)

guard-pilot:
	./scripts/guard_android_pilot_gate.sh --action $(ACTION) --samples $(SAMPLES) --max-report-age-hours $(MAX_REPORT_AGE_HOURS) --config $(CONFIG)
