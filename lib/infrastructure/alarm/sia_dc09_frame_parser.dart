import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../../domain/alarms/contact_id_event.dart';

DateTime _siaSystemNow() => DateTime.now().toUtc();

class SiaDc09FrameParser {
  final DateTime Function() now;

  SiaDc09FrameParser({DateTime Function()? now}) : now = now ?? _siaSystemNow;

  SiaDc09ParseResult parse(String rawFrame, Uint8List aesKey) {
    final normalizedRaw = rawFrame;
    final line = rawFrame.endsWith('\r\n')
        ? rawFrame.substring(0, rawFrame.length - 2)
        : rawFrame;
    if (line.length < 18) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.malformedFrame,
        rawFrame: normalizedRaw,
        detail: 'Frame is too short.',
      );
    }
    final openParen = line.indexOf('(');
    final closeParen = line.lastIndexOf(')');
    if (openParen <= 0 ||
        closeParen <= openParen ||
        closeParen + 5 != line.length) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.malformedFrame,
        rawFrame: normalizedRaw,
        detail: 'Frame does not contain a valid payload/CRC segment.',
      );
    }

    final header = line.substring(0, openParen);
    if (header.length != 13) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.malformedFrame,
        rawFrame: normalizedRaw,
        detail: 'Frame header length is invalid.',
      );
    }
    final receiverNumber = header.substring(0, 4);
    final accountNumber = header.substring(4, 8);
    final prefix = header.substring(8, 9);
    final sequenceHex = header.substring(9, 13);
    if (!_isAsciiDigits(receiverNumber) || !_isAsciiDigits(accountNumber)) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.malformedFrame,
        rawFrame: normalizedRaw,
        detail: 'Receiver/account numbers must be 4 ASCII digits.',
      );
    }
    if (prefix != '/' && prefix != '*') {
      return SiaParseFailure(
        reason: SiaParseFailureReason.unsupportedFormat,
        rawFrame: normalizedRaw,
        detail: 'Unsupported DC-09 prefix: $prefix',
      );
    }
    final sequenceNumber = int.tryParse(sequenceHex, radix: 16);
    if (sequenceNumber == null) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.malformedFrame,
        rawFrame: normalizedRaw,
        detail: 'Sequence number must be 4 hexadecimal characters.',
      );
    }

    final frameBody = line.substring(0, closeParen + 1);
    final receivedCrc = line.substring(closeParen + 1).toUpperCase();
    final computedCrc = computeCrcHex(frameBody);
    if (receivedCrc != computedCrc) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.crcMismatch,
        rawFrame: normalizedRaw,
        detail: 'CRC mismatch. Expected $computedCrc, received $receivedCrc.',
      );
    }

    final payloadBlock = line.substring(openParen + 1, closeParen);
    final payloadData = prefix == '*'
        ? _decryptPayloadHex(
            payloadBlock,
            aesKey: aesKey,
            rawFrame: normalizedRaw,
          )
        : _payloadSuccess(payloadBlock);
    if (payloadData case final SiaParseFailure failure) {
      return failure;
    }

    return ContactIdFrame(
      accountNumber: accountNumber,
      receiverNumber: receiverNumber,
      sequenceNumber: sequenceNumber,
      isEncrypted: prefix == '*',
      isDuplicate: false,
      payloadData: (payloadData as _PayloadSuccess).payload,
      receivedAtUtc: now().toUtc(),
      rawFrame: normalizedRaw,
    );
  }

  static String appendCrc(String frameBody) {
    return '$frameBody${computeCrcHex(frameBody)}\r\n';
  }

  static String computeCrcHex(String frameBody) {
    final crc = _crc16Arc(ascii.encode(frameBody));
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static int _crc16Arc(List<int> bytes) {
    var crc = 0x0000;
    for (final byte in bytes) {
      crc ^= byte & 0xFF;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc & 0xFFFF;
  }

  Object _decryptPayloadHex(
    String payloadBlock, {
    required Uint8List aesKey,
    required String rawFrame,
  }) {
    try {
      if (aesKey.length != 16) {
        throw const FormatException('AES-128 key must be exactly 16 bytes.');
      }
      final encryptedBytes = _decodeHex(payloadBlock);
      if (encryptedBytes.length < 32 || encryptedBytes.length % 16 != 0) {
        throw const FormatException(
          'Encrypted payload must include a 16-byte IV and one cipher block.',
        );
      }
      final iv = encryptedBytes.sublist(0, 16);
      final cipherText = encryptedBytes.sublist(16);
      final cipher = PaddedBlockCipherImpl(
        PKCS7Padding(),
        CBCBlockCipher(AESEngine()),
      )..init(
          false,
          PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
            ParametersWithIV<KeyParameter>(KeyParameter(aesKey), iv),
            null,
          ),
        );
      final decrypted = cipher.process(cipherText);
      return _payloadSuccess(utf8.decode(decrypted, allowMalformed: false));
    } on FormatException catch (error) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.decryptionFailed,
        rawFrame: rawFrame,
        detail: error.message,
      );
    } catch (error) {
      return SiaParseFailure(
        reason: SiaParseFailureReason.decryptionFailed,
        rawFrame: rawFrame,
        detail: 'AES decryption failed: $error',
      );
    }
  }

  static Uint8List _decodeHex(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length.isOdd) {
      throw const FormatException('Encrypted payload hex is malformed.');
    }
    final bytes = <int>[];
    for (var index = 0; index < normalized.length; index += 2) {
      final byte = int.tryParse(normalized.substring(index, index + 2), radix: 16);
      if (byte == null) {
        throw const FormatException('Encrypted payload contains non-hex bytes.');
      }
      bytes.add(byte);
    }
    return Uint8List.fromList(bytes);
  }

  static bool _isAsciiDigits(String value) {
    return value.length == 4 && value.runes.every((rune) => rune >= 0x30 && rune <= 0x39);
  }

  static _PayloadSuccess _payloadSuccess(String payload) {
    return _PayloadSuccess(payload.trim());
  }
}

class _PayloadSuccess {
  final String payload;

  const _PayloadSuccess(this.payload);
}
