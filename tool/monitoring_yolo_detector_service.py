#!/usr/bin/env python3
import argparse
import base64
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple
from urllib.parse import urlparse


_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
_DEFAULT_FACE_DETECTOR_URL = (
    "https://github.com/opencv/opencv_zoo/raw/main/models/"
    "face_detection_yunet/face_detection_yunet_2023mar.onnx"
)
_DEFAULT_FACE_RECOGNIZER_URL = (
    "https://github.com/opencv/opencv_zoo/raw/main/models/"
    "face_recognition_sface/face_recognition_sface_2021dec.onnx"
)
_DEFAULT_PLATE_REGEX = r"^(?=.*[A-Z])(?=.*\d)[A-Z0-9]{5,10}$"
_DEFAULT_LPR_ALLOWLIST = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
_FR_ENABLED_ENV_RAW = os.getenv("ONYX_FR_ENABLED")
FR_ENABLED = (_FR_ENABLED_ENV_RAW or "false").strip().lower() == "true"
_FACE_RECOGNITION_MODULE = None
_FACE_RECOGNITION_IMPORT_ERROR = ""
_LPR_ENABLED_ENV_RAW = os.getenv("ONYX_LPR_ENABLED")
LPR_ENABLED = (_LPR_ENABLED_ENV_RAW or "false").strip().lower() == "true"
_EASYOCR_MODULE = None
_EASYOCR_IMPORT_ERROR = ""

if FR_ENABLED:
    try:
        import face_recognition as _FACE_RECOGNITION_MODULE
    except ImportError as exc:
        FR_ENABLED = False
        _FACE_RECOGNITION_IMPORT_ERROR = str(exc)

if LPR_ENABLED:
    try:
        import easyocr as _EASYOCR_MODULE
    except ImportError as exc:
        LPR_ENABLED = False
        _EASYOCR_IMPORT_ERROR = str(exc)


def _read_config(path: Path) -> Dict[str, Any]:
    raw = path.read_text()
    decoded = json.loads(raw)
    if not isinstance(decoded, dict):
        raise ValueError("Config must be a JSON object.")
    return decoded


def _read_string(config: Dict[str, Any], key: str, fallback: str = "") -> str:
    value = os.environ.get(key)
    if value is not None:
        return value.strip()
    return str(config.get(key, fallback)).strip()


def _read_bool(config: Dict[str, Any], key: str, fallback: bool = False) -> bool:
    raw = _read_string(config, key, fallback="true" if fallback else "false").lower()
    return raw in {"1", "true", "yes", "on"}


def _read_int(config: Dict[str, Any], key: str, fallback: int = 0) -> int:
    raw = _read_string(config, key, fallback=str(fallback))
    try:
        return int(raw)
    except ValueError:
        return fallback


def _read_float(config: Dict[str, Any], key: str, fallback: float = 0.0) -> float:
    raw = _read_string(config, key, fallback=str(fallback))
    try:
        return float(raw)
    except ValueError:
        return fallback


def _read_string_list(
    config: Dict[str, Any],
    key: str,
    fallback: Optional[Sequence[str]] = None,
) -> List[str]:
    value = os.environ.get(key)
    if value is None:
        raw_value = config.get(key)
    else:
        raw_value = value
    if raw_value is None:
        return list(fallback or [])
    if isinstance(raw_value, list):
        return [
            str(item).strip()
            for item in raw_value
            if str(item).strip()
        ]
    raw_text = str(raw_value).strip()
    if not raw_text:
        return list(fallback or [])
    try:
        decoded = json.loads(raw_text)
    except Exception:
        decoded = None
    if isinstance(decoded, list):
        return [
            str(item).strip()
            for item in decoded
            if str(item).strip()
        ]
    return [part.strip() for part in raw_text.split(",") if part.strip()]


def _fr_override_present() -> bool:
    return _FR_ENABLED_ENV_RAW is not None


def _resolved_fr_enabled(configured_enabled: bool) -> bool:
    if _fr_override_present():
        return FR_ENABLED
    return configured_enabled


def _lpr_override_present() -> bool:
    return _LPR_ENABLED_ENV_RAW is not None


def _resolved_lpr_enabled(configured_enabled: bool) -> bool:
    if _lpr_override_present():
        return LPR_ENABLED
    return configured_enabled


def _load_face_recognition_module() -> Optional[Any]:
    global _FACE_RECOGNITION_MODULE, _FACE_RECOGNITION_IMPORT_ERROR
    if _FACE_RECOGNITION_MODULE is not None:
        return _FACE_RECOGNITION_MODULE
    try:
        import face_recognition as module
    except ImportError as exc:
        _FACE_RECOGNITION_IMPORT_ERROR = str(exc)
        return None
    _FACE_RECOGNITION_MODULE = module
    _FACE_RECOGNITION_IMPORT_ERROR = ""
    return module


def _load_easyocr_module() -> Optional[Any]:
    global _EASYOCR_MODULE, _EASYOCR_IMPORT_ERROR
    if _EASYOCR_MODULE is not None:
        return _EASYOCR_MODULE
    try:
        import easyocr as module
    except ImportError as exc:
        _EASYOCR_IMPORT_ERROR = str(exc)
        return None
    _EASYOCR_MODULE = module
    _EASYOCR_IMPORT_ERROR = ""
    return module


def _contains_any(haystack: str, needles: Sequence[str]) -> bool:
    normalized = haystack.strip().lower()
    if not normalized:
        return False
    for needle in needles:
        if needle and needle in normalized:
            return True
    return False


def _normalize_label(value: str) -> Optional[str]:
    normalized = value.strip().lower()
    if not normalized or normalized == "unknown":
        return None
    if _contains_any(normalized, ("person", "human", "pedestrian", "intruder")):
        return "person"
    if _contains_any(
        normalized,
        (
            "vehicle",
            "car",
            "truck",
            "van",
            "motorbike",
            "motorcycle",
            "bus",
            "bakkie",
            "pickup",
            "suv",
        ),
    ):
        return "vehicle"
    if _contains_any(
        normalized,
        (
            "animal",
            "dog",
            "cat",
            "horse",
            "bird",
            "cow",
            "sheep",
        ),
    ):
        return "animal"
    if _contains_any(normalized, ("backpack", "back pack", "rucksack")):
        return "backpack"
    if _contains_any(
        normalized,
        (
            "handbag",
            "bag",
            "purse",
            "duffel",
            "luggage",
            "suitcase",
            "satchel",
            "tote",
        ),
    ):
        return "bag"
    if _contains_any(normalized, ("knife", "blade", "machete")):
        return "knife"
    if _contains_any(normalized, ("crowbar", "crow bar", "prybar", "pry bar")):
        return "weapon"
    if _contains_any(
        normalized,
        ("firearm", "pistol", "gun", "rifle", "shotgun", "revolver"),
    ):
        return "firearm"
    if "weapon" in normalized:
        return "weapon"
    return None


def _allowed_semantic_label(label: Optional[str]) -> bool:
    return label in {
        "person",
        "vehicle",
        "animal",
        "backpack",
        "bag",
        "knife",
        "firearm",
        "weapon",
    }


def _label_priority(label: Optional[str]) -> int:
    return {
        "firearm": 100,
        "weapon": 96,
        "knife": 90,
        "person": 76,
        "vehicle": 66,
        "backpack": 54,
        "bag": 50,
        "animal": 18,
    }.get(label or "", 0)


def _human_label(label: str) -> str:
    return {
        "person": "person activity",
        "vehicle": "vehicle activity",
        "animal": "animal activity",
        "backpack": "a backpack",
        "bag": "a bag",
        "knife": "a knife",
        "firearm": "a firearm",
        "weapon": "a weapon",
    }.get(label, label.replace("_", " "))


def _normalize_plate_candidate(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", value or "").upper()


def _decode_data_url(raw_url: str) -> bytes:
    match = re.match(r"^data:.*?;base64,(.+)$", raw_url.strip(), re.IGNORECASE | re.DOTALL)
    if not match:
        raise ValueError("Expected a base64 data URL image.")
    return base64.b64decode(match.group(1))


def _best_detection(detections: Sequence[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    best = None
    best_rank = (-1, -1.0)
    for detection in detections:
        label = detection.get("label")
        confidence = float(detection.get("confidence", 0.0) or 0.0)
        rank = (_label_priority(label), confidence)
        if rank > best_rank:
            best_rank = rank
            best = detection
    return best


def _dedupe_detections(detections: Sequence[Dict[str, Any]]) -> List[Dict[str, Any]]:
    by_label: Dict[str, Dict[str, Any]] = {}
    for detection in detections:
        label = str(detection.get("label", "")).strip()
        if not label:
            continue
        track_id = str(detection.get("track_id", "") or "").strip()
        dedupe_key = label if not track_id else f"{label}#{track_id}"
        current = by_label.get(dedupe_key)
        confidence = float(detection.get("confidence", 0.0) or 0.0)
        if current is None or confidence > float(current.get("confidence", 0.0) or 0.0):
            by_label[dedupe_key] = detection
    ordered = list(by_label.values())
    ordered.sort(
        key=lambda item: (_label_priority(item.get("label")), float(item.get("confidence", 0.0) or 0.0)),
        reverse=True,
    )
    return ordered


def _module_state(
    *,
    enabled: bool,
    configured: bool,
    ready: bool,
    detail: str = "",
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    state: Dict[str, Any] = {
        "enabled": enabled,
        "configured": configured,
        "ready": ready,
    }
    if detail:
        state["detail"] = detail
    if extra:
        state.update(extra)
    return state


def _tracking_source_key(item: Dict[str, Any]) -> str:
    parts = [
        str(item.get("client_id", "")).strip().upper(),
        str(item.get("site_id", "")).strip().upper(),
        str(item.get("camera_id", "")).strip().upper(),
    ]
    normalized = [part for part in parts if part]
    if normalized:
        return "|".join(normalized)
    fallback_parts = [
        str(item.get("provider", "")).strip().upper(),
        str(item.get("zone", "")).strip().upper(),
    ]
    fallback = [part for part in fallback_parts if part]
    return "|".join(fallback)


def _stable_track_id(source_key: str, raw_track_id: Any) -> Optional[str]:
    normalized_source = source_key.strip()
    raw_value = str(raw_track_id or "").strip()
    if not normalized_source or not raw_value:
        return None
    return f"{normalized_source}|track:{raw_value}"


class _TrackingSession:
    def __init__(self, model: Any) -> None:
        self.model = model
        self.last_used_at = time.monotonic()

    def touch(self) -> None:
        self.last_used_at = time.monotonic()


class DetectorBackend:
    backend_name = "unconfigured"

    def is_ready(self) -> Tuple[bool, str]:
        return False, "No detector backend configured."

    def module_states(self) -> Dict[str, Any]:
        return {}

    def detect(self, item: Dict[str, Any]) -> Dict[str, Any]:
        raise RuntimeError("Detector backend is not configured.")


class MockBackend(DetectorBackend):
    backend_name = "mock"

    def is_ready(self) -> Tuple[bool, str]:
        return True, ""

    def detect(self, item: Dict[str, Any]) -> Dict[str, Any]:
        text = " ".join(
            [
                str(item.get("object_label", "")),
                str(item.get("headline", "")),
                str(item.get("summary", "")),
                str(item.get("zone", "")),
            ]
        ).lower()
        source_key = _tracking_source_key(item) or "MOCK"
        detections: List[Dict[str, Any]] = []
        if "person" in text or "human" in text:
            detections.append(
                {
                    "label": "person",
                    "confidence": 0.91,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "person-1"),
                }
            )
        if "vehicle" in text or "car" in text or "driveway" in text:
            detections.append(
                {
                    "label": "vehicle",
                    "confidence": 0.89,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "vehicle-1"),
                }
            )
        if "animal" in text or "dog" in text or "cat" in text:
            detections.append(
                {
                    "label": "animal",
                    "confidence": 0.86,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "animal-1"),
                }
            )
        if "backpack" in text:
            detections.append(
                {
                    "label": "backpack",
                    "confidence": 0.8,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "backpack-1"),
                }
            )
        if "bag" in text:
            detections.append(
                {
                    "label": "bag",
                    "confidence": 0.77,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "bag-1"),
                }
            )
        if "knife" in text or "blade" in text:
            detections.append(
                {
                    "label": "knife",
                    "confidence": 0.84,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "knife-1"),
                }
            )
        if "weapon" in text or "gun" in text or "firearm" in text:
            detections.append(
                {
                    "label": "weapon",
                    "confidence": 0.83,
                    "source": "mock",
                    "track_id": _stable_track_id(source_key, "weapon-1"),
                }
            )
        detections = _dedupe_detections(detections)
        best = _best_detection(detections)
        return {
            "record_key": item["record_key"],
            "primary_label": None if best is None else best["label"],
            "confidence": 0.0 if best is None else best["confidence"],
            "track_id": None if best is None else best.get("track_id"),
            "summary": (
                f"Mock backend detected {_human_label(str(best['label']))}."
                if best is not None
                else "Mock backend found no supported objects."
            ),
            "detections": detections,
            "face_match_id": (
                "MSVALLEE_FLAGGED_EXAMPLE"
                if "flagged" in text
                else "MSVALLEE_VISITOR_EXAMPLE"
                if "visitor" in text
                else "MSVALLEE_RESIDENT_EXAMPLE"
                if "resident" in text
                else None
            ),
            "face_confidence": (
                0.88
                if any(word in text for word in ("resident", "visitor", "flagged"))
                else None
            ),
            "flagged": "flagged" in text,
            "threat_level": "high" if "flagged" in text else None,
            "plate_number": "CA123456" if "plate" in text else None,
            "plate_confidence": 0.81 if "plate" in text else None,
        }


class FaceRecognitionModule:
    def __init__(
        self,
        *,
        enabled: bool,
        gallery_dir: str,
        detector_model: str,
        recognizer_model: str,
        match_threshold: float,
        cache_dir: str,
    ) -> None:
        self.enabled = _resolved_fr_enabled(enabled)
        self.gallery_dir = Path(gallery_dir).expanduser().resolve() if gallery_dir.strip() else None
        self.detector_model_path = (
            Path(detector_model).expanduser().resolve()
            if detector_model.strip()
            else None
        )
        self.recognizer_model_path = (
            Path(recognizer_model).expanduser().resolve()
            if recognizer_model.strip()
            else None
        )
        self.cache_dir = (
            Path(cache_dir).expanduser().resolve()
            if cache_dir.strip()
            else None
        )
        self.match_threshold = match_threshold
        self._detector = None
        self._recognizer = None
        self._gallery_signature: Optional[Tuple[Tuple[str, int, int], ...]] = None
        self._gallery_embeddings: List[Dict[str, Any]] = []
        self._gallery_face_encodings: List[Dict[str, Any]] = []
        self._gallery_image_count = 0
        self._last_error = ""

    def module_state(self) -> Dict[str, Any]:
        if not self.enabled:
            detail = ""
            if _fr_override_present():
                detail = (
                    "Face recognition disabled by ONYX_FR_ENABLED."
                    if not FR_ENABLED
                    else ""
                )
            return _module_state(
                enabled=False,
                configured=self.gallery_dir is not None,
                ready=False,
                detail=detail,
            )
        ready, detail = self.is_ready()
        return _module_state(
            enabled=True,
            configured=self.gallery_dir is not None,
            ready=ready,
            detail=detail,
            extra={
                "gallery_dir": None if self.gallery_dir is None else str(self.gallery_dir),
                "gallery_image_count": self._gallery_image_count,
                "match_threshold": self.match_threshold,
            },
        )

    def is_ready(self) -> Tuple[bool, str]:
        if not self.enabled:
            return False, ""
        if self.gallery_dir is None:
            self._last_error = "Face recognition gallery directory is not configured."
            return False, self._last_error
        if not self.gallery_dir.exists():
            self._last_error = f"Face recognition gallery not found: {self.gallery_dir}"
            return False, self._last_error
        face_recognition = _load_face_recognition_module()
        if face_recognition is None:
            self._last_error = (
                _FACE_RECOGNITION_IMPORT_ERROR
                or "face_recognition is not installed."
            )
            return False, self._last_error
        try:
            self._ensure_models()
            self._refresh_gallery(face_recognition)
        except Exception as exc:
            self._last_error = str(exc)
            return False, self._last_error
        if not self._gallery_face_encodings:
            self._last_error = "Face recognition gallery is empty or contains no usable faces."
            return False, self._last_error
        self._last_error = ""
        return True, ""

    def match(
        self,
        image_bgr: Any,
        detections: Optional[Sequence[Dict[str, Any]]] = None,
    ) -> Optional[Dict[str, Any]]:
        if not self.enabled:
            return None
        face_recognition = _load_face_recognition_module()
        if face_recognition is None:
            self._last_error = (
                _FACE_RECOGNITION_IMPORT_ERROR
                or "face_recognition is not installed."
            )
            return None
        try:
            self._refresh_gallery(face_recognition)
        except Exception as exc:
            self._last_error = str(exc)
            return None
        if not self._gallery_face_encodings:
            return None

        height, width = image_bgr.shape[:2]
        if width >= 1000 and height >= 600:
            print(f"[ONYX] FR: Using HD frame {width}x{height} from RTSP")

        best_match_id = ""
        best_distance = None
        saw_person_crop = False
        saw_face = False
        for crop in self._candidate_face_crops(image_bgr, detections or []):
            saw_person_crop = True
            best_match_id, best_distance, crop_saw_face = self._match_attempts(
                face_recognition=face_recognition,
                attempts=self._face_attempts(crop),
                best_match_id=best_match_id,
                best_distance=best_distance,
            )
            saw_face = saw_face or crop_saw_face

        if saw_person_crop and not saw_face:
            print("[ONYX] FR: No face in crop")
        if not saw_face:
            print("[ONYX] FR: Trying direct full-frame fallback")
            best_match_id, best_distance, saw_face = self._match_attempts(
                face_recognition=face_recognition,
                attempts=self._full_frame_attempts(image_bgr),
                best_match_id=best_match_id,
                best_distance=best_distance,
            )
        if not saw_face:
            print("[ONYX] FR: No face found in direct fallback")
            return None

        if not best_match_id or best_distance is None or best_distance > self.match_threshold:
            return None

        confidence = max(0.0, min(1.0 - best_distance, 1.0))
        flagged = "_FLAGGED_" in best_match_id
        return {
            "face_match_id": best_match_id,
            "face_confidence": confidence,
            "face_distance": max(0.0, min(best_distance, 1.0)),
            "matched": True,
            "flagged": flagged,
            "threat_level": "high" if flagged else None,
        }

    def _ensure_models(self):
        import cv2

        detector_path = self._resolved_model_path(
            self.detector_model_path,
            "face_detection_yunet_2023mar.onnx",
            _DEFAULT_FACE_DETECTOR_URL,
        )
        recognizer_path = self._resolved_model_path(
            self.recognizer_model_path,
            "face_recognition_sface_2021dec.onnx",
            _DEFAULT_FACE_RECOGNIZER_URL,
        )
        if self._detector is None:
            self._detector = cv2.FaceDetectorYN_create(
                str(detector_path),
                "",
                (320, 320),
            )
        if self._recognizer is None:
            self._recognizer = cv2.FaceRecognizerSF_create(
                str(recognizer_path),
                "",
            )
        return self._detector, self._recognizer

    def _resolved_model_path(self, configured: Optional[Path], file_name: str, url: str) -> Path:
        if configured is not None:
            if not configured.exists():
                raise FileNotFoundError(f"Face recognition model not found: {configured}")
            return configured
        if self.cache_dir is None:
            raise ValueError(f"Face recognition cache directory is not configured for {file_name}.")
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        target = self.cache_dir / file_name
        if target.exists():
            return target
        temporary = target.with_suffix(f"{target.suffix}.download")
        with urllib.request.urlopen(url, timeout=30) as response:
            with temporary.open("wb") as handle:
                shutil.copyfileobj(response, handle)
        temporary.replace(target)
        return target

    def _refresh_gallery(self, face_recognition: Any) -> None:
        assert self.gallery_dir is not None
        detector, recognizer = self._ensure_models()
        files = sorted(
            path
            for path in self.gallery_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in _IMAGE_SUFFIXES
        )
        self._gallery_image_count = len(files)
        signature = tuple(
            (str(path), path.stat().st_mtime_ns, path.stat().st_size) for path in files
        )
        if signature == self._gallery_signature:
            return

        import cv2

        embeddings: List[Dict[str, Any]] = []
        face_encodings_gallery: List[Dict[str, Any]] = []
        for path in files:
            image = cv2.imread(str(path))
            if image is None:
                continue
            rgb = self._to_rgb(image)
            gallery_locations = face_recognition.face_locations(rgb, model="hog")
            gallery_encodings = face_recognition.face_encodings(rgb, gallery_locations)
            faces = self._detect_faces(detector, image)
            match_id = self._gallery_match_id(path)
            if not match_id:
                continue
            if faces:
                best_face = max(
                    faces,
                    key=lambda face: float(face[2] * face[3]) * float(face[-1] if len(face) > 14 else 1.0),
                )
                try:
                    aligned = recognizer.alignCrop(image, best_face)
                    feature = recognizer.feature(aligned)
                    embeddings.append({"match_id": match_id, "feature": feature})
                except Exception:
                    pass
            if gallery_encodings:
                best_index = 0
                if len(gallery_locations) == len(gallery_encodings):
                    best_index = max(
                        range(len(gallery_locations)),
                        key=lambda idx: (
                            (gallery_locations[idx][2] - gallery_locations[idx][0])
                            * (gallery_locations[idx][1] - gallery_locations[idx][3])
                        ),
                    )
                face_encodings_gallery.append(
                    {"match_id": match_id, "encoding": gallery_encodings[best_index]}
                )
        self._gallery_embeddings = embeddings
        self._gallery_face_encodings = face_encodings_gallery
        self._gallery_signature = signature

    def _gallery_match_id(self, path: Path) -> str:
        assert self.gallery_dir is not None
        relative = path.relative_to(self.gallery_dir)
        if len(relative.parts) > 2:
            return relative.parts[1].strip().upper()
        if len(relative.parts) > 1:
            return relative.parts[0].strip().upper()
        stem = path.stem.strip()
        return stem.split("__", 1)[0].strip().upper()

    def _detect_faces(self, detector: Any, image_bgr: Any) -> List[Any]:
        height, width = image_bgr.shape[:2]
        detector.setInputSize((width, height))
        _, faces = detector.detect(image_bgr)
        if faces is None:
            return []
        return [face for face in faces]

    def _candidate_face_crops(
        self,
        image_bgr: Any,
        detections: Sequence[Dict[str, Any]],
    ) -> List[Any]:
        crops: List[Any] = []
        frame_height, frame_width = image_bgr.shape[:2]
        for detection in detections:
            if detection.get("label") != "person":
                continue
            box = detection.get("box")
            if not isinstance(box, list) or len(box) != 4:
                continue
            raw_x1, raw_y1, raw_x2, raw_y2 = [
                int(max(0, round(float(value)))) for value in box
            ]
            person_width = max(1, raw_x2 - raw_x1)
            person_height = max(1, raw_y2 - raw_y1)
            x1 = max(0, raw_x1 - int(person_width * 0.2))
            x2 = min(frame_width, raw_x2 + int(person_width * 0.2))
            y1 = max(0, raw_y1 - int(person_height * 0.08))
            top_40_end = min(frame_height, y1 + int(person_height * 0.42))
            top_55_end = min(frame_height, y1 + int(person_height * 0.55))
            center_margin = int((x2 - x1) * 0.1)
            center_x1 = min(x2, max(0, x1 + center_margin))
            center_x2 = max(center_x1, min(frame_width, x2 - center_margin))
            variants = [
                image_bgr[y1:top_40_end, x1:x2],
                image_bgr[y1:top_55_end, x1:x2],
                image_bgr[y1:top_55_end, center_x1:center_x2],
            ]
            for crop in variants:
                if crop.size != 0:
                    crops.append(crop)
        return crops

    def _full_frame_attempts(self, image_bgr: Any) -> List[Any]:
        import cv2

        height, width = image_bgr.shape[:2]
        upscaled = cv2.resize(
            image_bgr,
            None,
            fx=2.0,
            fy=2.0,
            interpolation=cv2.INTER_CUBIC,
        )
        gray = cv2.cvtColor(upscaled, cv2.COLOR_BGR2GRAY)
        equalized = cv2.equalizeHist(gray)
        equalized_bgr = cv2.cvtColor(equalized, cv2.COLOR_GRAY2BGR)
        if width >= 1000 and height >= 600:
            return [upscaled, image_bgr, equalized_bgr]
        return [image_bgr, upscaled, equalized_bgr]

    def _face_attempts(self, crop: Any) -> List[Any]:
        import cv2

        upscaled = cv2.resize(
            crop,
            None,
            fx=4.0,
            fy=4.0,
            interpolation=cv2.INTER_CUBIC,
        )
        gray = cv2.cvtColor(upscaled, cv2.COLOR_BGR2GRAY)
        equalized = cv2.equalizeHist(gray)
        equalized_bgr = cv2.cvtColor(equalized, cv2.COLOR_GRAY2BGR)
        return [upscaled, equalized_bgr]

    def _match_attempts(
        self,
        *,
        face_recognition: Any,
        attempts: Sequence[Any],
        best_match_id: str,
        best_distance: Optional[float],
    ) -> Tuple[str, Optional[float], bool]:
        saw_face = False
        for attempt in attempts:
            rgb = self._to_rgb(attempt)
            locations = face_recognition.face_locations(rgb, model="cnn")
            if not locations:
                locations = face_recognition.face_locations(rgb, model="hog")
            if not locations:
                continue
            saw_face = True
            encodings = face_recognition.face_encodings(rgb, locations)
            for encoding in encodings:
                distances = face_recognition.face_distance(
                    [entry["encoding"] for entry in self._gallery_face_encodings],
                    encoding,
                )
                if len(distances) == 0:
                    continue
                best_index = int(distances.argmin())
                distance = float(distances[best_index])
                if best_distance is None or distance < best_distance:
                    best_distance = distance
                    best_match_id = self._gallery_face_encodings[best_index]["match_id"]
        return best_match_id, best_distance, saw_face

    def _to_rgb(self, image_bgr: Any):
        import cv2

        return cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)


class PlateRecognitionModule:
    def __init__(
        self,
        *,
        enabled: bool,
        languages: Sequence[str],
        minimum_confidence: float,
        allowlist: str,
        plate_regex: str,
    ) -> None:
        self.enabled = _resolved_lpr_enabled(enabled)
        self.languages = [item for item in languages if item.strip()] or ["en"]
        self.minimum_confidence = minimum_confidence
        self.allowlist = allowlist.strip() or _DEFAULT_LPR_ALLOWLIST
        self.plate_regex = re.compile(plate_regex.strip() or _DEFAULT_PLATE_REGEX)
        self._reader = None
        self._last_error = ""

    def module_state(self) -> Dict[str, Any]:
        if not self.enabled:
            detail = ""
            if _lpr_override_present():
                detail = (
                    _EASYOCR_IMPORT_ERROR
                    or "License plate recognition disabled by ONYX_LPR_ENABLED."
                )
            return _module_state(enabled=False, configured=False, ready=False, detail=detail)
        ready, detail = self.is_ready()
        return _module_state(
            enabled=True,
            configured=True,
            ready=ready,
            detail=detail,
            extra={
                "languages": self.languages,
                "minimum_confidence": self.minimum_confidence,
            },
        )

    def is_ready(self) -> Tuple[bool, str]:
        if not self.enabled:
            return False, ""
        easyocr = _load_easyocr_module()
        if easyocr is None:
            self._last_error = (
                _EASYOCR_IMPORT_ERROR
                or "easyocr is not installed."
            )
            return False, self._last_error
        self._last_error = ""
        return True, ""

    def detect(
        self,
        image_bgr: Any,
        detections: Sequence[Dict[str, Any]],
        item: Dict[str, Any],
    ) -> Optional[Dict[str, Any]]:
        if not self.enabled:
            return None
        try:
            reader = self._ensure_reader()
        except Exception as exc:
            self._last_error = str(exc)
            return None

        best_candidate = None
        best_score = -1.0
        for priority, crop in self._candidate_crops(image_bgr, detections, item):
            if crop.size == 0:
                continue
            attempts = self._ocr_attempts(crop)
            for attempt in attempts:
                results = reader.readtext(
                    attempt,
                    detail=1,
                    paragraph=False,
                    allowlist=self.allowlist,
                )
                for raw_result in results:
                    if len(raw_result) < 3:
                        continue
                    text = str(raw_result[1]).strip()
                    confidence = float(raw_result[2] or 0.0)
                    plate = _normalize_plate_candidate(text)
                    if not plate or not self.plate_regex.match(plate):
                        continue
                    if confidence < self.minimum_confidence:
                        continue
                    score = confidence + priority
                    if score > best_score:
                        best_score = score
                        best_candidate = {
                            "plate_number": plate,
                            "plate_confidence": confidence,
                        }
        return best_candidate

    def _ocr_attempts(self, crop: Any) -> List[Any]:
        import cv2

        height, width = crop.shape[:2]
        if max(height, width) <= 160:
            scale = 6.0
        elif max(height, width) <= 280:
            scale = 4.0
        else:
            scale = 2.0
        upscaled = cv2.resize(
            crop,
            None,
            fx=scale,
            fy=scale,
            interpolation=cv2.INTER_CUBIC,
        )
        gray = cv2.cvtColor(upscaled, cv2.COLOR_BGR2GRAY)
        enhanced = cv2.equalizeHist(gray)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray)
        blurred = cv2.GaussianBlur(enhanced, (3, 3), 0)
        bilateral = cv2.bilateralFilter(clahe, 9, 75, 75)
        _, binary = cv2.threshold(
            blurred,
            0,
            255,
            cv2.THRESH_BINARY + cv2.THRESH_OTSU,
        )
        adaptive = cv2.adaptiveThreshold(
            bilateral,
            255,
            cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY,
            31,
            5,
        )
        return [upscaled, gray, enhanced, clahe, bilateral, binary, adaptive]

    def _ensure_reader(self):
        if self._reader is not None:
            return self._reader
        easyocr = _load_easyocr_module()
        if easyocr is None:
            raise RuntimeError(
                _EASYOCR_IMPORT_ERROR
                or "EasyOCR is required for the ONYX LPR pipeline."
            )
        self._reader = easyocr.Reader(self.languages, gpu=False, verbose=False)
        return self._reader

    def _candidate_crops(
        self,
        image_bgr: Any,
        detections: Sequence[Dict[str, Any]],
        item: Dict[str, Any],
    ) -> List[Tuple[float, Any]]:
        crops: List[Tuple[float, Any]] = []
        height, width = image_bgr.shape[:2]
        for detection in detections:
            if detection.get("label") != "vehicle":
                continue
            box = detection.get("box")
            if not isinstance(box, list) or len(box) != 4:
                continue
            raw_x1, raw_y1, raw_x2, raw_y2 = [
                int(max(0, round(float(value)))) for value in box
            ]
            vehicle_width = max(1, raw_x2 - raw_x1)
            vehicle_height = max(1, raw_y2 - raw_y1)
            x1 = max(0, raw_x1 - int(vehicle_width * 0.08))
            y1 = max(0, raw_y1 - int(vehicle_height * 0.08))
            x2 = min(width, raw_x2 + int(vehicle_width * 0.08))
            y2 = min(height, raw_y2 + int(vehicle_height * 0.08))

            whole_vehicle = image_bgr[y1:y2, x1:x2]
            if whole_vehicle.size != 0:
                crops.append((0.12, whole_vehicle))

            lower_half_start = y1 + int((y2 - y1) * 0.45)
            lower_half = image_bgr[lower_half_start:y2, x1:x2]
            if lower_half.size != 0:
                crops.append((0.18, lower_half))

            lower_third_start = y1 + int((y2 - y1) * 0.66)
            lower_third = image_bgr[lower_third_start:y2, x1:x2]
            if lower_third.size != 0:
                crops.append((0.24, lower_third))

            center_margin = int((x2 - x1) * 0.18)
            center_x1 = min(x2, max(0, x1 + center_margin))
            center_x2 = max(center_x1, min(width, x2 - center_margin))
            center_lower_band_start = y1 + int((y2 - y1) * 0.58)
            center_lower_band = image_bgr[
                center_lower_band_start:y2,
                center_x1:center_x2,
            ]
            if center_lower_band.size != 0:
                crops.append((0.32, center_lower_band))

            lower_quarter_start = y1 + int((y2 - y1) * 0.74)
            lower_quarter = image_bgr[lower_quarter_start:y2, x1:x2]
            if lower_quarter.size != 0:
                crops.append((0.38, lower_quarter))

            wide_center_margin = int((x2 - x1) * 0.08)
            wide_center_x1 = min(x2, max(0, x1 + wide_center_margin))
            wide_center_x2 = max(wide_center_x1, min(width, x2 - wide_center_margin))
            wide_center_strip_start = y1 + int((y2 - y1) * 0.68)
            wide_center_strip = image_bgr[
                wide_center_strip_start:y2,
                wide_center_x1:wide_center_x2,
            ]
            if wide_center_strip.size != 0:
                crops.append((0.42, wide_center_strip))
        signal_text = " ".join(
            [
                str(item.get("object_label", "")),
                str(item.get("headline", "")),
                str(item.get("summary", "")),
            ]
        ).lower()
        if width >= 1000 and height >= 600:
            hd_center_strip = image_bgr[
                int(height * 0.38):int(height * 0.62),
                int(width * 0.34):int(width * 0.72),
            ]
            if hd_center_strip.size != 0:
                crops.append((0.16, hd_center_strip))
            hd_lower_center = image_bgr[
                int(height * 0.35):int(height * 0.55),
                int(width * 0.25):int(width * 0.65),
            ]
            if hd_lower_center.size != 0:
                crops.append((0.20, hd_lower_center))
            hd_lower_third = image_bgr[
                int(height * 0.40):int(height * 0.60),
                int(width * 0.20):int(width * 0.70),
            ]
            if hd_lower_third.size != 0:
                crops.append((0.24, hd_lower_third))
        if not crops and _contains_any(signal_text, ("vehicle", "plate", "car", "truck", "gate")):
            crops.append((0.0, image_bgr))
        return crops


class UltralyticsBackend(DetectorBackend):
    backend_name = "ultralytics"

    def __init__(
        self,
        *,
        model_name: str,
        confidence: float,
        image_size: int,
        tracking_enabled: bool,
        tracker_name: str,
        track_ttl_seconds: int,
        weapon_model_name: str,
        weapon_confidence: float,
        face_module: FaceRecognitionModule,
        plate_module: PlateRecognitionModule,
    ) -> None:
        self._model_name = model_name.strip() or "yolov8l.pt"
        self._confidence = confidence
        self._image_size = image_size
        self._tracking_enabled = tracking_enabled
        self._tracker_name = tracker_name.strip() or "bytetrack"
        self._track_ttl_seconds = max(30, track_ttl_seconds)
        self._weapon_model_name = weapon_model_name.strip()
        self._weapon_confidence = weapon_confidence
        self._face_module = face_module
        self._plate_module = plate_module
        self._model = None
        self._weapon_model = None
        self._tracking_sessions: Dict[str, _TrackingSession] = {}
        self._last_error = ""

    def is_ready(self) -> Tuple[bool, str]:
        try:
            self._ensure_model()
            self._last_error = ""
            return True, ""
        except Exception as exc:  # pragma: no cover - exercised in smoke mode
            self._last_error = str(exc)
            return False, self._last_error

    def module_states(self) -> Dict[str, Any]:
        ready, detail = self.is_ready()
        modules: Dict[str, Any] = {
            "object_model": _module_state(
                enabled=True,
                configured=True,
                ready=ready,
                detail=detail,
                extra={
                    "model": self._model_name,
                    "tracking_enabled": self._tracking_enabled,
                    "tracker": self._tracker_config_name() if self._tracking_enabled else None,
                    "track_ttl_seconds": self._track_ttl_seconds,
                    "active_tracking_sources": len(self._tracking_sessions),
                },
            ),
            "weapon_model": self._weapon_module_state(),
            "face_recognition": self._face_module.module_state(),
            "license_plate": self._plate_module.module_state(),
        }
        return modules

    def detect(self, item: Dict[str, Any]) -> Dict[str, Any]:
        image_bytes = _decode_data_url(str(item["image_url"]))
        try:
            import cv2
            import numpy as np
            from PIL import Image
        except Exception as exc:  # pragma: no cover - exercised in smoke mode
            raise RuntimeError(
                f"Ultralytics backend requires Pillow, numpy, and OpenCV: {exc}"
            ) from exc

        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as exc:
            raise RuntimeError(f"Image decode failed: {exc}") from exc
        image_rgb = np.array(image)
        image_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
        source_key = _tracking_source_key(item)
        use_tracking = self._tracking_enabled and bool(source_key)
        object_model = (
            self._tracked_object_model_for_source(source_key)
            if use_tracking
            else self._ensure_model()
        )

        detections = self._predict_detections(
            model=object_model,
            image=image,
            confidence=self._confidence,
            source="object_model",
            source_key=source_key,
            use_tracking=use_tracking,
        )
        if self._weapon_model_name:
            weapon_model = self._ensure_weapon_model()
            detections.extend(
                self._predict_detections(
                    model=weapon_model,
                    image=image,
                    confidence=self._weapon_confidence,
                    source="weapon_model",
                    source_key=source_key,
                    use_tracking=False,
                )
            )
        detections = _dedupe_detections(detections)

        face_match = self._face_module.match(image_bgr, detections)
        plate_match = self._plate_module.detect(image_bgr, detections, item)

        best = _best_detection(detections)
        primary_label = None if best is None else best["label"]
        primary_confidence = 0.0 if best is None else float(best["confidence"])
        if primary_label is None and face_match is not None:
            primary_label = "person"
            primary_confidence = float(face_match["face_confidence"])
        if primary_label is None and plate_match is not None:
            primary_label = "vehicle"
            primary_confidence = float(plate_match["plate_confidence"])

        return {
            "record_key": item["record_key"],
            "primary_label": primary_label,
            "confidence": primary_confidence,
            "track_id": None if best is None else best.get("track_id"),
            "summary": self._summary_for(
                detections=detections,
                face_match=face_match,
                plate_match=plate_match,
            ),
            "detections": detections,
            "face_match": None
            if face_match is None
            else {
                "person_id": face_match["face_match_id"],
                "confidence": face_match["face_confidence"],
                "distance": face_match.get("face_distance"),
                "matched": True,
                "flagged": face_match.get("flagged", False),
                "threat_level": face_match.get("threat_level"),
            },
            "face_match_id": None if face_match is None else face_match["face_match_id"],
            "face_confidence": None if face_match is None else face_match["face_confidence"],
            "face_distance": None if face_match is None else face_match.get("face_distance"),
            "flagged": False if face_match is None else face_match.get("flagged", False),
            "threat_level": None if face_match is None else face_match.get("threat_level"),
            "plate_number": None if plate_match is None else plate_match["plate_number"],
            "plate_confidence": None if plate_match is None else plate_match["plate_confidence"],
        }

    def _ensure_model(self):
        if self._model is not None:
            return self._model
        self._model = self._create_model(self._model_name)
        return self._model

    def _create_model(self, model_name: str):
        try:
            from ultralytics import YOLO
        except Exception as exc:  # pragma: no cover - exercised in smoke mode
            raise RuntimeError(
                "Ultralytics backend requires 'ultralytics' to be installed."
            ) from exc
        return YOLO(model_name)

    def _ensure_weapon_model(self):
        if not self._weapon_model_name:
            return None
        if self._weapon_model is not None:
            return self._weapon_model
        self._weapon_model = self._create_model(self._weapon_model_name)
        return self._weapon_model

    def _tracker_config_name(self) -> str:
        normalized = self._tracker_name.strip().lower()
        if not normalized:
            return "bytetrack.yaml"
        if normalized.endswith(".yaml"):
            return normalized
        return f"{normalized}.yaml"

    def _tracked_object_model_for_source(self, source_key: str):
        self._evict_stale_tracking_sessions()
        session = self._tracking_sessions.get(source_key)
        if session is None:
            session = _TrackingSession(self._create_model(self._model_name))
            self._tracking_sessions[source_key] = session
        session.touch()
        return session.model

    def _evict_stale_tracking_sessions(self) -> None:
        if not self._tracking_sessions:
            return
        deadline = time.monotonic() - self._track_ttl_seconds
        stale = [
            key
            for key, session in self._tracking_sessions.items()
            if session.last_used_at < deadline
        ]
        for key in stale:
            self._tracking_sessions.pop(key, None)

    def _weapon_module_state(self) -> Dict[str, Any]:
        if not self._weapon_model_name:
            return _module_state(enabled=False, configured=False, ready=False)
        detail = ""
        ready = False
        try:
            self._ensure_weapon_model()
            ready = True
        except Exception as exc:
            detail = str(exc)
        return _module_state(
            enabled=True,
            configured=True,
            ready=ready,
            detail=detail,
            extra={"model": self._weapon_model_name},
        )

    def _predict_detections(
        self,
        *,
        model: Any,
        image: Any,
        confidence: float,
        source: str,
        source_key: str,
        use_tracking: bool,
    ) -> List[Dict[str, Any]]:
        if use_tracking:
            try:
                result = model.track(
                    source=image,
                    conf=confidence,
                    imgsz=self._image_size,
                    tracker=self._tracker_config_name(),
                    persist=True,
                    verbose=False,
                )[0]
            except Exception as exc:
                print(
                    "[ONYX] YOLO tracking unavailable; falling back to non-tracking prediction: "
                    f"{exc}"
                )
                result = model.predict(
                    source=image,
                    conf=confidence,
                    imgsz=self._image_size,
                    verbose=False,
                )[0]
                use_tracking = False
        else:
            result = model.predict(
                source=image,
                conf=confidence,
                imgsz=self._image_size,
                verbose=False,
            )[0]
        names = getattr(result, "names", {}) or {}
        detections: List[Dict[str, Any]] = []
        for box in getattr(result, "boxes", []) or []:
            cls_index = int(box.cls[0].item())
            raw_label = str(names.get(cls_index, "")).strip()
            label = _normalize_label(raw_label)
            score = float(box.conf[0].item())
            if not _allowed_semantic_label(label):
                continue
            track_id = None
            if use_tracking:
                raw_track_id = getattr(box, "id", None)
                if raw_track_id is not None:
                    try:
                        if len(raw_track_id) > 0:
                            track_id = _stable_track_id(
                                source_key,
                                int(raw_track_id[0].item()),
                            )
                    except Exception:
                        track_id = None
            xyxy = [
                float(box.xyxy[0][0].item()),
                float(box.xyxy[0][1].item()),
                float(box.xyxy[0][2].item()),
                float(box.xyxy[0][3].item()),
            ]
            detections.append(
                {
                    "label": label,
                    "raw_label": raw_label,
                    "confidence": score,
                    "box": xyxy,
                    "source": source,
                    "track_id": track_id,
                }
            )
        detections.sort(
            key=lambda item: (_label_priority(item.get("label")), float(item.get("confidence", 0.0) or 0.0)),
            reverse=True,
        )
        return detections

    def _summary_for(
        self,
        *,
        detections: Sequence[Dict[str, Any]],
        face_match: Optional[Dict[str, Any]],
        plate_match: Optional[Dict[str, Any]],
    ) -> str:
        parts: List[str] = []
        if detections:
            ordered_labels = [str(item["label"]) for item in detections[:3]]
            primary = ordered_labels[0]
            if len(ordered_labels) == 1:
                parts.append(f"Ultralytics detected {_human_label(primary)}.")
            else:
                remainder = ", ".join(_human_label(label) for label in ordered_labels[1:])
                parts.append(
                    f"Ultralytics detected {_human_label(primary)} and also saw {remainder}."
                )
        if face_match is not None:
            parts.append(
                f"Face recognition matched {face_match['face_match_id']} at {float(face_match['face_confidence']):.2f} confidence."
            )
        if plate_match is not None:
            parts.append(
                f"License plate recognition read {plate_match['plate_number']} at {float(plate_match['plate_confidence']):.2f} confidence."
            )
        if not parts:
            return "Ultralytics found no supported objects."
        return " ".join(parts)


class DarknetBackend(DetectorBackend):
    backend_name = "darknet"

    def __init__(
        self,
        binary_path: str,
        data_path: str,
        cfg_path: str,
        weights_path: str,
        threshold: float,
        working_directory: str,
        timeout_seconds: int,
    ) -> None:
        self._binary_path = binary_path.strip()
        self._data_path = data_path.strip()
        self._cfg_path = cfg_path.strip()
        self._weights_path = weights_path.strip()
        self._threshold = threshold
        self._working_directory = working_directory.strip()
        self._timeout_seconds = timeout_seconds

    def is_ready(self) -> Tuple[bool, str]:
        missing = [
            path
            for path in (
                self._binary_path,
                self._cfg_path,
                self._weights_path,
                self._data_path,
            )
            if not path
        ]
        if missing:
            return False, "Darknet backend requires binary, data, cfg, and weights paths."
        for path in (self._binary_path, self._cfg_path, self._weights_path, self._data_path):
            if not Path(path).exists():
                return False, f"Darknet path does not exist: {path}"
        return True, ""

    def detect(self, item: Dict[str, Any]) -> Dict[str, Any]:
        image_bytes = _decode_data_url(str(item["image_url"]))
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as handle:
            handle.write(image_bytes)
            temp_path = handle.name
        try:
            command = [
                self._binary_path,
                "detector",
                "test",
                self._data_path,
                self._cfg_path,
                self._weights_path,
                temp_path,
                "-dont_show",
                "-thresh",
                str(self._threshold),
            ]
            completed = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=self._timeout_seconds,
                cwd=self._working_directory or None,
                check=False,
            )
            if completed.returncode != 0:
                raise RuntimeError(
                    f"Darknet exited {completed.returncode}: {completed.stderr.strip() or completed.stdout.strip()}"
                )
            detections = self._parse_detections(completed.stdout)
            best = _best_detection(detections)
            return {
                "record_key": item["record_key"],
                "primary_label": None if best is None else best["label"],
                "confidence": 0.0 if best is None else best["confidence"],
                "summary": (
                    f"Darknet detected {_human_label(str(best['label']))}."
                    if best is not None
                    else "Darknet found no supported objects."
                ),
                "detections": detections,
                "face_match_id": None,
                "face_confidence": None,
                "plate_number": None,
                "plate_confidence": None,
            }
        finally:
            try:
                Path(temp_path).unlink(missing_ok=True)
            except Exception:
                pass

    def _parse_detections(self, stdout: str) -> List[Dict[str, Any]]:
        detections: List[Dict[str, Any]] = []
        for line in stdout.splitlines():
            match = re.match(r"^\s*([A-Za-z0-9 _-]+):\s*([0-9]+)%\s*$", line)
            if not match:
                continue
            label = _normalize_label(match.group(1))
            confidence = float(match.group(2)) / 100.0
            if not _allowed_semantic_label(label):
                continue
            detections.append(
                {
                    "label": label,
                    "confidence": confidence,
                    "source": "darknet",
                }
            )
        return _dedupe_detections(detections)


class DetectorRuntime:
    def __init__(self, config_path: Path, config: Dict[str, Any]) -> None:
        self.config_path = config_path
        self.host = _read_string(config, "ONYX_MONITORING_YOLO_HOST", fallback="127.0.0.1")
        self.port = _read_int(config, "ONYX_MONITORING_YOLO_PORT", fallback=11636)
        self.auth_token = _read_string(config, "ONYX_MONITORING_YOLO_AUTH_TOKEN")
        self.backend_name = _read_string(
            config, "ONYX_MONITORING_YOLO_BACKEND", fallback="ultralytics"
        ).lower()
        self._lock = threading.Lock()
        self._last_backend_error = ""
        self._last_request_error = ""
        self._last_request_at = 0.0
        self._last_success_at = 0.0
        self._successful_request_count = 0
        self.backend = self._build_backend(config)

    def _build_backend(self, config: Dict[str, Any]) -> DetectorBackend:
        if self.backend_name == "mock":
            return MockBackend()
        if self.backend_name == "darknet":
            return DarknetBackend(
                binary_path=_read_string(config, "ONYX_MONITORING_YOLO_DARKNET_BINARY"),
                data_path=_read_string(config, "ONYX_MONITORING_YOLO_DARKNET_DATA"),
                cfg_path=_read_string(config, "ONYX_MONITORING_YOLO_DARKNET_CFG"),
                weights_path=_read_string(config, "ONYX_MONITORING_YOLO_DARKNET_WEIGHTS"),
                threshold=_read_float(config, "ONYX_MONITORING_YOLO_CONFIDENCE", fallback=0.45),
                working_directory=_read_string(
                    config, "ONYX_MONITORING_YOLO_DARKNET_WORKDIR"
                ),
                timeout_seconds=_read_int(
                    config, "ONYX_MONITORING_YOLO_TIMEOUT_SECONDS", fallback=20
                ),
            )
        face_module = FaceRecognitionModule(
            enabled=_read_bool(
                config,
                "ONYX_FR_ENABLED",
                fallback=_read_bool(config, "ONYX_MONITORING_FR_ENABLED", fallback=False),
            ),
            gallery_dir=_read_string(config, "ONYX_MONITORING_FR_GALLERY_DIR"),
            detector_model=_read_string(config, "ONYX_MONITORING_FR_DETECTOR_MODEL"),
            recognizer_model=_read_string(config, "ONYX_MONITORING_FR_RECOGNIZER_MODEL"),
            match_threshold=_read_float(
                config,
                "ONYX_MONITORING_FR_MATCH_THRESHOLD",
                fallback=0.37,
            ),
            cache_dir=_read_string(
                config,
                "ONYX_MONITORING_FR_MODEL_CACHE_DIR",
                fallback="tool/model_cache/opencv_face",
            ),
        )
        plate_module = PlateRecognitionModule(
            enabled=_read_bool(
                config,
                "ONYX_LPR_ENABLED",
                fallback=_read_bool(config, "ONYX_MONITORING_LPR_ENABLED", fallback=False),
            ),
            languages=_read_string_list(config, "ONYX_MONITORING_LPR_LANGS", fallback=["en"]),
            minimum_confidence=_read_float(
                config,
                "ONYX_MONITORING_LPR_MIN_CONFIDENCE",
                fallback=0.55,
            ),
            allowlist=_read_string(
                config,
                "ONYX_MONITORING_LPR_ALLOWLIST",
                fallback=_DEFAULT_LPR_ALLOWLIST,
            ),
            plate_regex=_read_string(
                config,
                "ONYX_MONITORING_LPR_PLATE_REGEX",
                fallback=_DEFAULT_PLATE_REGEX,
            ),
        )
        return UltralyticsBackend(
            model_name=_read_string(config, "ONYX_MONITORING_YOLO_MODEL", fallback="yolov8l.pt"),
            confidence=_read_float(config, "ONYX_MONITORING_YOLO_CONFIDENCE", fallback=0.4),
            image_size=_read_int(config, "ONYX_MONITORING_YOLO_IMAGE_SIZE", fallback=960),
            tracking_enabled=_read_bool(
                config,
                "ONYX_MONITORING_YOLO_TRACKING_ENABLED",
                fallback=True,
            ),
            tracker_name=_read_string(
                config,
                "ONYX_MONITORING_YOLO_TRACKER",
                fallback="bytetrack",
            ),
            track_ttl_seconds=_read_int(
                config,
                "ONYX_MONITORING_YOLO_TRACK_TTL_SECONDS",
                fallback=180,
            ),
            weapon_model_name=_read_string(config, "ONYX_MONITORING_YOLO_WEAPON_MODEL"),
            weapon_confidence=_read_float(
                config,
                "ONYX_MONITORING_YOLO_WEAPON_CONFIDENCE",
                fallback=0.35,
            ),
            face_module=face_module,
            plate_module=plate_module,
        )

    def ready_state(self) -> Dict[str, Any]:
        ready, detail = self.backend.is_ready()
        self._last_backend_error = "" if ready else detail
        last_error = self._last_request_error or self._last_backend_error
        return {
            "status": "ok",
            "config_path": str(self.config_path),
            "backend": self.backend.backend_name,
            "ready": ready,
            "detail": detail,
            "modules": self.backend.module_states(),
            "last_error": last_error,
            "last_backend_error": self._last_backend_error or None,
            "last_request_error": self._last_request_error or None,
            "last_request_at_epoch": self._last_request_at or None,
            "last_success_at_epoch": self._last_success_at or None,
            "successful_request_count": self._successful_request_count,
        }

    def detect_items(self, items: List[Dict[str, Any]]) -> Dict[str, Any]:
        results = []
        with self._lock:
            self._last_request_at = time.time()
            last_request_error = ""
            successful_items = 0
            for item in items:
                try:
                    result = self.backend.detect(item)
                    results.append(result)
                    successful_items += 1
                except Exception as exc:
                    last_request_error = str(exc)
                    results.append(
                        {
                            "record_key": item.get("record_key", ""),
                            "primary_label": None,
                            "confidence": 0.0,
                            "track_id": None,
                            "summary": f"Detection failed: {exc}",
                            "detections": [],
                            "face_match_id": None,
                            "face_confidence": None,
                            "plate_number": None,
                            "plate_confidence": None,
                            "error": str(exc),
                        }
                    )
            if successful_items > 0:
                self._last_success_at = time.time()
                self._successful_request_count += successful_items
            self._last_request_error = last_request_error
        return {"results": results}


class DetectorRequestHandler(BaseHTTPRequestHandler):
    runtime: DetectorRuntime = None  # type: ignore[assignment]

    server_version = "OnyxYoloDetector/1.0"
    protocol_version = "HTTP/1.1"

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(HTTPStatus.NO_CONTENT)
        self._write_cors_headers()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._write_json(HTTPStatus.OK, self.runtime.ready_state())
            return
        self._write_json(
            HTTPStatus.NOT_FOUND,
            {"ok": False, "detail": "Use GET /health or POST /detect."},
        )

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        if parsed.path != "/detect":
            self._write_json(
                HTTPStatus.NOT_FOUND,
                {"ok": False, "detail": "Use POST /detect."},
            )
            return
        if not self._authorized():
            self._write_json(
                HTTPStatus.UNAUTHORIZED,
                {"ok": False, "detail": "Missing or invalid bearer token."},
            )
            return
        length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(length)
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except Exception:
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {"ok": False, "detail": "Request body must be valid JSON."},
            )
            return
        items = payload.get("items")
        if not isinstance(items, list):
            self._write_json(
                HTTPStatus.BAD_REQUEST,
                {"ok": False, "detail": "Request must include an items array."},
            )
            return
        normalized_items = []
        for raw_item in items:
            if not isinstance(raw_item, dict):
                continue
            item = {str(key): value for key, value in raw_item.items()}
            if not str(item.get("record_key", "")).strip():
                continue
            if not str(item.get("image_url", "")).strip():
                continue
            normalized_items.append(item)
        if not normalized_items:
            self._write_json(HTTPStatus.OK, {"results": []})
            return
        response = self.runtime.detect_items(normalized_items)
        self._write_json(HTTPStatus.OK, response)

    def log_message(self, format: str, *args: Any) -> None:
        sys.stdout.write(
            "%s - - [%s] %s\n"
            % (self.address_string(), self.log_date_time_string(), format % args)
        )

    def _authorized(self) -> bool:
        token = self.runtime.auth_token.strip()
        if not token:
            return True
        auth_header = self.headers.get("Authorization", "").strip()
        return auth_header == f"Bearer {token}"

    def _write_json(self, status: HTTPStatus, payload: Dict[str, Any]) -> None:
        encoded = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self._write_cors_headers()
        self.end_headers()
        self.wfile.write(encoded)

    def _write_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Authorization,Content-Type,Accept",
        )
        self.send_header("Access-Control-Max-Age", "600")
        if self.headers.get("Access-Control-Request-Private-Network", "") == "true":
            self.send_header("Access-Control-Allow-Private-Network", "true")


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="ONYX local YOLO detector sidecar")
    parser.add_argument("--config", default="config/onyx.local.json")
    args = parser.parse_args(argv)

    config_path = Path(args.config).expanduser().resolve()
    config = _read_config(config_path)
    enabled = _read_bool(config, "ONYX_MONITORING_YOLO_ENABLED", fallback=False)
    if not enabled:
        print(
            f"ONYX monitoring YOLO detector is disabled in {config_path}. "
            "Set ONYX_MONITORING_YOLO_ENABLED=true to run the sidecar.",
            file=sys.stderr,
        )
        return 64

    runtime = DetectorRuntime(config_path=config_path, config=config)
    handler = type(
        "ConfiguredDetectorRequestHandler",
        (DetectorRequestHandler,),
        {"runtime": runtime},
    )
    server = ThreadingHTTPServer((runtime.host, runtime.port), handler)
    health_url = f"http://{runtime.host}:{runtime.port}/health"
    detect_url = f"http://{runtime.host}:{runtime.port}/detect"
    print("ONYX YOLO detector sidecar is live.")
    print(f"Health: {health_url}")
    print(f"Detect: {detect_url}")
    ready_state = runtime.ready_state()
    print(
        f"Backend: {ready_state['backend']} • ready={ready_state['ready']} • detail={ready_state['detail'] or 'ok'}"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
