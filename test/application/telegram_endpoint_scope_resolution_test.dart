import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/telegram_endpoint_scope_resolution.dart';

class _FakeTelegramEndpointEntry {
  final String id;
  final int? threadId;

  const _FakeTelegramEndpointEntry({required this.id, required this.threadId});
}

void main() {
  group('resolveUniqueTelegramEndpointEntry', () {
    test('returns the single typed entry when the topic match is unique', () {
      final resolved = resolveUniqueTelegramEndpointEntry(
        entries: const <_FakeTelegramEndpointEntry>[
          _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: 44),
          _FakeTelegramEndpointEntry(id: 'endpoint-2', threadId: 77),
        ],
        messageThreadId: 77,
        threadIdOf: (entry) => entry.threadId,
      );

      expect(resolved?.id, 'endpoint-2');
    });

    test('fails closed when multiple typed entries share the same thread', () {
      final resolved = resolveUniqueTelegramEndpointEntry(
        entries: const <_FakeTelegramEndpointEntry>[
          _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: 77),
          _FakeTelegramEndpointEntry(id: 'endpoint-2', threadId: 77),
        ],
        messageThreadId: 77,
        threadIdOf: (entry) => entry.threadId,
      );

      expect(resolved, isNull);
    });

    test(
      'falls back to the single unthreaded entry when a topic reply has no thread-specific match',
      () {
        final resolved = resolveUniqueTelegramEndpointEntry(
          entries: const <_FakeTelegramEndpointEntry>[
            _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: null),
          ],
          messageThreadId: 77,
          threadIdOf: (entry) => entry.threadId,
        );

        expect(resolved?.id, 'endpoint-1');
      },
    );

    test(
      'prefers the thread-specific entry over the unthreaded fallback when both exist',
      () {
        final resolved = resolveUniqueTelegramEndpointEntry(
          entries: const <_FakeTelegramEndpointEntry>[
            _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: null),
            _FakeTelegramEndpointEntry(id: 'endpoint-2', threadId: 77),
          ],
          messageThreadId: 77,
          threadIdOf: (entry) => entry.threadId,
        );

        expect(resolved?.id, 'endpoint-2');
      },
    );

    test('counts unique typed endpoint mappings by chat and thread', () {
      final count = countUniqueTelegramEndpointMappings(
        entries: const <_FakeTelegramEndpointEntry>[
          _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: 77),
          _FakeTelegramEndpointEntry(id: 'endpoint-2', threadId: 77),
          _FakeTelegramEndpointEntry(id: 'endpoint-3', threadId: null),
        ],
        chatIdOf: (entry) => entry.id == 'endpoint-3' ? 'chat-2' : 'chat-1',
        threadIdOf: (entry) => entry.threadId,
      );

      expect(count, 2);
    });

    test('detects ambiguous typed endpoint mappings by chat and thread', () {
      final ambiguous = hasAmbiguousTelegramEndpointMappings(
        entries: const <_FakeTelegramEndpointEntry>[
          _FakeTelegramEndpointEntry(id: 'endpoint-1', threadId: 77),
          _FakeTelegramEndpointEntry(id: 'endpoint-2', threadId: 77),
          _FakeTelegramEndpointEntry(id: 'endpoint-3', threadId: null),
        ],
        chatIdOf: (entry) => entry.id == 'endpoint-3' ? 'chat-2' : 'chat-1',
        threadIdOf: (entry) => entry.threadId,
      );

      expect(ambiguous, isTrue);
    });
  });

  group('resolveUniqueTelegramEndpointRow', () {
    test('returns the single unthreaded row when the chat has one match', () {
      final resolved = resolveUniqueTelegramEndpointRow(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-001',
            'telegram_thread_id': '',
          },
        ],
        messageThreadId: null,
      );

      expect(resolved?['id'], 'endpoint-1');
    });

    test('fails closed when multiple unthreaded rows share the same chat', () {
      final resolved = resolveUniqueTelegramEndpointRow(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-001',
            'telegram_thread_id': '',
          },
          <String, dynamic>{
            'id': 'endpoint-2',
            'client_id': 'CLIENT-002',
            'site_id': 'SITE-002',
            'telegram_thread_id': '',
          },
        ],
        messageThreadId: null,
      );

      expect(resolved, isNull);
    });

    test('returns the single threaded row when the topic match is unique', () {
      final resolved = resolveUniqueTelegramEndpointRow(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-001',
            'telegram_thread_id': '44',
          },
          <String, dynamic>{
            'id': 'endpoint-2',
            'client_id': 'CLIENT-002',
            'site_id': 'SITE-002',
            'telegram_thread_id': '77',
          },
        ],
        messageThreadId: 77,
      );

      expect(resolved?['id'], 'endpoint-2');
    });

    test('fails closed when multiple rows share the same topic id', () {
      final resolved = resolveUniqueTelegramEndpointRow(
        rows: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'endpoint-1',
            'client_id': 'CLIENT-001',
            'site_id': 'SITE-001',
            'telegram_thread_id': '44',
          },
          <String, dynamic>{
            'id': 'endpoint-2',
            'client_id': 'CLIENT-002',
            'site_id': 'SITE-002',
            'telegram_thread_id': '44',
          },
        ],
        messageThreadId: 44,
      );

      expect(resolved, isNull);
    });

    test(
      'falls back to the chat-level row when a topic message arrives without a stored thread mapping',
      () {
        final resolved = resolveUniqueTelegramEndpointRow(
          rows: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'endpoint-1',
              'client_id': 'CLIENT-001',
              'site_id': 'SITE-001',
              'telegram_thread_id': '',
            },
          ],
          messageThreadId: 2016,
        );

        expect(resolved?['id'], 'endpoint-1');
      },
    );
  });
}
