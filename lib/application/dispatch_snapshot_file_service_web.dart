// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class DispatchSnapshotFileService {
  const DispatchSnapshotFileService();

  bool get supported => true;

  Future<void> downloadJsonFile({
    required String filename,
    required String contents,
  }) async {
    final blob = html.Blob([utf8.encode(contents)], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> downloadTextFile({
    required String filename,
    required String contents,
  }) async {
    final blob = html.Blob([utf8.encode(contents)], 'text/plain;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = filename
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<String?> pickJsonFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json';
    input.click();

    try {
      await input.onChange.first.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return null;
    }

    final file = input.files?.first;
    if (file == null) return null;
    final reader = html.FileReader();
    reader.readAsText(file);

    try {
      await reader.onLoad.first.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return null;
    }

    final result = reader.result;
    return result is String ? result : null;
  }
}
