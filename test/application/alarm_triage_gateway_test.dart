import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omnix_dashboard/application/alarm_account_registry.dart';
import 'package:omnix_dashboard/application/alarm_triage_gateway.dart';
import 'package:omnix_dashboard/domain/alarms/contact_id_event.dart';
import 'package:omnix_dashboard/domain/authority/onyx_command_brain_contract.dart';
import 'package:omnix_dashboard/domain/authority/onyx_task_protocol.dart';
import 'package:omnix_dashboard/infrastructure/alarm/contact_id_receiver_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('AlarmTriageGateway produces an OnyxWorkItem with the expected fields', () async {
    final receiver = _FakeContactIdReceiverService();
    final registry = _FakeAlarmAccountRegistry(
      binding: const AlarmAccountBinding(
        accountNumber: '1234',
        clientId: 'CLIENT-A',
        siteId: 'SITE-A',
      ),
    );
    AlarmTriageRecord? triagedRecord;
    final gateway = AlarmTriageGateway(
      receiver: receiver,
      accountRegistry: registry,
      decisionBuilder: _fakeDecision,
      onTriaged: (record) {
        triagedRecord = record;
      },
    );
    await gateway.start();
    addTearDown(gateway.dispose);

    receiver.emit(
      _frame(payloadData: '123418113001003'),
    );

    await _waitFor(() => triagedRecord != null);

    expect(triagedRecord!.workItem, isNotNull);
    expect(triagedRecord!.workItem!.clientId, 'CLIENT-A');
    expect(triagedRecord!.workItem!.siteId, 'SITE-A');
    expect(triagedRecord!.workItem!.sourceRouteLabel, 'SIA DC-09 / Contact ID');
    expect(triagedRecord!.workItem!.hasHumanSafetySignal, isFalse);
  });

  test('AlarmTriageGateway suppresses duplicate frames from triage', () async {
    final receiver = _FakeContactIdReceiverService();
    final gateway = AlarmTriageGateway(
      receiver: receiver,
      accountRegistry: _FakeAlarmAccountRegistry(),
      decisionBuilder: _fakeDecision,
    );
    await gateway.start();
    addTearDown(gateway.dispose);

    final records = <AlarmTriageRecord>[];
    final subscription = gateway.records.listen(records.add);
    addTearDown(subscription.cancel);

    receiver.emit(
      _frame(
        payloadData: '123418113001003',
        isDuplicate: true,
      ),
    );

    await _waitFor(() => records.isNotEmpty);

    expect(records.single.disposition, AlarmTriageDisposition.duplicate);
    expect(records.single.workItem, isNull);
  });

  test('AlarmTriageGateway routes restores to onRestore instead of triage', () async {
    final receiver = _FakeContactIdReceiverService();
    ContactIdEvent? restoredEvent;
    final gateway = AlarmTriageGateway(
      receiver: receiver,
      accountRegistry: _FakeAlarmAccountRegistry(),
      decisionBuilder: _fakeDecision,
      onRestore: (event) {
        restoredEvent = event;
      },
    );
    await gateway.start();
    addTearDown(gateway.dispose);

    receiver.emit(
      _frame(payloadData: '123418313001003'),
    );

    await _waitFor(() => restoredEvent != null);

    expect(restoredEvent, isNotNull);
    expect(restoredEvent!.isRestore, isTrue);
  });

  test('AlarmTriageGateway uses fallback scope ids for unknown accounts', () async {
    final receiver = _FakeContactIdReceiverService();
    AlarmTriageRecord? triagedRecord;
    final gateway = AlarmTriageGateway(
      receiver: receiver,
      accountRegistry: _FakeAlarmAccountRegistry(binding: null),
      decisionBuilder: _fakeDecision,
      onTriaged: (record) {
        triagedRecord = record;
      },
    );
    await gateway.start();
    addTearDown(gateway.dispose);

    receiver.emit(_frame(payloadData: '123418113001003'));

    await _waitFor(() => triagedRecord != null);

    expect(triagedRecord!.workItem!.clientId, 'unknown_account_1234');
    expect(triagedRecord!.workItem!.siteId, 'unknown_site_1234');
  });

  test('AlarmTriageGateway logs test signals without dispatching them', () async {
    final receiver = _FakeContactIdReceiverService();
    final audited = <ContactIdEvent>[];
    final records = <AlarmTriageRecord>[];
    final gateway = AlarmTriageGateway(
      receiver: receiver,
      accountRegistry: _FakeAlarmAccountRegistry(),
      decisionBuilder: _fakeDecision,
      onAuditEvent: audited.add,
    );
    await gateway.start();
    addTearDown(gateway.dispose);

    final subscription = gateway.records.listen(records.add);
    addTearDown(subscription.cancel);

    receiver.emit(_frame(payloadData: '123418660100000'));

    await _waitFor(() => records.isNotEmpty);

    expect(audited.single.isTest, isTrue);
    expect(records.single.disposition, AlarmTriageDisposition.testSignal);
    expect(records.single.workItem, isNull);
  });
}

BrainDecision _fakeDecision(OnyxWorkItem item) {
  return BrainDecision(
    workItemId: item.id,
    mode: BrainDecisionMode.deterministic,
    target: OnyxToolTarget.dispatchBoard,
    nextMoveLabel: 'OPEN DISPATCH BOARD',
    headline: 'Dispatch Board is the next move',
    detail: 'Controller should review the alarm.',
    summary: 'One next move is staged from Contact ID triage.',
    evidenceHeadline: 'Alarm triage work item staged.',
    evidenceDetail: 'The Contact ID gateway built a triage work item.',
  );
}

ContactIdFrame _frame({
  required String payloadData,
  bool isDuplicate = false,
}) {
  return ContactIdFrame(
    accountNumber: '1234',
    receiverNumber: '0001',
    sequenceNumber: 42,
    isEncrypted: false,
    isDuplicate: isDuplicate,
    payloadData: payloadData,
    receivedAtUtc: DateTime.utc(2026, 4, 7, 12),
    rawFrame: '00011234/002A($payloadData)ABCD\r\n',
  );
}

class _FakeContactIdReceiverService extends ContactIdReceiverService {
  final StreamController<ContactIdFrame> _controller =
      StreamController<ContactIdFrame>.broadcast();
  final List<ContactIdFrame> emittedRecords = <ContactIdFrame>[];

  _FakeContactIdReceiverService()
    : super(
        bindAddress: '127.0.0.1',
        port: 0,
        aesKey: Uint8List(16),
      );

  @override
  Stream<ContactIdFrame> get frames => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    await _controller.close();
  }

  void emit(ContactIdFrame frame) {
    emittedRecords.add(frame);
    _controller.add(frame);
  }
}

class _FakeAlarmAccountRegistry extends AlarmAccountRegistry {
  final AlarmAccountBinding? binding;

  _FakeAlarmAccountRegistry({this.binding})
    : super(client: _buildSupabaseClient());

  @override
  Future<AlarmAccountBinding?> resolve(String accountNumber) async {
    return binding;
  }
}

SupabaseClient _buildSupabaseClient() {
  return SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    accessToken: () async => null,
    httpClient: MockClient((_) async => http.Response('[]', 200)),
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
