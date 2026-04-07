import 'dart:async';

import '../domain/alarms/contact_id_event.dart';
import '../domain/alarms/contact_id_event_mapper.dart';
import '../domain/authority/onyx_command_brain_contract.dart';
import '../domain/authority/onyx_task_protocol.dart';
import '../domain/incidents/incident_enums.dart';
import '../infrastructure/alarm/contact_id_payload_parser.dart';
import '../infrastructure/alarm/contact_id_receiver_service.dart';
import 'alarm_account_registry.dart';
import 'onyx_command_brain_orchestrator.dart';

enum AlarmTriageDisposition { triaged, restore, duplicate, testSignal }

class AlarmTriageRecord {
  final AlarmTriageDisposition disposition;
  final ContactIdEvent event;
  final AlarmAccountBinding? binding;
  final OnyxWorkItem? workItem;
  final BrainDecision? decision;

  const AlarmTriageRecord({
    required this.disposition,
    required this.event,
    this.binding,
    this.workItem,
    this.decision,
  });
}

class AlarmTriageGateway {
  final ContactIdReceiverService receiver;
  final AlarmAccountRegistry accountRegistry;
  final ContactIdPayloadParser payloadParser;
  final ContactIdEventMapper mapper;
  final OnyxCommandBrainOrchestrator orchestrator;
  final FutureOr<void> Function(ContactIdEvent event)? onAuditEvent;
  final FutureOr<void> Function(ContactIdEvent event)? onRestore;
  final FutureOr<void> Function(AlarmTriageRecord record)? onTriaged;
  final BrainDecision Function(OnyxWorkItem item)? decisionBuilder;

  StreamSubscription<ContactIdFrame>? _subscription;
  final StreamController<AlarmTriageRecord> _recordsController =
      StreamController<AlarmTriageRecord>.broadcast();

  AlarmTriageGateway({
    required this.receiver,
    required this.accountRegistry,
    this.payloadParser = const ContactIdPayloadParser(),
    ContactIdEventMapper? mapper,
    this.orchestrator = const OnyxCommandBrainOrchestrator(),
    this.onAuditEvent,
    this.onRestore,
    this.onTriaged,
    this.decisionBuilder,
  }) : mapper = mapper ?? ContactIdEventMapper();

  Stream<AlarmTriageRecord> get records => _recordsController.stream;

  Future<void> start() async {
    if (_subscription != null) {
      return;
    }
    await receiver.start();
    _subscription = receiver.frames.listen(
      (frame) {
        unawaited(_handleFrame(frame));
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await receiver.stop();
    await _recordsController.close();
  }

  Future<void> _handleFrame(ContactIdFrame frame) async {
    ContactIdPayload payload;
    try {
      payload = payloadParser.parse(frame.payloadData);
    } on ContactIdParseException {
      return;
    }
    final binding = await accountRegistry.resolve(frame.accountNumber);
    final event = mapper.map(frame: frame, payload: payload);
    await onAuditEvent?.call(event);

    if (event.isTest) {
      final record = AlarmTriageRecord(
        disposition: AlarmTriageDisposition.testSignal,
        event: event,
        binding: binding,
      );
      _recordsController.add(record);
      return;
    }

    if (frame.isDuplicate) {
      final record = AlarmTriageRecord(
        disposition: AlarmTriageDisposition.duplicate,
        event: event,
        binding: binding,
      );
      _recordsController.add(record);
      return;
    }

    if (event.isRestore) {
      final record = AlarmTriageRecord(
        disposition: AlarmTriageDisposition.restore,
        event: event,
        binding: binding,
      );
      _recordsController.add(record);
      await onRestore?.call(event);
      return;
    }

    final workItem = _buildWorkItem(event, binding: binding);
    final decision =
        decisionBuilder?.call(workItem) ??
        orchestrator.decide(item: workItem);
    final record = AlarmTriageRecord(
      disposition: AlarmTriageDisposition.triaged,
      event: event,
      binding: binding,
      workItem: workItem,
      decision: decision,
    );
    _recordsController.add(record);
    await onTriaged?.call(record);
  }

  OnyxWorkItem _buildWorkItem(
    ContactIdEvent event, {
    AlarmAccountBinding? binding,
  }) {
    final clientId = binding?.clientId.trim().isNotEmpty == true
        ? binding!.clientId
        : 'unknown_account_${event.accountNumber}';
    final siteId = binding?.siteId.trim().isNotEmpty == true
        ? binding!.siteId
        : 'unknown_site_${event.accountNumber}';
    final zone = event.payload.zone.toString().padLeft(2, '0');
    final partition = event.payload.partition.toString().padLeft(2, '0');
    final severity = event.severity.name.toUpperCase();
    final prompt =
        '${event.description}\n'
        'Panel: ${event.accountNumber} | Severity: $severity | Received: ${event.receivedAtUtc.toIso8601String()}\n'
        'SIA DC-09 Contact ID event. Operator action required.';
    return OnyxWorkItem(
      id: 'contact-id-${event.eventId}',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt,
      clientId: clientId,
      siteId: siteId,
      incidentReference: event.eventId,
      sourceRouteLabel: 'SIA DC-09 / Contact ID',
      createdAt: event.receivedAtUtc,
      contextSummary:
          'Panel: ${event.accountNumber} | Zone: $zone | Partition: $partition',
      hasHumanSafetySignal: event.severity == IncidentSeverity.critical,
      latestEventLabel: event.description,
      latestEventAt: event.receivedAtUtc,
    );
  }
}
