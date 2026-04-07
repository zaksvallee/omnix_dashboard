import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class TextShareService {
  const TextShareService();

  bool get supported => web.window.navigator.hasProperty('share'.toJS).toDart;

  Future<bool> shareText({required String title, required String text}) async {
    if (!supported) {
      return false;
    }
    try {
      await web.window.navigator
          .share(web.ShareData(title: title, text: text))
          .toDart;
      return true;
    } catch (_) {
      return false;
    }
  }
}
