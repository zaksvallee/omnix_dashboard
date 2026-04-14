#!/usr/bin/env python3
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "config" / "onyx.local.json"
DEFAULT_GALLERY = ROOT / "tool" / "face_gallery"
_FR_ENABLED_ENV_RAW = os.getenv("ONYX_FR_ENABLED")
FR_ENABLED = (_FR_ENABLED_ENV_RAW or "false").strip().lower() == "true"
_FACE_RECOGNITION_MODULE = None
_FACE_RECOGNITION_IMPORT_ERROR = ""

if FR_ENABLED:
    try:
        import face_recognition as _FACE_RECOGNITION_MODULE
    except ImportError as exc:
        FR_ENABLED = False
        _FACE_RECOGNITION_IMPORT_ERROR = str(exc)


def _load_config(path: Path) -> dict:
    if not path.exists():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError("Config must be a JSON object.")
    return data


def _config_string(config: dict, key: str, fallback: str = "") -> str:
    value = os.environ.get(key)
    if value is not None:
        return value.strip()
    return str(config.get(key, fallback)).strip()


def _require_face_recognition():
    if _FACE_RECOGNITION_MODULE is not None:
        return _FACE_RECOGNITION_MODULE
    if _FACE_RECOGNITION_IMPORT_ERROR:
        raise RuntimeError(
            "face_recognition is not installed. Run: pip3 install face_recognition pillow"
        ) from None
    raise RuntimeError(
        "Face recognition is disabled. Set ONYX_FR_ENABLED=true to validate enrollment photos."
    )


def _validate_face(path: Path) -> None:
    face_recognition = _require_face_recognition()
    image = face_recognition.load_image_file(str(path))
    locations = face_recognition.face_locations(image)
    if not locations:
        raise ValueError(f"No detectable face found in {path}.")


def _prepare_photo(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        prepared = ImageOps.fit(
            image.convert("RGB"),
            (640, 640),
            method=Image.Resampling.LANCZOS,
        )
        prepared.save(destination, format="JPEG", quality=92)
    _validate_face(destination)


def _upsert_registry_row(
    *,
    supabase_url: str,
    service_key: str,
    site_id: str,
    person_id: str,
    display_name: str,
    role: str,
    photo_count: int,
    gallery_path: str,
) -> None:
    payload = json.dumps(
        [
            {
                "site_id": site_id,
                "person_id": person_id,
                "display_name": display_name,
                "role": role,
                "is_private": True,
                "photo_count": photo_count,
                "gallery_path": gallery_path,
                "is_enrolled": True,
                "enrolled_at": _iso_now(),
                "is_active": True,
            }
        ]
    ).encode("utf-8")
    query = urllib.parse.urlencode({"on_conflict": "person_id"})
    request = urllib.request.Request(
        f"{supabase_url.rstrip('/')}/rest/v1/fr_person_registry?{query}",
        data=payload,
        method="POST",
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        response.read()


def _iso_now() -> str:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc).isoformat()


def main() -> int:
    parser = argparse.ArgumentParser(description="Enroll a person into the ONYX FR gallery.")
    parser.add_argument("--site", required=True, help="Site ID, e.g. SITE-MS-VALLEE-RESIDENCE")
    parser.add_argument("--person-id", required=True, help="Unique person identifier")
    parser.add_argument("--name", required=True, help="Display name")
    parser.add_argument("--role", default="resident", help="resident | staff | guard | regular_visitor")
    parser.add_argument("--photos", nargs="+", required=True, help="One or more source photos")
    parser.add_argument("--config", default=str(DEFAULT_CONFIG), help="Config JSON path")
    parser.add_argument("--gallery-root", default=str(DEFAULT_GALLERY), help="Gallery root path")
    args = parser.parse_args()

    config = _load_config(Path(args.config))
    supabase_url = _config_string(config, "SUPABASE_URL")
    service_key = _config_string(config, "ONYX_SUPABASE_SERVICE_KEY")
    if not supabase_url or not service_key:
        print("SUPABASE_URL and ONYX_SUPABASE_SERVICE_KEY are required.", file=sys.stderr)
        return 1

    site_id = args.site.strip()
    person_id = args.person_id.strip().upper()
    display_name = args.name.strip()
    role = args.role.strip().lower() or "resident"
    if not site_id or not person_id or not display_name:
        print("site, person-id, and name are required.", file=sys.stderr)
        return 1

    gallery_dir = Path(args.gallery_root).expanduser().resolve() / site_id / person_id
    gallery_dir.mkdir(parents=True, exist_ok=True)

    written = []
    for index, raw_path in enumerate(args.photos, start=1):
        source = Path(raw_path).expanduser().resolve()
        if not source.exists():
            print(f"Photo not found: {source}", file=sys.stderr)
            return 1
        destination = gallery_dir / f"{person_id}_{index}.jpg"
        _prepare_photo(source, destination)
        written.append(destination)

    _upsert_registry_row(
        supabase_url=supabase_url,
        service_key=service_key,
        site_id=site_id,
        person_id=person_id,
        display_name=display_name,
        role=role,
        photo_count=len(written),
        gallery_path=str(gallery_dir.relative_to(ROOT)),
    )

    print("ONYX FR enrollment complete")
    print(f"  Site: {site_id}")
    print(f"  Person ID: {person_id}")
    print(f"  Name: {display_name}")
    print(f"  Role: {role}")
    print(f"  Gallery: {gallery_dir}")
    print(f"  Photos enrolled: {len(written)}")
    for path in written:
        print(f"    - {path.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
