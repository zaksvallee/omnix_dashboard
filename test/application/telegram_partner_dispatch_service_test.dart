import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_partner_dispatch_service.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/execution_completed.dart';
import 'package:omnix_dashboard/domain/events/partner_dispatch_status_declared.dart';
import 'package:omnix_dashboard/domain/events/response_arrived.dart';

void main() {
  const service = TelegramPartnerDispatchService();
  final context = TelegramPartnerDispatchContext(
    messageKey: 'tg-partner-dispatch-client-a-site-a-1',
    dispatchId: 'DSP-1001',
    clientId: 'CLIENT-A',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-A',
    siteName: 'MS Vallee Residence',
    incidentSummary: 'Vehicle and perimeter breach escalation.',
    partnerLabel: 'Partner Response',
    occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 0),
  );

  test('parses partner action replies and synonyms', () {
    expect(
      service.parseActionText('ACCEPT'),
      TelegramPartnerDispatchAction.accept,
    );
    expect(
      service.parseActionText('on scene'),
      TelegramPartnerDispatchAction.onSite,
    );
    expect(
      service.parseActionText('client safe'),
      TelegramPartnerDispatchAction.allClear,
    );
    expect(
      service.parseActionText('abort'),
      TelegramPartnerDispatchAction.cancel,
    );
    expect(service.parseActionText('maybe later'), isNull);
  });

  test('builds a partner dispatch message with explicit reply contract', () {
    final text = service.buildDispatchMessage(context);

    expect(text, contains('ONYX PARTNER DISPATCH'));
    expect(text, contains('incident=DSP-1001'));
    expect(text, contains('message_key=tg-partner-dispatch-client-a-site-a-1'));
    expect(
      text,
      contains('Reply with: ACCEPT, ON SITE, ALL CLEAR, or CANCEL.'),
    );
  });

  test(
    'accept resolves for an open dispatch and emits declared status event',
    () {
      final resolution = service.resolveReply(
        action: TelegramPartnerDispatchAction.accept,
        context: context,
        actorLabel: '@partner_unit_1',
        occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 2),
        events: [_decision()],
      );

      expect(resolution, isNotNull);
      expect(resolution!.event.status, PartnerDispatchStatus.accepted);
      expect(resolution.event.actorLabel, '@partner_unit_1');
      expect(resolution.clientStatusLabel, 'Partner Accepted');
    },
  );

  test('on site requires prior accept or verified arrival', () {
    expect(
      service.resolveReply(
        action: TelegramPartnerDispatchAction.onSite,
        context: context,
        actorLabel: '@partner_unit_1',
        occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 3),
        events: [_decision()],
      ),
      isNull,
    );

    final accepted = PartnerDispatchStatusDeclared(
      eventId: 'PARTNER-ACCEPTED-1',
      sequence: 2,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 15, 20, 1),
      dispatchId: 'DSP-1001',
      clientId: 'CLIENT-A',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-A',
      partnerLabel: 'Partner Response',
      actorLabel: '@partner_unit_1',
      status: PartnerDispatchStatus.accepted,
      sourceChannel: 'telegram',
      sourceMessageKey: context.messageKey,
    );

    final declared = service.resolveReply(
      action: TelegramPartnerDispatchAction.onSite,
      context: context,
      actorLabel: '@partner_unit_1',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 4),
      events: [_decision(), accepted],
    );
    expect(declared, isNotNull);
    expect(declared!.event.status, PartnerDispatchStatus.onSite);

    final verified = service.resolveReply(
      action: TelegramPartnerDispatchAction.onSite,
      context: context,
      actorLabel: '@partner_unit_1',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 4),
      events: [_decision(), _arrived()],
    );
    expect(verified, isNotNull);
  });

  test('all clear requires on-site state and allows post-execution updates', () {
    expect(
      service.resolveReply(
        action: TelegramPartnerDispatchAction.allClear,
        context: context,
        actorLabel: '@partner_unit_1',
        occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 6),
        events: [_decision()],
      ),
      isNull,
    );

    final onSite = PartnerDispatchStatusDeclared(
      eventId: 'PARTNER-ON-SITE-1',
      sequence: 2,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 15, 20, 5),
      dispatchId: 'DSP-1001',
      clientId: 'CLIENT-A',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-A',
      partnerLabel: 'Partner Response',
      actorLabel: '@partner_unit_1',
      status: PartnerDispatchStatus.onSite,
      sourceChannel: 'telegram',
      sourceMessageKey: context.messageKey,
    );
    final allClear = service.resolveReply(
      action: TelegramPartnerDispatchAction.allClear,
      context: context,
      actorLabel: '@partner_unit_1',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 8),
      events: [_decision(), onSite],
    );
    expect(allClear, isNotNull);
    expect(allClear!.event.status, PartnerDispatchStatus.allClear);

    final acceptedAfterExecution = service.resolveReply(
      action: TelegramPartnerDispatchAction.accept,
      context: context,
      actorLabel: '@partner_unit_1',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 8),
      events: [_decision(), _completed()],
    );
    expect(acceptedAfterExecution, isNotNull);
    expect(
      acceptedAfterExecution!.event.status,
      PartnerDispatchStatus.accepted,
    );
  });

  test('duplicate accept is rejected after prior acceptance', () {
    final accepted = PartnerDispatchStatusDeclared(
      eventId: 'PARTNER-ACCEPTED-1',
      sequence: 2,
      version: 1,
      occurredAt: DateTime.utc(2026, 3, 15, 20, 1),
      dispatchId: 'DSP-1001',
      clientId: 'CLIENT-A',
      regionId: 'REGION-GAUTENG',
      siteId: 'SITE-A',
      partnerLabel: 'Partner Response',
      actorLabel: '@partner_unit_1',
      status: PartnerDispatchStatus.accepted,
      sourceChannel: 'telegram',
      sourceMessageKey: context.messageKey,
    );

    final duplicate = service.resolveReply(
      action: TelegramPartnerDispatchAction.accept,
      context: context,
      actorLabel: '@partner_unit_2',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 20, 2),
      events: [_decision(), accepted],
    );

    expect(duplicate, isNull);
  });
}

DecisionCreated _decision() {
  return DecisionCreated(
    eventId: 'DEC-1',
    sequence: 1,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 15, 20, 0),
    clientId: 'CLIENT-A',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-A',
    dispatchId: 'DSP-1001',
  );
}

ResponseArrived _arrived() {
  return ResponseArrived(
    eventId: 'ARR-1',
    sequence: 2,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 15, 20, 3),
    dispatchId: 'DSP-1001',
    guardId: 'RO-441',
    clientId: 'CLIENT-A',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-A',
  );
}

ExecutionCompleted _completed() {
  return ExecutionCompleted(
    eventId: 'EXE-1',
    sequence: 3,
    version: 1,
    occurredAt: DateTime.utc(2026, 3, 15, 20, 10),
    dispatchId: 'DSP-1001',
    clientId: 'CLIENT-A',
    regionId: 'REGION-GAUTENG',
    siteId: 'SITE-A',
    success: true,
  );
}
