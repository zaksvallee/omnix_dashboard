import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class DispatchSnapshotFileService {
  const DispatchSnapshotFileService();

  bool get supported => true;

  Future<void> downloadJsonFile({
    required String filename,
    required String contents,
  }) => _downloadFile(
    filename: filename,
    contents: contents,
    mimeType: 'application/json',
  );

  Future<void> downloadTextFile({
    required String filename,
    required String contents,
  }) => _downloadFile(
    filename: filename,
    contents: contents,
    mimeType: 'text/plain;charset=utf-8',
  );

  Future<String?> pickJsonFile() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    input.click();

    try {
      await input.onChange.first.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return null;
    }

    final file = input.files?.item(0);
    if (file == null) {
      return null;
    }

    try {
      return (await file.text().toDart.timeout(const Duration(seconds: 30)))
          .toDart;
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _downloadFile({
    required String filename,
    required String contents,
    required String mimeType,
  }) async {
    final blob = web.Blob(
      [contents.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}
