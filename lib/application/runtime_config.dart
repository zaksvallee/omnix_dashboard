class OnyxRuntimeConfig {
  static String usableSecret(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isPlaceholderSecret(trimmed)) {
      return '';
    }
    return trimmed;
  }

  static String usableSupabaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isPlaceholderSupabaseUrl(trimmed)) {
      return '';
    }
    return trimmed;
  }

  static String usableLiveFeedUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isPlaceholderLiveFeedUrl(trimmed)) {
      return '';
    }
    return trimmed;
  }

  static String usableListenerAlarmFeedUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isPlaceholderLiveFeedUrl(trimmed)) {
      return '';
    }
    return trimmed;
  }

  static bool hasPlaceholderSecret(String raw) {
    return _isPlaceholderSecret(raw.trim());
  }

  static bool hasPlaceholderSupabaseUrl(String raw) {
    return _isPlaceholderSupabaseUrl(raw.trim());
  }

  static bool hasPlaceholderLiveFeedUrl(String raw) {
    return _isPlaceholderLiveFeedUrl(raw.trim());
  }

  static bool hasPlaceholderListenerAlarmFeedUrl(String raw) {
    return _isPlaceholderLiveFeedUrl(raw.trim());
  }

  static bool _isPlaceholderSecret(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized == 'replace-me') {
      return true;
    }
    return normalized.startsWith('your_') && normalized.endsWith('_here');
  }

  static bool _isPlaceholderSupabaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      return false;
    }
    return uri.host.trim().toLowerCase() == 'your-project.supabase.co';
  }

  static bool _isPlaceholderLiveFeedUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) {
      return false;
    }
    return uri.host.trim().toLowerCase() == 'example.com';
  }
}
