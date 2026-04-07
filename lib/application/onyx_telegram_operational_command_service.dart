import 'client_camera_health_fact_packet_service.dart';
import 'telegram_client_prompt_signals.dart';
import '../domain/authority/onyx_authority_scope.dart';
import '../domain/authority/onyx_command_intent.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/patrol_completed.dart';
import 'onyx_telegram_command_gateway.dart';

DateTime _systemNow() => DateTime.now();

class OnyxTelegramOperationalCommandResponse {
  final bool handled;
  final bool allowed;
  final OnyxCommandIntent intent;
  final String text;

  const OnyxTelegramOperationalCommandResponse({
    required this.handled,
    required this.allowed,
    required this.intent,
    required this.text,
  });
}

class OnyxTelegramOperationalCommandService {
  final OnyxTelegramCommandGateway gateway;
  final DateTime Function() now;

  const OnyxTelegramOperationalCommandService({
    this.gateway = const OnyxTelegramCommandGateway(),
    this.now = _systemNow,
  });

  OnyxTelegramOperationalCommandResponse handle({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final routed = gateway.route(request: request);
    if (!routed.allowed) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: false,
        intent: routed.parsedCommand.intent,
        text: routed.decisionMessage,
      );
    }

    final conversational = _clientConversationalResponse(
      request: request,
      events: events,
      intent: routed.parsedCommand.intent,
      cameraHealthFactPacket: cameraHealthFactPacket,
    );
    if (conversational != null) {
      return conversational;
    }

    return switch (routed.parsedCommand.intent) {
      OnyxCommandIntent.guardStatusLookup => _guardStatusResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.patrolReportLookup => _patrolReportResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.showUnresolvedIncidents => _unresolvedIncidentsResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.showDispatchesToday => _todayDispatchesResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.showIncidentsLastNight => _lastNightIncidentsResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.showSiteMostAlertsThisWeek => _siteAlertLeaderResponse(
        request: request,
        events: events,
      ),
      OnyxCommandIntent.summarizeIncident => _incidentClarificationResponse(
        request: request,
        events: events,
        cameraHealthFactPacket: cameraHealthFactPacket,
      ),
      _ => OnyxTelegramOperationalCommandResponse(
        handled: false,
        allowed: true,
        intent: routed.parsedCommand.intent,
        text:
            'ONYX understood the request, but this Telegram command is not wired yet. Use Command or Junior Analyst for that step.',
      ),
    };
  }

  OnyxTelegramOperationalCommandResponse? _clientConversationalResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    required OnyxCommandIntent intent,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    if (request.role != OnyxAuthorityRole.client) {
      return null;
    }

    final conversationalIntent = _resolveConversationalIntent(
      prompt: request.prompt,
      parsedIntent: intent,
    );
    if (conversationalIntent == null) {
      return null;
    }

    return switch (conversationalIntent) {
      _ConversationalOperationalIntent.statusReassurance =>
        _statusReassuranceResponse(
          request: request,
          events: events,
          cameraHealthFactPacket: cameraHealthFactPacket,
        ),
      _ConversationalOperationalIntent.actionRequest => _actionRequestResponse(
        request: request,
        events: events,
        cameraHealthFactPacket: cameraHealthFactPacket,
      ),
      _ConversationalOperationalIntent.verification => _verificationResponse(
        request: request,
        events: events,
        cameraHealthFactPacket: cameraHealthFactPacket,
      ),
      _ConversationalOperationalIntent.observationConcern =>
        _observationConcernResponse(
          request: request,
          events: events,
          cameraHealthFactPacket: cameraHealthFactPacket,
        ),
      _ConversationalOperationalIntent.incidentClarification =>
        _incidentClarificationResponse(
          request: request,
          events: events,
          cameraHealthFactPacket: cameraHealthFactPacket,
        ),
    };
  }

  OnyxTelegramOperationalCommandResponse _guardStatusResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final patrols = _eventsForRequest<PatrolCompleted>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (patrols.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.guardStatusLookup,
        text:
            'No scoped guard signal is attached yet in ${_scopeLabelForRequest(request)}.',
      );
    }
    final patrol = _matchPatrolForPrompt(request.prompt, patrols);
    if (patrol == null) {
      final latestByGuard = <String, PatrolCompleted>{};
      for (final entry in patrols) {
        latestByGuard.putIfAbsent(entry.guardId.trim(), () => entry);
      }
      final summaryRows = latestByGuard.values
          .take(3)
          .map((entry) {
            final durationMinutes = entry.durationSeconds ~/ 60;
            return '• ${entry.guardId} • ${_hhmm(entry.occurredAt.toLocal())} • ${_humanizeScopeLabel(entry.routeId)} • $durationMinutes min';
          })
          .join('\n');
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.guardStatusLookup,
        text:
            'Latest guard status in ${_scopeLabelForRequest(request)}:\n$summaryRows',
      );
    }
    final durationMinutes = patrol.durationSeconds ~/ 60;
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.guardStatusLookup,
      text:
          'Latest guard status for ${patrol.guardId} in ${_scopeLabelForRequest(request)}:\n'
          '• Last patrol ${_hhmm(patrol.occurredAt.toLocal())}\n'
          '• Route ${_humanizeScopeLabel(patrol.routeId)}\n'
          '• Duration $durationMinutes min',
    );
  }

  OnyxTelegramOperationalCommandResponse _patrolReportResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final patrols = _eventsForRequest<PatrolCompleted>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (patrols.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.patrolReportLookup,
        text:
            'No patrol report is attached yet in ${_scopeLabelForRequest(request)}.',
      );
    }
    final patrol = _resolvePatrolForPrompt(request.prompt, patrols);
    final durationMinutes = patrol.durationSeconds ~/ 60;
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.patrolReportLookup,
      text:
          'Last patrol report for ${patrol.guardId} in ${_scopeLabelForRequest(request)}:\n'
          '• Completed ${_hhmm(patrol.occurredAt.toLocal())}\n'
          '• Route ${_humanizeScopeLabel(patrol.routeId)}\n'
          '• Duration $durationMinutes min',
    );
  }

  OnyxTelegramOperationalCommandResponse _unresolvedIncidentsResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final decisions = _eventsForRequest<DecisionCreated>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final closedDispatchIds = _eventsForRequest<IncidentClosed>(
      events: events,
      request: request,
    ).map((event) => event.dispatchId.trim()).toSet();
    final unresolved = decisions
        .where((event) => !closedDispatchIds.contains(event.dispatchId.trim()))
        .toList(growable: false);
    final scopeLabel = _scopeLabelForRequest(request);
    if (unresolved.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.showUnresolvedIncidents,
        text: 'No unresolved incidents in $scopeLabel.',
      );
    }
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.showUnresolvedIncidents,
      text:
          'Unresolved incidents in $scopeLabel:\n${unresolved.take(3).map((event) => '• ${_incidentIdForDispatch(event.dispatchId)} • ${_hhmm(event.occurredAt.toLocal())}').join('\n')}',
    );
  }

  OnyxTelegramOperationalCommandResponse _statusReassuranceResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final truth = _truthSnapshotForRequest(request: request, events: events);
    final scopeLabel = _scopeLabelForRequest(request);
    final normalizedPrompt = _normalizedNaturalPrompt(request.prompt);
    final visualLine = _statusVisualQualificationForCurrentReply(
      request: request,
      siteReference: scopeLabel,
      cameraHealthFactPacket: cameraHealthFactPacket,
    );
    final movementStatusAsk = asksForTelegramClientMovementCheck(
      normalizedPrompt,
    );
    if (_isDirectSafetyAsk(normalizedPrompt) &&
        cameraHealthFactPacket != null &&
        cameraHealthFactPacket.status == ClientCameraHealthStatus.live) {
      if (_recentThreadShowsCameraDown(request)) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'Not confirmed yet. $visualLine I do not want to overstate the site status from partial camera coverage alone.',
        );
      }
      if (_recentThreadShowsUnusableCurrentImage(request)) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'Not confirmed yet. $visualLine I do not want to overstate the site status from that alone.',
        );
      }
    }

    if (movementStatusAsk) {
      if (truth.unresolvedDecisions.isNotEmpty) {
        final latestDecision = truth.unresolvedDecisions.first;
        final relevantIntel =
            _bestIntelForDecision(
              decision: latestDecision,
              intelligence: truth.intelligence,
            ) ??
            truth.latestIntelligence;
        final movementLead = relevantIntel == null
            ? null
            : _movementStatusLead(relevantIntel);
        final eventLine = movementLead == null
            ? relevantIntel == null
                  ? 'There is already an active operational review on site.'
                  : 'The latest confirmed signal was ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}. I do not have a newer confirmed movement signal than that right now.'
            : 'The latest confirmed movement signal was $movementLead at ${_hhmm(relevantIntel!.occurredAt.toLocal())}.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'There is active operational review at $scopeLabel right now. $eventLine Response is already in motion. $visualLine',
        );
      }

      if (truth.latestIntelligence != null) {
        final latestIntel = truth.latestIntelligence!;
        final movementLead = _movementStatusLead(latestIntel);
        if (movementLead != null) {
          return OnyxTelegramOperationalCommandResponse(
            handled: true,
            allowed: true,
            intent: OnyxCommandIntent.triageNextMove,
            text:
                'The latest verified movement on site was $movementLead at ${_hhmm(latestIntel.occurredAt.toLocal())}. It is not sitting as an open incident at the moment. $visualLine',
          );
        }
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'I do not have a confirmed movement signal at $scopeLabel right now. The latest logged signal was ${_intelligenceLead(latestIntel)} at ${_hhmm(latestIntel.occurredAt.toLocal())}. It is not an active incident now. $visualLine',
        );
      }

      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I do not have a confirmed movement signal at $scopeLabel right now. $visualLine',
      );
    }

    if (truth.unresolvedDecisions.isNotEmpty) {
      final latestDecision = truth.unresolvedDecisions.first;
      final latestIntel =
          _bestIntelForDecision(
            decision: latestDecision,
            intelligence: truth.intelligence,
          ) ??
          truth.latestIntelligence;
      final stateLine = truth.unresolvedDecisions.length == 1
          ? '$scopeLabel is under active review right now.'
          : '$scopeLabel is under active review right now, with ${truth.unresolvedDecisions.length} open incidents being managed.';
      final eventLine = latestIntel == null
          ? 'There is an open operational response on the site.'
          : 'The latest confirmed signal was ${_intelligenceLead(latestIntel)} at ${_hhmm(latestIntel.occurredAt.toLocal())}.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            '$stateLine $eventLine Response is already in motion. $visualLine',
      );
    }

    if (truth.latestIntelligence != null) {
      final latestIntel = truth.latestIntelligence!;
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I do not see a confirmed issue at $scopeLabel right now. The latest logged signal was ${_intelligenceLead(latestIntel)} at ${_hhmm(latestIntel.occurredAt.toLocal())}. It is not an active incident now. $visualLine',
      );
    }

    if (truth.latestPatrol != null) {
      final latestPatrol = truth.latestPatrol!;
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I do not see a confirmed issue at $scopeLabel right now. The latest guard activity logged was ${latestPatrol.guardId} on ${_humanizeScopeLabel(latestPatrol.routeId)} at ${_hhmm(latestPatrol.occurredAt.toLocal())}. $visualLine',
      );
    }

    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.triageNextMove,
      text:
          'I do not see a confirmed issue at $scopeLabel right now. $visualLine',
    );
  }

  OnyxTelegramOperationalCommandResponse _todayDispatchesResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final now = this.now().toLocal();
    final dispatches =
        _eventsForRequest<DecisionCreated>(events: events, request: request)
            .where((event) {
              final occurredAt = event.occurredAt.toLocal();
              return occurredAt.year == now.year &&
                  occurredAt.month == now.month &&
                  occurredAt.day == now.day;
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final scopeLabel = _scopeLabelForRequest(request);
    if (dispatches.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.showDispatchesToday,
        text: 'No dispatches created today in $scopeLabel.',
      );
    }
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.showDispatchesToday,
      text:
          'Today\'s dispatches for $scopeLabel:\n${dispatches.take(3).map((event) => '• ${event.dispatchId} • ${_hhmm(event.occurredAt.toLocal())}').join('\n')}',
    );
  }

  OnyxTelegramOperationalCommandResponse _lastNightIncidentsResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final window = _lastNightWindowLocal();
    final windowLabel = '${_hhmm(window.start)}-${_hhmm(window.end)}';
    final incidents =
        _eventsForRequest<DecisionCreated>(events: events, request: request)
            .where((event) {
              final occurredAt = event.occurredAt.toLocal();
              return !occurredAt.isBefore(window.start) &&
                  occurredAt.isBefore(window.end);
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final scopeLabel = _scopeLabelForRequest(request);
    final heading = _overnightIncidentHeadingForPrompt(request.prompt);
    final emptyLabel = _promptMentionsTonight(request.prompt)
        ? 'No incidents landed tonight in $scopeLabel.\n• Window: $windowLabel'
        : 'No incidents landed last night in $scopeLabel.\n• Window: $windowLabel';
    if (incidents.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.showIncidentsLastNight,
        text: emptyLabel,
      );
    }
    final latest = incidents.first;
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.showIncidentsLastNight,
      text:
          '$heading for $scopeLabel:\n'
          '• Count: ${incidents.length}\n'
          '• Window: $windowLabel\n'
          '• Latest: ${_incidentIdForDispatch(latest.dispatchId)} at ${_hhmm(latest.occurredAt.toLocal())}\n'
          '${incidents.take(3).map((event) => '• ${_incidentIdForDispatch(event.dispatchId)} • ${_hhmm(event.occurredAt.toLocal())}').join('\n')}',
    );
  }

  OnyxTelegramOperationalCommandResponse _verificationResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final truth = _truthSnapshotForRequest(request: request, events: events);
    final areaResolution = _resolvedAreaForRequest(request);
    final normalizedPrompt = _normalizedNaturalPrompt(request.prompt);
    final historicalCheckPrompt = _looksLikeHistoricalCheckPrompt(
      normalizedPrompt,
    );
    final wholeSiteReviewPrompt = _looksLikeWholeSiteReviewPrompt(
      normalizedPrompt,
    );
    final wholeSiteBreachReviewPrompt = _looksLikeWholeSiteBreachReviewPrompt(
      normalizedPrompt,
    );
    String visualLine([String? areaLabel]) =>
        _visualQualificationForCurrentReply(
          request: request,
          areaLabel: areaLabel,
          cameraHealthFactPacket: cameraHealthFactPacket,
        );
    if (wholeSiteReviewPrompt || wholeSiteBreachReviewPrompt) {
      final scopeLabel = _scopeLabelForRequest(request);
      if (wholeSiteBreachReviewPrompt) {
        if (truth.unresolvedDecisions.isNotEmpty) {
          return OnyxTelegramOperationalCommandResponse(
            handled: true,
            allowed: true,
            intent: OnyxCommandIntent.triageNextMove,
            text:
                'I do not have a confirmed full-site breach result for $scopeLabel yet because there is still active operational review on site. ${visualLine()}',
          );
        }
        if (truth.latestIntelligence != null) {
          final latestIntel = truth.latestIntelligence!;
          return OnyxTelegramOperationalCommandResponse(
            handled: true,
            allowed: true,
            intent: OnyxCommandIntent.triageNextMove,
            text:
                'I do not have evidence here confirming a breach across $scopeLabel from the logged site signals alone. The latest confirmed signal was ${_intelligenceLead(latestIntel)} at ${_hhmm(latestIntel.occurredAt.toLocal())}. It is not sitting as an open incident now. ${visualLine()}',
          );
        }
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'I do not have evidence here confirming a breach across $scopeLabel right now. ${visualLine()}',
        );
      }
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text: historicalCheckPrompt
            ? 'Not yet confirmed. I do not have a full-site review result tied to that alarm yet.'
            : cameraHealthFactPacket == null
            ? 'Yes. I can review the logged site signals across $scopeLabel and send you the confirmed result here. I do not have live visual confirmation across every area right now.'
            : 'Yes. I can review the logged site signals across $scopeLabel and send you the confirmed result here. ${visualLine()}',
      );
    }
    if (areaResolution.isAmbiguous) {
      final clarification = _looksLikeHistoricalCheckPrompt(normalizedPrompt)
          ? 'If you tell me which one you mean, I’ll confirm whether it was checked.'
          : 'If you tell me which one you want checked first, I’ll focus the next verified update there.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            '${_ambiguousAreaLead(areaResolution.ambiguousAreas)} $clarification',
      );
    }
    final area = areaResolution.area;
    if (area == null) {
      final clarification = _looksLikeHistoricalCheckPrompt(normalizedPrompt)
          ? 'I’m not fully certain which area you mean. If you tell me which gate, entrance, or camera you mean, I’ll confirm whether it was checked.'
          : 'I’m not fully certain which area you want checked. If you tell me which gate, entrance, or camera matters most, I’ll focus the next verified update there first.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text: clarification,
      );
    }

    final matchingIntel =
        _findAreaMatchedIntelligence(
          area: area,
          intelligence: truth.intelligence,
        ) ??
        truth.latestIntelligence;
    final matchingPatrol = _findAreaMatchedPatrol(
      area: area,
      patrols: truth.patrols,
    );
    final areaLabel = _humanizeAreaLabel(area);
    final scopedAreaLabel = _bestAreaLabelForReply(
      fallbackAreaLabel: areaLabel,
      intelligence: matchingIntel,
    );
    if (historicalCheckPrompt) {
      if (matchingPatrol == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.triageNextMove,
          text:
              'I do not have a confirmed guard check tied to $scopedAreaLabel yet. ${visualLine(scopedAreaLabel)}',
        );
      }
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'Yes. The latest guard check tied to $scopedAreaLabel was logged by ${matchingPatrol.guardId} at ${_hhmm(matchingPatrol.occurredAt.toLocal())}. ${visualLine(scopedAreaLabel)}',
      );
    }
    if (matchingIntel == null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I do not have a fresh verified event tied to $scopedAreaLabel right now. ${visualLine(scopedAreaLabel)} Nothing here shows an active ${_areaRiskLabel(area)} issue.',
      );
    }

    final areaSpecificMatch = _findAreaMatchedIntelligence(
      area: area,
      intelligence: truth.intelligence,
    );
    final openIncident = _decisionMatchesArea(
      decision: truth.unresolvedDecisions.isEmpty
          ? null
          : truth.unresolvedDecisions.first,
      area: area,
      intelligence: areaSpecificMatch ?? matchingIntel,
    );
    final actionLine = openIncident
        ? 'That area is currently being managed as an active operational signal.'
        : 'That area is not sitting as an open incident at the moment.';
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.triageNextMove,
      text:
          'The latest verified activity near $scopedAreaLabel was ${_intelligenceLead(areaSpecificMatch ?? matchingIntel)} at ${_hhmm(matchingIntel.occurredAt.toLocal())}. $actionLine ${visualLine(scopedAreaLabel)}',
    );
  }

  OnyxTelegramOperationalCommandResponse _actionRequestResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final truth = _truthSnapshotForRequest(request: request, events: events);
    final areaResolution = _resolvedAreaForRequest(request);
    String visualLine([String? areaLabel]) =>
        _visualQualificationForCurrentReply(
          request: request,
          areaLabel: areaLabel,
          cameraHealthFactPacket: cameraHealthFactPacket,
        );
    if (areaResolution.isAmbiguous) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            '${_ambiguousAreaLead(areaResolution.ambiguousAreas)} If you tell me which one you want actioned first, I’ll prioritise that for the next verified check.',
      );
    }
    final area = areaResolution.area;
    if (area == null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I’m not fully certain which area you want actioned first. If you tell me which gate, entrance, or perimeter point matters most, I’ll prioritise that for the next verified check.',
      );
    }

    final areaLabel = _humanizeAreaLabel(area);
    final matchingIntel =
        _findAreaMatchedIntelligence(
          area: area,
          intelligence: truth.intelligence,
        ) ??
        truth.latestIntelligence;
    final areaSpecificMatch = _findAreaMatchedIntelligence(
      area: area,
      intelligence: truth.intelligence,
    );
    final openIncident =
        (areaSpecificMatch ?? matchingIntel) != null &&
        _decisionMatchesArea(
          decision: truth.unresolvedDecisions.isEmpty
              ? null
              : truth.unresolvedDecisions.first,
          area: area,
          intelligence: areaSpecificMatch ?? matchingIntel!,
        );

    if (openIncident && matchingIntel != null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'There is already an active operational response around $areaLabel. The latest confirmed signal was ${_intelligenceLead(areaSpecificMatch ?? matchingIntel)} at ${_hhmm(matchingIntel.occurredAt.toLocal())}. I have not initiated a second dispatch from this message alone. ${visualLine(areaLabel)}',
      );
    }

    if (matchingIntel != null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'The latest verified activity near $areaLabel was ${_intelligenceLead(areaSpecificMatch ?? matchingIntel)} at ${_hhmm(matchingIntel.occurredAt.toLocal())}. It is not sitting as an open incident at the moment. I have not initiated a dispatch from this message alone, but I can prioritise $areaLabel for immediate verification. ${visualLine(areaLabel)}',
      );
    }

    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.triageNextMove,
      text:
          'I do not see a fresh verified event tied to $areaLabel right now. I have not initiated a dispatch from this message alone, but I can prioritise $areaLabel for immediate verification. ${visualLine(areaLabel)}',
    );
  }

  OnyxTelegramOperationalCommandResponse _observationConcernResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final truth = _truthSnapshotForRequest(request: request, events: events);
    final scopeLabel = _scopeLabelForRequest(request);
    final normalizedPrompt = _normalizedNaturalPrompt(request.prompt);
    final focusLabel = normalizedPrompt.contains('outside')
        ? 'the outside area'
        : 'that area';
    final area = _resolvedAreaForRequest(request).area;
    final areaLabel = area == null ? null : _humanizeAreaLabel(area);
    String visualLine([String? scopedAreaLabel]) =>
        _visualQualificationForCurrentReply(
          request: request,
          areaLabel: scopedAreaLabel,
          cameraHealthFactPacket: cameraHealthFactPacket,
        );
    final matchingIntel = area == null
        ? null
        : _findAreaMatchedIntelligence(
            area: area,
            intelligence: truth.intelligence,
          );

    if (truth.unresolvedDecisions.isNotEmpty) {
      final latestDecision = truth.unresolvedDecisions.first;
      final relevantIntel =
          matchingIntel ??
          _bestIntelForDecision(
            decision: latestDecision,
            intelligence: truth.intelligence,
          ) ??
          truth.latestIntelligence;
      final eventLine = relevantIntel == null
          ? 'There is already an active operational review on site.'
          : 'The latest confirmed signal was ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I\'m treating that as a live concern. $scopeLabel is already under active review right now. $eventLine Response is already in motion. ${visualLine(areaLabel)}',
      );
    }

    if (matchingIntel != null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I\'m treating that as a live concern. The latest verified activity near $areaLabel was ${_intelligenceLead(matchingIntel)} at ${_hhmm(matchingIntel.occurredAt.toLocal())}. It is not sitting as an open incident at the moment, but I can have $focusLabel checked immediately. ${visualLine(areaLabel)}',
      );
    }

    if (truth.latestIntelligence != null) {
      final latestIntel = truth.latestIntelligence!;
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.triageNextMove,
        text:
            'I\'m treating that as a live concern. The latest confirmed activity on site was ${_intelligenceLead(latestIntel)} at ${_hhmm(latestIntel.occurredAt.toLocal())}. It is not sitting as an open incident at the moment. I can have $focusLabel checked immediately. ${visualLine(areaLabel)}',
      );
    }

    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.triageNextMove,
      text:
          'I\'m treating that as a live concern. I do not see a confirmed active incident in the current operational picture. ${visualLine(areaLabel)} I can have $focusLabel verified immediately.',
    );
  }

  OnyxTelegramOperationalCommandResponse _incidentClarificationResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final truth = _truthSnapshotForRequest(request: request, events: events);
    final normalizedPrompt = _normalizedNaturalPrompt(request.prompt);
    String visualLine([String? areaLabel]) =>
        _visualQualificationForCurrentReply(
          request: request,
          areaLabel: areaLabel,
          cameraHealthFactPacket: cameraHealthFactPacket,
        );
    final historicalIncidentReviewPrompt =
        _looksLikeHistoricalIncidentReviewPrompt(normalizedPrompt);
    final historicalAlarmReviewPrompt = _looksLikeHistoricalAlarmReviewPrompt(
      normalizedPrompt,
    );
    final historicalResponseArrivalPrompt =
        _looksLikeHistoricalResponseArrivalPrompt(normalizedPrompt);
    final asksAboutBreach = _asksWhetherThereWasABreach(normalizedPrompt);
    final contextualComparison = _looksLikeIncidentComparisonPrompt(
      normalizedPrompt,
    );
    final incidentPersistenceFollowUp = _looksLikeIncidentPersistencePrompt(
      normalizedPrompt,
    );
    final incidentTimingFollowUp = _looksLikeIncidentTimingPrompt(
      normalizedPrompt,
    );
    final incidentRelativeCalmFollowUp = _looksLikeIncidentRelativeCalmPrompt(
      normalizedPrompt,
    );
    final incidentPatrolAnchoredCalmFollowUp =
        _looksLikeIncidentPatrolAnchoredCalmPrompt(normalizedPrompt);
    final incidentDispatchAnchoredCalmFollowUp =
        _looksLikeIncidentDispatchAnchoredCalmPrompt(normalizedPrompt);
    final incidentResponseArrivalAnchoredCalmFollowUp =
        _looksLikeIncidentResponseArrivalAnchoredCalmPrompt(normalizedPrompt);
    final incidentCameraReviewAnchoredCalmFollowUp =
        _looksLikeIncidentCameraReviewAnchoredCalmPrompt(normalizedPrompt);
    final quietTimingFollowUp = _looksLikeIncidentQuietTimingPrompt(
      normalizedPrompt,
    );
    final areaResolution = _resolvedAreaForRequest(request);
    if (areaResolution.isAmbiguous) {
      final clarification = historicalResponseArrivalPrompt
          ? 'If you tell me which one you mean, I’ll confirm whether response has arrived there.'
          : 'If you tell me which one you mean, I’ll anchor the next verified answer there.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '${_ambiguousAreaLead(areaResolution.ambiguousAreas)} $clarification',
      );
    }
    final contextArea = areaResolution.area;
    final contextAreaLabel = contextArea == null
        ? null
        : _humanizeAreaLabel(contextArea);
    final latestOpenDecision = truth.unresolvedDecisions.isEmpty
        ? null
        : truth.unresolvedDecisions.first;
    final latestDecision = truth.latestDecision;
    final relevantIntel = latestOpenDecision == null
        ? truth.latestIntelligence
        : _bestIntelForDecision(
                decision: latestOpenDecision,
                intelligence: truth.intelligence,
              ) ??
              truth.latestIntelligence;
    final latestClosed = truth.latestClosedIncident;
    final contextualIntel = contextArea == null
        ? null
        : _findAreaMatchedIntelligence(
            area: contextArea,
            intelligence: truth.intelligence,
          );
    final contextualPatrol = contextArea == null
        ? null
        : _findAreaMatchedPatrol(area: contextArea, patrols: truth.patrols);
    final contextualDecision = contextArea == null
        ? truth.latestDecision
        : _bestDecisionForArea(
            area: contextArea,
            decisions: truth.decisions,
            intelligence: truth.intelligence,
          );
    final contextualResponseArrival = _findOperationalMarkerIntelligence(
      intelligence: truth.intelligence,
      area: contextArea,
      matchesMarker: _isResponseArrivalIntelligence,
    );
    final contextualCameraReview = _findOperationalMarkerIntelligence(
      intelligence: truth.intelligence,
      area: contextArea,
      matchesMarker: _isCameraReviewMarkerIntelligence,
    );
    final requestedClockTime = _requestedClockTimeForPrompt(normalizedPrompt);
    final requestedClockLabel = requestedClockTime == null
        ? null
        : _clockTimeLabel(requestedClockTime);
    final requestedClockMatch = requestedClockTime == null
        ? null
        : _findIntelligenceNearRequestedClockTime(
            intelligence: contextArea == null
                ? truth.intelligence
                : truth.intelligence
                      .where(
                        (event) =>
                            _intelligenceSuggestsArea(event, contextArea),
                      )
                      .toList(growable: false),
            requestedClockTime: requestedClockTime,
          );

    if (latestDecision == null && relevantIntel == null) {
      if (historicalIncidentReviewPrompt) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              'Understood. You are asking about an earlier reported incident, not a live emergency. I do not have a confirmed historical incident review result for that report in the scoped record I can see yet.',
        );
      }
      if (historicalAlarmReviewPrompt) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              'I do not have a confirmed historical review result for that alarm window yet.',
        );
      }
      if (contextualComparison && contextAreaLabel == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              'I’m not fully certain which earlier area you mean. If you tell me which gate, entrance, or camera you want compared, I’ll anchor the next verified answer there.',
        );
      }
      if (historicalResponseArrivalPrompt) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed response arrival I can verify yet.'
              : 'I do not have a confirmed response arrival tied to $contextAreaLabel yet.',
        );
      }
      if (incidentPatrolAnchoredCalmFollowUp) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed guard check I can anchor that calmness check to right now.'
              : 'I do not have a confirmed guard check tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }
      if (incidentDispatchAnchoredCalmFollowUp) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed dispatch opening I can anchor that calmness check to right now.'
              : 'I do not have a confirmed dispatch opening tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }
      if (incidentResponseArrivalAnchoredCalmFollowUp) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed response arrival I can anchor that calmness check to right now.'
              : 'I do not have a confirmed response arrival tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }
      if (incidentCameraReviewAnchoredCalmFollowUp) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed camera review marker I can anchor that calmness check to right now.'
              : 'I do not have a confirmed camera review marker tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }
      if (incidentRelativeCalmFollowUp) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed earlier incident I can anchor that calmness check to right now.'
              : 'I do not have a confirmed earlier incident tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            'I do not see a confirmed alarm incident sitting open in the current operational picture.',
      );
    }

    if (historicalIncidentReviewPrompt && latestOpenDecision == null) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            'Understood. You are asking about an earlier reported incident, not a live emergency. The scoped record I can see does not show an active incident now.',
      );
    }

    if (requestedClockTime != null && requestedClockMatch == null) {
      final historicalScopeLabel = _historicalReviewScopeLabel(
        normalizedPrompt,
        contextAreaLabel,
      );
      final lead = contextAreaLabel == null
          ? 'I do not have a confirmed alert tied to around $requestedClockLabel in the logged history available to me.'
          : 'I do not have a confirmed alert tied to $historicalScopeLabel around $requestedClockLabel in the logged history available to me.';
      final breachLine = asksAboutBreach
          ? 'I do not have evidence here confirming a breach from that logged history alone.'
          : null;
      final latestLine =
          (historicalAlarmReviewPrompt || contextAreaLabel != null)
          ? null
          : relevantIntel == null
          ? null
          : 'The latest logged signal I can see is ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text: [
          lead,
          breachLine,
          latestLine,
        ].whereType<String>().where((line) => line.trim().isNotEmpty).join(' '),
      );
    }

    if (historicalResponseArrivalPrompt) {
      if (contextualResponseArrival == null) {
        final responseLine = contextAreaLabel == null
            ? 'I do not have a confirmed response arrival yet.'
            : 'I do not have a confirmed response arrival tied to $contextAreaLabel yet.';
        final statusLine = latestOpenDecision == null
            ? null
            : _packetizedIssueSummaryLine(
                    cameraHealthFactPacket: cameraHealthFactPacket,
                    areaLabel: contextAreaLabel,
                  ) ??
                  (contextAreaLabel == null
                      ? 'The current operational picture still shows that issue under review.'
                      : 'The current operational picture still shows $contextAreaLabel under review.');
        final visualLine = _visualQualificationForCurrentReply(
          request: request,
          areaLabel: contextAreaLabel,
          cameraHealthFactPacket: cameraHealthFactPacket,
        );
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: [responseLine, statusLine, visualLine]
              .whereType<String>()
              .where((line) => line.trim().isNotEmpty)
              .join(' '),
        );
      }

      final responseLine = contextAreaLabel == null
          ? 'Yes. A response arrival was logged at ${_hhmm(contextualResponseArrival.occurredAt.toLocal())}.'
          : 'Yes. A response arrival tied to $contextAreaLabel was logged at ${_hhmm(contextualResponseArrival.occurredAt.toLocal())}.';
      final statusLine = latestOpenDecision != null
          ? 'Response remains active while that area is being verified.'
          : latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      final visualLine = _visualQualificationForCurrentReply(
        request: request,
        areaLabel: contextAreaLabel,
        cameraHealthFactPacket: cameraHealthFactPacket,
      );
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text: '$responseLine $statusLine $visualLine',
      );
    }

    if (incidentPatrolAnchoredCalmFollowUp) {
      final calmPatrol =
          contextualPatrol ?? (contextArea == null ? truth.latestPatrol : null);
      if (calmPatrol == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed guard check I can anchor that calmness check to right now.'
              : 'I do not have a confirmed guard check tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }

      final patrolLine = contextAreaLabel == null
          ? 'The latest guard check was logged on ${_humanizeScopeLabel(calmPatrol.routeId)} by ${calmPatrol.guardId} at ${_hhmm(calmPatrol.occurredAt.toLocal())}.'
          : 'The latest guard check tied to $contextAreaLabel was logged by ${calmPatrol.guardId} at ${_hhmm(calmPatrol.occurredAt.toLocal())}.';
      if (latestOpenDecision != null) {
        final calmLead = contextAreaLabel == null
            ? 'No. The current operational picture does not look calm yet.'
            : (contextualIntel != null ||
                  (relevantIntel != null &&
                      _intelligenceSuggestsArea(relevantIntel, contextArea!)))
            ? 'No. The current operational picture still points to $contextAreaLabel.'
            : 'No. The current operational picture does not clearly show $contextAreaLabel as calm yet.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$calmLead $patrolLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final calmLead = contextAreaLabel == null
          ? 'Yes. The area in question appears calm since the guard check at ${_hhmm(calmPatrol.occurredAt.toLocal())}.'
          : 'Yes. $contextAreaLabel has been calm since the guard check at ${_hhmm(calmPatrol.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$calmLead $patrolLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentDispatchAnchoredCalmFollowUp) {
      final calmDecision = contextualDecision;
      if (calmDecision == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed dispatch opening I can anchor that calmness check to right now.'
              : 'I do not have a confirmed dispatch opening tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }

      final dispatchLine = contextAreaLabel == null
          ? 'The relevant dispatch was opened at ${_hhmm(calmDecision.occurredAt.toLocal())}.'
          : 'The dispatch tied to $contextAreaLabel was opened at ${_hhmm(calmDecision.occurredAt.toLocal())}.';
      if (latestOpenDecision != null) {
        final calmLead = contextAreaLabel == null
            ? 'No. The current operational picture does not look calm yet.'
            : (contextualIntel != null ||
                  (relevantIntel != null &&
                      _intelligenceSuggestsArea(relevantIntel, contextArea!)))
            ? 'No. The current operational picture still points to $contextAreaLabel.'
            : 'No. The current operational picture does not clearly show $contextAreaLabel as calm yet.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$calmLead $dispatchLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final calmLead = contextAreaLabel == null
          ? 'Yes. The earlier issue has remained calm since dispatch was opened at ${_hhmm(calmDecision.occurredAt.toLocal())}.'
          : 'Yes. $contextAreaLabel has remained calm since dispatch was opened at ${_hhmm(calmDecision.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$calmLead $dispatchLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentResponseArrivalAnchoredCalmFollowUp) {
      final responseArrivalIntel = contextualResponseArrival;
      if (responseArrivalIntel == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed response arrival I can anchor that calmness check to right now.'
              : 'I do not have a confirmed response arrival tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }

      final responseArrivalLine = contextAreaLabel == null
          ? 'A response arrival was logged at ${_hhmm(responseArrivalIntel.occurredAt.toLocal())}.'
          : 'A response arrival tied to $contextAreaLabel was logged at ${_hhmm(responseArrivalIntel.occurredAt.toLocal())}.';
      if (latestOpenDecision != null) {
        final calmLead = contextAreaLabel == null
            ? 'No. The current operational picture does not look calm yet.'
            : (contextualIntel != null ||
                  (relevantIntel != null &&
                      _intelligenceSuggestsArea(relevantIntel, contextArea!)))
            ? 'No. The current operational picture still points to $contextAreaLabel.'
            : 'No. The current operational picture does not clearly show $contextAreaLabel as calm yet.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$calmLead $responseArrivalLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final calmLead = contextAreaLabel == null
          ? 'Yes. The area in question appears calm since the response arrived at ${_hhmm(responseArrivalIntel.occurredAt.toLocal())}.'
          : 'Yes. $contextAreaLabel has appeared calm since the response arrived at ${_hhmm(responseArrivalIntel.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$calmLead $responseArrivalLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentCameraReviewAnchoredCalmFollowUp) {
      if (contextualCameraReview == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: contextAreaLabel == null
              ? 'I do not have a confirmed camera review marker I can anchor that calmness check to right now.'
              : 'I do not have a confirmed camera review marker tied to $contextAreaLabel that I can anchor that calmness check to right now.',
        );
      }

      final reviewLine = contextAreaLabel == null
          ? 'A confirmed camera review marker was logged at ${_hhmm(contextualCameraReview.occurredAt.toLocal())}.'
          : 'A confirmed camera review marker tied to $contextAreaLabel was logged at ${_hhmm(contextualCameraReview.occurredAt.toLocal())}.';
      if (latestOpenDecision != null) {
        final calmLead = contextAreaLabel == null
            ? 'No. The current operational picture does not look calm yet.'
            : (contextualIntel != null ||
                  (relevantIntel != null &&
                      _intelligenceSuggestsArea(relevantIntel, contextArea!)))
            ? 'No. The current operational picture still points to $contextAreaLabel.'
            : 'No. The current operational picture does not clearly show $contextAreaLabel as calm yet.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$calmLead $reviewLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final calmLead = contextAreaLabel == null
          ? 'Yes. The area in question appears calm since the last confirmed camera review at ${_hhmm(contextualCameraReview.occurredAt.toLocal())}.'
          : 'Yes. $contextAreaLabel has appeared calm since the last confirmed camera review at ${_hhmm(contextualCameraReview.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$calmLead $reviewLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentRelativeCalmFollowUp) {
      final calmIntel = contextualIntel ?? relevantIntel;
      if (latestOpenDecision != null) {
        final calmLead = contextAreaLabel == null
            ? 'No. The current operational picture does not look calm yet.'
            : (calmIntel != null &&
                  (contextualIntel != null ||
                      _intelligenceSuggestsArea(calmIntel, contextArea!)))
            ? 'No. The current operational picture still points to $contextAreaLabel.'
            : 'No. The current operational picture does not clearly show $contextAreaLabel as calm yet.';
        final eventLine = calmIntel == null
            ? 'An active operational response is still open.'
            : 'The latest confirmed alert was ${_intelligenceLead(calmIntel)} at ${_hhmm(calmIntel.occurredAt.toLocal())}.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$calmLead $eventLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final calmLead = contextAreaLabel == null
          ? 'Yes. The earlier issue appears calm now.'
          : 'Yes. $contextAreaLabel has been calm since the earlier signal.';
      final eventLine = calmIntel == null
          ? 'I do not see an active response sitting open against it now.'
          : 'The latest confirmed alert was ${_intelligenceLead(calmIntel)} at ${_hhmm(calmIntel.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$calmLead $eventLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentPersistenceFollowUp) {
      final persistenceIntel = contextualIntel ?? relevantIntel;
      if (latestOpenDecision != null) {
        final persistenceLead =
            _packetizedIssueSummaryLine(
              cameraHealthFactPacket: cameraHealthFactPacket,
              areaLabel: contextAreaLabel,
            ) ??
            (contextAreaLabel == null
                ? 'The current operational picture still shows that issue as active.'
                : (persistenceIntel != null &&
                      (contextualIntel != null ||
                          _intelligenceSuggestsArea(
                            persistenceIntel,
                            contextArea!,
                          )))
                ? 'The current operational picture still points to $contextAreaLabel.'
                : 'The current operational picture does not clearly point back to $contextAreaLabel from the current operational picture.');
        final eventLine = persistenceIntel == null
            ? 'An active operational response is still open.'
            : 'The latest confirmed alert was ${_intelligenceLead(persistenceIntel)} at ${_hhmm(persistenceIntel.occurredAt.toLocal())}.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$persistenceLead $eventLine Response is still active. ${visualLine(contextAreaLabel)}',
        );
      }

      final settledLead = contextAreaLabel == null
          ? 'That earlier issue has settled.'
          : 'The earlier $contextAreaLabel signal has settled.';
      final eventLine = persistenceIntel == null
          ? 'I do not see an active response sitting open against it now.'
          : 'The latest confirmed alert was ${_intelligenceLead(persistenceIntel)} at ${_hhmm(persistenceIntel.occurredAt.toLocal())}.';
      final statusLine = latestClosed != null
          ? 'It was reviewed properly and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$settledLead $eventLine $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (incidentTimingFollowUp) {
      final timingIntel =
          requestedClockMatch ?? contextualIntel ?? relevantIntel;
      if (timingIntel == null) {
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: quietTimingFollowUp && contextAreaLabel != null
              ? 'I do not have a confirmed alert tied to $contextAreaLabel earlier tonight in the current operational picture.'
              : 'I do not have a confirmed alert timestamp I can anchor to that follow-up right now.',
        );
      }

      if (requestedClockTime != null && requestedClockMatch != null) {
        final timingLead = contextAreaLabel == null
            ? 'The confirmed alert closest to $requestedClockLabel was ${_intelligenceLead(requestedClockMatch)} at ${_hhmm(requestedClockMatch.occurredAt.toLocal())}.'
            : 'The confirmed alert closest to $requestedClockLabel tied to $contextAreaLabel was ${_intelligenceLead(requestedClockMatch)} at ${_hhmm(requestedClockMatch.occurredAt.toLocal())}.';
        final breachLine = !asksAboutBreach
            ? null
            : latestOpenDecision != null
            ? 'That alert is still under review, so I cannot confirm a breach yet.'
            : 'I do not have evidence here confirming a breach from that logged history alone.';
        final statusLine = latestOpenDecision != null
            ? 'Response is still active.'
            : latestClosed != null
            ? 'It has been reviewed and is not an active incident now.'
            : 'It is not an active incident now.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: [timingLead, breachLine, statusLine]
              .whereType<String>()
              .where((line) => line.trim().isNotEmpty)
              .join(' '),
        );
      }

      final occurredEarlierTonight = _occurredEarlierTonight(
        timingIntel.occurredAt,
      );
      if (quietTimingFollowUp) {
        final quietLead = occurredEarlierTonight
            ? contextAreaLabel == null
                  ? 'No. The latest confirmed alert was recorded earlier tonight at ${_hhmm(timingIntel.occurredAt.toLocal())}.'
                  : 'No. The latest confirmed alert tied to $contextAreaLabel was recorded earlier tonight at ${_hhmm(timingIntel.occurredAt.toLocal())}.'
            : contextAreaLabel == null
            ? 'Yes. I would not place the latest confirmed alert earlier tonight. It was recorded at ${_hhmm(timingIntel.occurredAt.toLocal())}.'
            : 'Yes. I would not place the latest confirmed alert tied to $contextAreaLabel earlier tonight. It was recorded at ${_hhmm(timingIntel.occurredAt.toLocal())}.';
        final statusLine = latestOpenDecision != null
            ? 'Response is still active.'
            : latestClosed != null
            ? 'It has been reviewed and is not sitting as an active incident now.'
            : 'It is not sitting as an active incident now.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text: '$quietLead $statusLine ${visualLine(contextAreaLabel)}',
        );
      }
      final timingLead = occurredEarlierTonight
          ? 'Yes. The latest confirmed alert was recorded earlier tonight at ${_hhmm(timingIntel.occurredAt.toLocal())}.'
          : 'The latest confirmed alert was recorded at ${_hhmm(timingIntel.occurredAt.toLocal())}, so I would not place it earlier tonight.';
      final statusLine = latestOpenDecision != null
          ? 'Response is still active.'
          : latestClosed != null
          ? 'It has been reviewed and is not sitting as an active incident now.'
          : 'It is not sitting as an active incident now.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text: '$timingLead $statusLine ${visualLine(contextAreaLabel)}',
      );
    }

    if (contextualComparison && contextAreaLabel != null) {
      final comparisonIntel = contextualIntel ?? relevantIntel;
      if (comparisonIntel != null) {
        final areaMatchesCurrent =
            contextualIntel != null ||
            _intelligenceSuggestsArea(comparisonIntel, contextArea!);
        final areaSentence = areaMatchesCurrent
            ? 'The latest confirmed alert points to $contextAreaLabel again.'
            : 'The latest confirmed alert does not clearly point back to $contextAreaLabel from the current operational picture.';
        final statusSentence = latestOpenDecision != null
            ? 'Response is still active.'
            : latestClosed != null
            ? 'It was reviewed properly and is not sitting as an active incident now.'
            : 'It is not sitting as an active incident now.';
        return OnyxTelegramOperationalCommandResponse(
          handled: true,
          allowed: true,
          intent: OnyxCommandIntent.summarizeIncident,
          text:
              '$areaSentence The latest confirmed alert was ${_intelligenceLead(comparisonIntel)} at ${_hhmm(comparisonIntel.occurredAt.toLocal())}. $statusSentence ${visualLine(contextAreaLabel)}',
        );
      }
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            'I can anchor that comparison to $contextAreaLabel, but I do not have a fresh confirmed alert tied to it right now. ${visualLine(contextAreaLabel)}',
      );
    }

    if (latestOpenDecision != null) {
      final seriousness = _seriousnessLeadForIntelligence(relevantIntel);
      final eventLine = relevantIntel == null
          ? 'An active operational response is still open.'
          : 'The latest confirmed alert was ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            '$seriousness $eventLine Response is still active. ${visualLine()}',
      );
    }

    if (latestClosed != null) {
      final eventLine = relevantIntel == null
          ? 'The latest alarm-linked event was reviewed and is no longer open.'
          : 'The latest confirmed alert was ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}.';
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.summarizeIncident,
        text:
            'It was treated as a real signal and reviewed properly, but it is not sitting as an active incident now. $eventLine The current operational picture does not show an open threat at this stage.',
      );
    }

    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.summarizeIncident,
      text:
          'It registered as a signal worth review, but I do not see an active response sitting open against it now. ${relevantIntel == null ? visualLine() : 'The latest confirmed alert was ${_intelligenceLead(relevantIntel)} at ${_hhmm(relevantIntel.occurredAt.toLocal())}.'}',
    );
  }

  OnyxTelegramOperationalCommandResponse _siteAlertLeaderResponse({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final window = _thisWeekWindowLocal();
    final alertCountsBySite = <String, int>{};
    for (final alert in _eventsForRequest<IntelligenceReceived>(
      events: events,
      request: request,
      includeAllSitesForClient: true,
    )) {
      final occurredAt = alert.occurredAt.toLocal();
      if (occurredAt.isBefore(window.start) || occurredAt.isAfter(window.end)) {
        continue;
      }
      final siteId = alert.siteId.trim();
      if (siteId.isEmpty) {
        continue;
      }
      alertCountsBySite.update(siteId, (count) => count + 1, ifAbsent: () => 1);
    }
    final rankedSites = alertCountsBySite.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    if (rankedSites.isEmpty) {
      return OnyxTelegramOperationalCommandResponse(
        handled: true,
        allowed: true,
        intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
        text: 'No alert activity landed this week in the allowed scope.',
      );
    }
    final leader = rankedSites.first;
    return OnyxTelegramOperationalCommandResponse(
      handled: true,
      allowed: true,
      intent: OnyxCommandIntent.showSiteMostAlertsThisWeek,
      text:
          'This week\'s alert leader: ${_humanizeScopeLabel(leader.key)} (${leader.value} alert${leader.value == 1 ? '' : 's'})\n${rankedSites.skip(1).take(2).map((entry) => '• ${_humanizeScopeLabel(entry.key)} • ${entry.value} alert${entry.value == 1 ? '' : 's'}').join('\n')}',
    );
  }

  List<T> _eventsForRequest<T extends DispatchEvent>({
    required List<DispatchEvent> events,
    required OnyxTelegramCommandRequest request,
    bool includeAllSitesForClient = false,
  }) {
    final requestedClientId = request.requestedClientId.trim();
    final requestedSiteId = request.requestedSiteId.trim();
    final allowedClients = request.userAllowedClientIds;
    final allowedSites = request.userAllowedSiteIds;

    return events
        .whereType<T>()
        .where((event) {
          final clientId = switch (event) {
            DecisionCreated value => value.clientId.trim(),
            IncidentClosed value => value.clientId.trim(),
            IntelligenceReceived value => value.clientId.trim(),
            PatrolCompleted value => value.clientId.trim(),
            _ => '',
          };
          final siteId = switch (event) {
            DecisionCreated value => value.siteId.trim(),
            IncidentClosed value => value.siteId.trim(),
            IntelligenceReceived value => value.siteId.trim(),
            PatrolCompleted value => value.siteId.trim(),
            _ => '',
          };
          if (allowedClients.isNotEmpty &&
              clientId.isNotEmpty &&
              !allowedClients.contains(clientId)) {
            return false;
          }
          if (allowedSites.isNotEmpty &&
              siteId.isNotEmpty &&
              !allowedSites.contains(siteId)) {
            return false;
          }
          if (requestedClientId.isNotEmpty && clientId != requestedClientId) {
            return false;
          }
          if (!includeAllSitesForClient &&
              requestedSiteId.isNotEmpty &&
              siteId != requestedSiteId) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  ({DateTime start, DateTime end}) _lastNightWindowLocal() {
    final now = this.now().toLocal();
    final end = DateTime(now.year, now.month, now.day, 6);
    final start = DateTime(
      end.year,
      end.month,
      end.day,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
    return (start: start, end: end);
  }

  ({DateTime start, DateTime end}) _thisWeekWindowLocal() {
    final now = this.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final start = todayStart.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    return (start: start, end: now);
  }

  String _incidentIdForDispatch(String dispatchId) {
    return 'INC-$dispatchId';
  }

  String _hhmm(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _scopeLabelForRequest(OnyxTelegramCommandRequest request) {
    if (request.requestedSiteLabel.trim().isNotEmpty) {
      return request.requestedSiteLabel.trim();
    }
    if (request.requestedClientLabel.trim().isNotEmpty) {
      return request.requestedClientLabel.trim();
    }
    if (request.requestedSiteId.trim().isNotEmpty) {
      return _humanizeScopeLabel(request.requestedSiteId);
    }
    if (request.requestedClientId.trim().isNotEmpty) {
      return _humanizeScopeLabel(request.requestedClientId);
    }
    return 'the allowed scope';
  }

  _RequestTruthSnapshot _truthSnapshotForRequest({
    required OnyxTelegramCommandRequest request,
    required List<DispatchEvent> events,
  }) {
    final decisions = _eventsForRequest<DecisionCreated>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final closed = _eventsForRequest<IncidentClosed>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final intelligence = _eventsForRequest<IntelligenceReceived>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final patrols = _eventsForRequest<PatrolCompleted>(
      events: events,
      request: request,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final closedDispatchIds = closed
        .map((event) => event.dispatchId.trim())
        .toSet();
    final unresolved = decisions
        .where((event) => !closedDispatchIds.contains(event.dispatchId.trim()))
        .toList(growable: false);
    return _RequestTruthSnapshot(
      decisions: decisions,
      unresolvedDecisions: unresolved,
      closedIncidents: closed,
      intelligence: intelligence,
      patrols: patrols,
    );
  }

  bool _promptMentionsTonight(String prompt) {
    final normalized = prompt.trim().toLowerCase();
    return normalized.contains('tonight') ||
        normalized.contains("tonight's") ||
        normalized.contains('tonights');
  }

  String _overnightIncidentHeadingForPrompt(String prompt) {
    if (_promptMentionsTonight(prompt)) {
      return "Tonight's incidents";
    }
    return "Last night's incidents";
  }

  PatrolCompleted _resolvePatrolForPrompt(
    String prompt,
    List<PatrolCompleted> patrols,
  ) {
    return _matchPatrolForPrompt(prompt, patrols) ?? patrols.first;
  }

  PatrolCompleted? _matchPatrolForPrompt(
    String prompt,
    List<PatrolCompleted> patrols,
  ) {
    final normalizedPrompt = _normalizedCommandToken(prompt);
    for (final patrol in patrols) {
      final normalizedGuard = _normalizedCommandToken(patrol.guardId);
      final normalizedRoute = _normalizedCommandToken(patrol.routeId);
      if ((normalizedGuard.isNotEmpty &&
              normalizedPrompt.contains(normalizedGuard)) ||
          (normalizedRoute.isNotEmpty &&
              normalizedPrompt.contains(normalizedRoute))) {
        return patrol;
      }
    }
    return null;
  }

  String _humanizeScopeLabel(String raw) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
        .replaceAll(RegExp(r'[_\\-]+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return raw;
    }
    final stopWords = <String>{'and', 'of', 'the'};
    return cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final lower = entry.value.toLowerCase();
          if (entry.key > 0 && stopWords.contains(lower)) {
            return lower;
          }
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  String _normalizedCommandToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  _ConversationalOperationalIntent? _resolveConversationalIntent({
    required String prompt,
    required OnyxCommandIntent parsedIntent,
  }) {
    if (parsedIntent == OnyxCommandIntent.summarizeIncident) {
      return _ConversationalOperationalIntent.incidentClarification;
    }
    final normalized = _normalizedNaturalPrompt(prompt);
    if (normalized.isEmpty) {
      return null;
    }
    if (parsedIntent != OnyxCommandIntent.triageNextMove) {
      if (_looksLikeIncidentOperationalAnchorCalmPrompt(normalized)) {
        return _ConversationalOperationalIntent.incidentClarification;
      }
      if (_shouldPreferIncidentClarificationPrompt(normalized)) {
        return _ConversationalOperationalIntent.incidentClarification;
      }
      if (_looksLikeVerificationPrompt(normalized)) {
        return _ConversationalOperationalIntent.verification;
      }
      return null;
    }
    if (_looksLikeIncidentOperationalAnchorCalmPrompt(normalized)) {
      return _ConversationalOperationalIntent.incidentClarification;
    }
    if (_shouldPreferIncidentClarificationPrompt(normalized)) {
      return _ConversationalOperationalIntent.incidentClarification;
    }
    if (_looksLikeActionRequestPrompt(normalized)) {
      return _ConversationalOperationalIntent.actionRequest;
    }
    if (_looksLikeVerificationPrompt(normalized)) {
      return _ConversationalOperationalIntent.verification;
    }
    if (_looksLikeIncidentClarificationPrompt(normalized)) {
      return _ConversationalOperationalIntent.incidentClarification;
    }
    if (_looksLikeObservationConcernPrompt(normalized)) {
      return _ConversationalOperationalIntent.observationConcern;
    }
    if (_looksLikeStatusReassurancePrompt(normalized)) {
      return _ConversationalOperationalIntent.statusReassurance;
    }
    return null;
  }

  String _normalizedNaturalPrompt(String prompt) {
    final raw = normalizeTelegramClientPromptSignalText(prompt);
    if (raw.isEmpty) {
      return raw;
    }
    const replacements = <String, String>{
      'cn': 'can',
      'u': 'you',
      'chek': 'check',
      'chekc': 'check',
      'rong': 'wrong',
      'tht': 'that',
      'alrm': 'alarm',
      'pls': 'please',
      'plz': 'please',
      'snd': 'send',
      'thy': 'they',
      'any1': 'anyone',
      'sm1': 'someone',
      'some1': 'someone',
      'sme': 'same',
      'staid': 'stayed',
      'didnt': 'didnt',
      'oaky': 'okay',
      'saef': 'safe',
      'smone': 'someone',
      'somone': 'someone',
      'smeone': 'someone',
      'cleer': 'clear',
      'qiuet': 'quiet',
      'caln': 'calm',
      'camra': 'camera',
      'cctvv': 'cctv',
      'gaurd': 'guard',
      'frnt': 'front',
      'gte': 'gate',
      'othr': 'other',
      'ovr': 'over',
      'ther': 'there',
      'clse': 'close',
      'oky': 'okay',
    };
    final normalizedTokens = raw
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .map((token) => replacements[token] ?? token)
        .toList(growable: false);
    return normalizedTokens.join(' ');
  }

  bool _looksLikeStatusReassurancePrompt(String normalized) {
    return asksForTelegramClientBroadStatusOrCurrentSiteView(normalized) ||
        asksForTelegramClientCurrentSiteIssueCheck(normalized) ||
        asksForTelegramClientMovementCheck(normalized) ||
        normalized.contains('anything wrong') ||
        normalized.contains('any update') ||
        normalized.contains('what happening') ||
        normalized.contains('what going on') ||
        normalized.contains('site secure') ||
        normalized.contains('status');
  }

  bool _looksLikeVerificationPrompt(String normalized) {
    if (_looksLikeHistoricalAlarmReviewPrompt(normalized)) {
      return false;
    }
    if (_looksLikeWholeSiteBreachReviewPrompt(normalized)) {
      return true;
    }
    if (_looksLikeWholeSiteReviewPrompt(normalized)) {
      return true;
    }
    final asksToCheck =
        normalized.contains('check') ||
        normalized.contains('look') ||
        normalized.contains('verify');
    final mentionsArea =
        normalized.contains('gate') ||
        normalized.contains('entrance') ||
        normalized.contains('perimeter') ||
        normalized.contains('driveway') ||
        normalized.contains('camera') ||
        normalized.contains('cctv');
    final areaReassuranceAsk = _looksLikeAreaReassurancePrompt(normalized);
    final contextualArea = _looksLikeContextualAreaReferencePrompt(normalized);
    return (asksToCheck && (mentionsArea || contextualArea)) ||
        (areaReassuranceAsk && (mentionsArea || contextualArea));
  }

  bool _looksLikeActionRequestPrompt(String normalized) {
    final explicitDispatchAsk =
        normalized.contains('send someone') ||
        normalized.contains('send a guard') ||
        normalized.contains('send guard') ||
        normalized.contains('dispatch someone') ||
        normalized.contains('dispatch a guard') ||
        normalized.contains('have someone') ||
        normalized.contains('have a guard') ||
        normalized.contains('get someone') ||
        normalized.contains('get a guard') ||
        normalized.contains('ask someone') ||
        normalized.contains('ask a guard');
    final softAvailabilityAsk =
        normalized.contains('can someone') ||
        normalized.contains('can a guard');
    final mentionsCheckOrVerify =
        normalized.contains('check') ||
        normalized.contains('look at') ||
        normalized.contains('verify') ||
        normalized.contains('go to');
    final mentionsArea =
        normalized.contains('gate') ||
        normalized.contains('entrance') ||
        normalized.contains('perimeter') ||
        normalized.contains('driveway') ||
        normalized.contains('outside') ||
        normalized.contains('camera') ||
        normalized.contains('cctv');
    return explicitDispatchAsk ||
        (softAvailabilityAsk &&
            (mentionsCheckOrVerify ||
                mentionsArea ||
                _looksLikeContextualAreaReferencePrompt(normalized)));
  }

  bool _looksLikeIncidentClarificationPrompt(String normalized) {
    return normalized.contains('alarm serious') ||
        normalized.contains('that alarm') ||
        normalized.contains('what happened') ||
        _looksLikeHistoricalIncidentReviewPrompt(normalized) ||
        _looksLikeHistoricalAlarmReviewPrompt(normalized) ||
        (_asksWhetherThereWasABreach(normalized) &&
            (normalized.contains('alarm') ||
                normalized.contains('trigger') ||
                _looksLikeIncidentTimingPrompt(normalized))) ||
        normalized.contains('was that') ||
        normalized.contains('same gate') ||
        normalized.contains('same entrance') ||
        normalized.contains('same camera') ||
        normalized.contains('same one') ||
        normalized.contains('same as before') ||
        normalized.contains('as before') ||
        normalized.contains('same issue') ||
        normalized.contains('settle down') ||
        normalized.contains('earlier tonight') ||
        _looksLikeHistoricalResponseArrivalPrompt(normalized) ||
        _looksLikeIncidentOperationalAnchorCalmPrompt(normalized) ||
        _looksLikeIncidentRelativeCalmPrompt(normalized) ||
        normalized.contains('incident serious') ||
        normalized.contains('serious') && normalized.contains('alarm');
  }

  bool _looksLikeIncidentComparisonPrompt(String normalized) {
    return normalized.contains('same gate') ||
        normalized.contains('same entrance') ||
        normalized.contains('same camera') ||
        normalized.contains('same cctv') ||
        normalized.contains('same one') ||
        normalized.contains('same as before') ||
        (normalized.contains('was that') && normalized.contains('before'));
  }

  bool _looksLikeIncidentPersistencePrompt(String normalized) {
    return normalized.contains('same issue') ||
        normalized.contains('still the same') ||
        normalized.contains('still active') ||
        normalized.contains('still going') ||
        normalized.contains('still happening') ||
        normalized.contains('settle down') ||
        normalized.contains('settled down');
  }

  bool _looksLikeIncidentRelativeCalmPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final relativeReference =
        normalized.contains('since then') ||
        normalized.contains('since earlier');
    return asksAboutCalm && relativeReference;
  }

  bool _looksLikeIncidentPatrolAnchoredCalmPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final patrolReference =
        normalized.contains('guard checked') ||
        normalized.contains('guard check') ||
        normalized.contains('patrol passed') ||
        normalized.contains('patrol check') ||
        normalized.contains('they checked it') ||
        normalized.contains('they checked there') ||
        normalized.contains('they checked the gate') ||
        normalized.contains('they looked at it') ||
        normalized.contains('someone checked it') ||
        normalized.contains('someone checked there') ||
        normalized.contains('someone checked that side') ||
        normalized.contains('someone checked the gate') ||
        normalized.contains('someone looked there');
    return asksAboutCalm && patrolReference;
  }

  bool _looksLikeIncidentDispatchAnchoredCalmPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final dispatchReference =
        normalized.contains('dispatch was opened') ||
        normalized.contains('dispatch opened') ||
        normalized.contains('dispatch was opened there') ||
        normalized.contains('dispatch opened there') ||
        normalized.contains('dispatch was opened on that side') ||
        normalized.contains('dispatch opened on that side');
    return asksAboutCalm && dispatchReference;
  }

  bool _looksLikeIncidentResponseArrivalAnchoredCalmPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final responseArrivalReference =
        normalized.contains('response arrived') ||
        normalized.contains('response arrival') ||
        normalized.contains('unit arrived') ||
        normalized.contains('team arrived there') ||
        normalized.contains('team arrived') ||
        normalized.contains('team got there') ||
        normalized.contains('they got there') ||
        normalized.contains('someone got there') ||
        normalized.contains('someone got to') ||
        normalized.contains('guys got there') ||
        normalized.contains('response team got there') ||
        normalized.contains('response team got to');
    return asksAboutCalm && responseArrivalReference;
  }

  bool _looksLikeIncidentCameraReviewAnchoredCalmPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final reviewReference =
        normalized.contains('cameras were reviewed') ||
        normalized.contains('camera was reviewed') ||
        normalized.contains('camera review') ||
        normalized.contains('cameras were checked') ||
        normalized.contains('camera was checked') ||
        normalized.contains('camera check');
    return asksAboutCalm && reviewReference;
  }

  bool _looksLikeIncidentOperationalAnchorCalmPrompt(String normalized) {
    return _looksLikeIncidentPatrolAnchoredCalmPrompt(normalized) ||
        _looksLikeIncidentDispatchAnchoredCalmPrompt(normalized) ||
        _looksLikeIncidentResponseArrivalAnchoredCalmPrompt(normalized) ||
        _looksLikeIncidentCameraReviewAnchoredCalmPrompt(normalized);
  }

  bool _looksLikeIncidentTimingPrompt(String normalized) {
    return normalized.contains('earlier tonight') ||
        normalized.contains('from tonight') ||
        _requestedClockTimeForPrompt(normalized) != null;
  }

  bool _shouldPreferIncidentClarificationPrompt(String normalized) {
    if (!_looksLikeIncidentClarificationPrompt(normalized)) {
      return false;
    }
    return _looksLikeHistoricalIncidentReviewPrompt(normalized) ||
        normalized.contains('alarm') ||
        normalized.contains('what happened') ||
        normalized.contains('trigger') ||
        _requestedClockTimeForPrompt(normalized) != null;
  }

  bool _looksLikeIncidentQuietTimingPrompt(String normalized) {
    return normalized.contains('quiet') &&
        _looksLikeIncidentTimingPrompt(normalized);
  }

  bool _looksLikeObservationConcernPrompt(String normalized) {
    final mentionsConcern =
        normalized.contains('heard') ||
        normalized.contains('noise') ||
        normalized.contains('sound') ||
        normalized.contains('outside') ||
        normalized.contains('someone') ||
        normalized.contains('something') ||
        normalized.contains('movement') ||
        normalized.contains('worried') ||
        normalized.contains('concerned');
    final framesObservation =
        normalized.contains('heard something') ||
        normalized.contains('heard a noise') ||
        normalized.contains('heard noise') ||
        normalized.contains('something outside') ||
        normalized.contains('someone outside') ||
        normalized.contains('movement outside') ||
        normalized.contains('outside my house') ||
        normalized.contains('outside the house') ||
        normalized.contains('outside the site') ||
        normalized.contains('outside here');
    return mentionsConcern && framesObservation;
  }

  bool _looksLikeAreaReassurancePrompt(String normalized) {
    final reassuranceKeyword =
        normalized.contains('okay') ||
        normalized.contains('safe') ||
        normalized.contains('clear') ||
        normalized.contains('quiet') ||
        normalized.contains('calm');
    final reassuranceThen =
        normalized.contains('then') && !normalized.contains('since then');
    final reassuranceTiming =
        normalized.contains('now') ||
        reassuranceThen ||
        normalized.contains('still') ||
        normalized.contains('stayed');
    final reassuranceThere = normalized.contains('there');
    final reassuranceSide = normalized.contains('side');
    final reassuranceOneReference =
        normalized.contains('same one') ||
        normalized.contains('that one') ||
        normalized.contains('other one');
    final reassuranceExplicitCarryoverArea =
        normalized.contains('same gate') ||
        normalized.contains('same entrance') ||
        normalized.contains('same camera') ||
        normalized.contains('same cctv');
    return normalized.contains('okay now') ||
        normalized.contains('okay then') ||
        normalized.contains('safe now') ||
        normalized.contains('safe then') ||
        normalized.contains('clear then') ||
        normalized.contains('clear now') ||
        (reassuranceKeyword &&
            reassuranceTiming &&
            (reassuranceThere ||
                reassuranceSide ||
                reassuranceOneReference ||
                reassuranceExplicitCarryoverArea));
  }

  bool _looksLikeHistoricalCheckPrompt(String normalized) {
    return normalized.contains('did they check') ||
        normalized.contains('did anyone check') ||
        normalized.contains('did someone check') ||
        normalized.contains('someone did check') ||
        normalized.contains('someone has checked') ||
        normalized.contains('did someone check there yet') ||
        normalized.contains('has someone checked') ||
        normalized.contains('has anyone checked') ||
        normalized.contains('still no one has checked') ||
        normalized.contains('no one has checked') ||
        normalized.contains('still no one checked') ||
        normalized.contains('no one checked') ||
        normalized.contains('did they look there') ||
        normalized.contains('did anyone look there') ||
        normalized.contains('did someone look there') ||
        normalized.contains('someone did look there') ||
        normalized.contains('someone has looked there') ||
        normalized.contains('has someone looked there') ||
        normalized.contains('has anyone looked there') ||
        normalized.contains('still no one has looked there') ||
        normalized.contains('no one has looked there') ||
        normalized.contains('still no one looked there') ||
        normalized.contains('no one looked there') ||
        normalized.contains('was it checked') ||
        normalized.contains('was that checked');
  }

  bool _looksLikeHistoricalResponseArrivalPrompt(String normalized) {
    final asksAboutCalm =
        normalized.contains('quiet') || normalized.contains('calm');
    final asksRelativeTimeline =
        normalized.contains('after that') ||
        normalized.contains('since then') ||
        normalized.contains('then');
    return normalized.contains('did they get there') ||
        normalized.contains('did they get to') ||
        normalized.contains('did anyone get there') ||
        normalized.contains('did someone get there') ||
        (!asksAboutCalm && normalized.contains('someone got there')) ||
        (!asksAboutCalm &&
            asksRelativeTimeline &&
            normalized.contains('still someone there')) ||
        normalized.contains('someone did get there') ||
        normalized.contains('someone is there') ||
        normalized.contains('did anyone get to') ||
        normalized.contains('did someone get to') ||
        (!asksAboutCalm && normalized.contains('someone got to')) ||
        normalized.contains('someone did get to') ||
        (!asksAboutCalm &&
            asksRelativeTimeline &&
            (normalized.contains('someone on that side') ||
                normalized.contains('someone on the other side') ||
                normalized.contains('someone over there'))) ||
        (!asksAboutCalm &&
            asksRelativeTimeline &&
            normalized.contains('still someone over there')) ||
        normalized.contains('still no one there') ||
        normalized.contains('still no one on that side') ||
        normalized.contains('still no one over there') ||
        normalized.contains('still no one got there') ||
        normalized.contains('still no one got to') ||
        normalized.contains('no one on that side') ||
        normalized.contains('no one got there') ||
        normalized.contains('no one got to') ||
        normalized.contains('did team get there') ||
        normalized.contains('did the team get there') ||
        normalized.contains('did response team get there') ||
        normalized.contains('did they arrive') ||
        normalized.contains('did they arrive yet there') ||
        normalized.contains('did anyone arrive') ||
        normalized.contains('did someone arrive') ||
        normalized.contains('someone did arrive') ||
        normalized.contains('someone has arrived') ||
        normalized.contains('no one arrived') ||
        normalized.contains('did team arrive') ||
        normalized.contains('did the team arrive') ||
        normalized.contains('has response arrived') ||
        normalized.contains('has the team arrived');
  }

  bool _looksLikeContextualAreaReferencePrompt(String normalized) {
    final carriesForwardThere =
        normalized.contains('there') &&
        !normalized.contains('there was') &&
        !normalized.contains('there were') &&
        (normalized.contains('check') ||
            normalized.contains('look') ||
            normalized.contains('verify') ||
            normalized.contains('send someone') ||
            normalized.contains('send a guard') ||
            normalized.contains('send guard') ||
            normalized.contains('dispatch someone') ||
            normalized.contains('dispatch a guard') ||
            normalized.contains('have someone') ||
            normalized.contains('have a guard') ||
            normalized.contains('get someone') ||
            normalized.contains('get a guard') ||
            normalized.contains('can someone') ||
            normalized.contains('can a guard') ||
            _looksLikeAreaReassurancePrompt(normalized));
    return normalized.contains('same gate') ||
        normalized.contains('same entrance') ||
        normalized.contains('same camera') ||
        normalized.contains('same cctv') ||
        normalized.contains('same one') ||
        normalized.contains('same side') ||
        normalized.contains('other gate') ||
        normalized.contains('other entrance') ||
        normalized.contains('other camera') ||
        normalized.contains('other one') ||
        normalized.contains('that side') ||
        normalized.contains('other side') ||
        normalized.contains('over there') ||
        normalized.contains('that gate') ||
        normalized.contains('that entrance') ||
        normalized.contains('that camera') ||
        normalized.contains('that one') ||
        normalized.contains('far side') ||
        normalized.contains('driveway side') ||
        normalized.contains('perimeter side') ||
        normalized.contains('entrance side') ||
        normalized.contains('gate side') ||
        normalized.contains('camera side') ||
        normalized.contains('left side') ||
        normalized.contains('right side') ||
        normalized.contains('left one') ||
        normalized.contains('right one') ||
        normalized.contains('back one') ||
        normalized.contains('front one') ||
        normalized.contains('one by the driveway') ||
        normalized.contains('by the driveway') ||
        normalized.contains('near the driveway') ||
        normalized.contains('one by the perimeter') ||
        normalized.contains('by the perimeter') ||
        normalized.contains('near the perimeter') ||
        normalized.contains('one by the entrance') ||
        normalized.contains('by the entrance') ||
        normalized.contains('near the entrance') ||
        normalized.contains('one by the gate') ||
        normalized.contains('by the gate') ||
        normalized.contains('near the gate') ||
        normalized.contains('one by the camera') ||
        normalized.contains('by the camera') ||
        normalized.contains('near the camera') ||
        normalized.contains('near the back') ||
        normalized.contains('near back') ||
        normalized.contains('by the back') ||
        normalized.contains('near the front') ||
        normalized.contains('near front') ||
        normalized.contains('by the front') ||
        carriesForwardThere;
  }

  bool _looksLikeWholeSiteReviewPrompt(String normalized) {
    final asksToCheck =
        normalized.contains('check') ||
        normalized.contains('look') ||
        normalized.contains('review') ||
        normalized.contains('verify') ||
        normalized.contains('sweep');
    final broadCoverage =
        normalized.contains('every area') ||
        normalized.contains('all areas') ||
        normalized.contains('whole site') ||
        normalized.contains('entire site') ||
        normalized.contains('whole property') ||
        normalized.contains('entire property');
    return asksToCheck && broadCoverage;
  }

  bool _looksLikeWholeSiteBreachReviewPrompt(String normalized) {
    final asksToCheck =
        normalized.contains('check') ||
        normalized.contains('look') ||
        normalized.contains('review') ||
        normalized.contains('verify') ||
        normalized.contains('sweep');
    final mentionsSiteWideScope =
        normalized.contains('site') ||
        normalized.contains('property') ||
        normalized.contains('premises') ||
        normalized.contains('premis');
    return asksToCheck &&
        mentionsSiteWideScope &&
        _asksWhetherThereWasABreach(normalized);
  }

  bool _looksLikeHistoricalAlarmReviewPrompt(String normalized) {
    final asksToReview =
        normalized.contains('check') ||
        normalized.contains('look') ||
        normalized.contains('review') ||
        normalized.contains('verify');
    final mentionsHistoricalWindow =
        normalized.contains('last night') ||
        normalized.contains('earlier last night') ||
        normalized.contains('while setup was live') ||
        normalized.contains('while the setup was live') ||
        _requestedClockTimeForPrompt(normalized) != null;
    final mentionsAlarmOrScene =
        normalized.contains('alarm') ||
        normalized.contains('trigger') ||
        normalized.contains('activity') ||
        normalized.contains('camera') ||
        normalized.contains('cctv') ||
        normalized.contains('outdoor') ||
        normalized.contains('perimeter');
    return asksToReview && mentionsHistoricalWindow && mentionsAlarmOrScene;
  }

  bool _looksLikeHistoricalIncidentReviewPrompt(String normalized) {
    final mentionsHistoricalIncident =
        normalized.contains('robbery') ||
        normalized.contains('robbed') ||
        normalized.contains('theft') ||
        normalized.contains('burglary') ||
        normalized.contains('stolen');
    if (!mentionsHistoricalIncident) {
      return false;
    }
    final hasHistoricalCue =
        normalized.contains('earlier today') ||
        normalized.contains('earlier') ||
        normalized.contains('took place') ||
        normalized.contains('happened') ||
        normalized.contains('that occurred');
    final asksAwarenessOrReview =
        normalized.contains('are you aware') ||
        normalized.contains('were you aware') ||
        normalized.contains('did you know about') ||
        normalized.contains('asking if you were aware') ||
        normalized.contains('asking if') ||
        normalized.contains('what happened') ||
        normalized.contains('review') ||
        normalized.contains('recap');
    return hasHistoricalCue && asksAwarenessOrReview;
  }

  bool _asksWhetherThereWasABreach(String normalized) {
    return normalized.contains('breach') ||
        normalized.contains('break in') ||
        normalized.contains('breakin') ||
        normalized.contains('intrusion');
  }

  String _historicalReviewScopeLabel(
    String normalizedPrompt,
    String? contextAreaLabel,
  ) {
    final mentionsOutdoorCameras =
        normalizedPrompt.contains('outdoor camera') ||
        normalizedPrompt.contains('outdoor cameras');
    if (mentionsOutdoorCameras && contextAreaLabel != null) {
      return '$contextAreaLabel or the outdoor cameras';
    }
    if (mentionsOutdoorCameras) {
      return 'the outdoor cameras';
    }
    return contextAreaLabel ?? 'that area';
  }

  _ContextAreaResolution _resolvedAreaForRequest(
    OnyxTelegramCommandRequest request,
  ) {
    final normalizedPrompt = _normalizedNaturalPrompt(request.prompt);
    final directArea = _areaHintFromPrompt(request.prompt);
    final contextAreas = _contextAreaHintsForRequest(request);
    final directionalAlias =
        normalizedPrompt.contains('front one') ||
        normalizedPrompt.contains('back one');
    final prefersContextualCarryover =
        _looksLikeContextualAreaReferencePrompt(normalizedPrompt) ||
        _looksLikeIncidentComparisonPrompt(normalizedPrompt) ||
        _looksLikeIncidentPersistencePrompt(normalizedPrompt) ||
        _looksLikeHistoricalResponseArrivalPrompt(normalizedPrompt) ||
        _looksLikeIncidentOperationalAnchorCalmPrompt(normalizedPrompt) ||
        _looksLikeIncidentRelativeCalmPrompt(normalizedPrompt) ||
        _looksLikeIncidentTimingPrompt(normalizedPrompt);
    final candidateAreas = contextAreas
        .where((area) => _promptCanUseContextArea(normalizedPrompt, area))
        .toList(growable: false);
    final typedCarryoverAmbiguous =
        _looksLikeTypedAreaCarryoverPrompt(normalizedPrompt) &&
        candidateAreas.length >= 2;
    if ((typedCarryoverAmbiguous ||
            _looksLikeAmbiguousContextualAreaPrompt(normalizedPrompt)) &&
        (candidateAreas.length >= 2 ||
            (_canFallbackToBroadContextAmbiguity(normalizedPrompt) &&
                contextAreas.length >= 2))) {
      final ambiguousAreas =
          (typedCarryoverAmbiguous || candidateAreas.length >= 2)
          ? candidateAreas.take(2).toList(growable: false)
          : contextAreas.take(2).toList(growable: false);
      return _ContextAreaResolution(ambiguousAreas: ambiguousAreas);
    }
    if (directArea != null) {
      final prefersContextualUpgrade =
          prefersContextualCarryover &&
          (directArea == 'gate' ||
              directArea == 'entrance' ||
              directArea == 'camera' ||
              directArea == 'cctv' ||
              directionalAlias);
      if (!prefersContextualUpgrade) {
        return _ContextAreaResolution(area: directArea);
      }
    }
    if (!prefersContextualCarryover) {
      return _ContextAreaResolution(area: directArea);
    }
    if (candidateAreas.isNotEmpty) {
      return _ContextAreaResolution(area: candidateAreas.first);
    }
    return _ContextAreaResolution(area: directArea);
  }

  List<String> _contextAreaHintsForRequest(OnyxTelegramCommandRequest request) {
    final areas = <String>[];
    void addArea(String? area) {
      final cleaned = (area ?? '').trim();
      if (cleaned.isEmpty || areas.contains(cleaned)) {
        return;
      }
      areas.add(cleaned);
    }

    addArea(_areaHintFromPrompt(request.replyToText ?? ''));
    for (final raw in request.recentThreadContextTexts) {
      addArea(_areaHintFromPrompt(raw));
    }
    return areas;
  }

  String? _areaHintFromPrompt(String prompt) {
    final normalized = _normalizedNaturalPrompt(prompt);
    if (normalized.contains('left entrance')) {
      return 'left entrance';
    }
    if (normalized.contains('right entrance')) {
      return 'right entrance';
    }
    if (normalized.contains('front entrance')) {
      return 'front entrance';
    }
    if (normalized.contains('main entrance')) {
      return 'main entrance';
    }
    if (normalized.contains('back entrance')) {
      return 'back entrance';
    }
    if (normalized.contains('left gate')) {
      return 'left gate';
    }
    if (normalized.contains('right gate')) {
      return 'right gate';
    }
    if (normalized.contains('front gate')) {
      return 'front gate';
    }
    if (normalized.contains('main gate')) {
      return 'main gate';
    }
    if (normalized.contains('back gate')) {
      return 'back gate';
    }
    if (normalized.contains('front one')) {
      return 'front gate';
    }
    if (normalized.contains('back one')) {
      return 'back gate';
    }
    if (normalized.contains('left camera')) {
      return 'left camera';
    }
    if (normalized.contains('right camera')) {
      return 'right camera';
    }
    if (normalized.contains('front camera')) {
      return 'front camera';
    }
    if (normalized.contains('main camera')) {
      return 'main camera';
    }
    if (normalized.contains('back camera')) {
      return 'back camera';
    }
    if (normalized.contains('left cctv')) {
      return 'left cctv';
    }
    if (normalized.contains('right cctv')) {
      return 'right cctv';
    }
    if (normalized.contains('front cctv')) {
      return 'front cctv';
    }
    if (normalized.contains('main cctv')) {
      return 'main cctv';
    }
    if (normalized.contains('back cctv')) {
      return 'back cctv';
    }
    if (normalized.contains('gate')) {
      return 'gate';
    }
    if (normalized.contains('entrance')) {
      return 'entrance';
    }
    if (normalized.contains('perimeter')) {
      return 'perimeter';
    }
    if (normalized.contains('driveway')) {
      return 'driveway';
    }
    if (normalized.contains('camera')) {
      return 'camera';
    }
    if (normalized.contains('cctv')) {
      return 'cctv';
    }
    return null;
  }

  bool _promptCanUseContextArea(String normalizedPrompt, String area) {
    final normalizedArea = area.trim().toLowerCase();
    if (normalizedArea.isEmpty) {
      return false;
    }
    if (normalizedPrompt.contains('left side') ||
        normalizedPrompt.contains('left one')) {
      return normalizedArea.startsWith('left ');
    }
    if (normalizedPrompt.contains('right side') ||
        normalizedPrompt.contains('right one')) {
      return normalizedArea.startsWith('right ');
    }
    if (normalizedPrompt.contains('front one') ||
        normalizedPrompt.contains('near the front') ||
        normalizedPrompt.contains('near front') ||
        normalizedPrompt.contains('by the front')) {
      return normalizedArea.startsWith('front ');
    }
    if (normalizedPrompt.contains('back one') ||
        normalizedPrompt.contains('near the back') ||
        normalizedPrompt.contains('near back') ||
        normalizedPrompt.contains('by the back')) {
      return normalizedArea.startsWith('back ');
    }
    if (normalizedPrompt.contains('driveway')) {
      return normalizedArea.contains('driveway');
    }
    if (normalizedPrompt.contains('perimeter')) {
      return normalizedArea.contains('perimeter');
    }
    if (normalizedPrompt.contains('entrance') &&
        !normalizedArea.contains('entrance')) {
      return false;
    }
    if (normalizedPrompt.contains('gate') && !normalizedArea.contains('gate')) {
      return false;
    }
    final cameraWordActsAsAreaHint =
        (normalizedPrompt.contains('camera') ||
            normalizedPrompt.contains('cctv')) &&
        !_looksLikeIncidentCameraReviewAnchoredCalmPrompt(normalizedPrompt);
    if (cameraWordActsAsAreaHint &&
        !(normalizedArea.contains('camera') ||
            normalizedArea.contains('cctv'))) {
      return false;
    }
    return true;
  }

  bool _looksLikeAmbiguousContextualAreaPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('other one') ||
        normalizedPrompt.contains('that one') ||
        normalizedPrompt.contains('other gate') ||
        normalizedPrompt.contains('other entrance') ||
        normalizedPrompt.contains('other camera') ||
        normalizedPrompt.contains('far side') ||
        normalizedPrompt.contains('that side') ||
        normalizedPrompt.contains('over there') ||
        normalizedPrompt.contains('left side') ||
        normalizedPrompt.contains('right side') ||
        normalizedPrompt.contains('other side');
  }

  bool _canFallbackToBroadContextAmbiguity(String normalizedPrompt) {
    return normalizedPrompt.contains('far side') ||
        normalizedPrompt.contains('that side') ||
        normalizedPrompt.contains('over there') ||
        normalizedPrompt.contains('other side') ||
        normalizedPrompt.contains('left side') ||
        normalizedPrompt.contains('right side');
  }

  bool _looksLikeTypedAreaCarryoverPrompt(String normalizedPrompt) {
    return normalizedPrompt.contains('same gate') ||
        normalizedPrompt.contains('same entrance') ||
        normalizedPrompt.contains('same camera') ||
        normalizedPrompt.contains('same cctv') ||
        normalizedPrompt.contains('driveway side') ||
        normalizedPrompt.contains('perimeter side') ||
        normalizedPrompt.contains('entrance side') ||
        normalizedPrompt.contains('gate side') ||
        normalizedPrompt.contains('camera side') ||
        normalizedPrompt.contains('one by the driveway') ||
        normalizedPrompt.contains('by the driveway') ||
        normalizedPrompt.contains('near the driveway') ||
        normalizedPrompt.contains('one by the perimeter') ||
        normalizedPrompt.contains('by the perimeter') ||
        normalizedPrompt.contains('near the perimeter') ||
        normalizedPrompt.contains('one by the entrance') ||
        normalizedPrompt.contains('by the entrance') ||
        normalizedPrompt.contains('near the entrance') ||
        normalizedPrompt.contains('one by the gate') ||
        normalizedPrompt.contains('by the gate') ||
        normalizedPrompt.contains('near the gate') ||
        normalizedPrompt.contains('one by the camera') ||
        normalizedPrompt.contains('by the camera') ||
        normalizedPrompt.contains('near the camera');
  }

  String _ambiguousAreaLead(List<String> ambiguousAreas) {
    final labels = ambiguousAreas
        .map(_humanizeAreaLabel)
        .where((label) => label.trim().isNotEmpty)
        .toList(growable: false);
    if (labels.length < 2) {
      return 'I’m not fully certain which area you mean.';
    }
    return 'I’m not fully certain whether you mean ${labels[0]} or ${labels[1]}.';
  }

  IntelligenceReceived? _findAreaMatchedIntelligence({
    required String area,
    required List<IntelligenceReceived> intelligence,
  }) {
    final normalizedArea = _normalizedCommandToken(area);
    for (final event in intelligence) {
      final combined = _normalizedCommandToken(
        '${event.zone ?? ''} ${event.headline} ${event.summary} ${event.cameraId ?? ''}',
      );
      if (normalizedArea.isNotEmpty && combined.contains(normalizedArea)) {
        return event;
      }
    }
    return null;
  }

  PatrolCompleted? _findAreaMatchedPatrol({
    required String area,
    required List<PatrolCompleted> patrols,
  }) {
    final normalizedArea = _normalizedCommandToken(area);
    for (final patrol in patrols) {
      final combined = _normalizedCommandToken(
        '${patrol.routeId} ${patrol.guardId}',
      );
      if (normalizedArea.isNotEmpty && combined.contains(normalizedArea)) {
        return patrol;
      }
    }
    return null;
  }

  DecisionCreated? _bestDecisionForArea({
    required String area,
    required List<DecisionCreated> decisions,
    required List<IntelligenceReceived> intelligence,
  }) {
    for (final decision in decisions) {
      final bestIntel = _bestIntelForDecision(
        decision: decision,
        intelligence: intelligence,
      );
      if (bestIntel != null && _intelligenceSuggestsArea(bestIntel, area)) {
        return decision;
      }
    }
    return decisions.length == 1 ? decisions.first : null;
  }

  IntelligenceReceived? _findOperationalMarkerIntelligence({
    required List<IntelligenceReceived> intelligence,
    required bool Function(IntelligenceReceived) matchesMarker,
    String? area,
  }) {
    for (final event in intelligence) {
      if (area != null && !_intelligenceSuggestsArea(event, area)) {
        continue;
      }
      if (matchesMarker(event)) {
        return event;
      }
    }
    if (area != null) {
      return null;
    }
    for (final event in intelligence) {
      if (matchesMarker(event)) {
        return event;
      }
    }
    return null;
  }

  bool _isResponseArrivalIntelligence(IntelligenceReceived intelligence) {
    final combined = _normalizedCommandToken(
      '${intelligence.zone ?? ''} ${intelligence.headline} ${intelligence.summary}',
    );
    return combined.contains('responsearrival') ||
        combined.contains('responseunitarrived') ||
        combined.contains('fieldresponseunitarrived');
  }

  bool _isCameraReviewMarkerIntelligence(IntelligenceReceived intelligence) {
    final combined = _normalizedCommandToken(
      '${intelligence.zone ?? ''} ${intelligence.headline} ${intelligence.summary}',
    );
    return combined.contains('camerareview') ||
        combined.contains('reviewedcamera') ||
        combined.contains('cameracheck') ||
        combined.contains('checkedcamera');
  }

  IntelligenceReceived? _bestIntelForDecision({
    required DecisionCreated decision,
    required List<IntelligenceReceived> intelligence,
  }) {
    for (final event in intelligence) {
      if (event.occurredAt.isAfter(decision.occurredAt)) {
        continue;
      }
      if (decision.occurredAt.difference(event.occurredAt).abs() >
          const Duration(hours: 6)) {
        continue;
      }
      return event;
    }
    return intelligence.isEmpty ? null : intelligence.first;
  }

  bool _decisionMatchesArea({
    required DecisionCreated? decision,
    required String area,
    required IntelligenceReceived intelligence,
  }) {
    if (decision == null) {
      return false;
    }
    final combined = _normalizedCommandToken(
      '${intelligence.zone ?? ''} ${intelligence.headline} ${intelligence.summary}',
    );
    return combined.contains(_normalizedCommandToken(area));
  }

  bool _intelligenceSuggestsArea(
    IntelligenceReceived intelligence,
    String area,
  ) {
    final combined = _normalizedCommandToken(
      '${intelligence.zone ?? ''} ${intelligence.headline} ${intelligence.summary} ${intelligence.cameraId ?? ''}',
    );
    return combined.contains(_normalizedCommandToken(area));
  }

  String _intelligenceLead(IntelligenceReceived event) {
    final structured = _structuredIntelligenceLead(event);
    if (structured != null) {
      return structured;
    }
    final combined = _clientSafeIntelligenceDetail(
      event,
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (combined.isEmpty) {
      return 'an operational signal';
    }
    final sentence = _clipClientLead(combined, maxLength: 120);
    final lowered = sentence[0].toLowerCase() + sentence.substring(1);
    return lowered.endsWith('.')
        ? lowered.substring(0, lowered.length - 1)
        : lowered;
  }

  String? _movementStatusLead(IntelligenceReceived event) {
    final lead = _intelligenceLead(event);
    final normalizedLead = lead.trim().toLowerCase();
    if (normalizedLead.isEmpty) {
      return null;
    }
    if (normalizedLead.contains('video-loss') ||
        normalizedLead.contains('recorder event') ||
        normalizedLead.contains('recorder signal')) {
      return null;
    }
    if (normalizedLead.contains('movement') ||
        normalizedLead.contains('motion') ||
        normalizedLead.contains('intrusion') ||
        normalizedLead.contains('line-crossing')) {
      return lead;
    }
    return null;
  }

  String _visualQualificationForCurrentReply({
    OnyxTelegramCommandRequest? request,
    String? siteReference,
    String? areaLabel,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    final packet = cameraHealthFactPacket;
    final scopedArea = (areaLabel ?? '').trim();
    final effectiveSiteReference =
        (siteReference ??
                (request == null ? '' : _scopeLabelForRequest(request)))
            .trim();
    if (request != null && _recentThreadShowsUnusableCurrentImage(request)) {
      return 'I do not have a usable current image to share right now.';
    }
    final downCameraLabel = request == null
        ? null
        : _recentThreadDownCameraLabel(request);
    if (downCameraLabel != null &&
        packet != null &&
        packet.status == ClientCameraHealthStatus.live &&
        effectiveSiteReference.isNotEmpty) {
      return 'We still have some visual coverage at $effectiveSiteReference, but $downCameraLabel is down.';
    }
    if (packet != null && packet.status == ClientCameraHealthStatus.live) {
      if (effectiveSiteReference.isEmpty) {
        return 'We currently have visual confirmation right now.';
      }
      return 'We currently have visual confirmation at $effectiveSiteReference.';
    }
    if (scopedArea.isEmpty) {
      return 'I do not have live visual confirmation right now.';
    }
    return 'I do not have live visual confirmation on $scopedArea right now.';
  }

  String _statusVisualQualificationForCurrentReply({
    required OnyxTelegramCommandRequest request,
    required String siteReference,
    ClientCameraHealthFactPacket? cameraHealthFactPacket,
  }) {
    return _visualQualificationForCurrentReply(
      request: request,
      siteReference: siteReference,
      cameraHealthFactPacket: cameraHealthFactPacket,
    );
  }

  String? _packetizedIssueSummaryLine({
    required ClientCameraHealthFactPacket? cameraHealthFactPacket,
    String? areaLabel,
  }) {
    final label = cameraHealthFactPacket?.operatorIssueSignalLabel(
      preferredAreaLabel: areaLabel,
    );
    if (label == null || label.trim().isEmpty) {
      return null;
    }
    return 'The current operational picture still shows ${label.trim()}.';
  }

  bool _recentThreadShowsUnusableCurrentImage(
    OnyxTelegramCommandRequest request,
  ) {
    final combined = [
      request.replyToText ?? '',
      ...request.recentThreadContextTexts,
    ].join('\n').trim().toLowerCase();
    if (combined.isEmpty) {
      return false;
    }
    return combined.contains('do not have a usable current verified image') ||
        combined.contains('could not attach the current frame') ||
        combined.contains(
          'do not have a current verified image to send right now',
        );
  }

  bool _recentThreadShowsCameraDown(OnyxTelegramCommandRequest request) {
    return _recentThreadDownCameraLabel(request) != null;
  }

  String? _recentThreadDownCameraLabel(OnyxTelegramCommandRequest request) {
    final combined = [
      request.replyToText ?? '',
      ...request.recentThreadContextTexts,
    ].join('\n').trim().toLowerCase();
    if (combined.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'camera\s+(\d+)\s+(?:(?:is|was)\s+)?(?:currently\s+)?(?:down|offline)',
    ).firstMatch(combined);
    final digits = match?.group(1) ?? '';
    if (digits.isEmpty) {
      return null;
    }
    return 'Camera $digits';
  }

  bool _isDirectSafetyAsk(String normalizedPrompt) {
    return normalizedPrompt.contains('safe') ||
        normalizedPrompt.contains('secure');
  }

  String _areaRiskLabel(String area) {
    final normalized = area.trim().toLowerCase();
    if (normalized == 'gate' ||
        normalized == 'front gate' ||
        normalized == 'main gate' ||
        normalized == 'back gate') {
      return '$normalized-related';
    }
    return normalized;
  }

  String _humanizeAreaLabel(String area) {
    final cleaned = area.trim();
    if (cleaned.isEmpty) {
      return 'that area';
    }
    return cleaned
        .split(' ')
        .map(
          (token) => token.isEmpty
              ? token
              : '${token[0].toUpperCase()}${token.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _bestAreaLabelForReply({
    required String fallbackAreaLabel,
    required IntelligenceReceived? intelligence,
  }) {
    final normalizedArea = fallbackAreaLabel.trim().toLowerCase();
    if ((normalizedArea == 'camera' || normalizedArea == 'cctv') &&
        intelligence != null) {
      final cameraLabel = _humanizeCameraLabel(intelligence.cameraId);
      if (cameraLabel != null) {
        return cameraLabel;
      }
    }
    return fallbackAreaLabel;
  }

  String? _structuredIntelligenceLead(IntelligenceReceived event) {
    final headline = event.headline.trim();
    final summary = event.summary.trim();
    final normalized = _normalizedCommandToken(
      '$headline $summary ${event.objectLabel ?? ''}',
    );
    final provider = event.provider.trim().toLowerCase();
    final semanticLead = _semanticIntelligenceLead(event);
    if (semanticLead != null &&
        (provider.contains('_yolo') ||
            provider.contains('_fr') ||
            provider.contains('_lpr') ||
            (event.objectLabel ?? '').trim().isNotEmpty ||
            (event.faceMatchId ?? '').trim().isNotEmpty ||
            (event.plateNumber ?? '').trim().isNotEmpty)) {
      return semanticLead;
    }
    final metadataHeavy =
        summary.toLowerCase().contains('provider:') ||
        headline.contains('_') ||
        normalized.contains('videoevent') ||
        normalized.contains('videoloss');
    if (!metadataHeavy) {
      return null;
    }
    final cameraLabel = _humanizeCameraLabel(event.cameraId);
    String lead;
    if (normalized.contains('videoloss')) {
      lead = 'a video-loss signal';
    } else if ((event.objectLabel ?? '').trim().toLowerCase() == 'person') {
      lead = 'person movement';
    } else if ((event.objectLabel ?? '').trim().toLowerCase() == 'vehicle') {
      lead = 'vehicle movement';
    } else if (normalized.contains('motion')) {
      lead = 'motion';
    } else if (normalized.contains('intrusion')) {
      lead = 'an intrusion signal';
    } else if (normalized.contains('linecross')) {
      lead = 'a line-crossing signal';
    } else if (normalized.contains('videoevent')) {
      lead = 'a recorder event';
    } else {
      lead = 'a recorder signal';
    }
    if (cameraLabel != null) {
      return '$lead on $cameraLabel';
    }
    final zoneLabel = _cleanStructuredZoneLabel(event.zone);
    if (zoneLabel != null) {
      return '$lead near $zoneLabel';
    }
    return lead;
  }

  String? _semanticIntelligenceLead(IntelligenceReceived event) {
    final objectLabel = (event.objectLabel ?? '').trim().toLowerCase();
    final cameraLabel = _humanizeCameraLabel(event.cameraId);
    final zoneLabel = _cleanStructuredZoneLabel(event.zone);
    final locationLabel = cameraLabel ?? zoneLabel;
    final faceMatchId = (event.faceMatchId ?? '').trim().toUpperCase();
    final plateNumber = (event.plateNumber ?? '').trim().toUpperCase();

    String? lead;
    switch (objectLabel) {
      case 'person':
      case 'human':
      case 'intruder':
        lead = 'person movement';
        break;
      case 'vehicle':
      case 'car':
      case 'truck':
        lead = 'vehicle movement';
        break;
      case 'animal':
      case 'dog':
      case 'cat':
      case 'bird':
        lead = 'animal movement';
        break;
      case 'backpack':
        lead = 'a backpack signal';
        break;
      case 'bag':
        lead = 'a bag signal';
        break;
      case 'knife':
        lead = 'a potential weapon signal';
        break;
      case 'weapon':
      case 'firearm':
        lead = 'a potential threat signal';
        break;
    }

    if (lead == null && faceMatchId.isNotEmpty) {
      lead = 'a matched person signal';
    }
    if (lead == null && plateNumber.isNotEmpty) {
      lead = 'a vehicle signal';
    }
    if (lead == null) {
      return null;
    }
    if (locationLabel != null && locationLabel.trim().isNotEmpty) {
      return '$lead on $locationLabel';
    }
    return lead;
  }

  String _clientSafeIntelligenceDetail(IntelligenceReceived event) {
    final combined = '${event.headline.trim()} ${event.summary.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (combined.isEmpty) {
      return combined;
    }
    return combined
        .replaceAll(
          RegExp(r'\b(?:yolo|ultralytics)\b', caseSensitive: false),
          'ONYX',
        )
        .replaceAll(
          RegExp(r'\bface recognition\b', caseSensitive: false),
          'ONYX matching',
        )
        .replaceAll(
          RegExp(r'\blicense plate recognition\b', caseSensitive: false),
          'ONYX plate matching',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _clipClientLead(String value, {required int maxLength}) {
    if (value.length <= maxLength) {
      return value;
    }
    final hardLimit = maxLength - 1;
    final candidate = value.substring(0, hardLimit).trimRight();
    final punctuationMatches = RegExp(r'[.!?](?=\s|$)').allMatches(candidate);
    if (punctuationMatches.isNotEmpty) {
      final lastBoundary = punctuationMatches.last.end;
      if (lastBoundary >= (maxLength * 0.55).round()) {
        return candidate.substring(0, lastBoundary).trimRight();
      }
    }
    final whitespaceBoundary = candidate.lastIndexOf(RegExp(r'\s'));
    if (whitespaceBoundary >= (maxLength * 0.55).round()) {
      return '${candidate.substring(0, whitespaceBoundary).trimRight()}...';
    }
    return '${candidate.trimRight()}...';
  }

  String? _humanizeCameraLabel(String? rawCameraId) {
    final trimmed = (rawCameraId ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final channelMatch = RegExp(
      r'channel-(\d+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (channelMatch != null) {
      return 'Camera ${channelMatch.group(1)}';
    }
    final normalized = trimmed
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lowered = normalized.toLowerCase();
    if (lowered.startsWith('camera ')) {
      final suffix = normalized.substring('camera '.length).trim();
      if (suffix.isNotEmpty) {
        return '${_humanizeAreaLabel(suffix)} Camera';
      }
    }
    if (lowered.startsWith('cam ')) {
      final suffix = normalized.substring('cam '.length).trim();
      if (suffix.isNotEmpty) {
        return '${_humanizeAreaLabel(suffix)} Camera';
      }
    }
    return _humanizeAreaLabel(normalized);
  }

  String? _cleanStructuredZoneLabel(String? rawZone) {
    final trimmed = (rawZone ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lowered = trimmed.toLowerCase();
    if (lowered.contains('provider:') || lowered.contains('channel-')) {
      return null;
    }
    return _humanizeAreaLabel(trimmed);
  }

  String _seriousnessLeadForIntelligence(IntelligenceReceived? event) {
    if (event == null) {
      return 'It was treated as a live signal.';
    }
    if (event.riskScore >= 80) {
      return 'It was treated as a serious signal.';
    }
    if (event.riskScore >= 60) {
      return 'It was treated as an operational signal that warranted review.';
    }
    return 'It was treated as a signal worth review.';
  }

  bool _occurredEarlierTonight(DateTime occurredAt) {
    final localNow = now().toLocal();
    final localOccurredAt = occurredAt.toLocal();
    final DateTime start;
    final DateTime end;
    if (localNow.hour >= 18) {
      start = DateTime(localNow.year, localNow.month, localNow.day, 18);
      end = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).add(const Duration(days: 1, hours: 6));
    } else {
      end = DateTime(localNow.year, localNow.month, localNow.day, 6);
      start = DateTime(
        end.year,
        end.month,
        end.day,
      ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
    }
    return !localOccurredAt.isBefore(start) && localOccurredAt.isBefore(end);
  }

  ({int hour, int minute})? _requestedClockTimeForPrompt(String normalized) {
    final detailed = RegExp(
      r'\b(?:around|about|at)?\s*(\d{1,2})\s+(\d{2})\s*(am|pm)\b',
    ).firstMatch(normalized);
    if (detailed != null) {
      final hour = int.tryParse(detailed.group(1)!);
      final minute = int.tryParse(detailed.group(2)!);
      final meridiem = detailed.group(3)!;
      if (hour == null || minute == null || hour > 12 || minute > 59) {
        return null;
      }
      return _to24HourClock(hour: hour, minute: minute, meridiem: meridiem);
    }
    final simple = RegExp(
      r'\b(?:around|about|at)?\s*(\d{1,2})\s*(am|pm)\b',
    ).firstMatch(normalized);
    if (simple == null) {
      return null;
    }
    final hour = int.tryParse(simple.group(1)!);
    final meridiem = simple.group(2)!;
    if (hour == null || hour > 12) {
      return null;
    }
    return _to24HourClock(hour: hour, minute: 0, meridiem: meridiem);
  }

  ({int hour, int minute}) _to24HourClock({
    required int hour,
    required int minute,
    required String meridiem,
  }) {
    final normalizedHour = hour % 12;
    final converted = meridiem == 'pm' ? normalizedHour + 12 : normalizedHour;
    return (hour: converted, minute: minute);
  }

  IntelligenceReceived? _findIntelligenceNearRequestedClockTime({
    required List<IntelligenceReceived> intelligence,
    required ({int hour, int minute}) requestedClockTime,
  }) {
    if (intelligence.isEmpty) {
      return null;
    }
    final requestedMinutes =
        requestedClockTime.hour * 60 + requestedClockTime.minute;
    IntelligenceReceived? bestMatch;
    var bestDelta = 24 * 60;
    for (final event in intelligence) {
      final local = event.occurredAt.toLocal();
      final eventMinutes = local.hour * 60 + local.minute;
      final delta = (eventMinutes - requestedMinutes).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestMatch = event;
      }
    }
    if (bestDelta > 75) {
      return null;
    }
    return bestMatch;
  }

  String _clockTimeLabel(({int hour, int minute}) clockTime) {
    final hh = clockTime.hour.toString().padLeft(2, '0');
    final mm = clockTime.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

enum _ConversationalOperationalIntent {
  statusReassurance,
  actionRequest,
  verification,
  observationConcern,
  incidentClarification,
}

class _ContextAreaResolution {
  final String? area;
  final List<String> ambiguousAreas;

  const _ContextAreaResolution({
    this.area,
    this.ambiguousAreas = const <String>[],
  });

  bool get isAmbiguous => ambiguousAreas.length >= 2;
}

class _RequestTruthSnapshot {
  final List<DecisionCreated> decisions;
  final List<DecisionCreated> unresolvedDecisions;
  final List<IncidentClosed> closedIncidents;
  final List<IntelligenceReceived> intelligence;
  final List<PatrolCompleted> patrols;

  const _RequestTruthSnapshot({
    required this.decisions,
    required this.unresolvedDecisions,
    required this.closedIncidents,
    required this.intelligence,
    required this.patrols,
  });

  DecisionCreated? get latestDecision =>
      decisions.isEmpty ? null : decisions.first;

  IncidentClosed? get latestClosedIncident =>
      closedIncidents.isEmpty ? null : closedIncidents.first;

  IntelligenceReceived? get latestIntelligence =>
      intelligence.isEmpty ? null : intelligence.first;

  PatrolCompleted? get latestPatrol => patrols.isEmpty ? null : patrols.first;
}
