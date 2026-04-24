Probe A — Pi connections to DVR
sudo: a password is required
Connection to 192.168.0.67 closed.

sudo: a password is required
Connection to 192.168.0.67 closed.

Probe B — Hetzner camera worker state
○ onyx-camera-worker.service - ONYX Camera Worker — Hikvision ISAPI stream to Supabase
     Loaded: loaded (/etc/systemd/system/onyx-camera-worker.service; disabled; preset: enabled)
     Active: inactive (dead)

Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Supabase: https://mnbloeoiiwenlywnnoxe.supabase.co (service key)
Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Camera worker starting.
Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Target: 192.168.0.117:80  user=admin
Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Scope:  client=CLIENT-MS-VALLEE  site=SITE-MS-VALLEE-RESIDENCE
Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Fault channels: 11
Apr 17 15:18:38 ubuntu-4gb-nbg1-onyx-prod-1 onyx-camera-worker[135253]: [ONYX] Connected — listening for events.
Apr 17 20:47:33 ubuntu-4gb-nbg1-onyx-prod-1 systemd[1]: Stopping onyx-camera-worker.service - ONYX Camera Worker — Hikvision ISAPI stream to Supabase...
Apr 17 20:47:33 ubuntu-4gb-nbg1-onyx-prod-1 systemd[1]: onyx-camera-worker.service: Deactivated successfully.
Apr 17 20:47:33 ubuntu-4gb-nbg1-onyx-prod-1 systemd[1]: Stopped onyx-camera-worker.service - ONYX Camera Worker — Hikvision ISAPI stream to Supabase.
Apr 17 20:47:33 ubuntu-4gb-nbg1-onyx-prod-1 systemd[1]: onyx-camera-worker.service: Consumed 2.893s CPU time, 7.1M memory peak, 0B memory swap peak.

disabled

inactive

Probe C — Hetzner DVR connections
no connections to 192.168.0.117

Probe D — Pi ARP and conntrack for DVR
bash: line 1: arp: command not found

conntrack not available or no entries
Connection to 192.168.0.67 closed.

Probe E — RTSP frame server health
    PID     ELAPSED CMD
1683544  1-02:13:19 ./.venv-monitoring-yolo/bin/python ./tool/onyx_rtsp_frame_server.py --config /opt/onyx/config/onyx.local.json

sudo: a password is required
Connection to 192.168.0.67 closed.

Probe F — Worker log evidence

Probe G — Scheduled jobs
NEXT                              LEFT LAST                               PASSED UNIT                           ACTIVATES
Fri 2026-04-24 09:10:00 SAST      5min Fri 2026-04-24 09:00:26 SAST 3min 49s ago sysstat-collect.timer          sysstat-collect.service
Fri 2026-04-24 10:56:31 SAST  1h 52min Fri 2026-04-24 09:01:26 SAST 2min 49s ago fwupd-refresh.timer            fwupd-refresh.service
Fri 2026-04-24 12:09:03 SAST   3h 4min Fri 2026-04-24 04:58:26 SAST  4h 5min ago motd-news.timer                motd-news.service
Fri 2026-04-24 13:12:23 SAST   4h 8min Thu 2026-04-23 19:41:26 SAST      13h ago apt-daily.timer                apt-daily.service
Fri 2026-04-24 15:27:26 SAST        6h Thu 2026-04-23 15:27:26 SAST      17h ago update-notifier-download.timer update-notifier-download.service
Fri 2026-04-24 15:38:59 SAST        6h Thu 2026-04-23 15:38:59 SAST      17h ago systemd-tmpfiles-clean.timer   systemd-tmpfiles-clean.service
Sat 2026-04-25 00:00:00 SAST       14h Fri 2026-04-24 00:00:07 SAST       9h ago dpkg-db-backup.timer           dpkg-db-backup.service
Sat 2026-04-25 00:00:00 SAST       14h Fri 2026-04-24 00:00:07 SAST       9h ago logrotate.timer                logrotate.service
Sat 2026-04-25 00:07:00 SAST       15h Fri 2026-04-24 00:07:07 SAST       8h ago sysstat-summary.timer          sysstat-summary.service
Sat 2026-04-25 02:33:50 SAST       17h Fri 2026-04-24 00:57:37 SAST       8h ago man-db.timer                   man-db.service
Sat 2026-04-25 06:42:55 SAST       21h Fri 2026-04-24 06:04:26 SAST 2h 59min ago apt-daily-upgrade.timer        apt-daily-upgrade.service
Sun 2026-04-26 03:10:52 SAST 1 day 18h Sun 2026-04-19 03:10:53 SAST   5 days ago e2scrub_all.timer              e2scrub_all.service
Mon 2026-04-27 00:01:05 SAST    2 days Mon 2026-04-20 00:26:17 SAST   4 days ago fstrim.timer                   fstrim.service
Wed 2026-04-29 18:51:14 SAST    5 days Thu 2026-04-23 06:50:04 SAST 1 day 2h ago update-notifier-motd.timer     update-notifier-motd.service

14 timers listed.
Pass --all to see loaded but inactive timers, too.
Connection to 192.168.0.67 closed.

Interpretation
INCONCLUSIVE: Probe B and Probe C rule out Hetzner candidate #2: `onyx-camera-worker` is `disabled` and `inactive` on `178.104.91.182`, and `ss` there returned `no connections to 192.168.0.117`. The material unknown is candidate #1 on the Pi, because Probe A and the process-owning half of Probe E could not complete: the Pi `sudo ss -tanp` invocations required an interactive password, Probe D's `arp` command was not present, and Probe F did not surface the worker's `Another edge likely owns the Hikvision alert stream` path. That leaves a second local Pi consumer we could not enumerate or an external/browser/mobile/Hik-Connect session as unresolved possibilities.

Recommended next action
Get privileged Pi-side visibility for the exact `sudo ss -tanp` and `sudo conntrack -L` probes so we can confirm or eliminate a second local consumer. If those still come back clean, move next to DVR-side session inspection or packet capture for browser/mobile/Hik-Connect ownership.
