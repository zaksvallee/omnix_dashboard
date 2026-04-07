import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_health_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_camera_bridge_server_contract.dart';
import 'package:omnix_dashboard/ui/onyx_camera_bridge_tone_resolver.dart';

final DateTime _bridgeFixtureNowUtc = DateTime.now().toUtc();

DateTime _bridgeCheckedAtUtc() =>
    _bridgeFixtureNowUtc.subtract(const Duration(minutes: 5));

DateTime _bridgePresentationNowUtc() => _bridgeFixtureNowUtc;

void main() {
  test('camera bridge tone resolver maps shared status tones', () {
    const palette = OnyxCameraBridgeStatusTonePalette(
      live: Color(0xFF111111),
      failed: Color(0xFF222222),
      starting: Color(0xFF333333),
      disabled: Color(0xFF444444),
      standby: Color(0xFF555555),
    );

    expect(
      resolveOnyxCameraBridgeStatusColor(
        OnyxAgentCameraBridgeStatusTone.live,
        palette: palette,
      ),
      const Color(0xFF111111),
    );
    expect(
      resolveOnyxCameraBridgeStatusColor(
        OnyxAgentCameraBridgeStatusTone.disabled,
        palette: palette,
      ),
      const Color(0xFF444444),
    );
    expect(
      resolveOnyxCameraBridgeStatusColorForStatus(
        const OnyxAgentCameraBridgeStatus(
          enabled: true,
          running: true,
          statusLabel: 'Live',
        ),
        palette: palette,
      ),
      const Color(0xFF111111),
    );
  });

  test('camera bridge tone resolver maps validation and chip tones', () {
    const validationPalette = OnyxCameraBridgeValidationTonePalette(
      success: Color(0xFFAAAAAA),
      warning: Color(0xFFBBBBBB),
      neutral: Color(0xFFCCCCCC),
    );
    const chipPalette = OnyxCameraBridgeChipTonePalette(
      status: Color(0xFF010101),
      info: Color(0xFF020202),
      success: Color(0xFF030303),
      warning: Color(0xFF040404),
      neutral: Color(0xFF050505),
      danger: Color(0xFF060606),
    );

    expect(
      resolveOnyxCameraBridgeValidationColor(
        OnyxAgentCameraBridgeValidationTone.warning,
        palette: validationPalette,
      ),
      const Color(0xFFBBBBBB),
    );
    expect(
      resolveOnyxCameraBridgeChipColor(
        OnyxAgentCameraBridgeChipTone.danger,
        palette: chipPalette,
      ),
      const Color(0xFF060606),
    );
    expect(
      resolveOnyxCameraBridgeChipColorForStatusAccent(
        OnyxAgentCameraBridgeChipTone.status,
        statusAccent: const Color(0xFF777777),
      ),
      const Color(0xFF777777),
    );
  });

  test('camera bridge tone resolver maps shared health tones', () {
    const palette = OnyxCameraBridgeHealthTonePalette(
      status: Color(0xFF101010),
      error: Color(0xFF202020),
      warning: Color(0xFF303030),
      success: Color(0xFF404040),
    );

    expect(
      resolveOnyxCameraBridgeHealthColor(
        OnyxAgentCameraBridgeHealthTone.error,
        palette: palette,
      ),
      const Color(0xFF202020),
    );
    expect(
      resolveOnyxCameraBridgeHealthColor(
        OnyxAgentCameraBridgeHealthTone.success,
        palette: palette,
      ),
      const Color(0xFF404040),
    );
    expect(
      resolveOnyxCameraBridgeHealthColorForSnapshot(
        OnyxAgentCameraBridgeHealthSnapshot(
          requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
          healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
          reachable: true,
          running: true,
          statusLabel: 'Healthy',
          detail: 'Bridge is healthy.',
          executePath: '/execute',
          checkedAtUtc: _bridgeCheckedAtUtc(),
        ),
        palette: palette,
      ),
      const Color(0xFF404040),
    );
  });

  test('camera bridge tone resolver maps agent and admin surface palettes', () {
    const liveStatus = OnyxAgentCameraBridgeStatus(
      enabled: true,
      running: true,
      statusLabel: 'Live',
    );
    const disabledStatus = OnyxAgentCameraBridgeStatus(
      enabled: false,
      running: false,
      statusLabel: 'Disabled',
    );
    final snapshot = OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
      healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
      reachable: true,
      running: false,
      statusLabel: 'Warning',
      detail: 'Bridge is not running.',
      executePath: '/execute',
      checkedAtUtc: _bridgeCheckedAtUtc(),
    );

    expect(
      resolveOnyxCameraBridgeStatusColorForSurface(
        liveStatus,
        variant: OnyxCameraBridgeSurfaceToneVariant.agent,
      ),
      const Color(0xFF34D399),
    );
    expect(
      resolveOnyxCameraBridgeStatusColorForSurface(
        disabledStatus,
        variant: OnyxCameraBridgeSurfaceToneVariant.admin,
      ),
      const Color(0xFF8EA4C2),
    );
    expect(
      resolveOnyxCameraBridgeHealthColorForSurface(
        snapshot,
        statusAccent: const Color(0xFF34D399),
        variant: OnyxCameraBridgeSurfaceToneVariant.agent,
      ),
      const Color(0xFFFBBF24),
    );
    expect(
      resolveOnyxCameraBridgeHealthColorForSurface(
        snapshot,
        statusAccent: const Color(0xFF34D399),
        variant: OnyxCameraBridgeSurfaceToneVariant.admin,
      ),
      const Color(0xFFF1B872),
    );
    expect(
      resolveOnyxCameraBridgeValidationColorForSurface(
        OnyxAgentCameraBridgeValidationTone.success,
        variant: OnyxCameraBridgeSurfaceToneVariant.agent,
      ),
      const Color(0xFF9FE6B8),
    );
    expect(
      resolveOnyxCameraBridgeValidationColorForSurface(
        OnyxAgentCameraBridgeValidationTone.success,
        variant: OnyxCameraBridgeSurfaceToneVariant.admin,
      ),
      const Color(0xFFA7F3D0),
    );
    final adminAccents = resolveOnyxCameraBridgeSurfaceAccents(
      status: liveStatus,
      snapshot: snapshot,
      variant: OnyxCameraBridgeSurfaceToneVariant.admin,
    );
    expect(adminAccents.status, const Color(0xFF34D399));
    expect(adminAccents.health, const Color(0xFFF1B872));
  });

  test('camera bridge tone resolver packages shared surface presentation', () {
    final status = OnyxAgentCameraBridgeStatus(
      enabled: true,
      running: true,
      endpoint: Uri.parse('http://127.0.0.1:11634'),
      statusLabel: 'Live',
    );
    final restoredSnapshot = OnyxAgentCameraBridgeHealthSnapshot(
      requestedEndpoint: Uri.parse('http://127.0.0.1:11634'),
      healthEndpoint: Uri.parse('http://127.0.0.1:11634/health'),
      reachable: true,
      running: true,
      statusLabel: 'Healthy',
      detail: 'Bridge is healthy.',
      executePath: '/execute',
      checkedAtUtc: _bridgeCheckedAtUtc(),
    );

    final presentation = resolveOnyxCameraBridgeSurfacePresentation(
      status: status,
      localSnapshot: null,
      fallbackSnapshot: restoredSnapshot,
      healthProbeConfigured: true,
      validationInFlight: true,
      variant: OnyxCameraBridgeSurfaceToneVariant.admin,
      nowUtc: _bridgePresentationNowUtc(),
    );

    expect(presentation.displaySnapshot, isNull);
    expect(presentation.effectiveSnapshot, same(restoredSnapshot));
    expect(presentation.surfaceState.controls.showHealthCard, isTrue);
    expect(
      presentation.surfaceState.receiptState,
      OnyxAgentCameraBridgeReceiptState.current,
    );
    expect(presentation.accents.status, const Color(0xFF34D399));
    expect(presentation.accents.health, const Color(0xFF34D399));
  });
}
