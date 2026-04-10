#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request
import uuid
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "config" / "onyx.local.json"
DEFAULT_FACE_GALLERY = ROOT / "tool" / "face_gallery"
DEFAULT_PUBLIC_API_BASE = "https://api.onyxsecurity.co.za"

INDUSTRY_CHOICES = ("residential", "retail", "warehouse", "office", "other")
ZONE_TYPE_CHOICES = ("perimeter", "semi_perimeter", "indoor", "other")


@dataclass(frozen=True)
class SiteSetup:
    site_id: str
    client_id: str
    client_name: str
    address: str
    industry_type: str
    camera_count: int
    nvr_ip: str
    nvr_username: str
    nvr_password: str
    expected_occupancy: int
    telegram_chat_id: str
    gallery_dir: Path


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


def _slug_tokens(value: str) -> list[str]:
    return [token.upper() for token in re.findall(r"[A-Za-z0-9]+", value)]


def _site_id_default(client_name: str, address: str) -> str:
    client_tokens = _slug_tokens(client_name)[:3] or ["CLIENT"]
    address_tokens = _slug_tokens(address)[:3] or ["SITE"]
    return f"SITE-{'-'.join(client_tokens)}-{'-'.join(address_tokens)}"


def _client_id_default(client_name: str) -> str:
    client_tokens = _slug_tokens(client_name)[:3] or ["CLIENT"]
    return f"CLIENT-{'-'.join(client_tokens)}"


def _person_id_for(site_id: str, role: str, display_name: str) -> str:
    site_token = site_id.replace("SITE-", "").replace("-", "_")
    name_tokens = _slug_tokens(display_name)[:3] or ["PERSON"]
    role_token = (role or "resident").strip().upper() or "RESIDENT"
    return f"{site_token}_{role_token}_{'_'.join(name_tokens)}"


def _prompt(text: str, *, default: str | None = None, required: bool = False) -> str:
    while True:
        suffix = f" [{default}]" if default not in (None, "") else ""
        raw = input(f"{text}{suffix}: ").strip()
        if raw:
            return raw
        if default is not None:
            return default
        if not required:
            return ""
        print("A value is required.")


def _prompt_int(text: str, *, default: int | None = None, minimum: int = 0) -> int:
    while True:
        raw = _prompt(text, default="" if default is None else str(default), required=default is None)
        try:
            value = int(raw)
        except ValueError:
            print("Enter a whole number.")
            continue
        if value < minimum:
            print(f"Value must be at least {minimum}.")
            continue
        return value


def _prompt_choice(text: str, choices: tuple[str, ...], *, default: str) -> str:
    normalized = {choice.lower(): choice for choice in choices}
    choice_label = "/".join(choices)
    while True:
        raw = _prompt(f"{text} ({choice_label})", default=default, required=True).lower()
        if raw in normalized:
            return normalized[raw]
        print(f"Choose one of: {choice_label}")


def _rest_request(
    *,
    base_url: str,
    service_key: str,
    method: str,
    table: str,
    params: dict[str, object] | None = None,
    payload: object | None = None,
    prefer: str | None = None,
) -> object:
    query = urllib.parse.urlencode(params or {}, doseq=True)
    url = f"{base_url.rstrip('/')}/rest/v1/{table}"
    if query:
        url = f"{url}?{query}"
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if prefer:
        headers["Prefer"] = prefer
    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
    if not body:
        return None
    return json.loads(body.decode("utf-8"))


def _get_rows(base_url: str, service_key: str, table: str, params: dict[str, object]) -> list[dict]:
    response = _rest_request(
        base_url=base_url,
        service_key=service_key,
        method="GET",
        table=table,
        params=params,
    )
    if not isinstance(response, list):
        return []
    return [row for row in response if isinstance(row, dict)]


def _upsert_rows(
    *,
    base_url: str,
    service_key: str,
    table: str,
    rows: list[dict],
    on_conflict: str,
) -> list[dict]:
    response = _rest_request(
        base_url=base_url,
        service_key=service_key,
        method="POST",
        table=table,
        params={"on_conflict": on_conflict},
        payload=rows,
        prefer="resolution=merge-duplicates,return=representation",
    )
    if not isinstance(response, list):
        return []
    return [row for row in response if isinstance(row, dict)]


def _industry_storage(industry_choice: str) -> str:
    return "custom" if industry_choice == "other" else industry_choice


def _occupancy_defaults(industry_choice: str, expected_occupancy: int) -> tuple[str, str]:
    if industry_choice == "residential":
        return ("residents", "private_residence")
    if industry_choice == "retail":
        return ("staff", "retail")
    if industry_choice == "warehouse":
        return ("staff", "warehouse")
    if industry_choice == "office":
        return ("staff", "office")
    return ("people", "custom")


def _profile_row(setup: SiteSetup) -> dict:
    industry = _industry_storage(setup.industry_type)
    row = {
        "site_id": setup.site_id,
        "industry_type": industry,
        "timezone": "Africa/Johannesburg",
        "has_guard": False,
        "has_armed_response": False,
        "send_shift_start_briefing": True,
        "send_shift_end_report": True,
        "send_daily_summary": True,
        "custom_rules": [],
    }
    if setup.industry_type == "residential":
        row.update(
            {
                "operating_hours_start": "06:00",
                "operating_hours_end": "22:00",
                "expected_resident_count": setup.expected_occupancy,
                "monitor_staff_activity": False,
                "monitor_vehicle_movement": True,
            }
        )
    elif setup.industry_type == "retail":
        row.update(
            {
                "operating_hours_start": "08:00",
                "operating_hours_end": "18:00",
                "expected_staff_count": setup.expected_occupancy,
                "monitor_staff_activity": True,
                "monitor_till_attendance": True,
                "during_hours_sensitivity": "medium",
            }
        )
    elif setup.industry_type == "warehouse":
        row.update(
            {
                "operating_hours_start": "06:00",
                "operating_hours_end": "18:00",
                "expected_staff_count": setup.expected_occupancy,
                "monitor_staff_activity": True,
                "monitor_vehicle_movement": True,
                "during_hours_sensitivity": "medium",
            }
        )
    elif setup.industry_type == "office":
        row.update(
            {
                "operating_hours_start": "07:00",
                "operating_hours_end": "18:00",
                "expected_staff_count": setup.expected_occupancy,
                "monitor_staff_activity": True,
                "monitor_vehicle_movement": True,
                "during_hours_sensitivity": "low",
            }
        )
    else:
        row.update(
            {
                "operating_hours_start": "08:00",
                "operating_hours_end": "18:00",
                "expected_staff_count": setup.expected_occupancy,
                "during_hours_sensitivity": "medium",
            }
        )
    return row


def _alert_config_row(setup: SiteSetup) -> dict:
    if setup.industry_type == "residential":
        return {
            "site_id": setup.site_id,
            "alert_window_start": "23:00",
            "alert_window_end": "08:00",
            "timezone": "Africa/Johannesburg",
            "perimeter_sensitivity": "suspicious_only",
            "semi_perimeter_sensitivity": "suspicious_only",
            "indoor_sensitivity": "off",
            "loiter_detection_minutes": 3,
            "perimeter_sequence_alert": True,
            "quiet_hours_sensitivity": "all_motion",
            "day_sensitivity": "suspicious_only",
            "vehicle_daytime_threshold": "quiet_hours_only",
        }
    return {
        "site_id": setup.site_id,
        "alert_window_start": "18:00",
        "alert_window_end": "06:00",
        "timezone": "Africa/Johannesburg",
        "perimeter_sensitivity": "suspicious_only",
        "semi_perimeter_sensitivity": "suspicious_only",
        "indoor_sensitivity": "off",
        "loiter_detection_minutes": 3,
        "perimeter_sequence_alert": True,
        "quiet_hours_sensitivity": "all_motion",
        "day_sensitivity": "suspicious_only",
        "vehicle_daytime_threshold": "normal",
    }


def _client_row(setup: SiteSetup) -> dict:
    return {
        "client_id": setup.client_id,
        "name": setup.client_name,
        "display_name": setup.client_name,
        "legal_name": setup.client_name,
        "contact_name": setup.client_name,
        "billing_address": setup.address,
        "metadata": {
            "industry_type": _industry_storage(setup.industry_type),
            "onboarded_via": "tool/onboard_new_site.py",
        },
        "is_active": True,
    }


def _site_row(setup: SiteSetup) -> dict:
    site_name = setup.address if setup.address else setup.site_id
    return {
        "site_id": setup.site_id,
        "client_id": setup.client_id,
        "site_name": site_name,
        "site_code": setup.site_id,
        "name": site_name,
        "code": setup.site_id,
        "timezone": "Africa/Johannesburg",
        "address_line_1": setup.address,
        "country_code": "ZA",
        "metadata": {
            "camera_count": setup.camera_count,
            "nvr_host": setup.nvr_ip,
            "industry_type": _industry_storage(setup.industry_type),
            "onboarded_via": "tool/onboard_new_site.py",
        },
        "is_active": True,
    }


def _endpoint_row(setup: SiteSetup) -> dict:
    return {
        "client_id": setup.client_id,
        "site_id": setup.site_id,
        "provider": "telegram",
        "telegram_chat_id": setup.telegram_chat_id,
        "display_label": setup.address or setup.client_name,
        "endpoint_role": "client",
        "verified_at": _utc_now(),
        "is_active": True,
        "metadata": {},
    }


def _utc_now() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()


def _zone_row(site_id: str, channel_id: int, zone_name: str, zone_type: str, notes: str) -> dict:
    return {
        "site_id": site_id,
        "channel_id": channel_id,
        "zone_name": zone_name,
        "zone_type": zone_type,
        "is_perimeter": zone_type == "perimeter",
        "is_indoor": zone_type == "indoor",
        "notes": notes or None,
    }


def _collect_site_setup(gallery_root: Path) -> SiteSetup:
    print("ONYX client onboarding wizard\n")
    client_name = _prompt("Client name", required=True)
    address = _prompt("Address", required=True)
    generated_site_id = _site_id_default(client_name, address)
    site_id = _prompt("Site ID", default=generated_site_id, required=True).upper()
    client_id = _client_id_default(client_name)
    print(f"Client ID will be {client_id}")
    industry_type = _prompt_choice("Industry type", INDUSTRY_CHOICES, default="residential")
    camera_count = _prompt_int("Camera count", default=16, minimum=1)
    nvr_ip = _prompt("NVR IP", required=True)
    nvr_username = _prompt("NVR username", required=True)
    if sys.stdin.isatty():
        try:
            import getpass

            nvr_password = getpass.getpass("NVR password: ").strip()
        except Exception:
            nvr_password = _prompt("NVR password", required=True)
    else:
        nvr_password = _prompt("NVR password", required=True)
    expected_occupancy = _prompt_int("Expected occupancy", default=4, minimum=0)
    telegram_chat_id = _prompt("Client Telegram chat ID", required=True)
    gallery_dir = gallery_root / site_id
    return SiteSetup(
        site_id=site_id,
        client_id=client_id,
        client_name=client_name,
        address=address,
        industry_type=industry_type,
        camera_count=camera_count,
        nvr_ip=nvr_ip,
        nvr_username=nvr_username,
        nvr_password=nvr_password,
        expected_occupancy=expected_occupancy,
        telegram_chat_id=telegram_chat_id,
        gallery_dir=gallery_dir,
    )


def _collect_zone_rows(site_id: str, camera_count: int) -> list[dict]:
    print("\nZone mapping")
    print("Enter a zone name and type for each channel. Leave the name blank to skip a channel.")
    rows: list[dict] = []
    for channel_id in range(1, camera_count + 1):
        zone_name = _prompt(
            f"Channel {channel_id} zone name (suggested: Channel {channel_id})",
            default="",
        )
        if not zone_name.strip():
            continue
        zone_choice = _prompt_choice("Zone type", ZONE_TYPE_CHOICES, default="semi_perimeter")
        zone_type = zone_choice
        if zone_choice == "other":
            zone_type = _prompt("Custom zone type", default="other", required=True).strip().lower()
        notes = _prompt("Notes", default="")
        rows.append(_zone_row(site_id, channel_id, zone_name.strip(), zone_type, notes.strip()))
        print("")
    return rows


def _collect_people_to_enroll(site_id: str) -> list[str]:
    raw = _prompt(
        "People to enroll later (comma separated names, optional)",
        default="",
    ).strip()
    if not raw:
        return []
    names = [segment.strip() for segment in raw.split(",") if segment.strip()]
    if names:
        print("\nFR enrollment commands")
        for name in names:
            person_id = _person_id_for(site_id, "resident", name)
            print(
                f"python3 tool/enroll_person.py --site {site_id} "
                f"--person-id {person_id} --name \"{name}\" --role resident "
                f"--photos /path/to/{person_id.lower()}_1.jpg /path/to/{person_id.lower()}_2.jpg"
            )
    return names


def _upsert_client_endpoint(
    *,
    base_url: str,
    service_key: str,
    row: dict,
) -> dict:
    existing = _get_rows(
        base_url,
        service_key,
        "client_messaging_endpoints",
        {
            "select": "id",
            "client_id": f"eq.{row['client_id']}",
            "site_id": f"eq.{row['site_id']}",
            "provider": "eq.telegram",
            "telegram_chat_id": f"eq.{row['telegram_chat_id']}",
            "limit": "1",
        },
    )
    if existing:
        endpoint_id = existing[0]["id"]
        updated = _rest_request(
            base_url=base_url,
            service_key=service_key,
            method="PATCH",
            table="client_messaging_endpoints",
            params={"id": f"eq.{endpoint_id}", "select": "*"},
            payload=row,
            prefer="return=representation",
        )
        if isinstance(updated, list) and updated and isinstance(updated[0], dict):
            return updated[0]
        return dict(existing[0])
    created = _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="client_messaging_endpoints",
        rows=[row],
        on_conflict="client_id,id",
    )
    return created[0] if created else {}


def _insert_api_token(base_url: str, service_key: str, site_id: str) -> str:
    token = str(uuid.uuid4())
    created = _rest_request(
        base_url=base_url,
        service_key=service_key,
        method="POST",
        table="site_api_tokens",
        payload=[
            {
                "site_id": site_id,
                "token": token,
                "label": "onboarding-wizard",
            }
        ],
        prefer="return=representation",
    )
    if isinstance(created, list) and created:
        return str(created[0].get("token", token))
    return token


def _create_records(
    *,
    base_url: str,
    service_key: str,
    setup: SiteSetup,
    zone_rows: list[dict],
) -> dict[str, object]:
    _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="clients",
        rows=[_client_row(setup)],
        on_conflict="client_id",
    )
    _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="sites",
        rows=[_site_row(setup)],
        on_conflict="site_id",
    )
    _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="site_intelligence_profiles",
        rows=[_profile_row(setup)],
        on_conflict="site_id",
    )
    occupancy_label, site_type = _occupancy_defaults(setup.industry_type, setup.expected_occupancy)
    _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="site_occupancy_config",
        rows=[
            {
                "site_id": setup.site_id,
                "expected_occupancy": setup.expected_occupancy,
                "occupancy_label": occupancy_label,
                "site_type": site_type,
                "reset_hour": 3,
                "has_guard": False,
                "has_gate_sensors": False,
            }
        ],
        on_conflict="site_id",
    )
    _upsert_rows(
        base_url=base_url,
        service_key=service_key,
        table="site_alert_config",
        rows=[_alert_config_row(setup)],
        on_conflict="site_id",
    )
    if zone_rows:
        _upsert_rows(
            base_url=base_url,
            service_key=service_key,
            table="site_camera_zones",
            rows=zone_rows,
            on_conflict="site_id,channel_id",
        )
    endpoint = _upsert_client_endpoint(
        base_url=base_url,
        service_key=service_key,
        row=_endpoint_row(setup),
    )
    token = _insert_api_token(base_url, service_key, setup.site_id)
    return {
        "endpoint": endpoint,
        "token": token,
    }


def _welcome_message(setup: SiteSetup, token: str, api_base_url: str) -> str:
    status_url = f"{api_base_url.rstrip('/')}/v1/status/{setup.site_id}?token={token}"
    return "\n".join(
        [
            f"Welcome to ONYX, {setup.client_name}.",
            f"{setup.address} is now configured for {setup.camera_count} camera channels.",
            "You can ask this group for live status, incidents, reports, and visitor updates.",
            "",
            f"Voice assistant status URL: {status_url}",
            "Reply here if you want to add residents, staff, visitors, or patrol rules.",
        ]
    )


def _print_summary(
    *,
    setup: SiteSetup,
    zone_rows: list[dict],
    enroll_names: list[str],
    token: str,
    api_base_url: str,
    dry_run: bool,
) -> None:
    status_url = f"{api_base_url.rstrip('/')}/v1/status/{setup.site_id}?token={token}"
    print("\nOnboarding summary")
    print(f"- Mode: {'dry run' if dry_run else 'records created'}")
    print(f"- Site ID: {setup.site_id}")
    print(f"- Client ID: {setup.client_id}")
    print(f"- Industry: {_industry_storage(setup.industry_type)}")
    print(f"- Cameras mapped: {len(zone_rows)} of {setup.camera_count}")
    print(f"- Expected occupancy: {setup.expected_occupancy}")
    print(f"- Client Telegram chat: {setup.telegram_chat_id}")
    print(f"- API token: {token}")
    print(f"- Siri shortcut URL: {status_url}")
    print(f"- FR gallery directory: {setup.gallery_dir}")
    print("\nNext steps")
    print("- Install the site-specific NVR credentials into the deployment config.")
    print("- Confirm all camera channels are mapped correctly after live viewing.")
    print("- Enroll residents/staff with 3-5 face photos each.")
    print("- Send the welcome message to the client Telegram group.")
    print("- Test the status API URL from Siri Shortcuts or Alexa.")
    if enroll_names:
        print("- Finish the FR enrollment commands printed above.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Interactive ONYX site onboarding wizard.")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG), help="Path to config JSON")
    parser.add_argument(
        "--api-base-url",
        default=DEFAULT_PUBLIC_API_BASE,
        help="Public API base URL for Siri/Alexa shortcut links",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Collect inputs and print outputs without writing to Supabase",
    )
    args = parser.parse_args()

    config = _load_config(Path(args.config))
    supabase_url = _config_string(config, "SUPABASE_URL")
    service_key = _config_string(config, "ONYX_SUPABASE_SERVICE_KEY")
    if not args.dry_run and (not supabase_url or not service_key):
        print("SUPABASE_URL and ONYX_SUPABASE_SERVICE_KEY are required.", file=sys.stderr)
        return 1

    setup = _collect_site_setup(DEFAULT_FACE_GALLERY)
    if not args.dry_run:
        setup.gallery_dir.mkdir(parents=True, exist_ok=True)
    zone_rows = _collect_zone_rows(setup.site_id, setup.camera_count)
    enroll_names = _collect_people_to_enroll(setup.site_id)

    token = str(uuid.uuid4())
    if not args.dry_run:
        created = _create_records(
            base_url=supabase_url,
            service_key=service_key,
            setup=setup,
            zone_rows=zone_rows,
        )
        token = str(created["token"])

    print("\nClient welcome message")
    print(_welcome_message(setup, token, args.api_base_url))
    _print_summary(
        setup=setup,
        zone_rows=zone_rows,
        enroll_names=enroll_names,
        token=token,
        api_base_url=args.api_base_url,
        dry_run=args.dry_run,
    )
    print("\nNVR credentials captured for deployment handoff and intentionally not written to Supabase.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
