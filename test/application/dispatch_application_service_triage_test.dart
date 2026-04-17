import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/dispatch_application_service.dart';
import 'package:omnix_dashboard/application/radio_bridge_service.dart';
import 'package:omnix_dashboard/domain/authority/authority_token.dart';
import 'package:omnix_dashboard/domain/authority/operator_context.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_repository.dart';
import 'package:omnix_dashboard/domain/evidence/client_ledger_service.dart';
import 'package:omnix_dashboard/domain/events/dispatch_event.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/incident_closed.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';
import 'package:omnix_dashboard/domain/intelligence/risk_policy.dart';
import 'package:omnix_dashboard/domain/store/event_store.dart';
import 'package:omnix_dashboard/domain/store/in_memory_event_store.dart';
import 'package:omnix_dashboard/engine/execution/execution_engine.dart';
import 'package:omnix_dashboard/infrastructure/events/in_memory_client_ledger_repository.dart';

void main() {
  DispatchApplicationService buildServiceWithEngine(ExecutionEngine engine) {
    final store = InMemoryEventStore();
    return DispatchApplicationService(
      store: store,
      engine: engine,
      policy: const RiskPolicy(escalationThreshold: 70),
      ledgerService: ClientLedgerService(InMemoryClientLedgerRepository()),
      operator: const OperatorContext(
        operatorId: 'OP-1',
        allowedRegions: {'REGION-GAUTENG'},
        allowedSites: {'SITE-SANDTON'},
      ),
    );
  }

  DispatchApplicationService buildService() {
    return buildServiceWithEngine(ExecutionEngine());
  }

  test(
    'auto creates dispatch decision for corroborated high-risk batch',
    () async {
      final service = buildService();
      final now = DateTime.utc(2026, 3, 6, 14, 0);
      final records = [
        NormalizedIntelRecord(
          provider: 'watchtower',
          sourceType: 'news',
          externalId: 'WT-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Armed suspects seen near gate B',
          summary: 'Vehicle loitering and perimeter pressure',
          riskScore: 88,
          occurredAtUtc: now,
        ),
        NormalizedIntelRecord(
          provider: 'community-feed',
          sourceType: 'community',
          externalId: 'CF-1',
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          headline: 'Community reports armed suspects near gate B',
          summary: 'Same vehicle loitering by perimeter',
          riskScore: 72,
          occurredAtUtc: now.add(const Duration(minutes: 2)),
        ),
      ];

      final outcome = await service.ingestNormalizedIntelligence(
        records: records,
      );

      expect(outcome.appendedIntelligence, 2);
      expect(outcome.createdDecisions, 1);
      expect(outcome.advisoryCount, 0);
      expect(outcome.watchCount, 1);
      expect(outcome.dispatchCandidateCount, 1);
      expect(outcome.appendedEvents, hasLength(2));
      expect(
        service.store.allEvents().whereType<DecisionCreated>(),
        hasLength(1),
      );
    },
  );

  test('does not auto escalate isolated high-risk signal', () async {
    final service = buildService();
    final now = DateTime.utc(2026, 3, 6, 14, 30);
    final records = [
      NormalizedIntelRecord(
        provider: 'watchtower',
        sourceType: 'news',
        externalId: 'WT-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'High-risk perimeter alert',
        summary: 'Single-source signal only',
        riskScore: 90,
        occurredAtUtc: now,
      ),
    ];

    final outcome = await service.ingestNormalizedIntelligence(
      records: records,
    );

    expect(outcome.appendedIntelligence, 1);
    expect(outcome.createdDecisions, 0);
    expect(outcome.advisoryCount, 0);
    expect(outcome.watchCount, 1);
    expect(outcome.dispatchCandidateCount, 0);
    expect(outcome.appendedEvents, hasLength(1));
    expect(service.store.allEvents().whereType<DecisionCreated>(), isEmpty);
  });

  test('radio all-clear transcript closes open incident', () {
    final service = buildService();
    service.store.append(
      DecisionCreated(
        eventId: 'DEC-DSP-ZELLO-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 10, 19, 0),
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        dispatchId: 'DSP-ZELLO-1',
      ),
    );

    final outcome = service.ingestRadioTransmissions(
      transmissions: [
        RadioTransmissionRecord(
          transmissionId: 'ZEL-1001',
          provider: 'zello',
          channel: 'ops-primary',
          speakerRole: 'client',
          speakerId: 'Resident-42',
          transcript: 'Control, all clear now. Client safe.',
          occurredAtUtc: DateTime.utc(2026, 3, 10, 19, 1),
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          dispatchId: 'DSP-ZELLO-1',
        ),
      ],
    );

    expect(outcome.appended, 1);
    expect(outcome.allClearDetected, 1);
    expect(outcome.panicDetected, 0);
    expect(outcome.duressDetected, 0);
    expect(outcome.escalationDispatchesCreated, 0);
    expect(outcome.incidentsClosed, 1);
    expect(outcome.automatedResponses, hasLength(1));
    expect(outcome.automatedResponses.single.dispatchId, 'DSP-ZELLO-1');
    expect(outcome.automatedResponses.single.responseType, 'AI_ALL_CLEAR_ACK');
    expect(
      outcome.automatedResponses.single.message,
      contains('marked dispatch DSP-ZELLO-1 all clear'),
    );
    expect(
      service.store.allEvents().whereType<IncidentClosed>().single.dispatchId,
      'DSP-ZELLO-1',
    );
  });

  test('radio ingest deduplicates transmission ids', () {
    final service = buildService();
    final record = RadioTransmissionRecord(
      transmissionId: 'ZEL-1002',
      provider: 'zello',
      channel: 'ops-primary',
      speakerRole: 'client',
      speakerId: 'Resident-43',
      transcript: 'Please send update to control.',
      occurredAtUtc: DateTime.utc(2026, 3, 10, 19, 5),
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    final first = service.ingestRadioTransmissions(transmissions: [record]);
    final second = service.ingestRadioTransmissions(transmissions: [record]);

    expect(first.appended, 1);
    expect(second.appended, 0);
    expect(second.skipped, 1);
  });

  test('radio all-clear can emit automated response without auto-close', () {
    final service = buildService();
    service.store.append(
      DecisionCreated(
        eventId: 'DEC-DSP-ZELLO-2',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 10, 19, 20),
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        dispatchId: 'DSP-ZELLO-2',
      ),
    );

    final outcome = service.ingestRadioTransmissions(
      transmissions: [
        RadioTransmissionRecord(
          transmissionId: 'ZEL-1003',
          provider: 'zello',
          channel: 'ops-primary',
          speakerRole: 'client',
          speakerId: 'Resident-88',
          transcript: 'Control confirms all clear at unit two.',
          occurredAtUtc: DateTime.utc(2026, 3, 10, 19, 21),
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
        ),
      ],
      autoCloseOnAllClear: false,
    );

    expect(outcome.allClearDetected, 1);
    expect(outcome.panicDetected, 0);
    expect(outcome.duressDetected, 0);
    expect(outcome.escalationDispatchesCreated, 0);
    expect(outcome.incidentsClosed, 0);
    expect(outcome.automatedResponses, hasLength(1));
    expect(outcome.automatedResponses.single.dispatchId, 'DSP-ZELLO-2');
    expect(outcome.automatedResponses.single.responseType, 'AI_ALL_CLEAR_ACK');
    expect(
      outcome.automatedResponses.single.message,
      contains('marked dispatch DSP-ZELLO-2 all clear'),
    );
    expect(service.store.allEvents().whereType<IncidentClosed>(), isEmpty);
  });

  test(
    'radio automated response send is appended as ledger intelligence event',
    () {
      final service = buildService();

      final appended = service.recordRadioAutomatedResponses(
        responses: const [
          RadioAutomatedResponse(
            transmissionId: 'ZEL-3001',
            provider: 'zello',
            channel: 'ops-primary',
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
            dispatchId: 'DSP-ZELLO-3',
            message: 'ONYX AI marked dispatch DSP-ZELLO-3 all clear.',
            responseType: 'AI_ALL_CLEAR_ACK',
            intent: 'all_clear',
          ),
        ],
      );

      expect(appended, 1);
      final intel = service.store.allEvents().whereType<IntelligenceReceived>();
      expect(intel, hasLength(1));
      expect(intel.single.provider, 'onyx-radio');
      expect(intel.single.sourceType, 'system');
      expect(intel.single.headline, 'ONYX RADIO AI_ALL_CLEAR_ACK');
      expect(intel.single.summary, contains('DSP-ZELLO-3'));
      expect(intel.single.summary, contains('intent:ALL_CLEAR'));
      expect(intel.single.summary, contains('channel:ops-primary'));
    },
  );

  test(
    'radio panic and duress signals create escalation dispatch decisions',
    () {
      final service = buildService();

      final outcome = service.ingestRadioTransmissions(
        transmissions: [
          RadioTransmissionRecord(
            transmissionId: 'ZEL-5001',
            provider: 'zello',
            channel: 'ops-primary',
            speakerRole: 'guard',
            speakerId: 'Echo-3',
            transcript: 'Panic button triggered, need backup now!',
            occurredAtUtc: DateTime.utc(2026, 3, 10, 19, 30),
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
          RadioTransmissionRecord(
            transmissionId: 'ZEL-5002',
            provider: 'zello',
            channel: 'ops-primary',
            speakerRole: 'client',
            speakerId: 'Resident-12',
            transcript: 'Silent duress at gate six. Unsafe code spoken.',
            occurredAtUtc: DateTime.utc(2026, 3, 10, 19, 31),
            clientId: 'CLIENT-001',
            regionId: 'REGION-GAUTENG',
            siteId: 'SITE-SANDTON',
          ),
        ],
      );

      expect(outcome.allClearDetected, 0);
      expect(outcome.panicDetected, 1);
      expect(outcome.duressDetected, 1);
      expect(outcome.escalationDispatchesCreated, 2);
      expect(outcome.incidentsClosed, 0);
      expect(outcome.automatedResponses, hasLength(2));
      expect(
        outcome.automatedResponses.map((entry) => entry.responseType),
        containsAll(const ['AI_PANIC_ACK', 'AI_DURESS_ACK']),
      );
      expect(
        service.store.allEvents().whereType<DecisionCreated>(),
        hasLength(2),
      );
    },
  );

  test(
    'ingestNormalizedIntelligence awaits ledger seal before returning',
    () async {
      final ledger = _RecordingLedgerService(
        intelligenceSealCompleter: Completer<void>(),
      );
      final service = DispatchApplicationService(
        store: InMemoryEventStore(),
        engine: ExecutionEngine(),
        policy: const RiskPolicy(escalationThreshold: 70),
        ledgerService: ledger,
        operator: const OperatorContext(
          operatorId: 'OP-1',
          allowedRegions: {'REGION-GAUTENG'},
          allowedSites: {'SITE-SANDTON'},
        ),
      );

      var completed = false;
      final future = service
          .ingestNormalizedIntelligence(
            records: [
              NormalizedIntelRecord(
                provider: 'watchtower',
                sourceType: 'news',
                externalId: 'WT-LEDGER-1',
                clientId: 'CLIENT-001',
                regionId: 'REGION-GAUTENG',
                siteId: 'SITE-SANDTON',
                headline: 'Await ledger seal',
                summary: 'Return only after ledger batch finishes',
                riskScore: 45,
                occurredAtUtc: DateTime.utc(2026, 3, 11, 10, 0),
              ),
            ],
            autoGenerateDispatches: false,
            verifyReplay: false,
          )
          .then((value) {
            completed = true;
            return value;
          });

      await Future<void>.delayed(Duration.zero);
      expect(ledger.sealedIntelligenceEvents, hasLength(1));
      expect(completed, isFalse);

      ledger.intelligenceSealCompleter!.complete();
      final outcome = await future;

      expect(completed, isTrue);
      expect(outcome.appendedIntelligence, 1);
    },
  );

  test('execute seals dispatch before appending execution completed', () async {
    final store = InMemoryEventStore();
    final ledger = _RecordingLedgerService();
    final service = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: const RiskPolicy(escalationThreshold: 70),
      ledgerService: ledger,
      operator: const OperatorContext(
        operatorId: 'OP-1',
        allowedRegions: {'REGION-GAUTENG'},
        allowedSites: {'SITE-SANDTON'},
      ),
    );

    store.append(
      DecisionCreated(
        eventId: 'DEC-ORDER-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 11, 11, 0),
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        dispatchId: 'DSP-ORDER-1',
      ),
    );

    await service.execute(
      dispatchId: 'DSP-ORDER-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(ledger.lastDispatchEvents, isNotNull);
    expect(ledger.lastDispatchEvents!.whereType<ExecutionCompleted>(), isEmpty);
    expect(store.allEvents().whereType<ExecutionCompleted>(), hasLength(1));
  });

  test('execute assigns monotonic per-dispatch sequences', () async {
    final store = _RawEventStore(
      seedEvents: [
        DecisionCreated(
          eventId: 'DEC-SEQ-1',
          sequence: 4,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 11, 12, 0),
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          dispatchId: 'DSP-SEQ-1',
        ),
        DecisionCreated(
          eventId: 'DEC-OTHER-99',
          sequence: 99,
          version: 1,
          occurredAt: DateTime.utc(2026, 3, 11, 12, 1),
          clientId: 'CLIENT-001',
          regionId: 'REGION-GAUTENG',
          siteId: 'SITE-SANDTON',
          dispatchId: 'DSP-OTHER-99',
        ),
      ],
    );
    final service = DispatchApplicationService(
      store: store,
      engine: ExecutionEngine(),
      policy: const RiskPolicy(escalationThreshold: 70),
      ledgerService: _RecordingLedgerService(),
      operator: const OperatorContext(
        operatorId: 'OP-1',
        allowedRegions: {'REGION-GAUTENG'},
        allowedSites: {'SITE-SANDTON'},
      ),
    );

    await service.execute(
      dispatchId: 'DSP-SEQ-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    final execution = store.allEvents().whereType<ExecutionCompleted>().single;
    expect(execution.sequence, 5);
  });

  test('dispatch ids keep the full provider string and stable uuid suffix', () {
    final service = buildService();
    final alpha = _intelligence(
      provider: 'watchtower-alpha',
      externalId: 'evt-001',
      intelligenceId: 'INTEL-ALPHA',
    );
    final beta = _intelligence(
      provider: 'watchtower-beta',
      externalId: 'evt-001',
      intelligenceId: 'INTEL-BETA',
    );

    expect(service.escalateIntelligence(alpha, verifyReplay: false), isTrue);
    expect(service.escalateIntelligence(alpha, verifyReplay: false), isFalse);
    expect(service.escalateIntelligence(beta, verifyReplay: false), isTrue);

    final decisions = service.store
        .allEvents()
        .whereType<DecisionCreated>()
        .toList();
    expect(decisions, hasLength(2));
    expect(
      decisions[0].dispatchId,
      matches(
        RegExp(
          r'^DSP-WATCHTOWERALPHA-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      decisions[1].dispatchId,
      matches(
        RegExp(
          r'^DSP-WATCHTOWERBETA-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(decisions[0].dispatchId, isNot(decisions[1].dispatchId));
  });

  test('dispatch execution uses UTC authority timestamps', () async {
    final engine = _RecordingExecutionEngine();
    final service = buildServiceWithEngine(engine);
    service.store.append(
      DecisionCreated(
        eventId: 'DEC-UTC-1',
        sequence: 0,
        version: 1,
        occurredAt: DateTime.utc(2026, 3, 10, 19, 0),
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        dispatchId: 'DSP-UTC-1',
      ),
    );

    await service.execute(
      dispatchId: 'DSP-UTC-1',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-SANDTON',
    );

    expect(engine.lastAuthority, isNotNull);
    expect(engine.lastAuthority!.timestamp.isUtc, isTrue);
  });
}

IntelligenceReceived _intelligence({
  required String provider,
  required String externalId,
  required String intelligenceId,
}) {
  return IntelligenceReceived(
    eventId: 'INT-$intelligenceId',
    sequence: 0,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 11, 13, 0),
    intelligenceId: intelligenceId,
    provider: provider,
    sourceType: 'hardware',
    externalId: externalId,
    clientId: 'CLIENT-001',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-SANDTON',
    headline: 'Provider dispatch collision probe',
    summary: 'Used to verify dispatch ids remain stable and distinct.',
    riskScore: 88,
    canonicalHash: 'canon-$intelligenceId',
  );
}

class _RecordingExecutionEngine extends ExecutionEngine {
  AuthorityToken? lastAuthority;

  @override
  bool execute(String dispatchId, {required AuthorityToken authority}) {
    lastAuthority = authority;
    return super.execute(dispatchId, authority: authority);
  }
}

class _RecordingLedgerService extends ClientLedgerService {
  final Completer<void>? intelligenceSealCompleter;
  List<IntelligenceReceived>? sealedIntelligenceEvents;
  List<DispatchEvent>? lastDispatchEvents;

  _RecordingLedgerService({this.intelligenceSealCompleter})
    : super(InMemoryClientLedgerRepository());

  @override
  Future<void> sealIntelligenceBatch({
    required Iterable<IntelligenceReceived> events,
  }) async {
    sealedIntelligenceEvents = List<IntelligenceReceived>.from(events);
    if (intelligenceSealCompleter != null) {
      await intelligenceSealCompleter!.future;
    }
  }

  @override
  Future<ClientLedgerRow?> sealDispatch({
    required String clientId,
    required String dispatchId,
    required List<DispatchEvent> events,
  }) async {
    lastDispatchEvents = List<DispatchEvent>.from(events);
    return null;
  }
}

class _RawEventStore implements EventStore {
  final List<DispatchEvent> _events;
  final Set<String> _eventIds;

  _RawEventStore({List<DispatchEvent> seedEvents = const []})
    : _events = List<DispatchEvent>.from(seedEvents),
      _eventIds = seedEvents.map((event) => event.eventId).toSet();

  @override
  void append(DispatchEvent event) {
    if (_eventIds.contains(event.eventId)) {
      throw StateError('Duplicate eventId detected: ${event.eventId}');
    }
    _events.add(event);
    _eventIds.add(event.eventId);
  }

  @override
  List<DispatchEvent> allEvents() {
    return List<DispatchEvent>.unmodifiable(_events);
  }

  @override
  Stream<List<DispatchEvent>> watchAllEvents() {
    return Stream<List<DispatchEvent>>.value(allEvents());
  }
}
