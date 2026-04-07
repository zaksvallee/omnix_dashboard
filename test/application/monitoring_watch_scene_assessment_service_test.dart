import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/mo_knowledge_repository.dart';
import 'package:omnix_dashboard/application/mo_promotion_decision_store.dart';
import 'package:omnix_dashboard/application/mo_runtime_matching_service.dart';
import 'package:omnix_dashboard/application/monitoring_identity_policy_service.dart';
import 'package:omnix_dashboard/application/monitoring_temporary_identity_approval_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_scene_assessment_service.dart';
import 'package:omnix_dashboard/application/monitoring_watch_runtime_store.dart';
import 'package:omnix_dashboard/application/monitoring_watch_vision_review_service.dart';
import 'package:omnix_dashboard/domain/intelligence/onyx_mo_record.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';

void main() {
  group('MonitoringWatchSceneAssessmentService', () {
    const service = MonitoringWatchSceneAssessmentService();
    const promotionDecisionStore = MoPromotionDecisionStore();
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

    setUp(() {
      promotionDecisionStore.reset();
    });

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

    test('flags environmental hazards from metadata-only review', () {
      final event = _intel(
        objectLabel: 'equipment',
        objectConfidence: 0.76,
        riskScore: 70,
        headline: 'HIKVISION_DVR_MONITOR_ONLY EQUIPMENT_ALERT',
        summary: 'Electrical hazard detected near the control panel.',
        snapshotUrl: 'https://edge.example.com/snapshot.jpg',
      );

      final assessment = service.assess(
        event: event,
        review: buildMetadataOnlyMonitoringWatchVisionReview(event),
        priorReviewedEvents: 0,
      );

      expect(assessment.environmentHazardSignal, isTrue);
      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.postureLabel, 'environmental hazard alert');
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

    test(
      'infers person object truth from face matches even when review stays generic',
      () {
        final event = _intel(
          objectLabel: '',
          objectConfidence: 0.43,
          riskScore: 72,
          headline: 'HIK_CONNECT_OPENAPI FR_MATCH',
          summary: 'Face match arrived from Hik-Connect.',
          snapshotUrl: null,
          faceMatchId: 'RESIDENT-44',
          faceConfidence: 91.2,
        );
        const review = MonitoringWatchVisionReviewResult(
          sourceLabel: 'openai:gpt-4.1-mini',
          usedFallback: false,
          primaryObjectLabel: 'movement',
          confidence: MonitoringWatchVisionConfidence.medium,
          indicatesPerson: false,
          indicatesVehicle: false,
          indicatesAnimal: false,
          indicatesLoitering: false,
          indicatesBoundaryConcern: false,
          indicatesEscalationCandidate: false,
          riskDelta: 0,
          summary: 'Subject visible near the lobby.',
        );

        final assessment = service.assess(
          event: event,
          review: review,
          priorReviewedEvents: 0,
        );

        expect(assessment.objectLabel, 'person');
        expect(assessment.rationale, contains('object:person'));
      },
    );

    test(
      'infers vehicle object truth from plate hits even when review stays generic',
      () {
        final event = _intel(
          objectLabel: '',
          objectConfidence: 0.52,
          riskScore: 68,
          headline: 'HIK_CONNECT_OPENAPI ANPR',
          summary: 'Plate hit arrived from Hik-Connect.',
          snapshotUrl: null,
          plateNumber: 'CA123456',
          plateConfidence: 96.4,
        );
        const review = MonitoringWatchVisionReviewResult(
          sourceLabel: 'metadata-only',
          usedFallback: true,
          primaryObjectLabel: 'unknown',
          confidence: MonitoringWatchVisionConfidence.medium,
          indicatesPerson: false,
          indicatesVehicle: false,
          indicatesAnimal: false,
          indicatesLoitering: false,
          indicatesBoundaryConcern: false,
          indicatesEscalationCandidate: false,
          riskDelta: 0,
          summary: 'Vehicle metadata only.',
        );

        final assessment = service.assess(
          event: event,
          review: review,
          priorReviewedEvents: 0,
        );

        expect(assessment.objectLabel, 'vehicle');
        expect(assessment.rationale, contains('object:vehicle'));
      },
    );

    test('surfaces MO shadow match for service impersonation scene', () {
      final moAwareService = MonitoringWatchSceneAssessmentService(
        moRuntimeMatchingService: MoRuntimeMatchingService(
          repository: InMemoryMoKnowledgeRepository(
            seedRecords: {
              'MO-EXT-OFFICE': OnyxMoRecord(
                moId: 'MO-EXT-OFFICE',
                title: 'Office contractor impersonation pattern',
                environmentTypes: const ['office_building'],
                summary: 'Contractor impersonation moving floor to floor.',
                sourceType: OnyxMoSourceType.externalIncident,
                sourceLabel: 'Security Bulletin',
                sourceConfidence: 'high',
                patternConfidence: 'high',
                behaviorStage: 'inside_behavior',
                incidentType: 'deception_led_intrusion',
                entryIndicators: const ['spoofed_service_access'],
                insideBehaviorIndicators: const [
                  'multi_zone_roaming',
                  'room_probing',
                ],
                deceptionIndicators: const ['maintenance_impersonation'],
                observableCues: const ['route_anomalies'],
                attackGoal: 'theft',
                evidenceQuality: 'high',
                riskWeight: 82,
                recommendedActionPlans: const [
                  'PROMOTE SCENE REVIEW',
                  'RAISE READINESS',
                ],
                observabilityScore: 0.82,
                localRelevanceScore: 0.88,
                firstSeenUtc: DateTime.utc(2026, 3, 10),
                lastSeenUtc: DateTime.utc(2026, 3, 17),
                validationStatus: OnyxMoValidationStatus.shadowMode,
              ),
            },
          ),
        ),
      );
      final event = _intel(
        objectLabel: 'person',
        objectConfidence: 0.87,
        riskScore: 79,
        headline: 'Maintenance-looking person roaming office floors',
        summary:
            'Contractor-like person moved floor to floor and tried several restricted doors.',
        snapshotUrl: 'https://edge.example.com/snapshot.jpg',
      );

      final assessment = moAwareService.assess(
        event: event,
        review: buildMetadataOnlyMonitoringWatchVisionReview(event),
        priorReviewedEvents: 0,
      );

      expect(
        assessment.moShadowMatchTitles,
        contains('Office contractor impersonation pattern'),
      );
      expect(
        assessment.moShadowSummary,
        contains('Office contractor impersonation pattern'),
      );
      expect(assessment.rationale, contains('mo_shadow:MO-EXT-OFFICE'));
      expect(assessment.shouldNotifyClient, isTrue);
    });

    test('applies accepted promotion decisions for injected MO repositories', () {
      promotionDecisionStore.accept(
        moId: 'MO-EXT-OFFICE',
        targetValidationStatus: 'validated',
      );
      final repository = InMemoryMoKnowledgeRepository(
        seedRecords: {
          'MO-EXT-OFFICE': OnyxMoRecord(
            moId: 'MO-EXT-OFFICE',
            title: 'Office contractor impersonation pattern',
            environmentTypes: const ['office_building'],
            summary: 'Contractor impersonation moving floor to floor.',
            sourceType: OnyxMoSourceType.externalIncident,
            sourceLabel: 'Security Bulletin',
            sourceConfidence: 'high',
            patternConfidence: 'high',
            behaviorStage: 'inside_behavior',
            incidentType: 'deception_led_intrusion',
            entryIndicators: const ['spoofed_service_access'],
            insideBehaviorIndicators: const [
              'multi_zone_roaming',
              'room_probing',
            ],
            deceptionIndicators: const ['maintenance_impersonation'],
            observableCues: const ['route_anomalies'],
            attackGoal: 'theft',
            evidenceQuality: 'high',
            riskWeight: 82,
            recommendedActionPlans: const [
              'PROMOTE SCENE REVIEW',
              'RAISE READINESS',
            ],
            observabilityScore: 0.82,
            localRelevanceScore: 0.88,
            firstSeenUtc: DateTime.utc(2026, 3, 10),
            lastSeenUtc: DateTime.utc(2026, 3, 17),
            validationStatus: OnyxMoValidationStatus.shadowMode,
          ),
        },
      );
      final moAwareService = MonitoringWatchSceneAssessmentService(
        moRuntimeMatchingService: MoRuntimeMatchingService(
          repository: repository,
        ),
      );
      final event = _intel(
        objectLabel: 'person',
        objectConfidence: 0.87,
        riskScore: 79,
        headline: 'Maintenance-looking person roaming office floors',
        summary:
            'Contractor-like person moved floor to floor and tried several restricted doors.',
        snapshotUrl: 'https://edge.example.com/snapshot.jpg',
      );

      final assessment = moAwareService.assess(
        event: event,
        review: buildMetadataOnlyMonitoringWatchVisionReview(event),
        priorReviewedEvents: 0,
      );

      expect(assessment.moShadowMatchTitles, isNotEmpty);
      expect(assessment.rationale, contains('mo_shadow:MO-EXT-OFFICE'));
      expect(
        repository.readAll().first.validationStatus,
        OnyxMoValidationStatus.validated,
      );
      expect(
        repository.readAll().first.metadata['promotion_decision_status'],
        'accepted',
      );
    });

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

    test('classifies short tracked dwell as passing by', () {
      final latest = _intel(
        id: 'track-passing',
        occurredAt: DateTime.utc(2026, 3, 14, 21, 0, 40),
        objectLabel: 'person',
        objectConfidence: 0.74,
        riskScore: 36,
        headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
        summary: 'Person moved through the gate lane.',
        snapshotUrl: 'https://edge.example.com/passing.jpg',
        trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:11',
      );

      final assessment = service.assess(
        event: latest,
        review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
        priorReviewedEvents: 0,
        groupedEventCount: 1,
        relatedEvents: const <IntelligenceReceived>[],
        persistedTrackedSubject: MonitoringWatchTrackedSubjectState(
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:11',
          cameraId: 'CHANNEL-1',
          objectLabel: 'person',
          firstSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 0, 5),
          lastSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 0, 20),
          eventCount: 1,
        ),
      );

      expect(
        assessment.trackedPostureStage,
        MonitoringWatchTrackedPostureStage.innocent,
      );
      expect(assessment.trackedPostureLabel, 'passing by');
      expect(assessment.trackedPresenceWindow, const Duration(seconds: 35));
      expect(assessment.repeatActivity, isFalse);
      expect(assessment.shouldNotifyClient, isFalse);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'passing by');
    });

    test('classifies medium tracked dwell as suspicious dwell alert', () {
      final latest = _intel(
        id: 'track-dwell',
        occurredAt: DateTime.utc(2026, 3, 14, 21, 2, 5),
        objectLabel: 'person',
        objectConfidence: 0.79,
        riskScore: 38,
        headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
        summary: 'Person remained near the front gate.',
        snapshotUrl: 'https://edge.example.com/dwell.jpg',
        trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:12',
      );

      final assessment = service.assess(
        event: latest,
        review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
        priorReviewedEvents: 0,
        groupedEventCount: 1,
        relatedEvents: const <IntelligenceReceived>[],
        persistedTrackedSubject: MonitoringWatchTrackedSubjectState(
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:12',
          cameraId: 'CHANNEL-1',
          objectLabel: 'person',
          firstSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 0, 15),
          lastSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 1, 10),
          eventCount: 2,
        ),
      );

      expect(
        assessment.trackedPostureStage,
        MonitoringWatchTrackedPostureStage.suspicious,
      );
      expect(assessment.trackedPostureLabel, 'dwell alert');
      expect(
        assessment.trackedPresenceWindow,
        const Duration(minutes: 1, seconds: 50),
      );
      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.postureLabel, 'dwell alert');
      expect(assessment.rationale, contains('track_posture:dwell_alert'));
    });

    test('treats three minutes at a restricted gate as critical staging', () {
      final latest = _intel(
        id: 'track-gate-critical',
        occurredAt: DateTime.utc(2026, 3, 14, 21, 3, 0),
        objectLabel: 'person',
        objectConfidence: 0.8,
        riskScore: 40,
        zone: 'Front Gate',
        headline: 'Front gate movement',
        summary: 'Person remained near the front gate.',
        snapshotUrl: 'https://edge.example.com/front-gate.jpg',
        trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:13',
      );

      final assessment = service.assess(
        event: latest,
        review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
        priorReviewedEvents: 0,
        groupedEventCount: 1,
        relatedEvents: const <IntelligenceReceived>[],
        persistedTrackedSubject: MonitoringWatchTrackedSubjectState(
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:13',
          cameraId: 'CHANNEL-1',
          objectLabel: 'person',
          firstSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 0, 0),
          lastSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 1, 30),
          eventCount: 2,
        ),
      );

      expect(
        assessment.zoneSensitivity,
        MonitoringWatchZoneSensitivity.restrictedZone,
      );
      expect(assessment.zoneLabel, 'Front Gate');
      expect(
        assessment.trackedPostureStage,
        MonitoringWatchTrackedPostureStage.critical,
      );
      expect(assessment.trackedPostureLabel, 'loitering/staging');
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.postureLabel, 'critical loitering/staging');
      expect(assessment.rationale, contains('zone:restricted'));
    });

    test(
      'treats three minutes in a public driveway lane as suspicious, not critical',
      () {
        final latest = _intel(
          id: 'track-driveway-public',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 3, 0),
          objectLabel: 'person',
          objectConfidence: 0.8,
          riskScore: 40,
          zone: 'Public Driveway Lane',
          headline: 'Driveway lane movement',
          summary: 'Person remained in the public driveway lane.',
          snapshotUrl: 'https://edge.example.com/public-driveway.jpg',
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:14',
        );

        final assessment = service.assess(
          event: latest,
          review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
          priorReviewedEvents: 0,
          groupedEventCount: 1,
          relatedEvents: const <IntelligenceReceived>[],
          persistedTrackedSubject: MonitoringWatchTrackedSubjectState(
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:14',
            cameraId: 'CHANNEL-1',
            objectLabel: 'person',
            firstSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 0, 0),
            lastSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 1, 30),
            eventCount: 2,
          ),
        );

        expect(
          assessment.zoneSensitivity,
          MonitoringWatchZoneSensitivity.publicApproach,
        );
        expect(assessment.zoneLabel, 'Public Driveway Lane');
        expect(
          assessment.trackedPostureStage,
          MonitoringWatchTrackedPostureStage.suspicious,
        );
        expect(assessment.trackedPostureLabel, 'dwell alert');
        expect(assessment.shouldNotifyClient, isTrue);
        expect(assessment.shouldEscalate, isFalse);
        expect(assessment.postureLabel, 'dwell alert');
        expect(assessment.rationale, contains('zone:public_approach'));
      },
    );

    test(
      'elevates sustained tracked person activity into loitering concern',
      () {
        final latest = _intel(
          id: 'track-latest',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 20),
          objectLabel: 'person',
          objectConfidence: 0.82,
          riskScore: 38,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Person remained around the front gate.',
          snapshotUrl: 'https://edge.example.com/tracked-person.jpg',
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
        );
        final relatedEvents = <IntelligenceReceived>[
          _intel(
            id: 'track-earlier-1',
            occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
            objectLabel: 'person',
            objectConfidence: 0.80,
            riskScore: 36,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Person stayed near the front gate.',
            snapshotUrl: 'https://edge.example.com/tracked-person-1.jpg',
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
          ),
          _intel(
            id: 'track-earlier-2',
            occurredAt: DateTime.utc(2026, 3, 14, 21, 17),
            objectLabel: 'person',
            objectConfidence: 0.81,
            riskScore: 37,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Same person remained in the gate lane.',
            snapshotUrl: 'https://edge.example.com/tracked-person-2.jpg',
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
          ),
          latest,
        ];

        final assessment = service.assess(
          event: latest,
          review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
          priorReviewedEvents: 0,
          groupedEventCount: relatedEvents.length,
          relatedEvents: relatedEvents,
        );

        expect(
          assessment.trackId,
          'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
        );
        expect(assessment.trackedEventCount, 3);
        expect(assessment.trackedPresenceWindow, const Duration(minutes: 6));
        expect(
          assessment.trackedPostureStage,
          MonitoringWatchTrackedPostureStage.critical,
        );
        expect(assessment.trackedPostureLabel, 'loitering/staging');
        expect(assessment.repeatActivity, isTrue);
        expect(assessment.loiteringConcern, isTrue);
        expect(assessment.shouldNotifyClient, isTrue);
        expect(assessment.shouldEscalate, isTrue);
        expect(assessment.postureLabel, 'critical loitering/staging');
        expect(assessment.rationale, contains('track_repeat:3'));
        expect(assessment.rationale, contains('track_loiter'));
        expect(
          assessment.rationale,
          contains('track_posture:loitering_staging'),
        );
      },
    );

    test(
      'uses persisted tracked subject history across separate watch sweeps',
      () {
        final latest = _intel(
          id: 'track-latest-runtime',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 20),
          objectLabel: 'person',
          objectConfidence: 0.82,
          riskScore: 38,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Person remained around the front gate.',
          snapshotUrl: 'https://edge.example.com/tracked-person.jpg',
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
        );

        final assessment = service.assess(
          event: latest,
          review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
          priorReviewedEvents: 0,
          groupedEventCount: 1,
          relatedEvents: const <IntelligenceReceived>[],
          persistedTrackedSubject: MonitoringWatchTrackedSubjectState(
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
            cameraId: 'CHANNEL-1',
            objectLabel: 'person',
            firstSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 14),
            lastSeenAtUtc: DateTime.utc(2026, 3, 14, 21, 17),
            eventCount: 2,
          ),
        );

        expect(
          assessment.trackId,
          'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:7',
        );
        expect(assessment.trackedEventCount, 3);
        expect(assessment.trackedPresenceWindow, const Duration(minutes: 6));
        expect(
          assessment.trackedPostureStage,
          MonitoringWatchTrackedPostureStage.critical,
        );
        expect(assessment.trackedPostureLabel, 'loitering/staging');
        expect(assessment.repeatActivity, isTrue);
        expect(assessment.loiteringConcern, isTrue);
        expect(assessment.shouldEscalate, isTrue);
        expect(assessment.postureLabel, 'critical loitering/staging');
        expect(assessment.rationale, contains('track_repeat:3'));
        expect(assessment.rationale, contains('track_loiter'));
        expect(
          assessment.rationale,
          contains('track_posture:loitering_staging'),
        );
      },
    );

    test(
      'does not infer loitering when grouped events belong to different tracked subjects',
      () {
        final latest = _intel(
          id: 'track-current',
          occurredAt: DateTime.utc(2026, 3, 14, 21, 20),
          objectLabel: 'person',
          objectConfidence: 0.82,
          riskScore: 38,
          headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
          summary: 'Person moved past the front gate.',
          snapshotUrl: 'https://edge.example.com/tracked-current.jpg',
          trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:9',
        );
        final relatedEvents = <IntelligenceReceived>[
          _intel(
            id: 'track-other-1',
            occurredAt: DateTime.utc(2026, 3, 14, 21, 14),
            objectLabel: 'person',
            objectConfidence: 0.80,
            riskScore: 36,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Another person crossed near the front gate.',
            snapshotUrl: 'https://edge.example.com/tracked-other-1.jpg',
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:4',
          ),
          _intel(
            id: 'track-other-2',
            occurredAt: DateTime.utc(2026, 3, 14, 21, 17),
            objectLabel: 'person',
            objectConfidence: 0.81,
            riskScore: 37,
            headline: 'HIKVISION_DVR_MONITOR_ONLY MOTION',
            summary: 'Different person moved near the gate lane.',
            snapshotUrl: 'https://edge.example.com/tracked-other-2.jpg',
            trackId: 'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:5',
          ),
          latest,
        ];

        final assessment = service.assess(
          event: latest,
          review: buildMetadataOnlyMonitoringWatchVisionReview(latest),
          priorReviewedEvents: 0,
          groupedEventCount: relatedEvents.length,
          relatedEvents: relatedEvents,
        );

        expect(
          assessment.trackId,
          'SITE-MS-VALLEE-RESIDENCE|CHANNEL-1|track:9',
        );
        expect(assessment.trackedEventCount, 1);
        expect(assessment.trackedPresenceWindow, Duration.zero);
        expect(
          assessment.trackedPostureStage,
          MonitoringWatchTrackedPostureStage.none,
        );
        expect(assessment.repeatActivity, isFalse);
        expect(assessment.loiteringConcern, isFalse);
        expect(assessment.postureLabel, 'monitored movement alert');
        expect(
          assessment.rationale.where((entry) => entry.startsWith('track_')),
          isEmpty,
        );
      },
    );

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

    test('escalates firearm-class detections immediately', () {
      final assessment = service.assess(
        event: _intel(
          objectLabel: 'firearm',
          objectConfidence: 0.92,
          riskScore: 72,
          headline: 'YOLO detected a firearm near the front gate',
          summary: 'Weapon-shaped object detected at the boundary.',
          snapshotUrl: 'https://edge.example.com/firearm.jpg',
        ),
        review: buildMetadataOnlyMonitoringWatchVisionReview(
          _intel(
            objectLabel: 'firearm',
            objectConfidence: 0.92,
            riskScore: 72,
            headline: 'YOLO detected a firearm near the front gate',
            summary: 'Weapon-shaped object detected at the boundary.',
            snapshotUrl: 'https://edge.example.com/firearm.jpg',
          ),
        ),
        priorReviewedEvents: 0,
      );

      expect(assessment.shouldNotifyClient, isTrue);
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.postureLabel, 'escalation candidate');
      expect(assessment.effectiveRiskScore, greaterThanOrEqualTo(96));
    });

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
  String id = '1',
  DateTime? occurredAt,
  required String objectLabel,
  required double objectConfidence,
  required int riskScore,
  required String headline,
  required String summary,
  required String? snapshotUrl,
  String? zone,
  String? trackId,
  String? faceMatchId,
  double? faceConfidence,
  String? plateNumber,
  double? plateConfidence,
}) {
  return IntelligenceReceived(
    eventId: 'evt-$id',
    sequence: 1,
    version: 1,
    occurredAt: occurredAt ?? DateTime.utc(2026, 3, 14, 21, 14),
    intelligenceId: 'intel-$id',
    provider: 'hikvision_dvr_monitor_only',
    sourceType: 'dvr',
    externalId: 'ext-$id',
    clientId: 'CLIENT-MS-VALLEE',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    cameraId: 'channel-1',
    zone: zone,
    objectLabel: objectLabel,
    objectConfidence: objectConfidence,
    trackId: trackId,
    faceMatchId: faceMatchId,
    faceConfidence: faceConfidence,
    plateNumber: plateNumber,
    plateConfidence: plateConfidence,
    headline: headline,
    summary: summary,
    riskScore: riskScore,
    snapshotUrl: snapshotUrl,
    canonicalHash: 'hash-$id',
  );
}
