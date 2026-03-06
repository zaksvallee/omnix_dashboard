#!/usr/bin/env bash
set -euo pipefail

echo "== ONYX UI Compact Smoke =="
echo "Running targeted route widget tests..."

flutter test \
  test/ui/dashboard_page_widget_test.dart \
  test/ui/dispatch_page_widget_test.dart \
  test/ui/events_page_widget_test.dart \
  test/ui/sites_page_widget_test.dart \
  test/ui/guards_page_widget_test.dart \
  test/ui/ledger_page_widget_test.dart \
  test/ui/client_app_page_widget_test.dart \
  test/ui/reports_page_widget_test.dart

echo "Running analyzer..."
flutter analyze

echo "PASS: UI compact smoke complete."
