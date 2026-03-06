// ignore_for_file: avoid_dynamic_calls, avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class TextShareService {
  const TextShareService();

  bool get supported {
    final dynamic navigator = html.window.navigator;
    return navigator.share != null;
  }

  Future<bool> shareText({required String title, required String text}) async {
    if (!supported) {
      return false;
    }
    final dynamic navigator = html.window.navigator;
    final payload = <String, Object?>{'title': title, 'text': text};
    try {
      await navigator.share(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
