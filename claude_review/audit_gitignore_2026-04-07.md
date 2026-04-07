# Audit: .gitignore coverage — binary and model files

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `.gitignore`, `yolov8l.pt`, `yolov8n.pt`, `tool/model_cache/`, `.venv-monitoring-yolo/`
- Read-only: yes

## Executive Summary

The root `.gitignore` has no coverage for ML model weight files (`.pt`, `.onnx`) or the Python virtual environment directory. Two YOLOv8 weight files sit at the repo root and two OpenCV `.onnx` model files live under `tool/model_cache/` — none are currently tracked by git, but none are protected from an accidental `git add -A`. The venv is self-excluding via its internal `*` rule but has no root-level guard. Three additions to `.gitignore` close all gaps.

---

## What Looks Good

- `android/.gradle`, `build/`, `.dart_tool/`, `tmp/` are all correctly excluded.
- `config/*.local.json` and `.env` are excluded — secret config files will not leak.
- The `.venv-monitoring-yolo/` internal `.gitignore` (`*`) does prevent individual file tracking today.

---

## Findings

### P1 — `yolov8l.pt` and `yolov8n.pt` not in `.gitignore`
- **Action:** AUTO
- **Finding:** Two PyTorch YOLOv8 model weight files exist at the repo root and are not excluded by any gitignore rule.
- **Why it matters:** `.pt` files are large binary blobs (yolov8l is ~87 MB, yolov8n ~6 MB). A single `git add .` or `git add -A` would commit them. Once committed, they permanently inflate git history — removing them later requires a full history rewrite.
- **Evidence:** `yolov8l.pt` and `yolov8n.pt` at repo root; `git check-ignore -v yolov8l.pt yolov8n.pt` returns no output (no rule applies).
- **Required addition to `.gitignore`:**
  ```
  # ML model weights
  *.pt
  ```

### P2 — `tool/model_cache/` not in `.gitignore`
- **Action:** AUTO
- **Finding:** `tool/model_cache/opencv_face/` contains two binary `.onnx` model files (`face_detection_yunet_2023mar.onnx`, `face_recognition_sface_2021dec.onnx`). Neither the directory nor the `.onnx` extension is excluded.
- **Why it matters:** Same binary-blob-in-history risk as P1. OpenCV model files are redistributable but large; they belong in a fetch script or LFS, not committed source.
- **Evidence:** `tool/model_cache/opencv_face/face_detection_yunet_2023mar.onnx`, `tool/model_cache/opencv_face/face_recognition_sface_2021dec.onnx`; `git check-ignore -v tool/model_cache/` returns `NOT ignored`.
- **Required addition to `.gitignore`:**
  ```
  # ML model cache (OpenCV, ONNX)
  tool/model_cache/
  ```

### P3 — `.venv-monitoring-yolo/` not in root `.gitignore`
- **Action:** AUTO
- **Finding:** The Python virtual environment directory is only excluded by its own internal `*` rule (created by `venv`). The root `.gitignore` has no entry for it.
- **Why it matters:** The internal rule is fragile — if the venv is recreated without the internal `.gitignore` being preserved, or if the directory is renamed, the entire venv tree (hundreds of MB of Python packages) becomes visible to git. Standard practice is an explicit root-level entry.
- **Evidence:** `git check-ignore -v .venv-monitoring-yolo/` reports the rule comes from `.venv-monitoring-yolo/.gitignore:2:*`, not the root `.gitignore`.
- **Required addition to `.gitignore`:**
  ```
  # Python virtual environment
  .venv-monitoring-yolo/
  ```

---

## Duplication

None — this is a configuration-file audit.

---

## Coverage Gaps

No tests exist for gitignore correctness (i.e., a script that asserts model files are not stageable). This is low priority but worth noting given the binary-blob risk.

---

## Performance / Stability Notes

If any of the three items above are committed before the fix lands, the only clean resolution is `git filter-repo` or BFG Repo Cleaner — both require force-pushing and rewriting history. The cost of the fix now is three lines; the cost later is a coordinated history rewrite.

---

## Recommended Fix Order

1. **Add `*.pt` to `.gitignore`** — closes the highest-size risk immediately (P1).
2. **Add `tool/model_cache/`** — closes the ONNX files (P2).
3. **Add `.venv-monitoring-yolo/`** — belt-and-suspenders for the venv (P3).

All three belong in a single commit to `.gitignore` under a `# ML / Python tooling` section.

---

## Exact diff for Codex to apply

```diff
--- a/.gitignore
+++ b/.gitignore
@@ -42,3 +42,9 @@ supabase/.temp/
+
+# ML model weights (PyTorch, ONNX) — never commit binary blobs
+*.pt
+tool/model_cache/
+
+# Python virtual environment
+.venv-monitoring-yolo/
```
