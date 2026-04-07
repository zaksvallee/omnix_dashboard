import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/infrastructure/alarm/contact_id_receiver_service.dart';
import 'package:omnix_dashboard/infrastructure/alarm/sia_dc09_frame_parser.dart';

void main() {
  final aesKey = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));

  test('ContactIdReceiverService handles two simultaneous connections', () async {
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
    );
    await service.start();
    addTearDown(service.dispose);

    final frames = <ContactIdFrame>[];
    final subscription = service.frames.listen(frames.add);
    addTearDown(subscription.cancel);

    final socketA = await Socket.connect('127.0.0.1', service.boundPort!);
    final socketB = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socketA.close);
    addTearDown(socketB.close);

    socketA.write(_buildFrame(account: '1234', sequenceHex: '0001'));
    socketB.write(_buildFrame(account: '5678', sequenceHex: '0001'));
    await socketA.flush();
    await socketB.flush();

    await _waitFor(() => frames.length == 2);

    expect(frames.map((frame) => frame.accountNumber).toSet(), {
      '1234',
      '5678',
    });
  });

  test('ContactIdReceiverService sends ACK for valid frames', () async {
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
    );
    await service.start();
    addTearDown(service.dispose);

    final socket = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socket.close);

    socket.write(_buildFrame(account: '1234', sequenceHex: '0001'));
    await socket.flush();
    final ack = await socket.first.timeout(const Duration(seconds: 2));

    expect(String.fromCharCodes(ack), contains('ACK'));
  });

  test('ContactIdReceiverService marks duplicate sequences', () async {
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
    );
    await service.start();
    addTearDown(service.dispose);

    final emitted = <ContactIdFrame>[];
    final subscription = service.frames.listen(emitted.add);
    addTearDown(subscription.cancel);

    final socket = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socket.close);

    socket.write(_buildFrame(account: '1234', sequenceHex: '0001'));
    socket.write(_buildFrame(account: '1234', sequenceHex: '0001'));
    await socket.flush();

    await _waitFor(() => emitted.length == 2);

    expect(emitted.first.isDuplicate, isFalse);
    expect(emitted.last.isDuplicate, isTrue);
  });

  test('ContactIdReceiverService treats 65535 -> 0 as a wrap-around advance', () async {
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
    );
    await service.start();
    addTearDown(service.dispose);

    final emitted = <ContactIdFrame>[];
    final subscription = service.frames.listen(emitted.add);
    addTearDown(subscription.cancel);

    final socket = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socket.close);

    socket.write(_buildFrame(account: '1234', sequenceHex: 'FFFF'));
    socket.write(_buildFrame(account: '1234', sequenceHex: '0000'));
    await socket.flush();

    await _waitFor(() => emitted.length == 2);

    expect(emitted.first.isDuplicate, isFalse);
    expect(emitted.last.sequenceNumber, 0);
    expect(emitted.last.isDuplicate, isFalse);
  });

  test('ContactIdReceiverService sends NAK for invalid frames', () async {
    final logs = <String>[];
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
      logger: (event, {context = const {}}) {
        logs.add('$event|${context['reason'] ?? ''}');
      },
    );
    await service.start();
    addTearDown(service.dispose);

    final socket = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socket.close);

    socket.write('00011234/0001(123418113001003)FFFF\r\n');
    await socket.flush();
    final response = await socket.first.timeout(const Duration(seconds: 2));

    expect(String.fromCharCodes(response), contains('NAK'));
    await _waitFor(
      () => logs.any((entry) => entry.startsWith('sia_dc09_frame_rejected|')),
    );
  });

  test('ContactIdReceiverService closes idle sockets after timeout', () async {
    final logs = <String>[];
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: aesKey,
      connectionTimeout: const Duration(milliseconds: 50),
      logger: (event, {context = const {}}) {
        logs.add(event);
      },
    );
    await service.start();
    addTearDown(service.dispose);

    final socket = await Socket.connect('127.0.0.1', service.boundPort!);
    addTearDown(socket.destroy);

    await _waitFor(() => logs.contains('sia_dc09_socket_timeout'));
    await _waitFor(() => service.activeConnectionCount == 0);
    expect(service.activeConnectionCount, 0);
  });

  test('ContactIdReceiverService dispose is idempotent', () async {
    final service = ContactIdReceiverService(
      bindAddress: '127.0.0.1',
      port: 0,
      aesKey: Uint8List.fromList(aesKey),
    );
    await service.start();

    await service.dispose();
    await service.dispose();

    expect(service.isRunning, isFalse);
  });
}

String _buildFrame({
  required String account,
  required String sequenceHex,
}) {
  return SiaDc09FrameParser.appendCrc(
    '0001$account/$sequenceHex(123418113001003)',
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
