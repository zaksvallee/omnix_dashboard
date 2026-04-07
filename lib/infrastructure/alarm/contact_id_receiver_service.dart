import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/alarms/contact_id_event.dart';
import 'sia_dc09_frame_parser.dart';

typedef ContactIdReceiverLogger =
    void Function(String event, {Map<String, Object?> context});

class ContactIdReceiverService {
  final String bindAddress;
  final int port;
  final Uint8List _aesKey;
  final Duration connectionTimeout;
  final SiaDc09FrameParser frameParser;
  final ContactIdReceiverLogger? logger;

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  final StreamController<ContactIdFrame> _framesController =
      StreamController<ContactIdFrame>.broadcast();
  final Map<Socket, Timer> _idleTimers = <Socket, Timer>{};
  final Map<String, int> _lastSequencePerAccount = <String, int>{};
  bool _disposed = false;

  ContactIdReceiverService({
    required this.bindAddress,
    required this.port,
    required Uint8List aesKey,
    this.connectionTimeout = const Duration(seconds: 30),
    SiaDc09FrameParser? frameParser,
    this.logger,
  }) : _aesKey = Uint8List.fromList(aesKey),
       frameParser = frameParser ?? SiaDc09FrameParser();

  Stream<ContactIdFrame> get frames => _framesController.stream;

  bool get isRunning => _server != null;

  int? get boundPort => _server?.port;

  int get activeConnectionCount => _idleTimers.length;

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final server = await ServerSocket.bind(bindAddress, port);
    _server = server;
    _serverSubscription = server.listen(
      _handleConnection,
      onError: (Object error, StackTrace stackTrace) {
        _log('sia_dc09_receiver_server_error', context: {'error': '$error'});
      },
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    final sockets = _idleTimers.keys.toList(growable: false);
    for (final socket in sockets) {
      _cancelIdleTimer(socket);
      await socket.close();
    }
    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop();
    _aesKey.fillRange(0, _aesKey.length, 0);
    await _framesController.close();
  }

  void _handleConnection(Socket socket) {
    var buffer = '';
    _resetIdleTimer(socket);
    socket.listen(
      (data) {
        _resetIdleTimer(socket);
        buffer += latin1.decode(data);
        while (true) {
          final terminatorIndex = buffer.indexOf('\r\n');
          if (terminatorIndex == -1) {
            break;
          }
          final frame = buffer.substring(0, terminatorIndex + 2);
          buffer = buffer.substring(terminatorIndex + 2);
          _processFrame(socket, frame);
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        _log(
          'sia_dc09_socket_error',
          context: {
            'remote': '${socket.remoteAddress.address}:${socket.remotePort}',
            'error': '$error',
          },
        );
        _cancelIdleTimer(socket);
        await socket.close();
      },
      onDone: () async {
        if (buffer.trim().isNotEmpty) {
          _log(
            'sia_dc09_partial_frame_discarded',
            context: {
              'remote': '${socket.remoteAddress.address}:${socket.remotePort}',
              'remaining_bytes': buffer.length,
            },
          );
        }
        _cancelIdleTimer(socket);
        await socket.close();
      },
      cancelOnError: false,
    );
  }

  void _processFrame(Socket socket, String frame) {
    final result = frameParser.parse(frame, _aesKey);
    if (result case final ContactIdFrame parsedFrame) {
      final taggedFrame = _tagDuplicateFrame(parsedFrame);
      _framesController.add(taggedFrame);
      socket.add(ascii.encode('ACK\r\n'));
      _log(
        'sia_dc09_frame_received',
        context: {
          'account': taggedFrame.accountNumber,
          'receiver': taggedFrame.receiverNumber,
          'sequence': taggedFrame.sequenceNumber,
          'encrypted': taggedFrame.isEncrypted,
          'duplicate': taggedFrame.isDuplicate,
        },
      );
      return;
    }
    final failure = result as SiaParseFailure;
    socket.add(ascii.encode('NAK\r\n'));
    _log(
      'sia_dc09_frame_rejected',
      context: {
        'reason': failure.reason.name,
        'detail': failure.detail,
      },
    );
  }

  ContactIdFrame _tagDuplicateFrame(ContactIdFrame frame) {
    final accountNumber = frame.accountNumber;
    final previousSequence = _lastSequencePerAccount[accountNumber];
    if (previousSequence == null) {
      _lastSequencePerAccount[accountNumber] = frame.sequenceNumber;
      return frame;
    }
    final delta = (frame.sequenceNumber - previousSequence) & 0xFFFF;
    if (delta == 0 || delta >= 0x8000) {
      return frame.copyWith(isDuplicate: true);
    }
    _lastSequencePerAccount[accountNumber] = frame.sequenceNumber;
    return frame;
  }

  void _resetIdleTimer(Socket socket) {
    _cancelIdleTimer(socket);
    _idleTimers[socket] = Timer(connectionTimeout, () async {
      _log(
        'sia_dc09_socket_timeout',
        context: {
          'remote': '${socket.remoteAddress.address}:${socket.remotePort}',
        },
      );
      _cancelIdleTimer(socket);
      await socket.close();
    });
  }

  void _cancelIdleTimer(Socket socket) {
    _idleTimers.remove(socket)?.cancel();
  }

  void _log(String event, {Map<String, Object?> context = const {}}) {
    logger?.call(event, context: context);
  }
}
