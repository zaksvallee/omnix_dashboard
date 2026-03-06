import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/runtime_config.dart';

void main() {
  test('usableSecret rejects placeholder values', () {
    expect(OnyxRuntimeConfig.usableSecret('replace-me'), isEmpty);
    expect(
      OnyxRuntimeConfig.usableSecret('your_newsapi_org_key_here'),
      isEmpty,
    );
    expect(OnyxRuntimeConfig.usableSecret(' real-key '), 'real-key');
  });

  test('usableSupabaseUrl rejects the template project url', () {
    expect(
      OnyxRuntimeConfig.usableSupabaseUrl('https://your-project.supabase.co'),
      isEmpty,
    );
    expect(
      OnyxRuntimeConfig.usableSupabaseUrl('https://project.supabase.co'),
      'https://project.supabase.co',
    );
  });

  test('usableLiveFeedUrl rejects the example placeholder url', () {
    expect(
      OnyxRuntimeConfig.usableLiveFeedUrl('https://example.com/live-feed.json'),
      isEmpty,
    );
    expect(
      OnyxRuntimeConfig.usableLiveFeedUrl(
        'https://feeds.security.example.org/live.json',
      ),
      'https://feeds.security.example.org/live.json',
    );
  });
}
