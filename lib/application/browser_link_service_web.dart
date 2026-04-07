import 'package:web/web.dart' as web;

class BrowserLinkService {
  const BrowserLinkService();

  bool get supported => true;

  Future<bool> open(Uri uri, {String target = '_blank'}) async {
    web.window.open(uri.toString(), target);
    return true;
  }
}
