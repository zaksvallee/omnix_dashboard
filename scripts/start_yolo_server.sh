#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
MODEL="${ONYX_MONITORING_YOLO_MODEL:-yolov8l.pt}"
HOST="${ONYX_MONITORING_YOLO_HOST:-127.0.0.1}"
PORT="${ONYX_MONITORING_YOLO_PORT:-11636}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

echo "[ONYX] Starting YOLO server on ${HOST}:${PORT} with ${MODEL}"

if [[ -f "${ROOT_DIR}/tool/start_monitoring_yolo_detector.sh" ]]; then
  exec bash "${ROOT_DIR}/tool/start_monitoring_yolo_detector.sh" --config "$CONFIG_FILE" "$@"
fi

python3 - <<PYEOF
from ultralytics import YOLO
import uvicorn
from fastapi import FastAPI, UploadFile, HTTPException
from PIL import Image
import io, os

app = FastAPI()
model = YOLO(os.environ.get('ONYX_MONITORING_YOLO_MODEL', '${MODEL}'))
CONF = float(os.environ.get('ONYX_MONITORING_YOLO_CONFIDENCE', '0.35'))

@app.get('/health')
def health():
    return {'status': 'ready', 'model': os.environ.get('ONYX_MONITORING_YOLO_MODEL', '${MODEL}')}

@app.post('/detect')
async def detect(file: UploadFile):
    try:
        contents = await file.read()
        img = Image.open(io.BytesIO(contents)).convert('RGB')
        results = model(img, conf=CONF, verbose=False)
        detections = []
        for r in results:
            for box in r.boxes:
                detections.append({
                    'class': model.names[int(box.cls)],
                    'confidence': float(box.conf),
                    'bbox': box.xyxy[0].tolist()
                })
        return {'detections': detections}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

uvicorn.run(app, host='${HOST}', port=${PORT}, log_level='warning')
PYEOF
