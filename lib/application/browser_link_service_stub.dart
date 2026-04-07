class BrowserLinkService {
  const BrowserLinkService();

  bool get supported => false;

  Future<bool> open(Uri uri, {String target = '_blank'}) async {
    return false;
  }
}
