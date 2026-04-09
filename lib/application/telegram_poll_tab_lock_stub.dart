class TelegramPollingTabLock {
  TelegramPollingTabLock({
    this.channelName = 'onyx_telegram_lock',
    this.onPrimaryLost,
    this.onPrimaryAvailable,
  });

  final String channelName;
  final void Function()? onPrimaryLost;
  final void Function()? onPrimaryAvailable;

  bool get isPrimary => true;

  Future<bool> ensurePrimary({
    Duration responseWindow = const Duration(milliseconds: 500),
  }) async {
    return true;
  }

  void release() {}

  void dispose() {}
}
