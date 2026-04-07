import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/openai_runtime_config.dart';

void main() {
  test('resolve prefers primary values first', () {
    final config = OpenAiRuntimeConfig.resolve(
      primaryApiKey: 'primary-key',
      primaryModel: 'gpt-5.4',
      primaryEndpoint: 'https://api.openai.com/v1/responses',
      secondaryApiKey: 'secondary-key',
      secondaryModel: 'gpt-4.1-mini',
      secondaryEndpoint: 'https://secondary.example/v1/responses',
      genericApiKey: 'generic-key',
      genericModel: 'gpt-4o-mini',
      genericBaseUrl: 'https://generic.example',
    );

    expect(config.apiKey, 'primary-key');
    expect(config.model, 'gpt-5.4');
    expect(config.endpoint.toString(), 'https://api.openai.com/v1/responses');
    expect(config.isConfigured, isTrue);
  });

  test('resolve falls back to generic OPENAI values', () {
    final config = OpenAiRuntimeConfig.resolve(
      primaryApiKey: '',
      primaryModel: '',
      primaryEndpoint: '',
      genericApiKey: 'generic-key',
      genericModel: 'gpt-5.4',
      genericBaseUrl: 'https://api.openai.com',
    );

    expect(config.apiKey, 'generic-key');
    expect(config.model, 'gpt-5.4');
    expect(config.endpoint.toString(), 'https://api.openai.com/v1/responses');
    expect(config.isConfigured, isTrue);
  });

  test('resolve appends responses path to v1-compatible generic base url', () {
    final config = OpenAiRuntimeConfig.resolve(
      primaryApiKey: '',
      primaryModel: '',
      primaryEndpoint: '',
      genericApiKey: 'generic-key',
      genericModel: 'gpt-5.4',
      genericBaseUrl: 'https://gateway.example/v1',
    );

    expect(
      config.endpoint.toString(),
      'https://gateway.example/v1/responses',
    );
  });

  test('resolve leaves explicit responses endpoint unchanged', () {
    final config = OpenAiRuntimeConfig.resolve(
      primaryApiKey: '',
      primaryModel: '',
      primaryEndpoint: '',
      genericApiKey: 'generic-key',
      genericModel: 'gpt-5.4',
      genericBaseUrl: 'https://gateway.example/custom/responses',
    );

    expect(
      config.endpoint.toString(),
      'https://gateway.example/custom/responses',
    );
  });
}
