#!/usr/bin/env python3
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "config" / "onyx.local.json"


def _load_config(path: Path) -> dict:
    if not path.exists():
        return {}
    decoded = json.loads(path.read_text())
    if not isinstance(decoded, dict):
        raise ValueError("Config must be a JSON object.")
    return decoded


def _config_string(config: dict, key: str, fallback: str = "") -> str:
    value = os.environ.get(key)
    if value is not None:
        return value.strip()
    return str(config.get(key, fallback)).strip()


def _rest_rows(base_url: str, service_key: str, table: str, params: dict) -> list[dict]:
    query = urllib.parse.urlencode(params, doseq=True)
    url = f"{base_url.rstrip('/')}/rest/v1/{table}?{query}"
    request = urllib.request.Request(
        url,
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        decoded = json.loads(response.read().decode("utf-8"))
        if not isinstance(decoded, list):
            return []
        return [row for row in decoded if isinstance(row, dict)]


def main() -> int:
    config = _load_config(DEFAULT_CONFIG)
    supabase_url = _config_string(config, "SUPABASE_URL")
    service_key = _config_string(config, "ONYX_SUPABASE_SERVICE_KEY")
    site_id = _config_string(config, "ONYX_SITE_ID", "SITE-MS-VALLEE-RESIDENCE")
    if not supabase_url or not service_key:
        print("SUPABASE_URL and ONYX_SUPABASE_SERVICE_KEY are required.", file=sys.stderr)
        return 1

    fr_rows = _rest_rows(
        supabase_url,
        service_key,
        "fr_person_registry",
        {"select": "person_id", "site_id": f"eq.{site_id}", "is_active": "eq.true"},
    )
    zone_rows = _rest_rows(
        supabase_url,
        service_key,
        "site_camera_zones",
        {"select": "channel_id", "site_id": f"eq.{site_id}", "limit": "1"},
    )
    alert_rows = _rest_rows(
        supabase_url,
        service_key,
        "site_alert_config",
        {"select": "site_id", "site_id": f"eq.{site_id}", "limit": "1"},
    )
    profile_rows = _rest_rows(
        supabase_url,
        service_key,
        "site_intelligence_profiles",
        {"select": "industry_type,has_guard", "site_id": f"eq.{site_id}", "limit": "1"},
    )
    checkpoint_rows = _rest_rows(
        supabase_url,
        service_key,
        "patrol_checkpoints",
        {"select": "id", "site_id": f"eq.{site_id}", "is_active": "eq.true"},
    )

    industry = profile_rows[0].get("industry_type", "not configured") if profile_rows else "not configured"
    has_guard = bool(profile_rows[0].get("has_guard")) if profile_rows else False

    print(f"ONYX onboarding checklist — {site_id}")
    print(f"- FR gallery: {len(fr_rows)} people enrolled")
    print(f"- Zone mapping: {'configured' if zone_rows else 'not configured'}")
    print(f"- Alert config: {'configured' if alert_rows else 'not configured'}")
    print(f"- Guard assigned: {'yes' if has_guard else 'no'}")
    print(f"- Patrol routes: {len(checkpoint_rows)} checkpoints configured")
    print(f"- Site profile: {industry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
