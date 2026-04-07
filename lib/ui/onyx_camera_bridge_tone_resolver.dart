import 'package:flutter/material.dart';

import '../application/onyx_agent_camera_bridge_health_service.dart';
import '../application/onyx_agent_camera_bridge_server_contract.dart';

enum OnyxCameraBridgeSurfaceToneVariant { agent, admin }

class OnyxCameraBridgeSurfaceAccents {
  final Color status;
  final Color health;

  const OnyxCameraBridgeSurfaceAccents({
    required this.status,
    required this.health,
  });
}

class OnyxCameraBridgeSurfacePresentation {
  final OnyxAgentCameraBridgeHealthSnapshot? effectiveSnapshot;
  final OnyxAgentCameraBridgeHealthSnapshot? displaySnapshot;
  final OnyxAgentCameraBridgeSurfaceState surfaceState;
  final OnyxCameraBridgeSurfaceAccents accents;

  const OnyxCameraBridgeSurfacePresentation({
    required this.effectiveSnapshot,
    required this.displaySnapshot,
    required this.surfaceState,
    required this.accents,
  });
}

class OnyxCameraBridgeStatusTonePalette {
  final Color live;
  final Color failed;
  final Color starting;
  final Color disabled;
  final Color standby;

  const OnyxCameraBridgeStatusTonePalette({
    required this.live,
    required this.failed,
    required this.starting,
    required this.disabled,
    required this.standby,
  });
}

class OnyxCameraBridgeHealthTonePalette {
  final Color status;
  final Color error;
  final Color warning;
  final Color success;

  const OnyxCameraBridgeHealthTonePalette({
    required this.status,
    required this.error,
    required this.warning,
    required this.success,
  });
}

class OnyxCameraBridgeValidationTonePalette {
  final Color success;
  final Color warning;
  final Color neutral;

  const OnyxCameraBridgeValidationTonePalette({
    required this.success,
    required this.warning,
    required this.neutral,
  });
}

class OnyxCameraBridgeChipTonePalette {
  final Color status;
  final Color info;
  final Color success;
  final Color warning;
  final Color neutral;
  final Color danger;

  const OnyxCameraBridgeChipTonePalette({
    required this.status,
    required this.info,
    required this.success,
    required this.warning,
    required this.neutral,
    required this.danger,
  });
}

OnyxCameraBridgeStatusTonePalette _onyxCameraBridgeSurfaceStatusTonePalette(
  OnyxCameraBridgeSurfaceToneVariant variant,
) {
  return switch (variant) {
    OnyxCameraBridgeSurfaceToneVariant.agent =>
      const OnyxCameraBridgeStatusTonePalette(
        live: Color(0xFF34D399),
        failed: Color(0xFFF87171),
        starting: Color(0xFFFBBF24),
        disabled: Color(0xFF94A3B8),
        standby: Color(0xFF67E8F9),
      ),
    OnyxCameraBridgeSurfaceToneVariant.admin =>
      const OnyxCameraBridgeStatusTonePalette(
        live: Color(0xFF34D399),
        failed: Color(0xFFF87171),
        starting: Color(0xFFF1B872),
        disabled: Color(0xFF8EA4C2),
        standby: Color(0xFF67E8F9),
      ),
  };
}

OnyxCameraBridgeHealthTonePalette _onyxCameraBridgeSurfaceHealthTonePalette(
  OnyxCameraBridgeSurfaceToneVariant variant, {
  required Color statusAccent,
}) {
  return switch (variant) {
    OnyxCameraBridgeSurfaceToneVariant.agent =>
      OnyxCameraBridgeHealthTonePalette(
        status: statusAccent,
        error: const Color(0xFFF87171),
        warning: const Color(0xFFFBBF24),
        success: const Color(0xFF34D399),
      ),
    OnyxCameraBridgeSurfaceToneVariant.admin =>
      OnyxCameraBridgeHealthTonePalette(
        status: statusAccent,
        error: const Color(0xFFF87171),
        warning: const Color(0xFFF1B872),
        success: const Color(0xFF34D399),
      ),
  };
}

OnyxCameraBridgeValidationTonePalette
_onyxCameraBridgeSurfaceValidationTonePalette(
  OnyxCameraBridgeSurfaceToneVariant variant,
) {
  return switch (variant) {
    OnyxCameraBridgeSurfaceToneVariant.agent =>
      const OnyxCameraBridgeValidationTonePalette(
        success: Color(0xFF9FE6B8),
        warning: Color(0xFFFDE68A),
        neutral: Color(0xFFCBD5E1),
      ),
    OnyxCameraBridgeSurfaceToneVariant.admin =>
      const OnyxCameraBridgeValidationTonePalette(
        success: Color(0xFFA7F3D0),
        warning: Color(0xFFFDE68A),
        neutral: Color(0xFFCBD5E1),
      ),
  };
}

Color resolveOnyxCameraBridgeStatusColor(
  OnyxAgentCameraBridgeStatusTone tone, {
  required OnyxCameraBridgeStatusTonePalette palette,
}) {
  return switch (tone) {
    OnyxAgentCameraBridgeStatusTone.live => palette.live,
    OnyxAgentCameraBridgeStatusTone.failed => palette.failed,
    OnyxAgentCameraBridgeStatusTone.starting => palette.starting,
    OnyxAgentCameraBridgeStatusTone.disabled => palette.disabled,
    OnyxAgentCameraBridgeStatusTone.standby => palette.standby,
  };
}

Color resolveOnyxCameraBridgeStatusColorForStatus(
  OnyxAgentCameraBridgeStatus status, {
  required OnyxCameraBridgeStatusTonePalette palette,
}) {
  return resolveOnyxCameraBridgeStatusColor(
    resolveOnyxAgentCameraBridgeStatusToneForStatus(status),
    palette: palette,
  );
}

Color resolveOnyxCameraBridgeStatusColorForSurface(
  OnyxAgentCameraBridgeStatus status, {
  required OnyxCameraBridgeSurfaceToneVariant variant,
}) {
  return resolveOnyxCameraBridgeStatusColorForStatus(
    status,
    palette: _onyxCameraBridgeSurfaceStatusTonePalette(variant),
  );
}

Color resolveOnyxCameraBridgeHealthColor(
  OnyxAgentCameraBridgeHealthTone tone, {
  required OnyxCameraBridgeHealthTonePalette palette,
}) {
  return switch (tone) {
    OnyxAgentCameraBridgeHealthTone.status => palette.status,
    OnyxAgentCameraBridgeHealthTone.error => palette.error,
    OnyxAgentCameraBridgeHealthTone.warning => palette.warning,
    OnyxAgentCameraBridgeHealthTone.success => palette.success,
  };
}

Color resolveOnyxCameraBridgeHealthColorForSnapshot(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot, {
  required OnyxCameraBridgeHealthTonePalette palette,
}) {
  return resolveOnyxCameraBridgeHealthColor(
    resolveOnyxAgentCameraBridgeHealthTone(snapshot),
    palette: palette,
  );
}

Color resolveOnyxCameraBridgeHealthColorForSurface(
  OnyxAgentCameraBridgeHealthSnapshot? snapshot, {
  required Color statusAccent,
  required OnyxCameraBridgeSurfaceToneVariant variant,
}) {
  return resolveOnyxCameraBridgeHealthColorForSnapshot(
    snapshot,
    palette: _onyxCameraBridgeSurfaceHealthTonePalette(
      variant,
      statusAccent: statusAccent,
    ),
  );
}

OnyxCameraBridgeSurfaceAccents resolveOnyxCameraBridgeSurfaceAccents({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthSnapshot? snapshot,
  required OnyxCameraBridgeSurfaceToneVariant variant,
}) {
  final statusAccent = resolveOnyxCameraBridgeStatusColorForSurface(
    status,
    variant: variant,
  );
  return OnyxCameraBridgeSurfaceAccents(
    status: statusAccent,
    health: resolveOnyxCameraBridgeHealthColorForSurface(
      snapshot,
      statusAccent: statusAccent,
      variant: variant,
    ),
  );
}

OnyxCameraBridgeSurfacePresentation resolveOnyxCameraBridgeSurfacePresentation({
  required OnyxAgentCameraBridgeStatus status,
  required OnyxAgentCameraBridgeHealthSnapshot? localSnapshot,
  OnyxAgentCameraBridgeHealthSnapshot? fallbackSnapshot,
  required bool healthProbeConfigured,
  bool validationInFlight = false,
  bool resetInFlight = false,
  required OnyxCameraBridgeSurfaceToneVariant variant,
  DateTime? nowUtc,
}) {
  final effectiveSnapshot = localSnapshot ?? fallbackSnapshot;
  return OnyxCameraBridgeSurfacePresentation(
    effectiveSnapshot: effectiveSnapshot,
    displaySnapshot: localSnapshot,
    surfaceState: resolveOnyxAgentCameraBridgeSurfaceState(
      status: status,
      snapshot: effectiveSnapshot,
      healthProbeConfigured: healthProbeConfigured,
      validationInFlight: validationInFlight,
      resetInFlight: resetInFlight,
      hasLocalSnapshot: localSnapshot != null,
      nowUtc: nowUtc,
    ),
    accents: resolveOnyxCameraBridgeSurfaceAccents(
      status: status,
      snapshot: effectiveSnapshot,
      variant: variant,
    ),
  );
}

Color resolveOnyxCameraBridgeValidationColor(
  OnyxAgentCameraBridgeValidationTone tone, {
  required OnyxCameraBridgeValidationTonePalette palette,
}) {
  return switch (tone) {
    OnyxAgentCameraBridgeValidationTone.success => palette.success,
    OnyxAgentCameraBridgeValidationTone.warning => palette.warning,
    OnyxAgentCameraBridgeValidationTone.neutral => palette.neutral,
  };
}

Color resolveOnyxCameraBridgeValidationColorForSurface(
  OnyxAgentCameraBridgeValidationTone tone, {
  required OnyxCameraBridgeSurfaceToneVariant variant,
}) {
  return resolveOnyxCameraBridgeValidationColor(
    tone,
    palette: _onyxCameraBridgeSurfaceValidationTonePalette(variant),
  );
}

Color resolveOnyxCameraBridgeChipColor(
  OnyxAgentCameraBridgeChipTone tone, {
  required OnyxCameraBridgeChipTonePalette palette,
}) {
  return switch (tone) {
    OnyxAgentCameraBridgeChipTone.status => palette.status,
    OnyxAgentCameraBridgeChipTone.info => palette.info,
    OnyxAgentCameraBridgeChipTone.success => palette.success,
    OnyxAgentCameraBridgeChipTone.warning => palette.warning,
    OnyxAgentCameraBridgeChipTone.neutral => palette.neutral,
    OnyxAgentCameraBridgeChipTone.danger => palette.danger,
  };
}

Color resolveOnyxCameraBridgeChipColorForStatusAccent(
  OnyxAgentCameraBridgeChipTone tone, {
  required Color statusAccent,
}) {
  return resolveOnyxCameraBridgeChipColor(
    tone,
    palette: OnyxCameraBridgeChipTonePalette(
      status: statusAccent,
      info: const Color(0xFF67E8F9),
      success: const Color(0xFF86EFAC),
      warning: const Color(0xFFFBBF24),
      neutral: const Color(0xFFCBD5E1),
      danger: const Color(0xFFFCA5A5),
    ),
  );
}
