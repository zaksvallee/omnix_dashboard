import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/authority/authority_token.dart';
import 'package:omnix_dashboard/engine/execution/execution_engine.dart';

void main() {
  final authority = AuthorityToken(
    authorizedBy: 'CONTROL-01',
    timestamp: DateTime.utc(2026, 4, 7, 10, 0),
  );

  test('rejects duplicate dispatch execution attempts', () {
    final engine = ExecutionEngine();

    expect(engine.execute('DSP-1', authority: authority), isTrue);
    expect(
      () => engine.execute('DSP-1', authority: authority),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects empty authority', () {
    final engine = ExecutionEngine();

    expect(
      () => engine.execute(
        'DSP-1',
        authority: AuthorityToken(
          authorizedBy: '',
          timestamp: DateTime.utc(2026, 4, 7, 10, 0),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects empty dispatch ids', () {
    final engine = ExecutionEngine();

    expect(
      () => engine.execute('', authority: authority),
      throwsA(isA<ArgumentError>()),
    );
  });
}
