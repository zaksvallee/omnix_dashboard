import 'site_identity_registry_repository.dart';

class MonitoringTemporaryIdentityApprovalMatch {
  final bool matched;
  final bool matchedFace;
  final bool matchedPlate;
  final DateTime? validUntilUtc;

  const MonitoringTemporaryIdentityApprovalMatch({
    this.matched = false,
    this.matchedFace = false,
    this.matchedPlate = false,
    this.validUntilUtc,
  });
}

class MonitoringTemporaryIdentityApprovalService {
  final List<SiteIdentityProfile> profiles;

  const MonitoringTemporaryIdentityApprovalService({
    this.profiles = const <SiteIdentityProfile>[],
  });

  MonitoringTemporaryIdentityApprovalService copyWith({
    List<SiteIdentityProfile>? profiles,
  }) {
    return MonitoringTemporaryIdentityApprovalService(
      profiles: profiles ?? this.profiles,
    );
  }

  MonitoringTemporaryIdentityApprovalMatch matchAllowed({
    required String clientId,
    required String siteId,
    String? faceMatchId,
    String? plateNumber,
    DateTime? atUtc,
  }) {
    final normalizedFace = _normalize(faceMatchId);
    final normalizedPlate = _normalize(plateNumber);
    final when = (atUtc ?? DateTime.now()).toUtc();
    for (final profile in profiles) {
      if (!_isActiveTemporaryApproval(
        profile,
        clientId: clientId,
        siteId: siteId,
        atUtc: when,
      )) {
        continue;
      }
      final matchedFace =
          normalizedFace.isNotEmpty &&
          _normalize(profile.faceMatchId) == normalizedFace;
      final matchedPlate =
          normalizedPlate.isNotEmpty &&
          _normalize(profile.plateNumber) == normalizedPlate;
      if (matchedFace || matchedPlate) {
        return MonitoringTemporaryIdentityApprovalMatch(
          matched: true,
          matchedFace: matchedFace,
          matchedPlate: matchedPlate,
          validUntilUtc: profile.validUntilUtc?.toUtc(),
        );
      }
    }
    return const MonitoringTemporaryIdentityApprovalMatch();
  }

  MonitoringTemporaryIdentityApprovalService upsertProfile(
    SiteIdentityProfile profile,
  ) {
    final nextProfiles =
        profiles
            .where((candidate) {
              final sameId =
                  profile.profileId.trim().isNotEmpty &&
                  candidate.profileId.trim() == profile.profileId.trim();
              final sameReference =
                  profile.externalReference.trim().isNotEmpty &&
                  candidate.externalReference.trim() ==
                      profile.externalReference.trim();
              final sameScope =
                  candidate.clientId == profile.clientId &&
                  candidate.siteId == profile.siteId;
              final sameFace =
                  _normalize(candidate.faceMatchId).isNotEmpty &&
                  _normalize(candidate.faceMatchId) ==
                      _normalize(profile.faceMatchId);
              final samePlate =
                  _normalize(candidate.plateNumber).isNotEmpty &&
                  _normalize(candidate.plateNumber) ==
                      _normalize(profile.plateNumber);
              return !(sameId ||
                  sameReference ||
                  (sameScope && (sameFace || samePlate)));
            })
            .toList(growable: true)
          ..add(profile);
    return MonitoringTemporaryIdentityApprovalService(
      profiles: _prunedProfiles(nextProfiles),
    );
  }

  MonitoringTemporaryIdentityApprovalService pruneExpired({DateTime? nowUtc}) {
    return MonitoringTemporaryIdentityApprovalService(
      profiles: _prunedProfiles(profiles, nowUtc: nowUtc),
    );
  }

  static MonitoringTemporaryIdentityApprovalService fromProfiles(
    Iterable<SiteIdentityProfile> profiles,
  ) {
    return MonitoringTemporaryIdentityApprovalService(
      profiles: profiles.toList(growable: false),
    );
  }

  static List<SiteIdentityProfile> _prunedProfiles(
    List<SiteIdentityProfile> profiles, {
    DateTime? nowUtc,
  }) {
    final when = (nowUtc ?? DateTime.now()).toUtc();
    return profiles
        .where(
          (profile) => _isActiveTemporaryApproval(
            profile,
            clientId: profile.clientId,
            siteId: profile.siteId,
            atUtc: when,
          ),
        )
        .toList(growable: false);
  }

  static bool _isActiveTemporaryApproval(
    SiteIdentityProfile profile, {
    required String clientId,
    required String siteId,
    required DateTime atUtc,
  }) {
    if (profile.clientId != clientId || profile.siteId != siteId) {
      return false;
    }
    if (profile.status != SiteIdentityStatus.allowed) {
      return false;
    }
    final validUntilUtc = profile.validUntilUtc?.toUtc();
    if (validUntilUtc == null || !validUntilUtc.isAfter(atUtc)) {
      return false;
    }
    final validFromUtc = profile.validFromUtc?.toUtc();
    if (validFromUtc != null && validFromUtc.isAfter(atUtc)) {
      return false;
    }
    return _normalize(profile.faceMatchId).isNotEmpty ||
        _normalize(profile.plateNumber).isNotEmpty;
  }

  static String _normalize(String? raw) {
    return (raw ?? '').trim().toUpperCase();
  }
}
