# ONYX — Overnight Report (2026-04-17)

## Task-by-task status

1. **Task 1 — Orphan frame cleanup:** done  
   `tmp/onyx_rtsp_frames/` is empty. No repo changes required.

2. **Task 2 — Disable Hetzner broken camera-worker:** done  
   `onyx-camera-worker.service` on `root@178.104.91.182` is now `inactive (dead)` and `disabled`.

3. **Task 3 — Re-create `scripts/onyx_watchdog.sh`:** done  
   No recoverable git history existed, so the script was reconstituted as a compatibility wrapper to `ensure_camera_worker.sh --watchdog`.

4. **Task 4 — Add `scripts/ensure_dvr_proxy.sh`:** done  
   DVR proxy is now part of the `make start` stack and was verified in `make status`.

5. **Task 5 — Fix `make status` shallow liveness check:** done  
   Added uptime + respawn heuristics. Verification surfaced a stale in-memory legacy watchdog, so I replaced it with the restored on-disk watchdog path and re-stabilized the local stack. Current status is healthy.

6. **Task 6 — Log rotation on `tmp/dvr_proxy.log`:** done  
   Safely truncated `tmp/dvr_proxy.log` without killing the proxy and committed a rotating log sink for DVR proxy, camera worker, YOLO, and RTSP frame server. Important note: the rotation code is pushed, but because the relevant services were already running and the task explicitly avoided touching healthy processes, the new rotating sink will attach on the next service restart. Disk pressure is reduced immediately because the runaway DVR log was truncated.

7. **Task 7 — Commit `SESSION.md` + push everything:** done  
   `SESSION.md` committed and all local commits pushed to `origin/main`.

## Final git log -10 --oneline

```text
7adde70 docs(session): 2026-04-17 standing items post-Vallee recovery
186ef8a fix(logs): add rotation to prevent tmp/*.log unbounded growth
850cd86 fix(make-status): detect crash loops via process uptime and respawn rate
b8a6f6b feat(scripts): add ensure_dvr_proxy.sh to make-start stack
3a6b267 feat(scripts): reconstitute onyx_watchdog.sh after disk loss
9047737 fix(org-chart): remove raw hex outlier and Material AppBar
bf2d795 style(ledger): monospace record codes, linked event IDs, and detail grid IDs
7d09a36 style(alarms): monospace alarm short ID on alarm card header
807920e style(reports): monospace dispatch ID, receipt hero ID, and REPORT ID badge
d85d2e2 feat(zara-theatre): isolated smoke harness for full alarmTriage loop
```

## Final git status

```text
?? OVERNIGHT_REPORT.md
```

## make status output

```text
ONYX stack status
Config: config/onyx.local.json
Flutter app: RUNNING (pid 24383, uptime 6m 35s)
  /Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dartvm --resolved_executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart --executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart --packages=/Users/zaks/development/flutter/packages/flutter_tools/.dart_tool/package_config.json /Users/zaks/development/flutter/bin/cache/flutter_tools.snapshot run -d chrome --dart-define-from-file=config/onyx.local.json
Telegram proxy: RUNNING (pid 24447, uptime 6m 35s)
  /Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dartvm --resolved_executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart --executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart bin/onyx_telegram_bot_api_proxy.dart --config config/onyx.local.json
YOLO detector: RUNNING (pid 24566, uptime 6m 30s)
  /opt/homebrew/Cellar/python@3.14/3.14.3_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python /Users/zaks/omnix_dashboard/tool/monitoring_yolo_detector_service.py --config config/onyx.local.json
RTSP frame server: RUNNING (pid 24679, uptime 6m 29s)
  /opt/homebrew/Cellar/python@3.14/3.14.3_1/Frameworks/Python.framework/Versions/3.14/Resources/Python.app/Contents/MacOS/Python /Users/zaks/omnix_dashboard/tool/onyx_rtsp_frame_server.py --config config/onyx.local.json
DVR proxy: RUNNING (pid 25413, uptime 5m 58s)
  /Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python scripts/onyx_dvr_cors_proxy.py --config config/onyx.local.json --port 11635
Camera worker: RUNNING (pid 25442, uptime 5m 58s)
  /Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dartvm --resolved_executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart --executable_name=/Users/zaks/development/flutter/bin/cache/dart-sdk/bin/dart bin/onyx_camera_worker.dart
Proxy listen:
  COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
  dartvm  24447 zaks    8u  IPv4 0x769329de8f41ee15      0t0  TCP 127.0.0.1:11637 (LISTEN)
YOLO listen:
  COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
  Python  24566 zaks    3u  IPv4 0xb238211944cf19eb      0t0  TCP 127.0.0.1:11636 (LISTEN)
YOLO health: ready (ultralytics; ok)
RTSP frame listen:
  COMMAND   PID USER   FD   TYPE            DEVICE SIZE/OFF NODE NAME
  Python  24679 zaks    3u  IPv4 0x762066b7f96b109      0t0  TCP 127.0.0.1:11638 (LISTEN)
RTSP frame health: ready (4 channels)
DVR proxy listen:
  COMMAND   PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
  Python  25413 zaks    4u  IPv4 0x2ef7b649ae7bb835      0t0  TCP 127.0.0.1:11635 (LISTEN)
Telegram queue depth: 0
```

## Observations for morning

- The deliberate camera-worker crash test proved the new `make status` heuristics, but it also exposed that the legacy in-memory watchdog from before script restoration was stale. I replaced it with the restored on-disk watchdog path, and the current local camera worker + watchdog are healthy.
- Hetzner is now correctly out of the camera-worker path. Cloud camera-worker is disabled; local Mac is authoritative until Pi deployment.
- `tmp/dvr_proxy.log` was truncated safely and is no longer consuming hundreds of MB. The new rotation code is pushed, but because the services were already running and I avoided restarting healthy processes, the rotating sink will take effect on the next controlled restart of DVR proxy / camera worker / YOLO / RTSP frame server.
- `dart analyze lib/` stayed clean between tasks and `flutter build web --release` succeeded.

## Summary

MS Vallee stable overnight — partial
