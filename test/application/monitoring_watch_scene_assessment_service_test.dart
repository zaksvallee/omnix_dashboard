import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/monitoring_identity_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_temporary_identity_approval_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_scene_assessment_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_vision_review_service.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchSceneAssessmentService', () {
    const service = MonitoringWatchSceneAssessmentService();
    final policyDrivenService = MonitoringWatchSceneAssessmentService(
      identityPolicyService: MonitoringIdentityPolicyService.parseJson(
        '[{"client_id":"CLIENT-MS-VALLEE","site_id":"SITE-MS-VALLEE-RESIDENCE","allowed_face_match_ids":["RESIDENT-01"],"flagged_face_match_ids":["PERSON-44"],"allowed_plate_numbers":["CA111111"],"flagged_plate_numbers":["CA123456"]}]',
      ),
    );
    final temporaryApprovalDrivenService =
        MonitoringWatchSceneAssessmentService(
          temporaryIdentityApprovalService:
              MonitoringTemporaryIdentityApprovalService.fromProfiles([
                SiteIdentityProfile(
                  profileId: 'tmp-1',
                  clientId: 'CLIENT-MS-VALLEE',
                  siteId: 'SITE-MS-VALLEE-RESIDENCE',
                  identityType: SiteIdentityType.person,
                  category: SiteIdentityCategory.visitor,
                  status: SiteIdentityStatus.allowed,
                  displayName: 'Temporary visitor',
                  faceMatchId: 'PERSON-77',
                  plateNumber: 'CA777777',
                  validFromUtc: DateTime.utc(2026, 3, 14, 20),
                  validUntilUtc: DateTime.utc(2026, 3, 15, 8),
                  createdAtUtc: DateTime.utc(2026, 3, 14, 20),
                  updatedAtUtc: DateTime.utc(2026, 3, 14, 20),
                ),
              ]),
        );

    test('suppresses low-significance animal motion with weak confidence', () {
      final assessment = service.assess(
        event: _intel(
          objectLabel: 'cat',
          objectConfidence: 0.32,
          riskScore: 34,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Routine motion',
          snapshotUrl: null,
        ),
        review: buildMetadataOnlyMonitoringWatchVisionReview(
          _intel(
            objectLabel: 'cat',
            objectConfidence: 0.32,
            riskScore: 34,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Routine motion',
            snapshotUrl: null,
          ),
        ),
        priorReviewedEvents: 0,
      );

      expect(assessment.shouldNotifyClient, isFalse);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'monitored movement alert');
    });

    test('elevates repeated vehicle motion into repeat monitored activity', () {
      final assessment = service.assess(
        event: _intel(
          objectLabel: 'vehicle',
          objectConfidence: 0.88,
          riskScore: 78,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Vehicle on perimeter',
          snapshotUrl: 'https://edge.example.com/snapshot.jpg',
        ),
        review: buildMetadataOnlyMonitoringWatchVisionReview(
          _intel(
            objectLabel: 'vehicle',
            objectConfidence: 0.88,
            riskScore: 78,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Vehicle on perimeter',
            snapshotUrl: 'https://edge.example.com/snapshot.jpg',
          ),
        ),
        priorReviewedEvents: 1,
        groupedEventCount: 2,
      );

      expect(assessment.repeatActivity, isTrue);
      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'repeat monitored activity');
      expect(assessment.effectiveRiskScore, greaterThanOrEqualTo(88));
    });

    test('marks repeated person activity as escalation candidate', () {
      final assessment = service.assess(
        event: _intel(
          objectLabel: 'person',
          objectConfidence: 0.94,
          riskScore: 82,
          headline: 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING',
          summary: 'Perimeter line crossing event',
          snapshotUrl: 'https://edge.example.com/snapshot.jpg',
        ),
        review: buildMetadataOnlyMonitoringWatchVisionReview(
          _intel(
            objectLabel: 'person',
            objectConfidence: 0.94,
            riskScore: 82,
            headline: 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING',
            summary: 'Perimeter line crossing event',
            snapshotUrl: 'https://edge.example.com/snapshot.jpg',
          ),
        ),
        priorReviewedEvents: 1,
      );

      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.postureLabel, 'escalation candidate');
    });

    test('escalates fire and smoke emergencies from metadata-only review', () {
      final event = _intel(
        objectLabel: 'smoke',
        objectConfidence: 0.93,
        riskScore: 74,
        headline: 'HIKVISION_DVR_MONITOR_ONLY FIRE_ALERT',
        summary: 'Smoke visible in the generator room.',
        snapshotUrl: 'https://edge.example.com/snapshot.jpg',
      );

      final assessment = service.assess(
        event: event,
        review: buildMetadataOnlyMonitoringWatchVisionReview(event),
        priorReviewedEvents: 0,
      );

      expect(assessment.fireSignal, isTrue);
      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.postureLabel, 'fire and smoke emergency');
      expect(assessment.effectiveRiskScore, greaterThanOrEqualTo(95));
    });

    test('escalates flood or leak emergencies from metadata-only review', () {
      final event = _intel(
        objectLabel: 'leak',
        objectConfidence: 0.89,
        riskScore: 72,
        headline: 'HIKVISION_DVR_MONITOR_ONLY WATER_ALERT',
        summary: 'Pipe burst caused flooding near the stock room.',
        snapshotUrl: 'https://edge.example.com/snapshot.jpg',
      );

      final assessment = service.assess(
        event: event,
        review: buildMetadataOnlyMonitoringWatchVisionReview(event),
        priorReviewedEvents: 0,
      );

      expect(assessment.waterLeakSignal, isTrue);
      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.postureLabel, 'flood or leak emergency');
      expect(assessment.effectiveRiskScore, greaterThanOrEqualTo(90));
    });

    test(
      'uses high-confidence vision result to override weak metadata label',
      () {
        final event = _intel(
          objectLabel: 'movement',
          objectConfidence: 0.41,
          riskScore: 76,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'General motion',
          snapshotUrl: 'https://edge.example.com/snapshot.jpg',
        );
        const review = MonitoringWatchVisionReviewResult(
          sourceLabel: 'openai:gpt-4.1-mini',
          usedFallback: false,
          primaryObjectLabel: 'person',
          confidence: MonitoringWatchVisionConfidence.high,
          indicatesPerson: true,
          indicatesVehicle: false,
          indicatesAnimal: false,
          indicatesLoitering: false,
          indicatesBoundaryConcern: true,
          indicatesEscalationCandidate: false,
          riskDelta: 10,
          summary: 'Person visible near the boundary.',
          tags: ['person', 'boundary'],
        );

        final assessment = service.assess(
          event: event,
          review: review,
          priorReviewedEvents: 0,
        );

        expect(assessment.objectLabel, 'person');
        expect(assessment.shouldNotifyClient, isTrue);
        expect(assessment.effectiveRiskScore, greaterThanOrEqualTo(90));
      },
    );

    test('labels same-pass loitering scenes explicitly', () {
      final event = _intel(
        objectLabel: 'person',
        objectConfidence: 0.72,
        riskScore: 50,
        headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
        summary: 'Person loitering near the driveway gate',
        snapshotUrl: null,
      );
      const review = MonitoringWatchVisionReviewResult(
        sourceLabel: 'openai:gpt-4.1-mini',
        usedFallback: false,
        primaryObjectLabel: 'person',
        confidence: MonitoringWatchVisionConfidence.medium,
        indicatesPerson: true,
        indicatesVehicle: false,
        indicatesAnimal: false,
        indicatesLoitering: true,
        indicatesBoundaryConcern: false,
        indicatesEscalationCandidate: false,
        riskDelta: 0,
        summary: 'Person remained in view near the driveway gate.',
        tags: ['person', 'loitering'],
      );

      final assessment = service.assess(
        event: event,
        review: review,
        priorReviewedEvents: 0,
      );

      expect(assessment.loiteringConcern, isTrue);
      expect(assessment.boundaryConcern, isFalse);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'loitering concern');
    });

    test('labels combined boundary and loitering scenes explicitly', () {
      final event = _intel(
        objectLabel: 'person',
        objectConfidence: 0.78,
        riskScore: 50,
        headline: 'HIKVISION_DVR_MONITOR_ONLY LINE_CROSSING',
        summary: 'Person loitering near the boundary line',
        snapshotUrl: null,
      );
      const review = MonitoringWatchVisionReviewResult(
        sourceLabel: 'openai:gpt-4.1-mini',
        usedFallback: false,
        primaryObjectLabel: 'person',
        confidence: MonitoringWatchVisionConfidence.medium,
        indicatesPerson: true,
        indicatesVehicle: false,
        indicatesAnimal: false,
        indicatesLoitering: true,
        indicatesBoundaryConcern: true,
        indicatesEscalationCandidate: false,
        riskDelta: 0,
        summary: 'Person remained near the boundary after line crossing.',
        tags: ['person', 'boundary', 'loitering', 'line_crossing'],
      );

      final assessment = service.assess(
        event: event,
        review: review,
        priorReviewedEvents: 0,
      );

      expect(assessment.loiteringConcern, isTrue);
      expect(assessment.boundaryConcern, isTrue);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'boundary loitering concern');
    });

    test(
      'escalates risky LPR/FR metadata when watchlist context is present',
      () {
        final assessment = policyDrivenService.assess(
          event: _intel(
            objectLabel: 'vehicle',
            objectConfidence: 0.91,
            riskScore: 78,
            headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
            summary: 'Vehicle detected at loading bay.',
            snapshotUrl: 'https://edge.example.com/snapshot.jpg',
            faceMatchId: 'PERSON-44',
            faceConfidence: 91.2,
            plateNumber: 'CA123456',
            plateConfidence: 96.4,
          ),
          review: buildMetadataOnlyMonitoringWatchVisionReview(
            _intel(
              objectLabel: 'vehicle',
              objectConfidence: 0.91,
              riskScore: 78,
              headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
              summary: 'Vehicle detected at loading bay.',
              snapshotUrl: 'https://edge.example.com/snapshot.jpg',
              faceMatchId: 'PERSON-44',
              faceConfidence: 91.2,
              plateNumber: 'CA123456',
              plateConfidence: 96.4,
            ),
          ),
          priorReviewedEvents: 0,
        );

        expect(assessment.identityRiskSignal, isTrue);
        expect(assessment.faceMatchId, 'PERSON-44');
        expect(assessment.plateNumber, 'CA123456');
        expect(assessment.shouldNotifyClient, isTrue);
        expect(assessment.shouldEscalate, isTrue);
        expect(assessment.postureLabel, 'escalation candidate');
      },
    );

    test(
      'suppresses known allowed identity matches when activity stays low',
      () {
        final assessment = policyDrivenService.assess(
          event: _intel(
            objectLabel: 'vehicle',
            objectConfidence: 0.61,
            riskScore: 52,
            headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
            summary: 'Resident vehicle arrived at the gate.',
            snapshotUrl: null,
            faceMatchId: 'RESIDENT-01',
            faceConfidence: 88.4,
            plateNumber: 'CA111111',
            plateConfidence: 95.0,
          ),
          review: buildMetadataOnlyMonitoringWatchVisionReview(
            _intel(
              objectLabel: 'vehicle',
              objectConfidence: 0.61,
              riskScore: 52,
              headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
              summary: 'Resident vehicle arrived at the gate.',
              snapshotUrl: null,
              faceMatchId: 'RESIDENT-01',
              faceConfidence: 88.4,
              plateNumber: 'CA111111',
              plateConfidence: 95.0,
            ),
          ),
          priorReviewedEvents: 0,
        );

        expect(assessment.identityAllowedSignal, isTrue);
        expect(assessment.identityRiskSignal, isFalse);
        expect(assessment.shouldNotifyClient, isFalse);
        expect(assessment.shouldEscalate, isFalse);
        expect(assessment.postureLabel, 'known allowed identity');
      },
    );

    test(
      'suppresses temporarily approved identity matches while approval is active',
      () {
        final assessment = temporaryApprovalDrivenService.assess(
          event: _intel(
            objectLabel: 'vehicle',
            objectConfidence: 0.61,
            riskScore: 52,
            headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
            summary: 'Visitor vehicle arrived at the gate.',
            snapshotUrl: null,
            faceMatchId: 'PERSON-77',
            faceConfidence: 88.4,
            plateNumber: 'CA777777',
            plateConfidence: 95.0,
          ),
          review: buildMetadataOnlyMonitoringWatchVisionReview(
            _intel(
              objectLabel: 'vehicle',
              objectConfidence: 0.61,
              riskScore: 52,
              headline: 'HIKVISION_DVR_MONITOR_ONLY LPR_ALERT',
              summary: 'Visitor vehicle arrived at the gate.',
              snapshotUrl: null,
              faceMatchId: 'PERSON-77',
              faceConfidence: 88.4,
              plateNumber: 'CA777777',
              plateConfidence: 95.0,
            ),
          ),
          priorReviewedEvents: 0,
        );

        expect(assessment.identityAllowedSignal, isTrue);
        expect(assessment.temporaryIdentityAllowedSignal, isTrue);
        expect(
          assessment.temporaryIdentityValidUntilUtc,
          DateTime.utc(2026, 3, 15, 8),
        );
        expect(assessment.shouldNotifyClient, isFalse);
        expect(assessment.shouldEscalate, isFalse);
        expect(assessment.postureLabel, 'known allowed identity');
      },
    );
  });
}

IntelligenceReceived _intel({
  required String objectLabel,
  required double objectConfidence,
  required int riskScore,
  required String headline,
  required String summary,
  required String? snapshotUrl,
  String? faceMatchId,
  double? faceConfidence,
  String? plateNumber,
  double? plateConfidence,
}) {
  return IntelligenceReceived(
    eventId: 'evt-1',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
    intelligenceId: 'intel-1',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-1',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: 'channel-1',
    objectLabel: objectLabel,
    objectConfidence: objectConfidence,
    faceMatchId: faceMatchId,
    faceConfidence: faceConfidence,
    plateNumber: plateNumber,
    plateConfidence: plateConfidence,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: snapshotUrl,
    canonicalHash: 'hash-1',
  );
}
