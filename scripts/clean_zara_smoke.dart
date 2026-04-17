import 'dart:convert';
import 'dart:io';

import 'package:omnix_dashboard/application/runtime_config.dart';
import 'package:supabase/supabase.dart';

const List<String> _scenarioPrefixes = <String>[
  'SCENARIO-SMOKE-%',
  'TEST-ZARA-SMOKE-%',
];

Future<void> main(List<String> args) async {
  final configPath = _readConfigPath(args);
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('FAIL: Missing config file: $configPath');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await configFile.readAsString());
  if (decoded is! Map) {
    stderr.writeln('FAIL: Config file must contain a JSON object.');
    exitCode = 1;
    return;
  }
  final config = decoded.map((key, value) {
    return MapEntry(key.toString(), value?.toString() ?? '');
  });
  final supabaseUrl = OnyxRuntimeConfig.usableSupabaseUrl(
    config['SUPABASE_URL'] ?? '',
  );
  final serviceKey = OnyxRuntimeConfig.usableSecret(
    config['ONYX_SUPABASE_SERVICE_KEY'] ?? '',
  );
  if (supabaseUrl.isEmpty || serviceKey.isEmpty) {
    stderr.writeln(
      'FAIL: SUPABASE_URL and ONYX_SUPABASE_SERVICE_KEY are required in the config file.',
    );
    exitCode = 1;
    return;
  }

  final client = SupabaseClient(supabaseUrl, serviceKey);
  try {
    final actionRows = await _selectRows(
      client: client,
      table: 'zara_action_log',
      column: 'scenario_id',
    );
    if (actionRows.isNotEmpty) {
      await _deleteRows(
        client: client,
        table: 'zara_action_log',
        column: 'scenario_id',
      );
    }

    final scenarioRows = await _selectRows(
      client: client,
      table: 'zara_scenarios',
      column: 'id',
    );
    if (scenarioRows.isNotEmpty) {
      await _deleteRows(
        client: client,
        table: 'zara_scenarios',
        column: 'id',
      );
    }

    stdout.writeln(
      'Zara smoke cleanup complete: ${actionRows.length} action log row(s), ${scenarioRows.length} scenario row(s) removed.',
    );
  } finally {
    client.dispose();
  }
}

String _readConfigPath(List<String> args) {
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--config' && index + 1 < args.length) {
      return args[index + 1];
    }
    if (arg.startsWith('--config=')) {
      return arg.substring('--config='.length);
    }
  }
  return 'config/onyx.smoke.local.json';
}

Future<List<Map<String, Object?>>> _selectRows({
  required SupabaseClient client,
  required String table,
  required String column,
}) async {
  final rows = await client
      .from(table)
      .select()
      .or(_prefixFilter(column));
  return rows.map((row) => Map<String, Object?>.from(row as Map)).toList();
}

Future<void> _deleteRows({
  required SupabaseClient client,
  required String table,
  required String column,
}) async {
  await client
      .from(table)
      .delete()
      .or(_prefixFilter(column));
}

String _prefixFilter(String column) {
  return _scenarioPrefixes.map((prefix) => '$column.like.$prefix').join(',');
}
