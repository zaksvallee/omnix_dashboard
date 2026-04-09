import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

class TelegramPollingTabLock {
  TelegramPollingTabLock({
    this.channelName = 'onyx_telegram_lock',
    this.onPrimaryLost,
    this.onPrimaryAvailable,
    this.heartbeatInterval = const Duration(seconds: 2),
    this.heartbeatTtl = const Duration(seconds: 6),
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
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 32)}';

  late final String _storageKey;
  web.BroadcastChannel? _broadcastChannel;
  Timer? _heartbeatTimer;
  Completer<bool>? _claimResponseCompleter;
  bool _initialized = false;
  bool _disposed = false;
  bool _isPrimary = false;

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
    _broadcastChannel?.close();
    _broadcastChannel = null;
    _claimResponseCompleter = null;
  }

  void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    _broadcastChannel = web.BroadcastChannel(channelName);
    _broadcastChannel!.onmessage = _handleMessage.toJS;
    _initialized = true;
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
        final completer = _claimResponseCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.complete(true);
        }
        return;
      case 'released':
        if (!_isPrimary) {
          onPrimaryAvailable?.call();
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
    _heartbeatTimer ??= Timer.periodic(heartbeatInterval, (_) {
      final current = _readLockRecord();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (current != null &&
          current.ownerId != _tabId &&
          _isFresh(current, nowMs: nowMs)) {
        _clearLockRecordIfOwned();
        _demoteToSecondary();
        onPrimaryLost?.call();
        return;
      }
      _writeLockRecord(nowMs);
    });
    _writeLockRecord(DateTime.now().millisecondsSinceEpoch);
  }

  void _demoteToSecondary() {
    _isPrimary = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
}

class _TelegramPollLockRecord {
  const _TelegramPollLockRecord({
    required this.ownerId,
    required this.heartbeatMs,
  });

  final String ownerId;
  final int heartbeatMs;
}
