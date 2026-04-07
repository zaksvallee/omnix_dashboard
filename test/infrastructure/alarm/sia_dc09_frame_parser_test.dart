import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/infrastructure/alarm/sia_dc09_frame_parser.dart';
import 'package:pointycastle/export.dart';

void main() {
  final aesKey = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));

  test('SiaDc09FrameParser parses a valid unencrypted frame', () {
    final parser = SiaDc09FrameParser(
      now: () => DateTime.utc(2026, 4, 7, 10, 15, 30),
    );
    final frame = _buildPlainFrame(
      receiverNumber: '0001',
      accountNumber: '1234',
      sequenceHex: '000A',
      payload: '12341813001003',
    );

    final result = parser.parse(frame, aesKey);

    expect(result, isA<ContactIdFrame>());
    final parsed = result as ContactIdFrame;
    expect(parsed.receiverNumber, '0001');
    expect(parsed.accountNumber, '1234');
    expect(parsed.sequenceNumber, 10);
    expect(parsed.isEncrypted, isFalse);
    expect(parsed.payloadData, '12341813001003');
    expect(parsed.receivedAtUtc, DateTime.utc(2026, 4, 7, 10, 15, 30));
  });

  test('SiaDc09FrameParser parses a valid AES-128-CBC encrypted frame', () {
    final parser = SiaDc09FrameParser();
    final frame = _buildEncryptedFrame(
      receiverNumber: '0001',
      accountNumber: '1234',
      sequenceHex: '000B',
      payload: '12341813001003',
      aesKey: aesKey,
    );

    final result = parser.parse(frame, aesKey);

    expect(result, isA<ContactIdFrame>());
    expect((result as ContactIdFrame).payloadData, '12341813001003');
    expect((result).isEncrypted, isTrue);
  });

  test('SiaDc09FrameParser rejects CRC mismatch', () {
    final parser = SiaDc09FrameParser();
    final validFrame = _buildPlainFrame(
      receiverNumber: '0001',
      accountNumber: '1234',
      sequenceHex: '000A',
      payload: '12341813001003',
    );
    final invalidFrame = '${validFrame.substring(0, validFrame.length - 6)}FFFF\r\n';

    final result = parser.parse(invalidFrame, aesKey);

    expect(result, isA<SiaParseFailure>());
    expect((result as SiaParseFailure).reason, SiaParseFailureReason.crcMismatch);
  });

  test('SiaDc09FrameParser rejects truncated frames', () {
    final parser = SiaDc09FrameParser();

    final result = parser.parse('00011234/000A(1234', aesKey);

    expect(result, isA<SiaParseFailure>());
    expect((result as SiaParseFailure).reason, SiaParseFailureReason.malformedFrame);
  });

  test('SiaDc09FrameParser reports decryption failure when the key is wrong', () {
    final parser = SiaDc09FrameParser();
    final frame = _buildEncryptedFrame(
      receiverNumber: '0001',
      accountNumber: '1234',
      sequenceHex: '000B',
      payload: '12341813001003',
      aesKey: aesKey,
    );
    final wrongKey = Uint8List.fromList(List<int>.filled(16, 9));

    final result = parser.parse(frame, wrongKey);

    expect(result, isA<SiaParseFailure>());
    expect(
      (result as SiaParseFailure).reason,
      SiaParseFailureReason.decryptionFailed,
    );
  });

  test(
    'SiaDc09FrameParser rejects encrypted payloads whose byte length is not AES aligned',
    () {
      final parser = SiaDc09FrameParser();
      final validFrame = _buildEncryptedFrame(
        receiverNumber: '0001',
        accountNumber: '1234',
        sequenceHex: '000C',
        payload: '123418130010031234',
        aesKey: aesKey,
      );
      final openParen = validFrame.indexOf('(');
      final closeParen = validFrame.indexOf(')');
      final payloadHex = validFrame.substring(openParen + 1, closeParen);
      final misalignedPayloadHex = payloadHex.substring(0, payloadHex.length - 2);
      final invalidFrame = SiaDc09FrameParser.appendCrc(
        '00011234*000C($misalignedPayloadHex)',
      );

      final result = parser.parse(invalidFrame, aesKey);

      expect(result, isA<SiaParseFailure>());
      expect(
        (result as SiaParseFailure).reason,
        SiaParseFailureReason.decryptionFailed,
      );
      expect(result.detail, contains('16-byte IV and one cipher block'));
    },
  );
}

String _buildPlainFrame({
  required String receiverNumber,
  required String accountNumber,
  required String sequenceHex,
  required String payload,
}) {
  final frameBody = '$receiverNumber$accountNumber/$sequenceHex($payload)';
  return SiaDc09FrameParser.appendCrc(frameBody);
}

String _buildEncryptedFrame({
  required String receiverNumber,
  required String accountNumber,
  required String sequenceHex,
  required String payload,
  required Uint8List aesKey,
}) {
  final iv = Uint8List.fromList(
    List<int>.generate(16, (index) => index + 31),
  );
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  )..init(
      true,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV<KeyParameter>(KeyParameter(aesKey), iv),
        null,
      ),
    );
  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(payload)));
  final payloadHex = _encodeHex(<int>[...iv, ...encrypted]);
  final frameBody = '$receiverNumber$accountNumber*$sequenceHex($payloadHex)';
  return SiaDc09FrameParser.appendCrc(frameBody);
}

String _encodeHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
  }
  return buffer.toString();
}
