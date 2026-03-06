class TextShareService {
  const TextShareService();

  bool get supported => false;

  Future<bool> shareText({required String title, required String text}) async {
    return false;
  }
}
