# DVR Reachability Audit (2026-04-24)

## Scope

Diagnostic-only audit from Zaks's Mac. No remediation executed.

## Results

### Ping

- Command: `ping -c 5 192.168.0.117`
- Result: 5 packets transmitted, 0 received
- Loss: 100.0%
- RTT: none recorded

### ARP

- Command: `arp -a | grep -i "192.168.0.117"`
- Result: `? (192.168.0.117) at (incomplete) on en0 ifscope [ethernet]`
- Interpretation: the Mac attempted ARP resolution on `en0`, but no MAC address
  was learned for `192.168.0.117`.

### Port probes

- Command: `nc -zv -w 3 192.168.0.117 80`
  - Result: `Operation timed out`
- Command: `nc -zv -w 3 192.168.0.117 8000`
  - Result: `Host is down`
- Command: `nc -zv -w 3 192.168.0.117 554`
  - Result: `Host is down`

### Traceroute

- Command: `traceroute -w 2 -q 1 192.168.0.117`
- Result: no successful hop responses
- Repeated diagnostics:
  - `sendto: Host is down`
  - `sendto: No route to host`

### Mac network state

- Command: `route -n get 192.168.0.117`
- Result:
  - interface: `en0`
  - destination: `192.168.0.117`
- Command: `arp -an | head -30`
- Result:
  - `192.168.0.117` present as `(incomplete)` on `en0`
  - nearby `192.168.0.118` resolves to `b8:1:1f:22:c0:2c`
  - `192.168.0.67` also appeared incomplete during this audit window

## Camera worker config cross-reference

- File read: `bin/onyx_camera_worker.dart`
- Relevant env var: `ONYX_HIK_HOST`
- Relevant default:
  - `_defaultHost = String.fromEnvironment('ONYX_HIK_HOST', defaultValue: '192.168.0.117')`
- Runtime load point:
  - `final host = Platform.environment['ONYX_HIK_HOST'] ?? _defaultHost;`

Interpretation:

- The code still treats `192.168.0.117` as the baked-in default target.
- The worker can be redirected via `ONYX_HIK_HOST`, but this audit did not
  inspect live runtime environment overrides because the task scope was limited
  to code cross-reference plus local network diagnostics.
- Based on the code path reviewed, there is no evidence in source that the
  expected DVR host has drifted away from `192.168.0.117`.

## Verdict

**b) DVR unreachable, IP absent from ARP — device off or unplugged**

Why this verdict fits best:

- The Mac is routing directly to `192.168.0.117` over `en0`, so this is not a
  simple off-LAN routing mismatch.
- ARP never resolved a MAC for `192.168.0.117`.
- ICMP failed completely.
- TCP probes on the expected DVR ports failed with timeout / host-down errors.
- No evidence of IP reassignment was observed because no MAC address was learned
  for `192.168.0.117`.

## Recommendations (not executed)

- Physically verify the DVR/NVR has power and link lights.
- Check the switch port and cable for the device expected to own
  `192.168.0.117`.
- If the device comes back on the network, run `arp -a | grep 192.168.0.117`
  again and compare the learned MAC against the expected DVR hardware.
- If the DVR responds but ISAPI still fails afterward, investigate HTTP auth /
  endpoint configuration next rather than changing application code.
