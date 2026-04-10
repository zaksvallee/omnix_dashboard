import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

class TelegramPollingTabLock {
  static const int _tabIdRandomMax = 1000000;
  static const Duration _startupStaleLockTtl = Duration(seconds: 30);

  TelegramPollingTabLock({
    this.channelName = 'onyx_telegram_lock',
    this.onPrimaryLost,
    this.onPrimaryAvailable,
    this.heartbeatInterval = const Duration(seconds: 5),
    this.heartbeatTtl = const Duration(seconds: 15),
  }) {
    _storageKey = '$channelName-owner';
    _ensureInitialized();
  }

  final String channelName;
  final void Function()? onPrimaryLost;
  final void Function()? onPrimaryAvailable;
  final Duration heartbeatInterval;
  final Duration heartbeatTtl;

  final String _tabId =
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(_tabIdRandomMax) + 1}';

  late final String _storageKey;
  late final JSFunction _visibilityChangeListener =
      _handleVisibilityChange.toJS;
  late final JSFunction _focusListener = _handleFocus.toJS;
  web.BroadcastChannel? _broadcastChannel;
  Timer? _heartbeatTimer;
  Timer? _watchdogTimer;
  Completer<bool>? _claimResponseCompleter;
  bool _initialized = false;
  bool _disposed = false;
  bool _isPrimary = false;
  bool _wasHidden = false;
  bool _availabilitySignalPending = false;
  String? _lastObservedPrimaryTabId;
  int? _lastObservedHeartbeatMs;

  bool get isPrimary => _isPrimary;

  Future<bool> ensurePrimary({
    Duration responseWindow = const Duration(milliseconds: 500),
  }) async {
    if (_disposed) {
      return false;
    }
    _ensureInitialized();
    if (_ownsCurrentLock()) {
      _promoteToPrimary();
      return true;
    }
    _postMessage(<String, Object?>{'type': 'claim', 'tabId': _tabId});
    final claimed = await _awaitClaimResponse(responseWindow);
    final activeOwner = _readLockRecord();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ownerIsActive =
        activeOwner != null &&
        activeOwner.ownerId != _tabId &&
        _isFresh(activeOwner, nowMs: nowMs);
    if (claimed || ownerIsActive) {
      _demoteToSecondary();
      return false;
    }
    _writeLockRecord(nowMs);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    if (_ownsCurrentLock()) {
      _promoteToPrimary();
      return true;
    }
    _demoteToSecondary();
    return false;
  }

  void release() {
    if (_disposed) {
      return;
    }
    final ownedLock = _ownsCurrentLock() || _isPrimary;
    _clearLockRecordIfOwned();
    _demoteToSecondary();
    if (ownedLock) {
      _postMessage(<String, Object?>{'type': 'released', 'tabId': _tabId});
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    release();
    _disposed = true;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    web.document.removeEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    web.window.removeEventListener('focus', _focusListener);
    _broadcastChannel?.close();
    _broadcastChannel = null;
    _claimResponseCompleter = null;
  }

  void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    _sanitizeStartupLockRecord();
    _broadcastChannel = web.BroadcastChannel(channelName);
    _broadcastChannel!.onmessage = _handleMessage.toJS;
    web.document.addEventListener(
      'visibilitychange',
      _visibilityChangeListener,
    );
    web.window.addEventListener('focus', _focusListener);
    _watchdogTimer = Timer.periodic(heartbeatInterval, (_) {
      _handleWatchdogTick();
    });
    _initialized = true;
  }

  void _sanitizeStartupLockRecord() {
    final record = _readLockRecord();
    if (record == null) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ageMs = nowMs - record.heartbeatMs;
    if (ageMs > _startupStaleLockTtl.inMilliseconds) {
      try {
        web.window.localStorage.removeItem(_storageKey);
      } catch (_) {
        // Ignore startup cleanup failures and fall back to handshake checks.
      }
      _recordObservedHeartbeat(senderId: '', heartbeatMs: 0);
      return;
    }
    if (ageMs <= heartbeatTtl.inMilliseconds && record.ownerId != _tabId) {
      _recordObservedHeartbeat(
        senderId: record.ownerId,
        heartbeatMs: record.heartbeatMs,
      );
    }
  }

  void _handleMessage(web.Event event) {
    if (_disposed || event.type != 'message') {
      return;
    }
    final raw = (event as web.MessageEvent).data.dartify();
    final normalized = json.decode(json.encode(raw));
    if (normalized is! Map) {
      return;
    }
    final message = normalized.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final senderId = (message['tabId'] ?? '').toString().trim();
    if (senderId.isEmpty || senderId == _tabId) {
      return;
    }
    switch ((message['type'] ?? '').toString().trim()) {
      case 'claim':
        if (_ownsCurrentLock()) {
          _promoteToPrimary();
          _postMessage(<String, Object?>{'type': 'claimed', 'tabId': _tabId});
        }
        return;
      case 'claimed':
        _recordObservedHeartbeat(
          senderId: senderId,
          heartbeatMs: _readHeartbeatMs(message),
        );
        final completer = _claimResponseCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(true);
        }
        return;
      case 'heartbeat':
        _recordObservedHeartbeat(
          senderId: senderId,
          heartbeatMs: _readHeartbeatMs(message),
        );
        return;
      case 'released':
        _recordObservedHeartbeat(senderId: '', heartbeatMs: 0);
        if (!_isPrimary) {
          _notifyPrimaryAvailable();
        }
        return;
    }
  }

  Future<bool> _awaitClaimResponse(Duration responseWindow) async {
    final completer = Completer<bool>();
    _claimResponseCompleter = completer;
    try {
      return await completer.future.timeout(
        responseWindow,
        onTimeout: () => false,
      );
    } finally {
      if (identical(_claimResponseCompleter, completer)) {
        _claimResponseCompleter = null;
      }
    }
  }

  void _promoteToPrimary() {
    _isPrimary = true;
    _availabilitySignalPending = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _recordObservedHeartbeat(senderId: _tabId, heartbeatMs: nowMs);
    _heartbeatTimer ??= Timer.periodic(heartbeatInterval, (_) {
      final current = _readLockRecord();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (current != null &&
          current.ownerId != _tabId &&
          _isFresh(current, nowMs: nowMs)) {
        _clearLockRecordIfOwned();
        _demoteToSecondary();
        onPrimaryLost?.call();
        _notifyPrimaryAvailable();
        return;
      }
      _writeLockRecord(nowMs);
      _postHeartbeat(nowMs);
    });
    _writeLockRecord(nowMs);
    _postHeartbeat(nowMs);
  }

  void _demoteToSecondary() {
    _isPrimary = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_lastObservedPrimaryTabId == _tabId) {
      _lastObservedPrimaryTabId = null;
      _lastObservedHeartbeatMs = null;
    }
  }

  _TelegramPollLockRecord? _readLockRecord() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final ownerId = (decoded['ownerId'] ?? '').toString().trim();
      final heartbeatMs = decoded['heartbeatMs'] is int
          ? decoded['heartbeatMs'] as int
          : int.tryParse((decoded['heartbeatMs'] ?? '').toString()) ?? 0;
      if (ownerId.isEmpty || heartbeatMs <= 0) {
        return null;
      }
      return _TelegramPollLockRecord(
        ownerId: ownerId,
        heartbeatMs: heartbeatMs,
      );
    } catch (_) {
      return null;
    }
  }

  bool _ownsCurrentLock() {
    final record = _readLockRecord();
    if (record == null) {
      return false;
    }
    return record.ownerId == _tabId && _isFresh(record);
  }

  bool _isFresh(_TelegramPollLockRecord record, {int? nowMs}) {
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return currentMs - record.heartbeatMs <= heartbeatTtl.inMilliseconds;
  }

  void _writeLockRecord(int nowMs) {
    try {
      web.window.localStorage.setItem(
        _storageKey,
        jsonEncode(<String, Object?>{'ownerId': _tabId, 'heartbeatMs': nowMs}),
      );
    } catch (_) {
      // Ignore localStorage failures and fall back to the broadcast handshake.
    }
  }

  void _clearLockRecordIfOwned() {
    try {
      final record = _readLockRecord();
      if (record?.ownerId == _tabId) {
        web.window.localStorage.removeItem(_storageKey);
      }
    } catch (_) {
      // Ignore localStorage failures during release.
    }
  }

  void _postMessage(Map<String, Object?> message) {
    final channel = _broadcastChannel;
    if (channel == null) {
      return;
    }
    try {
      channel.postMessage(message.jsify() as JSAny);
    } catch (_) {
      // Ignore transient broadcast failures.
    }
  }

  void _handleVisibilityChange(web.Event _) {
    if (_disposed) {
      return;
    }
    if (web.document.hidden) {
      _wasHidden = true;
      return;
    }
    if (_wasHidden) {
      _wasHidden = false;
      _restartElection();
    }
  }

  void _handleFocus(web.Event _) {
    if (_disposed || web.document.hidden) {
      return;
    }
    _revalidateLockOwnership();
  }

  void _handleWatchdogTick() {
    if (_disposed) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_isPrimary) {
      final current = _readLockRecord();
      if (current != null &&
          current.ownerId != _tabId &&
          _isFresh(current, nowMs: nowMs)) {
        _clearLockRecordIfOwned();
        _demoteToSecondary();
        onPrimaryLost?.call();
        _notifyPrimaryAvailable();
        return;
      }
      _writeLockRecord(nowMs);
      _postHeartbeat(nowMs);
      return;
    }
    final current = _readLockRecord();
    if (current != null &&
        current.ownerId != _tabId &&
        _isFresh(current, nowMs: nowMs)) {
      _recordObservedHeartbeat(
        senderId: current.ownerId,
        heartbeatMs: current.heartbeatMs,
      );
      _availabilitySignalPending = false;
      return;
    }
    if (_hasFreshObservedHeartbeat(nowMs: nowMs) || web.document.hidden) {
      return;
    }
    _notifyPrimaryAvailable();
  }

  void _restartElection() {
    final wasPrimary = _isPrimary || _ownsCurrentLock();
    release();
    if (wasPrimary) {
      onPrimaryLost?.call();
    }
    _availabilitySignalPending = false;
    _notifyPrimaryAvailable();
  }

  void _revalidateLockOwnership() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_isPrimary) {
      if (_ownsCurrentLock()) {
        _writeLockRecord(nowMs);
        _postHeartbeat(nowMs);
        return;
      }
      _clearLockRecordIfOwned();
      _demoteToSecondary();
      onPrimaryLost?.call();
      _notifyPrimaryAvailable();
      return;
    }
    final current = _readLockRecord();
    if (current != null &&
        current.ownerId != _tabId &&
        _isFresh(current, nowMs: nowMs)) {
      _recordObservedHeartbeat(
        senderId: current.ownerId,
        heartbeatMs: current.heartbeatMs,
      );
      _availabilitySignalPending = false;
      return;
    }
    if (!_hasFreshObservedHeartbeat(nowMs: nowMs)) {
      _notifyPrimaryAvailable();
    }
  }

  void _postHeartbeat(int nowMs) {
    _postMessage(<String, Object?>{
      'type': 'heartbeat',
      'tabId': _tabId,
      'heartbeatMs': nowMs,
    });
  }

  void _recordObservedHeartbeat({
    required String senderId,
    required int heartbeatMs,
  }) {
    if (senderId.trim().isEmpty || heartbeatMs <= 0) {
      _lastObservedPrimaryTabId = null;
      _lastObservedHeartbeatMs = null;
      return;
    }
    _lastObservedPrimaryTabId = senderId.trim();
    _lastObservedHeartbeatMs = heartbeatMs;
    _availabilitySignalPending = false;
  }

  bool _hasFreshObservedHeartbeat({int? nowMs}) {
    final heartbeatMs = _lastObservedHeartbeatMs;
    final ownerId = _lastObservedPrimaryTabId;
    if (heartbeatMs == null || ownerId == null || ownerId.isEmpty) {
      return false;
    }
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return currentMs - heartbeatMs <= heartbeatTtl.inMilliseconds;
  }

  void _notifyPrimaryAvailable() {
    if (_availabilitySignalPending) {
      return;
    }
    _availabilitySignalPending = true;
    scheduleMicrotask(() {
      if (_disposed) {
        return;
      }
      onPrimaryAvailable?.call();
    });
  }

  int _readHeartbeatMs(Map<String, Object?> message) {
    final raw = message['heartbeatMs'];
    if (raw is int) {
      return raw;
    }
    return int.tryParse((raw ?? '').toString()) ?? 0;
  }
}

class _TelegramPollLockRecord {
  const _TelegramPollLockRecord({
    required this.ownerId,
    required this.heartbeatMs,
  });

  final String ownerId;
  final int heartbeatMs;
}
