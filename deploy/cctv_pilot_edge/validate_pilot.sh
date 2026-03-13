#!/usr/bin/env bash
set -euo pipefail

EDGE_BASE_URL="${EDGE_BASE_URL:-http://localhost:5000}"

echo "Checking Frigate API..."
curl --fail --silent --show-error "${EDGE_BASE_URL}/api/version" >/dev/null

echo "Checking events feed..."
curl --fail --silent --show-error "${EDGE_BASE_URL}/api/events?limit=1" >/dev/null

if [[ -n "${EVENT_ID:-}" ]]; then
  echo "Checking snapshot ref for ${EVENT_ID}..."
  curl --fail --silent --show-error -I "${EDGE_BASE_URL}/api/events/${EVENT_ID}/snapshot.jpg" >/dev/null

  echo "Checking clip ref for ${EVENT_ID}..."
  if ! curl --fail --silent --show-error -I "${EDGE_BASE_URL}/api/events/${EVENT_ID}/clip.mp4" >/dev/null; then
    curl --fail --silent --show-error -H "Range: bytes=0-0" "${EDGE_BASE_URL}/api/events/${EVENT_ID}/clip.mp4" >/dev/null
  fi
fi

echo "Pilot edge validation passed."
