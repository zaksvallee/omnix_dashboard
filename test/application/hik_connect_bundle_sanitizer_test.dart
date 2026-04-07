import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/hik_connect_bundle_sanitizer.dart';

void main() {
  group('HikConnectBundleSanitizer', () {
    test('sanitizes sensitive json fields and urls', () {
      const sanitizer = HikConnectBundleSanitizer();

      final sanitized = sanitizer.sanitizeJsonString(
        '''
        {
          "app_key": "abc123",
          "app_secret": "secret-value",
          "appToken": "verylongtokenvalue1234567890",
          "data": {
            "url": "wss://stream.example.com/live/token",
            "downloadUrl": "https://files.example.com/download/video.mp4",
            "cameraName": "Front Yard"
          }
        }
        ''',
      );

      expect(sanitized, contains('"app_key": "[REDACTED]"'));
      expect(sanitized, contains('"app_secret": "[REDACTED]"'));
      expect(sanitized, contains('"appToken": "[REDACTED]"'));
      expect(sanitized, contains('wss://stream.example.com/[REDACTED]'));
      expect(sanitized, contains('https://files.example.com/[REDACTED]'));
      expect(sanitized, contains('"cameraName": "Front Yard"'));
    });

    test('exports a sanitized bundle copy', () async {
      final source = await Directory.systemTemp.createTemp('hik-source-');
      final target = await Directory.systemTemp.createTemp('hik-target-');
      addTearDown(() async {
        if (await source.exists()) {
          await source.delete(recursive: true);
        }
        if (await target.exists()) {
          await target.delete(recursive: true);
        }
      });
      await File('${source.path}/bundle-manifest.json').writeAsString(
        '{"app_key":"abc123","api_base_url":"https://api.hik-connect.example.com"}',
      );
      await File('${source.path}/preflight-report.md').writeAsString(
        'live: wss://stream.example.com/live/token\napp secret: hunter2\n',
      );
      await File('${source.path}/pilot-env.sh').writeAsString(
        "export ONYX_DVR_APP_KEY='abc123'\n"
        "export ONYX_DVR_APP_SECRET='hunter2'\n"
        "export ONYX_DVR_API_BASE_URL='https://api.hik-connect.example.com'\n",
      );
      await File('${source.path}/bootstrap-packet.md').writeAsString(
        'Pilot Env Block\n'
        "export ONYX_DVR_APP_KEY='abc123'\n"
        "export ONYX_DVR_APP_SECRET='hunter2'\n"
        "export ONYX_DVR_API_BASE_URL='https://api.hik-connect.example.com'\n",
      );

      const sanitizer = HikConnectBundleSanitizer();
      final written = await sanitizer.sanitizeBundleDirectory(
        sourceDirectoryPath: source.path,
        targetDirectoryPath: target.path,
      );

      expect(written, isNotEmpty);
      expect(
        File('${target.path}/bundle-manifest.json').readAsStringSync(),
        contains('"app_key": "[REDACTED]"'),
      );
      expect(
        File('${target.path}/preflight-report.md').readAsStringSync(),
        contains('wss://stream.example.com/[REDACTED]'),
      );
      expect(
        File('${target.path}/preflight-report.md').readAsStringSync(),
        contains('app secret: [REDACTED]'),
      );
      expect(
        File('${target.path}/pilot-env.sh').readAsStringSync(),
        contains("export ONYX_DVR_APP_KEY= '[REDACTED]'"),
      );
      expect(
        File('${target.path}/pilot-env.sh').readAsStringSync(),
        contains("export ONYX_DVR_APP_SECRET= '[REDACTED]'"),
      );
      expect(
        File('${target.path}/pilot-env.sh').readAsStringSync(),
        contains('https://api.hik-connect.example.com/[REDACTED]'),
      );
      expect(
        File('${target.path}/bootstrap-packet.md').readAsStringSync(),
        contains("export ONYX_DVR_APP_KEY= '[REDACTED]'"),
      );
      expect(
        File('${target.path}/bootstrap-packet.md').readAsStringSync(),
        contains("export ONYX_DVR_APP_SECRET= '[REDACTED]'"),
      );
    });
  });
}
