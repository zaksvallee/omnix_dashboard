import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:omnix_dashboard/application/client_camera_health_fact_packet_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_cloud_boost_service.dart';
import 'package:omnix_dashboard/application/onyx_agent_local_brain_service.dart';
import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';

class _StubOnyxAgentCloudBoostService implements OnyxAgentCloudBoostService {
  final OnyxAgentCloudBoostResponse? response;
  final bool configured;
  int callCount = 0;

  _StubOnyxAgentCloudBoostService({this.response, this.configured = true});

  @override
  bool get isConfigured => configured;

  @override
  Future<OnyxAgentCloudBoostResponse?> boost({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    callCount += 1;
    return response;
  }
}

class _StubOnyxAgentLocalBrainService implements OnyxAgentLocalBrainService {
  final OnyxAgentCloudBoostResponse? response;
  int callCount = 0;

  _StubOnyxAgentLocalBrainService({this.response});

  @override
  bool get isConfigured => response != null;

  @override
  Future<OnyxAgentCloudBoostResponse?> synthesize({
    required String prompt,
    required OnyxAgentCloudScope scope,
    required OnyxAgentCloudIntent intent,
    String contextSummary = '',
  }) async {
    callCount += 1;
    return response;
  }
}

ClientCameraHealthFactPacket _cameraHealthFactPacket({
  ClientCameraHealthStatus status = ClientCameraHealthStatus.offline,
  ClientCameraHealthReason reason = ClientCameraHealthReason.unknown,
  ClientCameraHealthPath path = ClientCameraHealthPath.unknown,
  DateTime? lastSuccessfulVisualAtUtc,
  DateTime? lastSuccessfulUpstreamProbeAtUtc,
  Uri? currentVisualSnapshotUri,
  DateTime? currentVisualVerifiedAtUtc,
  String? continuousVisualWatchStatus,
  String? continuousVisualWatchSummary,
  DateTime? continuousVisualWatchLastSweepAtUtc,
  DateTime? continuousVisualWatchLastCandidateAtUtc,
  String? continuousVisualWatchHotCameraLabel,
  String? continuousVisualWatchHotAreaLabel,
  String? continuousVisualWatchHotCameraChangeStage,
  String? continuousVisualWatchCorrelatedContextLabel,
  String? continuousVisualWatchCorrelatedChangeStage,
  ClientLiveSiteMovementStatus liveSiteMovementStatus =
      ClientLiveSiteMovementStatus.unknown,
  ClientLiveSiteIssueStatus liveSiteIssueStatus =
      ClientLiveSiteIssueStatus.unknown,
  DateTime? lastMovementSignalAtUtc,
  int recentMovementSignalCount = 0,
  String? recentMovementSignalLabel,
  String? recentIssueSignalLabel,
  String? recentMovementHotspotLabel,
  String? recentMovementObjectLabel,
  String nextAction =
      'Verify the camera path and confirm the next successful probe before promising live access.',
  String safeClientExplanation =
      'Live camera access at MS Vallee Residence is currently unavailable while we verify the monitoring path.',
}) {
  return ClientCameraHealthFactPacket(
    clientId: 'CLIENT-MS-VALLEE',
    siteId: 'SITE-MS-VALLEE-RESIDENCE',
    siteReference: 'MS Vallee Residence',
    status: status,
    reason: reason,
    path: path,
    lastSuccessfulVisualAtUtc: lastSuccessfulVisualAtUtc,
    lastSuccessfulUpstreamProbeAtUtc: lastSuccessfulUpstreamProbeAtUtc,
    currentVisualSnapshotUri: currentVisualSnapshotUri,
    currentVisualVerifiedAtUtc: currentVisualVerifiedAtUtc,
    continuousVisualWatchStatus: continuousVisualWatchStatus,
    continuousVisualWatchSummary: continuousVisualWatchSummary,
    continuousVisualWatchLastSweepAtUtc: continuousVisualWatchLastSweepAtUtc,
    continuousVisualWatchLastCandidateAtUtc:
        continuousVisualWatchLastCandidateAtUtc,
    continuousVisualWatchHotCameraLabel: continuousVisualWatchHotCameraLabel,
    continuousVisualWatchHotAreaLabel: continuousVisualWatchHotAreaLabel,
    continuousVisualWatchHotCameraChangeStage:
        continuousVisualWatchHotCameraChangeStage,
    continuousVisualWatchCorrelatedContextLabel:
        continuousVisualWatchCorrelatedContextLabel,
    continuousVisualWatchCorrelatedChangeStage:
        continuousVisualWatchCorrelatedChangeStage,
    liveSiteMovementStatus: liveSiteMovementStatus,
    liveSiteIssueStatus: liveSiteIssueStatus,
    lastMovementSignalAtUtc: lastMovementSignalAtUtc,
    recentMovementSignalCount: recentMovementSignalCount,
    recentMovementSignalLabel: recentMovementSignalLabel,
    recentIssueSignalLabel: recentIssueSignalLabel,
    recentMovementHotspotLabel: recentMovementHotspotLabel,
    recentMovementObjectLabel: recentMovementObjectLabel,
    nextAction: nextAction,
    safeClientExplanation: safeClientExplanation,
  );
}

void main() {
  int wordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .length;
  }

  String pairObservedDifference({
    required String baselineText,
    required String taggedText,
  }) {
    final baseline = baselineText.trim().toLowerCase();
    final tagged = taggedText.trim().toLowerCase();
    final addsReassurance =
        !baseline.contains('you are not alone') &&
        tagged.contains('you are not alone');
    final addsLiveUrgency =
        !baseline.contains('treating this as live') &&
        tagged.contains('treating this as live');
    final dropsFormalSeriousness =
        baseline.contains('taking this seriously') &&
        !tagged.contains('taking this seriously');
    final addsFormalEnterpriseTone =
        !baseline.contains('actively checking') &&
        tagged.contains('actively checking');
    final addsCameraValidation =
        (!baseline.contains('daylight') && tagged.contains('daylight')) ||
        (!baseline.contains('camera check') && tagged.contains('camera check'));
    final usesEtaShorthand =
        baseline.contains('when the eta is confirmed') &&
        tagged.contains('when it is confirmed');
    final tightensEta =
        tagged.contains('eta') &&
        (!baseline.contains('eta') ||
            wordCount(taggedText) < wordCount(baselineText));
    final notes = <String>[];
    if (dropsFormalSeriousness && addsReassurance && addsLiveUrgency) {
      notes.add(
        'tagged reply shifts from formal enterprise wording to more protective plain language',
      );
    } else if (addsReassurance && addsLiveUrgency) {
      notes.add('tagged reply adds explicit reassurance and stronger urgency');
    } else {
      if (addsReassurance) {
        notes.add('tagged reply adds explicit reassurance');
      }
      if (addsLiveUrgency) {
        notes.add('tagged reply sounds more protective and urgent');
      }
    }
    if (addsCameraValidation) {
      notes.add('tagged reply leans harder into camera validation');
    }
    if (addsFormalEnterpriseTone) {
      notes.add('tagged reply shifts toward more formal enterprise wording');
    }
    if (usesEtaShorthand && tightensEta) {
      notes.add('tagged reply uses tighter ETA shorthand');
    } else {
      if (usesEtaShorthand) {
        notes.add('tagged reply uses tighter ETA shorthand');
      }
      if (tightensEta) {
        notes.add('tagged reply stays tighter around the ETA');
      }
    }
    if (notes.isNotEmpty) {
      return notes.join(' • ');
    }
    if (baselineText.trim() == taggedText.trim()) {
      return 'tagged reply stays effectively identical to baseline';
    }
    if (wordCount(taggedText) < wordCount(baselineText)) {
      return 'tagged reply is slightly tighter than baseline';
    }
    return 'tagged reply shifts tone subtly while staying close to baseline';
  }

  String? journeyGroupPurposeNote(String groupTitle) {
    switch (groupTitle) {
      case 'VALLEE RESIDENTIAL JOURNEYS':
        return 'focus=pressure, validation, on-site, closure';
      case 'TOWER ENTERPRISE JOURNEYS':
        return 'focus=access, status, closure';
      default:
        return null;
    }
  }

  String? pairGroupPurposeNote(String groupTitle) {
    switch (groupTitle) {
      case 'VALLEE RESIDENTIAL PAIRS':
        return 'focus=reassurance warmth, camera validation, ETA tightening';
      case 'TOWER ENTERPRISE PAIRS':
        return 'focus=ETA tightening, plain-to-formal status shift, formal-to-protective worry shift';
      default:
        return null;
    }
  }

  Future<String> buildVoiceReviewTranscript() async {
    const service = UnconfiguredTelegramAiAssistantService();
    const learnedExample =
        'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.';
    final pairedCases =
        <
          ({
            String groupTitle,
            String title,
            String expectedShift,
            ({
              String label,
              List<String> preferredTags,
              List<String> learnedTags,
              Future<TelegramAiDraftReply> draft,
            })
            baseline,
            ({
              String label,
              List<String> preferredTags,
              List<String> learnedTags,
              Future<TelegramAiDraftReply> draft,
            })
            tagged,
          })
        >[
          (
            groupTitle: 'VALLEE RESIDENTIAL PAIRS',
            title: 'VALLEE_REASSURANCE_PAIR',
            expectedShift: 'baseline vs warmer reassurance under worry',
            baseline: (
              label: 'VALLEE_WORRIED',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'I am scared, what is happening?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ),
            tagged: (
              label: 'VALLEE_WORRIED_TAGGED_REASSURANCE',
              preferredTags: const <String>[],
              learnedTags: const ['Warm reassurance'],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'I am scared, what is happening?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                learnedReplyStyleTags: const ['Warm reassurance'],
              ),
            ),
          ),
          (
            groupTitle: 'VALLEE RESIDENTIAL PAIRS',
            title: 'VALLEE_VISUAL_PAIR',
            expectedShift: 'baseline vs stronger camera-validation wording',
            baseline: (
              label: 'VALLEE_VISUAL_BASELINE',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'What do you see on camera in daylight?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ),
            tagged: (
              label: 'VALLEE_VISUAL_TAGGED_CAMERA',
              preferredTags: const ['Camera validation'],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'What do you see on camera in daylight?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                preferredReplyStyleTags: const ['Camera validation'],
              ),
            ),
          ),
          (
            groupTitle: 'VALLEE RESIDENTIAL PAIRS',
            title: 'VALLEE_ETA_PAIR',
            expectedShift: 'baseline vs tighter ETA-focused wording',
            baseline: (
              label: 'VALLEE_ETA_BASELINE',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'How long?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
              ),
            ),
            tagged: (
              label: 'VALLEE_ETA_TAGGED_CRISP',
              preferredTags: const ['ETA crisp'],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'How long?',
                clientId: 'CLIENT-MS-VALLEE',
                siteId: 'SITE-MS-VALLEE-RESIDENCE',
                preferredReplyStyleTags: const ['ETA crisp'],
              ),
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE PAIRS',
            title: 'TOWER_STATUS_PAIR',
            expectedShift: 'baseline vs more formal enterprise status wording',
            baseline: (
              label: 'TOWER_STATUS_BASELINE',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'Any update?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
              ),
            ),
            tagged: (
              label: 'TOWER_STATUS_TAGGED_FORMAL',
              preferredTags: const ['Operations formal'],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'Any update?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                preferredReplyStyleTags: const ['Operations formal'],
              ),
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE PAIRS',
            title: 'TOWER_ETA_PAIR',
            expectedShift: 'baseline vs tighter ETA-focused enterprise wording',
            baseline: (
              label: 'TOWER_ETA_BASELINE',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'How long?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                recentConversationTurns: const [
                  'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are checking access at Sandton Tower now. I will update you here with the next confirmed step.',
                ],
              ),
            ),
            tagged: (
              label: 'TOWER_ETA_TAGGED_CRISP',
              preferredTags: const ['ETA crisp'],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'How long?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                preferredReplyStyleTags: const ['ETA crisp'],
                recentConversationTurns: const [
                  'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are checking access at Sandton Tower now. I will update you here with the next confirmed step.',
                ],
              ),
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE PAIRS',
            title: 'TOWER_WORRIED_PAIR',
            expectedShift:
                'baseline vs more protective enterprise reassurance wording',
            baseline: (
              label: 'TOWER_WORRIED_BASELINE',
              preferredTags: const <String>[],
              learnedTags: const <String>[],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'I am worried, what is happening?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
              ),
            ),
            tagged: (
              label: 'TOWER_WORRIED_TAGGED_REASSURANCE',
              preferredTags: const <String>[],
              learnedTags: const ['Warm reassurance'],
              draft: service.draftReply(
                audience: TelegramAiAudience.client,
                messageText: 'I am worried, what is happening?',
                clientId: 'CLIENT-SANDTON',
                siteId: 'SITE-SANDTON-TOWER',
                learnedReplyStyleTags: const ['Warm reassurance'],
              ),
            ),
          ),
        ];
    final standaloneCases =
        <
          ({
            String groupTitle,
            String label,
            List<String> preferredTags,
            List<String> learnedTags,
            Future<TelegramAiDraftReply> draft,
          })
        >[
          (
            groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
            label: 'VALLEE_PRESSURED_LEARNED',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'still waiting?',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              preferredReplyExamples: const [learnedExample],
              learnedReplyExamples: const [learnedExample],
              recentConversationTurns: const [
                'Telegram Inbound • telegram • Resident: still waiting',
                'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
              ],
            ),
          ),
          (
            groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
            label: 'VALLEE_VISUAL_MEMORY',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'What do you see on camera in daylight?',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              clientProfileSignals: const ['validation-heavy'],
            ),
          ),
          (
            groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
            label: 'VALLEE_ONSITE',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'Any update?',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              recentConversationTurns: const [
                'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
              ],
            ),
          ),
          (
            groupTitle: 'VALLEE RESIDENTIAL JOURNEYS',
            label: 'VALLEE_CLOSURE',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'Thank you',
              clientId: 'CLIENT-MS-VALLEE',
              siteId: 'SITE-MS-VALLEE-RESIDENCE',
              recentConversationTurns: const [
                'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
              ],
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE JOURNEYS',
            label: 'TOWER_ACCESS',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'The gate is not opening',
              clientId: 'CLIENT-SANDTON',
              siteId: 'SITE-SANDTON-TOWER',
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE JOURNEYS',
            label: 'TOWER_STATUS',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'Any update?',
              clientId: 'CLIENT-SANDTON',
              siteId: 'SITE-SANDTON-TOWER',
              recentConversationTurns: const [
                'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are actively checking access-control status for Sandton Tower now. I will share the next confirmed step the moment control has it.',
              ],
            ),
          ),
          (
            groupTitle: 'TOWER ENTERPRISE JOURNEYS',
            label: 'TOWER_CLOSURE',
            preferredTags: const <String>[],
            learnedTags: const <String>[],
            draft: service.draftReply(
              audience: TelegramAiAudience.client,
              messageText: 'Thanks',
              clientId: 'CLIENT-SANDTON',
              siteId: 'SITE-SANDTON-TOWER',
              recentConversationTurns: const [
                'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
              ],
            ),
          ),
        ];

    final buffer = StringBuffer();
    buffer.writeln('# LEGEND');
    buffer.writeln(
      'focus=what the grouped section is meant to cover during review',
    );
    buffer.writeln(
      'expectedShift=the wording change we hope the tag or memory will cause',
    );
    buffer.writeln(
      'observedDifference=the wording difference the transcript actually shows',
    );
    String? currentPairGroupTitle;
    void writeCase({
      required String label,
      required List<String> preferredTags,
      required List<String> learnedTags,
      required TelegramAiDraftReply draft,
    }) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln('=== $label ===');
      if (preferredTags.isNotEmpty) {
        buffer.writeln('preferredStyleTags=${preferredTags.join(' | ')}');
      }
      if (learnedTags.isNotEmpty) {
        buffer.writeln('learnedStyleTags=${learnedTags.join(' | ')}');
      }
      buffer.writeln(draft.text);
      buffer.write(
        'usedLearnedApprovalStyle=${draft.usedLearnedApprovalStyle}',
      );
    }

    for (final pair in pairedCases) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      if (currentPairGroupTitle != pair.groupTitle) {
        buffer.writeln('# ${pair.groupTitle}');
        final purposeNote = pairGroupPurposeNote(pair.groupTitle);
        if (purposeNote != null) {
          buffer.writeln(purposeNote);
        }
        currentPairGroupTitle = pair.groupTitle;
      }
      buffer.writeln('## ${pair.title}');
      buffer.writeln('expectedShift=${pair.expectedShift}');
      final baselineDraft = await pair.baseline.draft;
      final taggedDraft = await pair.tagged.draft;
      buffer.writeln(
        'observedDifference=${pairObservedDifference(baselineText: baselineDraft.text, taggedText: taggedDraft.text)}',
      );
      writeCase(
        label: pair.baseline.label,
        preferredTags: pair.baseline.preferredTags,
        learnedTags: pair.baseline.learnedTags,
        draft: baselineDraft,
      );
      writeCase(
        label: pair.tagged.label,
        preferredTags: pair.tagged.preferredTags,
        learnedTags: pair.tagged.learnedTags,
        draft: taggedDraft,
      );
    }
    if (standaloneCases.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln('# JOURNEY CASES');
    }
    String? currentJourneyGroupTitle;
    for (final voiceCase in standaloneCases) {
      if (currentJourneyGroupTitle != voiceCase.groupTitle) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.writeln('## ${voiceCase.groupTitle}');
        final purposeNote = journeyGroupPurposeNote(voiceCase.groupTitle);
        if (purposeNote != null) {
          buffer.writeln(purposeNote);
        }
        currentJourneyGroupTitle = voiceCase.groupTitle;
      }
      final draft = await voiceCase.draft;
      writeCase(
        label: voiceCase.label,
        preferredTags: voiceCase.preferredTags,
        learnedTags: voiceCase.learnedTags,
        draft: draft,
      );
    }
    return buffer.toString();
  }

  test('unconfigured assistant returns fallback draft', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need update please',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(service.isConfigured, isFalse);
    expect(draft.usedFallback, isTrue);
    expect(draft.text, contains('confirmed step'));
    expect(draft.text, isNot(contains('CLIENT-1')));
    expect(draft.text, isNot(contains('SITE-1')));
  });

  test('openai assistant injects ONYX client comms prompt context', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4.1-mini');
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      final systemText = system['text'] as String;
      expect(
        systemText,
        contains(
          'You are ONYX, an AI-powered security intelligence system.',
        ),
      );
      expect(systemText, contains('- Client: Morningstar'));
      expect(systemText, contains('- Site: North Gate'));
      expect(systemText, contains('- Watch status: unknown'));
      expect(systemText, contains('- Camera status: unknown'));
      expect(systemText, contains('- Active incidents: unknown'));
      expect(systemText, contains('- Last verified activity: unknown'));
      expect(systemText, contains('- Guard on site: unknown'));
      expect(systemText, contains('- Last guard check-in: unknown'));
      return http.Response(
        '{"id":"resp_1","output_text":"We are checking SITE-1 now and will send the next confirmed update as soon as it is in."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What is the status?',
      clientId: 'CLIENT-MORNINGSTAR',
      siteId: 'SITE-NORTH-GATE',
    );

    expect(service.isConfigured, isTrue);
    expect(draft.usedFallback, isFalse);
    expect(
      draft.text,
      'We are checking now and will send the next confirmed update as soon as it is in.',
    );
    expect(draft.providerLabel, 'openai:gpt-4.1-mini');
  });

  test('openai assistant adds urgency note for escalated client lane', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      expect(system['text'], contains('already escalated/high-priority'));
      return http.Response(
        '{"id":"resp_2","output_text":"This is already escalated with control and we are checking the next confirmed step now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
      recentConversationTurns: const [
        'Escalated • ai_policy • ONYX AI: Understood. This has been escalated to the control room now. If you are in immediate danger, call SAPS or 112 now.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(draft.text, contains('already escalated with control'));
  });

  test(
    'openai assistant adds steady-tone note for pressured client lane',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_3","output_text":"We are on it at MS Vallee Residence now. I will update you here the moment control confirms the next step."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        ],
      );

      expect(draft.usedFallback, isFalse);
      expect(systemText, contains('repeated anxious follow-ups'));
      expect(draft.text, contains('next confirmed step'));
    },
  );

  test('openai assistant adds on-site stage note for responder lane', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_4","output_text":"Security is already on site at MS Vallee Residence. We are checking the latest on-site position now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'ETA?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('already on site'));
    expect(systemText, contains('not ETA'));
    expect(draft.text, contains('already on site'));
  });

  test('openai assistant adds approval-draft delivery note', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.approvalDraft,
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('drafted for operator approval'));
    expect(draft.text, contains('next confirmed step'));
  });

  test(
    'openai assistant adds concise client-profile note when provided',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_5profile","output_text":"We are checking MS Vallee Residence now. I will share the next step when confirmed."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Need status please',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        clientProfileSignals: const ['concise-updates'],
      );

      expect(draft.usedFallback, isFalse);
      expect(systemText, contains('prefers short operational updates'));
      expect(
        draft.text,
        contains('update you here with the next confirmed step'),
      );
    },
  );

  test('openai assistant adds residential tone note for Vallee scope', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5a","output_text":"We are on it at MS Vallee Residence and control is checking the latest position now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('residential/private-community'));
  });

  test('openai assistant adds enterprise tone note for tower scope', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_5b","output_text":"We are actively checking the latest position for Sandton Tower now."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('corporate/enterprise site'));
  });

  test(
    'openai assistant adds residential visual tone note for daylight check',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_5c","output_text":"We are checking the latest camera view around MS Vallee Residence now."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'What do you see on camera in daylight?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.usedFallback, isFalse);
      expect(systemText, contains('camera/daylight validation'));
      expect(systemText, contains('protective and clear'));
    },
  );

  test(
    'openai assistant adds enterprise access tone note for tower scope',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_5d","output_text":"We are checking access-control status for Sandton Tower now."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'The gate is not opening',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      );

      expect(draft.usedFallback, isFalse);
      expect(systemText, contains('access control'));
      expect(systemText, contains('operational next steps'));
    },
  );

  test(
    'openai assistant includes approved wording examples when provided',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_6","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Need status please',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyExamples: const [
          'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
        ],
      );

      expect(draft.usedFallback, isFalse);
      expect(systemText, contains('Preferred approved reply examples'));
      expect(systemText, contains('I will share the next confirmed step'));
      expect(draft.text, contains('I will share the next confirmed step'));
    },
  );

  test(
    'openai assistant includes learned and preferred style tags when provided',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          '{"id":"resp_6tags","output_text":"We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Need status please',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyStyleTags: const ['Warm reassurance'],
        learnedReplyStyleTags: const ['Warm reassurance', 'ETA crisp'],
        preferredReplyExamples: const [
          'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
        ],
        learnedReplyExamples: const [
          'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
        ],
      );

      expect(draft.usedFallback, isFalse);
      expect(
        systemText,
        contains('Preferred style cues for this lane right now'),
      );
      expect(systemText, contains('Warm reassurance'));
      expect(systemText, contains('Learned lane style tags'));
      expect(systemText, contains('ETA crisp'));
      expect(systemText, contains('nudge the tone'));
    },
  );

  test('openai assistant includes learned lane examples when provided', () async {
    String? systemText;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final input = body['input'] as List<dynamic>;
      final system =
          ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                  .first
              as Map<String, dynamic>;
      systemText = system['text'] as String?;
      return http.Response(
        '{"id":"resp_6learned","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      learnedReplyExamples: const [
        'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(systemText, contains('Learned strong reply examples'));
    expect(systemText, contains('worked well in this lane before'));
    expect(draft.text, contains('I will share the next confirmed step'));
  });

  test('openai assistant normalizes drift back to learned closing style', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_7","output_text":"We are checking access status for MS Vallee Residence now. I will send the next confirmed step as soon as control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
      ],
    );

    expect(draft.usedFallback, isFalse);
    expect(
      draft.text,
      'We are checking access at MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
    );
  });

  test(
    'openai assistant normalizes sms-style drift into concise fallback voice',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"id":"resp_8","output_text":"We are checking MS Vallee Residence now. I will update you here the moment control confirms the next step."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        deliveryMode: TelegramAiDeliveryMode.smsFallback,
      );

      expect(draft.usedFallback, isFalse);
      expect(
        draft.text,
        'We are checking MS Vallee Residence now. I will send the next confirmed step.',
      );
    },
  );

  test('openai assistant falls back when API fails', () async {
    final client = MockClient((request) async {
      return http.Response('{"error":"rate limited"}', 429);
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'ETA?',
      clientId: 'CLIENT-1',
      siteId: 'SITE-1',
    );

    expect(draft.usedFallback, isTrue);
    expect(draft.text, contains('ETA'));
    expect(draft.text, isNot(contains('CLIENT-1')));
    expect(draft.text, isNot(contains('SITE-1')));
  });

  test(
    'openai assistant replaces mechanical client reply with warm fallback',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"id":"resp_1","output_text":"ONYX received your message (CLIENT-1/SITE-1). Command is reviewing and will send a verified update shortly."}',
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-4.1-mini',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Need status please',
        clientId: 'CLIENT-1',
        siteId: 'SITE-1',
      );

      expect(draft.usedFallback, isFalse);
      expect(draft.text, contains('confirmed step'));
      expect(draft.text, isNot(contains('received your message')));
      expect(draft.text, isNot(contains('we have your message')));
      expect(draft.text, isNot(contains('CLIENT-1')));
    },
  );

  test(
    'fallback reply reassures worried clients without sounding robotic',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I am really worried and scared',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.text, contains('You are not alone.'));
      expect(draft.text, contains('MS Vallee Residence'));
      expect(draft.text, contains('next confirmed step'));
    },
  );

  test('fallback reply honors reassurance tag memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'I am really worried and scared',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      learnedReplyStyleTags: const ['Warm reassurance'],
    );

    expect(draft.text, contains('You are not alone.'));
    expect(draft.text, contains('MS Vallee Residence'));
  });

  test(
    'fallback reply keeps enterprise worried tone plain and formal',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I am worried, what is happening?',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      );

      expect(
        draft.text,
        contains(
          'We are checking Sandton Tower now and taking this seriously.',
        ),
      );
      expect(draft.text, isNot(contains('You are not alone.')));
    },
  );

  test(
    'fallback reply uses enterprise status phrasing for tower scope',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Need status please',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      );

      expect(draft.text, contains('We are checking Sandton Tower now.'));
      expect(draft.text, isNot(contains('We are on it at Sandton Tower')));
    },
  );

  test('fallback reply honors formal operations tag memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-SANDTON',
      siteId: 'SITE-SANDTON-TOWER',
      preferredReplyStyleTags: const ['Operations formal'],
    );

    expect(
      draft.text,
      'We are actively checking Sandton Tower now. I will update you here with the next confirmed step.',
    );
  });

  test('fallback reply uses warmer residential thanks wording', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Thanks',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.text, contains('You are welcome.'));
    expect(draft.text, contains('keep you posted here'));
  });

  test(
    'fallback reply uses residential visual phrasing for Vallee daylight',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'What do you see on camera in daylight?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.text, contains('cameras around MS Vallee Residence now'));
      expect(draft.text, contains('camera check'));
    },
  );

  test(
    'fallback reply uses enterprise access phrasing for tower scope',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'The gate is not opening',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      );

      expect(draft.text, contains('checking access at Sandton Tower now'));
      expect(draft.text, contains('next confirmed step'));
    },
  );

  test('fallback reply honors concise client profile memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Need status please',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      clientProfileSignals: const ['concise-updates'],
    );

    expect(draft.text, contains('We are checking MS Vallee Residence now.'));
    expect(
      draft.text,
      contains('I will update you here with the next confirmed step.'),
    );
    expect(
      draft.text,
      isNot(contains('control is checking the latest position now')),
    );
  });

  test(
    'fallback reply honors validation-heavy client profile memory',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'What do you see on camera?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        clientProfileSignals: const ['validation-heavy'],
      );

      expect(
        draft.text,
        contains('cameras and daylight around MS Vallee Residence now'),
      );
      expect(draft.text, contains('confirmed camera check'));
    },
  );

  test('fallback reply honors visual tag memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyStyleTags: const ['Camera validation'],
    );

    expect(
      draft.text,
      contains('cameras and daylight around MS Vallee Residence now'),
    );
    expect(draft.text, contains('camera check'));
  });

  test(
    'fallback reply handles access issues with a concrete next step',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'We cannot get out the gate',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.text, contains('checking access at'));
      expect(draft.text, contains('next confirmed step'));
    },
  );

  test('fallback reply handles camera validation requests cleanly', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'What do you see on camera in daylight?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(draft.text, contains('cameras'));
    expect(draft.text, contains('camera check'));
  });

  test('fallback reply varies repeated status follow-up language', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update yet?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as it is in.',
      ],
    );

    expect(
      draft.text,
      contains('I will update you here with the next confirmed step.'),
    );
    expect(
      draft.text,
      isNot(contains('next confirmed update as soon as it is in')),
    );
  });

  test('fallback reply carries eta intent into short follow-up turns', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'still waiting?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX AI: We are checking live movement for MS Vallee Residence now. I will send the ETA as soon as control confirms it.',
      ],
    );

    expect(draft.text, contains('checking the ETA'));
    expect(
      draft.text,
      anyOf(contains('ETA'), contains('moment control confirms the ETA')),
    );
  });

  test('fallback reply honors eta crisp tag memory', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'How long?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyStyleTags: const ['ETA crisp'],
    );

    expect(
      draft.text,
      contains('We are checking the ETA for MS Vallee Residence now.'),
    );
    expect(
      draft.text,
      contains('I will update you here when it is confirmed.'),
    );
    expect(draft.text, isNot(contains('when the ETA is confirmed')));
  });

  test(
    'fallback reply tightens status follow-up once lane is escalated',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Escalated • ai_policy • ONYX AI: Understood. This has been escalated to the control room now. If you are in immediate danger, call SAPS or 112 now.',
        ],
      );

      expect(draft.text, contains('already escalated for'));
      expect(draft.text, contains('next confirmed step'));
      expect(draft.text, isNot(contains('keep this lane updated')));
    },
  );

  test(
    'fallback reply shortens repeated anxious follow-ups in one lane',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        ],
      );

      expect(draft.text, contains('We are checking MS Vallee Residence now.'));
      expect(
        draft.text,
        contains('I will update you here with the next confirmed step.'),
      );
      expect(draft.text, isNot(contains('keep this lane updated')));
      expect(
        draft.text,
        isNot(contains('control is checking the latest position now')),
      );
    },
  );

  test(
    'fallback reply shifts into on-site voice once responder is there',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'ETA?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
        ],
      );

      expect(
        draft.text,
        contains('Security is already on site at MS Vallee Residence.'),
      );
      expect(draft.text, contains('next on-site step'));
      expect(draft.text, isNot(contains('ETA as soon as control confirms it')));
    },
  );

  test(
    'fallback reply shifts into closure voice once incident is resolved',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
        ],
      );

      expect(draft.text, contains('MS Vallee Residence is secure right now.'));
      expect(draft.text, contains('message here immediately'));
      expect(draft.text, isNot(contains('checking the latest position now')));
    },
  );

  test('fallback reply uses approval-draft phrasing when requested', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.approvalDraft,
    );

    expect(draft.text, contains('checking access at'));
    expect(
      draft.text,
      contains('I will update you here with the next confirmed step.'),
    );
    expect(draft.text, isNot(contains('control has it')));
  });

  test('fallback reply uses concise sms fallback voice', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      deliveryMode: TelegramAiDeliveryMode.smsFallback,
      recentConversationTurns: const [
        'Telegram Inbound • telegram • Resident: still waiting',
      ],
    );

    expect(
      draft.text,
      'We are checking MS Vallee Residence. I will send the next confirmed step.',
    );
    expect(draft.text, isNot(contains('I will update you here')));
  });

  test('fallback reply mirrors preferred approved closing style', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final draft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'We cannot get out the gate',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are on it at MS Vallee Residence now. I will share the next confirmed step the moment control has it.',
      ],
    );

    expect(draft.text, contains('checking access at'));
    expect(
      draft.text,
      contains(
        'I will share the next confirmed step here when it is confirmed.',
      ),
    );
    expect(
      draft.text,
      isNot(
        contains(
          'I will send the next confirmed step as soon as control has it.',
        ),
      ),
    );
  });

  test('fallback sequence stays coherent across Vallee lane stages', () async {
    const service = UnconfiguredTelegramAiAssistantService();

    final worriedDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'I am scared, is someone coming?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );
    final onSiteDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Any update?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Responder On Site • partner_dispatch • ONYX AI: Responder on site at MS Vallee Residence.',
      ],
    );
    final closureDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'Thank you',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
      ],
    );

    expect(worriedDraft.text, contains('You are not alone.'));
    expect(worriedDraft.text, contains('MS Vallee Residence'));
    expect(onSiteDraft.text, contains('already on site'));
    expect(onSiteDraft.text, contains('next on-site step'));
    expect(onSiteDraft.text, isNot(contains('You are not alone.')));
    expect(closureDraft.text, contains('secure right now'));
    expect(closureDraft.text, contains('secure'));
    expect(closureDraft.text, isNot(contains('latest on-site position')));
  });

  test(
    'fallback sequence keeps learned Vallee closing style under pressure',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      const learnedExample =
          'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.';

      final firstFollowUp = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'still waiting?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyExamples: const [learnedExample],
        learnedReplyExamples: const [learnedExample],
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        ],
      );
      final secondFollowUp = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'please keep checking',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyExamples: const [learnedExample],
        learnedReplyExamples: const [learnedExample],
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
          'Telegram Inbound • telegram • Resident: please keep checking',
        ],
      );

      expect(firstFollowUp.usedLearnedApprovalStyle, isTrue);
      expect(secondFollowUp.usedLearnedApprovalStyle, isTrue);
      expect(
        firstFollowUp.text,
        contains(
          'I will share the next confirmed step here when it is confirmed.',
        ),
      );
      expect(
        secondFollowUp.text,
        contains(
          'I will share the next confirmed step here when it is confirmed.',
        ),
      );
      expect(
        secondFollowUp.text,
        isNot(
          contains(
            'I will send the next confirmed update as soon as control has it.',
          ),
        ),
      );
    },
  );

  test('openai draft marks learned approval style usage when provided', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"id":"resp_learned","output_text":"We are checking access status for MS Vallee Residence now. I will share the next confirmed step the moment control has it."}',
        200,
      );
    });
    final service = OpenAiTelegramAiAssistantService(
      client: client,
      apiKey: 'sk-test',
      model: 'gpt-4.1-mini',
    );

    final withLearnedStyle = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is still not opening',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      preferredReplyExamples: const [
        'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
      ],
      learnedReplyExamples: const [
        'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.',
      ],
    );
    final withoutLearnedStyle = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'The gate is still not opening',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
    );

    expect(withLearnedStyle.usedLearnedApprovalStyle, isTrue);
    expect(withoutLearnedStyle.usedLearnedApprovalStyle, isFalse);
  });

  test(
    'fallback reassurance clarifier avoids generic all-clear wording when remote monitoring is offline',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'does that mean everything is okay?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: MS Vallee Residence is temporarily without remote monitoring as of 12:11.',
          'ONYX AI: Remote watch is temporarily unavailable while the monitoring path is offline.',
          'ONYX AI: Current posture: field activity observed.',
          'ONYX AI: Assessment: routine on-site team activity is visible.',
        ],
      );

      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('Remote monitoring is offline'));
      expect(draft.text, contains('routine on-site activity'));
      expect(
        draft.text,
        isNot(
          contains(
            'We are treating this seriously and checking MS Vallee Residence now.',
          ),
        ),
      );
    },
  );

  test(
    'fallback reassurance clarifier stays explicit when security is already on site',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'you sure?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Security is already on site at MS Vallee Residence.',
          'ONYX AI: I will update you here with the next on-site step.',
        ],
      );

      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('Security is already on site'));
      expect(draft.text, contains('do not want to overstate'));
      expect(
        draft.text,
        isNot(contains('We are checking MS Vallee Residence now.')),
      );
    },
  );

  test(
    'onyx-first telegram assistant prefers onyx cloud before local and direct providers',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'Security is already on site at MS Vallee Residence. I will confirm here as soon as the next verified step comes in.',
          providerLabel: 'brain-cloud',
        ),
      );
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text: 'Local brain should not be used first.',
          providerLabel: 'brain-local',
        ),
      );
      var directCalls = 0;
      final direct = OpenAiTelegramAiAssistantService(
        client: MockClient((request) async {
          directCalls += 1;
          return http.Response(
            jsonEncode({
              'output_text':
                  'Direct provider should not be used when ONYX cloud is ready.',
            }),
            200,
          );
        }),
        apiKey: 'telegram-openai-key',
        model: 'gpt-4.1-mini',
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: direct,
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'you sure?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.providerLabel, 'onyx-cloud:brain-cloud');
      expect(draft.text, contains('Security is already on site'));
      expect(cloud.callCount, 1);
      expect(local.callCount, 0);
      expect(directCalls, 0);
    },
  );

  test(
    'onyx-first telegram assistant prefers direct provider before onyx local when cloud is unavailable',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'Local brain should stay as fallback when direct frontier assist is ready.',
          providerLabel: 'brain-local',
        ),
      );
      var directCalls = 0;
      final direct = OpenAiTelegramAiAssistantService(
        client: MockClient((request) async {
          directCalls += 1;
          return http.Response(
            jsonEncode({
              'output_text':
                  'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as everything is verified.',
            }),
            200,
          );
        }),
        apiKey: 'telegram-openai-key',
        model: 'gpt-4.1-mini',
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: direct,
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Front gate',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.providerLabel, 'openai:gpt-4.1-mini');
      expect(draft.text, contains('front gate'));
      expect(local.callCount, 0);
      expect(directCalls, 1);
    },
  );

  test(
    'onyx-first telegram assistant falls back to direct provider when onyx cloud returns an error response',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(
        response: const OnyxAgentCloudBoostResponse(
          text: '',
          providerLabel: 'brain-cloud',
          isError: true,
          errorSummary: 'OpenAI brain request failed',
          errorDetail: 'Provider returned HTTP 503.',
        ),
      );
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'Local brain should stay unused while direct fallback is ready.',
          providerLabel: 'brain-local',
        ),
      );
      var directCalls = 0;
      final direct = OpenAiTelegramAiAssistantService(
        client: MockClient((request) async {
          directCalls += 1;
          return http.Response(
            jsonEncode({
              'output_text':
                  'Control is checking the front gate at MS Vallee Residence now. I will confirm here as soon as everything is verified.',
            }),
            200,
          );
        }),
        apiKey: 'telegram-openai-key',
        model: 'gpt-4.1-mini',
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: direct,
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Front gate',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.providerLabel, 'openai:gpt-4.1-mini');
      expect(draft.text, contains('front gate'));
      expect(cloud.callCount, 1);
      expect(local.callCount, 0);
      expect(directCalls, 1);
    },
  );

  test(
    'onyx-first telegram assistant prefers direct provider for approval-draft assists before onyx local when cloud is unavailable',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'Local brain should stay as fallback when direct frontier assist is ready.',
          providerLabel: 'brain-local',
        ),
      );
      var directCalls = 0;
      final direct = OpenAiTelegramAiAssistantService(
        client: MockClient((request) async {
          directCalls += 1;
          return http.Response(
            jsonEncode({
              'output_text':
                  'We do not have live visual confirmation right now, but the latest telemetry does not show an open incident. If you want, we can arrange a manual check.',
            }),
            200,
          );
        }),
        apiKey: 'telegram-openai-key',
        model: 'gpt-4.1-mini',
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: direct,
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        deliveryMode: TelegramAiDeliveryMode.approvalDraft,
        messageText:
            'Client asked: everything good?\n'
            'Current operator draft: We currently do not have live visual confirmation. Please let us know if you want a manual check.\n'
            'Refine the operator draft into a calm, send-ready client reply.',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.providerLabel, 'openai:gpt-4.1-mini');
      expect(draft.text, contains('manual check'));
      expect(local.callCount, 0);
      expect(directCalls, 1);
    },
  );

  test(
    'onyx-first telegram assistant rewrites generic local reassurance replies into explicit offline-monitoring clarification',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'We are checking MS Vallee Residence now and staying close on this. I will update you here with the next confirmed step.',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'so this means everything is okay?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: MS Vallee Residence is temporarily without remote monitoring as of 13:31.',
          'ONYX AI: Remote watch is temporarily unavailable while the monitoring path is offline.',
          'ONYX AI: Current posture: field activity observed.',
          'ONYX AI: Assessment: routine on-site team activity is visible.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('Remote monitoring is offline'));
      expect(draft.text, isNot(contains('staying close on this')));
    },
  );

  test(
    'onyx-first telegram assistant rewrites generic local monitoring-restoration replies into honest restoration guidance',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'when will remote monitoring be back up?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: MS Vallee Residence is temporarily without remote monitoring as of 13:31.',
          'ONYX AI: Remote watch is temporarily unavailable while the monitoring path is offline.',
          'ONYX AI: If you need a manual follow-up or welfare check, message here and control will pick it up.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(draft.text, contains('do not have a confirmed time'));
      expect(draft.text, contains('monitoring path is restored'));
      expect(
        draft.text,
        isNot(
          contains(
            'We are checking MS Vallee Residence now. I will update you here with the next confirmed step.',
          ),
        ),
      );
    },
  );

  test(
    'onyx-first telegram assistant clarifies telemetry counts when the client challenges people-on-site wording',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'We are checking the security presence at MS Vallee Residence now. I will update you here with the next on-site step.',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'there isnt 19 guards or response teams on site',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(draft.text, contains('recorded ONYX telemetry activity'));
      expect(draft.text, contains('confirmed guard on site'));
      expect(draft.text, contains('current response position'));
      expect(draft.text, contains('next confirmed step'));
      expect(draft.text, isNot(contains('next on-site step')));
    },
  );

  test(
    'onyx-first telegram assistant answers everything-good follow-ups from telemetry summary without collapsing into a generic holding line',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'We are checking MS Vallee Residence now and will update you here with the next confirmed step.',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'everything good?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
          'ONYX AI: it is not sitting as an open incident now.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(
        draft.text,
        contains('latest ONYX telemetry includes a response-arrival signal'),
      );
      expect(
        draft.text,
        contains('nothing is currently sitting as an open incident'),
      );
      expect(
        draft.text,
        isNot(
          contains(
            'We are checking MS Vallee Residence now and will update you here with the next confirmed step.',
          ),
        ),
      );
    },
  );

  test(
    'onyx-first telegram assistant preserves operator draft intent for approval-draft assist when local rewrite drifts',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'We do not have access to cameras now but if you need help then send a message and we will send a unit over.',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'Client asked: so this means everything is good right?\n'
            'Current operator draft: We currently do not have access to remote monitoring. Please advise if everything is good or would you like us to send a unit over?\n'
            'Refine the operator draft into a calm, send-ready client reply. Preserve the confirmed facts and intended action from the draft unless the recent lane context clearly contradicts them. Do not switch to a different issue or offer a new action unless the client asked for it.',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        deliveryMode: TelegramAiDeliveryMode.approvalDraft,
        recentConversationTurns: const [
          'Active reply lane: Residents',
          'Current operator draft: We currently do not have access to remote monitoring. Please advise if everything is good or would you like us to send a unit over?',
          'ONYX AI: MS Vallee Residence is temporarily without remote monitoring as of 13:31.',
          'ONYX AI: Remote watch is temporarily unavailable while the monitoring path is offline.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(draft.text, contains('do not have access to remote monitoring'));
      expect(draft.text, contains('send a unit over'));
      expect(draft.text, isNot(contains('access to cameras')));
    },
  );

  test(
    'onyx-first telegram assistant rewrites optimistic telemetry-summary operator drafts into grounded manual-check language',
    () async {
      final cloud = _StubOnyxAgentCloudBoostService(configured: false);
      final local = _StubOnyxAgentLocalBrainService(
        response: const OnyxAgentCloudBoostResponse(
          text:
              'we do not have access to live monitoring of your site currently. if you need any assistance let us know and we send units',
          providerLabel: 'brain-local',
        ),
      );
      final service = OnyxFirstTelegramAiAssistantService(
        onyxCloudBoost: cloud,
        onyxLocalBrain: local,
        directProvider: const UnconfiguredTelegramAiAssistantService(),
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'Client asked: everything good?\n'
            "Current operator draft: We are checking MS Vallee Residence now and will update you here with the next confirmed step. If you need any assistance, let us know and we'll send units. Everything appears good for now.\n"
            'Refine the operator draft into a calm, send-ready client reply. Preserve the confirmed facts and intended action from the draft unless the recent lane context clearly contradicts them. Do not switch to a different issue or offer a new action unless the client asked for it.',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        deliveryMode: TelegramAiDeliveryMode.approvalDraft,
        recentConversationTurns: const [
          'Active reply lane: Residents',
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
          'ONYX AI: it is not sitting as an open incident now.',
        ],
      );

      expect(draft.providerLabel, 'onyx-local:brain-local');
      expect(
        draft.text,
        contains('latest ONYX telemetry includes a response-arrival signal'),
      );
      expect(draft.text, contains('do not have live visual confirmation'));
      expect(draft.text, contains('send a unit for a manual check'));
      expect(
        draft.text,
        isNot(contains('live monitoring of your site currently')),
      );
      expect(draft.text, isNot(contains('Everything appears good for now')));
    },
  );

  test(
    'fallback acknowledges gratitude and serious-alert watch requests without switching into an incident readout',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'thank you for assisting. i will let you know if i need anything else. please keep me posted on any serious alerts',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.text, contains('You are welcome.'));
      expect(draft.text, contains('keep you posted here'));
      expect(draft.text, contains('anything serious'));
      expect(draft.text, isNot(contains('No unresolved incidents')));
    },
  );

  test(
    'openai assistant rewrites overconfident telemetry-summary reassurance replies into grounded manual-check language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is secure right now, with security on site and no new alerts. We are checking the cameras regularly and will update you immediately if anything changes.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'so the site is safe?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
          'ONYX AI: it is not sitting as an open incident now.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(
        draft.text,
        contains('latest ONYX telemetry includes a response-arrival signal'),
      );
      expect(draft.text, isNot(contains('security on site')));
      expect(draft.text, isNot(contains('checking the cameras regularly')));
    },
  );

  test(
    'openai assistant rewrites camera reassurance replies into honest no-live-visual clarification',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The latest verified activity near Camera was community reports suspicious vehicle scouting the estate entrance at 11:15. That area is not sitting as an open incident at the moment.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'did you check cameras? is all good?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: it is not sitting as an open incident now.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('do not have a live camera check'));
      expect(draft.text, contains('does not show an open incident'));
      expect(draft.text, isNot(contains('near Camera')));
    },
  );

  test(
    'openai assistant corrects unsupported on-site claims when the client says security is not on site',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Security is now on site at MS Vallee Residence, and the team is conducting a thorough camera check as the next step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'security is NOT on site',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Reply Sent • openai:gpt-5.4 • ONYX AI: MS Vallee Residence is secure right now, with security on site and no new alerts.',
          'Telegram Inbound • telegram • Resident: security is NOT on site',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('will not call them on site'));
      expect(draft.text, contains('verify the current response position'));
      expect(draft.text, isNot(contains('Security is now on site')));
    },
  );

  test(
    'openai assistant corrects camera-down replies into no-live-visual language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The cameras are currently down, but security is on site and the team is conducting a thorough camera check as the next step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'but my cameras are down',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: but my cameras are down',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('do not have live visual confirmation'));
      expect(draft.text, contains('verify the current position'));
      expect(draft.text, isNot(contains('thorough camera check')));
      expect(draft.text, isNot(contains('security is on site')));
    },
  );

  test(
    'openai assistant includes structured camera facts and overrides contradictory restoration claims',
    () async {
      String? systemText;
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as List<dynamic>;
        final system =
            ((input.first as Map<String, dynamic>)['content'] as List<dynamic>)
                    .first
                as Map<String, dynamic>;
        systemText = system['text'] as String?;
        return http.Response(
          jsonEncode({
            'output_text':
                'Yes, the cameras are back online now and the connection is restored.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the connection fixed?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(systemText, contains('Structured camera health facts'));
      expect(systemText, contains('- camera_status: offline'));
      expect(systemText, contains('- camera_reason: bridge_offline'));
      expect(systemText, contains('- camera_path: legacy_local_proxy'));
      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(
        draft.text,
        contains(
          'Live camera visibility at MS Vallee Residence is unavailable right now.',
        ),
      );
      expect(draft.text, isNot(contains('back online')));
      expect(draft.text, isNot(contains('connection is restored')));
    },
  );

  test(
    'unconfigured assistant explains why cameras are unavailable from the structured packet',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.credentialsMissing,
        path: ClientCameraHealthPath.hikConnectApi,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the newer Hik-Connect credentials for this site are still outstanding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'why can\'t you see my cameras?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Live camera visibility at MS Vallee Residence is unavailable right now. I will update you here as soon as live camera access is confirmed again.',
      );
    },
  );

  test(
    'unconfigured assistant preserves limited camera visibility wording for camera-online asks',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.limited,
        reason: ClientCameraHealthReason.unknown,
        path: ClientCameraHealthPath.hikConnectApi,
        safeClientExplanation:
            'Live camera visibility at MS Vallee Residence is limited right now.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'are cameras online?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Not confirmed yet. Live camera visibility at MS Vallee Residence is limited right now.',
      );
      expect(draft.text, isNot(contains('unavailable right now')));
    },
  );

  test(
    'unconfigured assistant confirms the temporary legacy bridge when camera access is live',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        lastSuccessfulVisualAtUtc: DateTime.utc(2026, 4, 3, 13, 45),
        lastSuccessfulUpstreamProbeAtUtc: DateTime.utc(2026, 4, 3, 13, 47),
        nextAction:
            'Keep the legacy local Hikvision proxy on 127.0.0.1:11635 in place until the Hik-Connect credentials arrive, then switch this site to the Hik-Connect API path.',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the connection fixed?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Yes. We currently have live visual access at MS Vallee Residence.',
      );
    },
  );

  test(
    'unconfigured assistant turns generic update follow ups into camera bridge status updates',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'okay, update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: The count you see reflects telemetry signals, which do not always match the number of guards physically on site.',
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, startsWith('Update: Live camera visibility'));
      expect(
        draft.text,
        contains('MS Vallee Residence is unavailable right now'),
      );
      expect(draft.text, contains('next confirmed step'));
      expect(draft.text, isNot(contains('telemetry signals')));
      expect(draft.text, isNot(contains('physically on site')));
    },
  );

  test(
    'unconfigured assistant answers why cant we view live from the structured packet',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'why cant we view live?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Live camera visibility at MS Vallee Residence is unavailable right now. I will update you here as soon as live camera access is confirmed again.',
      );
    },
  );

  test(
    'unconfigured assistant answers bridge restored questions from the structured packet',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the bridge restored?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Not confirmed yet.'));
      expect(
        draft.text,
        contains(
          'Live camera visibility at MS Vallee Residence is unavailable right now.',
        ),
      );
      expect(draft.text, contains('live camera access is confirmed again'));
    },
  );

  test(
    'openai assistant falls back on generic camera status follow ups when the model repeats telemetry count language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The count you see reflects telemetry signals, which do not always match the number of guards physically on site. Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline. We are working to restore the bridge and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'okay, update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: The count you see reflects telemetry signals, which do not always match the number of guards physically on site.',
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, startsWith('Update: Live camera visibility'));
      expect(
        draft.text,
        contains('MS Vallee Residence is unavailable right now'),
      );
      expect(draft.text, contains('next confirmed step'));
      expect(draft.text, isNot(contains('telemetry signals')));
      expect(draft.text, isNot(contains('physically on site')));
    },
  );

  test(
    'unconfigured assistant clarifies telemetry counts when the client says there are no guards at the premises',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'there are no guards at premisies',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A response-arrival signal was logged through ONYX field telemetry.',
        ],
      );

      expect(draft.text, contains('ONYX telemetry'));
      expect(draft.text, contains('confirmed guard on site'));
      expect(draft.text, contains('current response position'));
      expect(draft.text, isNot(contains('We are checking the situation')));
    },
  );

  test(
    'openai assistant falls back on telemetry presence challenges when the model invents movement',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We are checking who is moving to MS Vallee Residence now. I will update you here with the next movement update.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'there are NO guards',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A response-arrival signal was logged through ONYX field telemetry.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('recorded ONYX telemetry activity'));
      expect(draft.text, contains('confirmed guard on site'));
      expect(draft.text, contains('current response position'));
      expect(draft.text, isNot(contains('who is moving')));
      expect(draft.text, isNot(contains('movement update')));
    },
  );

  test(
    'unconfigured assistant keeps guard-presence corrections deterministic even when the telemetry summary is no longer in recent turns',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'there are no guards',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: We are checking who is moving to MS Vallee Residence now. I will update you here with the next movement update.',
        ],
      );

      expect(
        draft.text,
        contains(
          'I do not have a confirmed guard on site at MS Vallee Residence',
        ),
      );
      expect(draft.text, contains('current response position'));
      expect(draft.text, isNot(contains('who is moving')));
      expect(draft.text, isNot(contains('movement update')));
    },
  );

  test(
    'openai assistant falls back on generic camera status follow ups when the model invents active restoration progress',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline. We are working on restoring the connection and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        'Update: Live camera visibility at MS Vallee Residence is unavailable right now. I will update you here with the next confirmed step.',
      );
      expect(draft.text, isNot(contains('working on restoring')));
    },
  );

  test(
    'openai assistant treats broad status checks as packet-grounded current-site-view asks during a bridge outage',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline. We are working to restore the connection and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'hows everything',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Based on what I can see, there are no active alerts at MS Vallee Residence. I do not have live visual right now but I am monitoring all signals. Want me to flag your guard for a check?',
      );
      expect(draft.text, isNot(contains('working to restore')));
    },
  );

  test(
    'openai assistant rejects camera-only reassurance wording for broad status checks during a bridge outage',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Not confirmed yet. Live camera visibility at MS Vallee Residence is unavailable right now. I do not have live visual confirmation right now. I will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'how is everything?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Based on what I can see, there are no active alerts at MS Vallee Residence. I do not have live visual right now but I am monitoring all signals. Want me to flag your guard for a check?',
      );
      expect(
        draft.text,
        isNot(contains('Not confirmed yet. Live camera visibility')),
      );
    },
  );

  test(
    'openai assistant treats broad live-status checks as packet-grounded current-site-view asks',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Everything is stable at MS Vallee Residence. We currently have live camera access through a temporary local recorder while waiting for updated credentials. I will keep you updated here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'hows everything?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A response-arrival signal was logged through ONYX field telemetry.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Based on what I can see, there are no active alerts at MS Vallee Residence. Monitoring looks normal right now. Want me to flag your guard for a check?',
      );
      expect(draft.text, isNot(contains('Everything is stable')));
    },
  );

  test(
    'openai assistant answers check site status with the updated monitoring tone',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Everything looks fine. I am checking the site status now.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.limited,
        reason: ClientCameraHealthReason.recorderUnreachable,
        path: ClientCameraHealthPath.directRecorder,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.noConfirmedIssue,
        lastMovementSignalAtUtc: DateTime.parse('2026-04-07T18:45:00Z'),
        recentMovementSignalLabel: 'Routine patrol check',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'check site status',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Telemetry • onyx • ONYX AI: No guard is confirmed on site at MS Vallee Residence yet.',
          'Telemetry • onyx • ONYX AI: A guard check-in was recorded on site at 2026-04-07T19:15:00Z.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Based on what I can see, there are no active alerts at MS Vallee Residence. My visual monitoring is limited right now. Want me to flag your guard for a check?',
      );
      expect(draft.text, isNot(contains('I cannot')));
      expect(draft.text, isNot(contains('camera visibility unavailable')));
    },
  );

  test(
    'openai assistant falls back on live camera safety asks when the model implies close monitoring as proof of safety',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We currently have live camera access at MS Vallee Residence through a temporary local recorder while waiting for updated credentials. I am monitoring closely and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is it safe?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A response-arrival signal was logged through ONYX field telemetry.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, contains('do not want to overstate'));
      expect(draft.text, isNot(contains('monitoring closely')));
    },
  );

  test(
    'openai assistant falls back on comfort asks when the model says rest easy from live camera access alone',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'You can rest easy. We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge and are closely monitoring the site. I will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'can i sleep peacefully? will you monitor?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A response-arrival signal was logged through ONYX field telemetry.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('do not want to overpromise'));
      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, contains('I will keep watching'));
      expect(draft.text, contains('next confirmed step'));
      expect(draft.text, isNot(contains('rest easy')));
      expect(draft.text, isNot(contains('closely monitoring')));
    },
  );

  test(
    'openai assistant falls back on live-visual corrections when the model denies active visual confirmation',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'I do not have live camera confirmation for MS Vallee Residence right now. We have recent visual data from a local recorder on Camera 11, but no live stream access yet. I will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'live visual ARE active',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: I do not see a confirmed issue at MS Vallee Residence right now.',
          'ONYX AI: We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Yes.'));
      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, isNot(contains('temporary local recorder bridge')));
      expect(
        draft.text,
        isNot(contains('do not have live camera confirmation')),
      );
      expect(draft.text, isNot(contains('no live stream access yet')));
    },
  );

  test(
    'unconfigured assistant trusts the live camera packet when the client says cameras are online',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'cameras are online',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Yes.'));
      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, isNot(contains('temporary local recorder bridge')));
      expect(draft.text, isNot(contains('offline')));
    },
  );

  test(
    'unconfigured assistant trusts the live camera packet when the client says cameras are not offline',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'cameras are not offline',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Yes.'));
      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, isNot(contains('temporary local recorder bridge')));
      expect(draft.text, isNot(contains('currently unavailable')));
      expect(draft.text, isNot(contains('offline')));
    },
  );

  test(
    'unconfigured assistant turns check now into a packet-grounded camera update in recent camera context',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'check now',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
          'Client: cameras are not offline',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        startsWith('Update: We currently have visual confirmation'),
      );
      expect(draft.text, isNot(contains('temporary local recorder bridge')));
      expect(draft.text, isNot(contains('currently unavailable')));
      expect(draft.text, isNot(contains('offline')));
    },
  );

  test(
    'unconfigured assistant keeps presence follow ups scoped to guard verification instead of drifting back to camera outages',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'whats the update?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Understood. That earlier summary refers to recorded ONYX telemetry activity, not confirmed guards physically on site now.',
          'ONYX AI: No guard is confirmed on site at MS Vallee Residence from that summary alone.',
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, startsWith('Update: No guard is confirmed on site'));
      expect(draft.text, contains('verified position update'));
      expect(draft.text, isNot(contains('camera bridge')));
      expect(draft.text, isNot(contains('live camera access')));
    },
  );

  test(
    'unconfigured assistant keeps what-now follow ups scoped to guard verification instead of drifting back to camera outages',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'what now?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Understood. That earlier summary refers to recorded ONYX telemetry activity, not confirmed guards physically on site now.',
          'ONYX AI: No guard is confirmed on site at MS Vallee Residence from that summary alone.',
          'ONYX AI: Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, startsWith('Update: No guard is confirmed on site'));
      expect(draft.text, contains('verified position update'));
      expect(draft.text, isNot(contains('camera bridge')));
      expect(draft.text, isNot(contains('live camera access')));
    },
  );

  test(
    'unconfigured assistant keeps long live-update follow ups pinned to guard verification after a no-guards challenge',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'give me an update on the site now - live update',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'Client: there are no guards',
          'ONYX AI: We are checking who is moving to MS Vallee Residence now. I will update you here with the next movement update.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, startsWith('Update: No guard is confirmed on site'));
      expect(draft.text, contains('verified position update'));
      expect(draft.text, isNot(contains('camera bridge')));
      expect(draft.text, isNot(contains('live camera access')));
    },
  );

  test(
    'unconfigured assistant keeps issue-on-site asks pinned to issue state after a no-guards correction',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'no response needed. is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Understood. I do not have a confirmed guard on site at MS Vallee Residence from the scoped record I can see right now.',
          'ONYX AI: If you want, I can verify the current response position and I will update you here with the next confirmed step.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('confirmed active issue'));
      expect(draft.text, contains('recorded ONYX field telemetry'));
      expect(draft.text, contains('not a confirmed active dispatch'));
      expect(draft.text, isNot(contains('guard presence on site')));
      expect(draft.text, isNot(contains('cameras are currently offline')));
      expect(draft.text, isNot(contains('local bridge issue')));
    },
  );

  test(
    'openai assistant falls back on issue-on-site asks when the model drifts into guard-presence and camera-status language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'There is no confirmed guard presence on site at MS Vallee Residence from the information I have. The cameras are currently offline due to a local bridge issue, so live visual confirmation is not available right now. We are monitoring the situation and will update you with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'no response needed. is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Understood. I do not have a confirmed guard on site at MS Vallee Residence from the scoped record I can see right now.',
          'ONYX AI: If you want, I can verify the current response position and I will update you here with the next confirmed step.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('confirmed active issue'));
      expect(draft.text, contains('recorded ONYX field telemetry'));
      expect(draft.text, contains('not a confirmed active dispatch'));
      expect(draft.text, isNot(contains('guard presence on site')));
      expect(draft.text, isNot(contains('cameras are currently offline')));
      expect(draft.text, isNot(contains('local bridge issue')));
    },
  );

  test('unconfigured assistant keeps current-frame movement asks conservative', () async {
    const service = UnconfiguredTelegramAiAssistantService();
    final packet = _cameraHealthFactPacket(
      status: ClientCameraHealthStatus.live,
      reason: ClientCameraHealthReason.legacyProxyActive,
      path: ClientCameraHealthPath.legacyLocalProxy,
      currentVisualSnapshotUri: Uri.parse(
        'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
      ),
      currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 14),
      safeClientExplanation:
          'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
    );

    final movementDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'any movement?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX: [Image] Current verified frame from Camera 11 at MS Vallee Residence.',
      ],
      cameraHealthFactPacket: packet,
    );

    expect(
      movementDraft.text,
      'Not confirmed from the current frame alone. I cannot confirm movement from a single image.',
    );

    final backyardDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'i see someone in backyard. can you confirm?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'ONYX: [Image] Current verified frame from Camera 11 at MS Vallee Residence.',
      ],
      cameraHealthFactPacket: packet,
    );

    expect(
      backyardDraft.text,
      'Not confirmed from the current frame alone. I cannot confirm a person in the backyard from a single image.',
    );
  });

  test(
    'unconfigured assistant keeps movement asks aligned with the live packet when there is no current frame context',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: No unresolved incidents in MS Vallee Residence.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('visual confirmation'));
      expect(draft.text, isNot(contains('temporary local recorder bridge')));
      expect(draft.text, contains('fresh movement confirmation'));
      expect(draft.text, isNot(contains('offline')));
    },
  );

  test(
    'unconfigured assistant surfaces recent movement signals before camera-outage wording for movement asks',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 4, 17, 58),
        recentMovementSignalCount: 3,
        recentMovementSignalLabel:
            '3 recent person movement signals around Front Gate',
        recentMovementHotspotLabel: 'Front Gate',
        recentMovementObjectLabel: 'person',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there any movement on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing 3 recent person movement signals around Front Gate at MS Vallee Residence. That means activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(
        draft.text,
        isNot(contains('local camera bridge is not responding')),
      );
      expect(
        draft.text,
        isNot(contains('cannot confirm movement visually right now')),
      );
    },
  );

  test(
    'unconfigured assistant surfaces continuous visual watch activity for live movement asks',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchSummary:
            'Continuous visual watch still sees a sustained high-priority perimeter pressure near Front Gate across 2 cameras.',
        continuousVisualWatchLastSweepAtUtc: DateTime.utc(2026, 4, 4, 16, 30),
        continuousVisualWatchLastCandidateAtUtc: DateTime.utc(
          2026,
          4,
          4,
          16,
          29,
        ),
        continuousVisualWatchHotCameraLabel: 'Perimeter Camera 11',
        continuousVisualWatchHotAreaLabel: 'Front Gate',
        continuousVisualWatchHotCameraChangeStage: 'sustained',
        continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
        continuousVisualWatchCorrelatedChangeStage: 'sustained',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing live activity around Front Gate right now. That means something active is happening there, but I cannot confirm from this signal alone whether it is a person, vehicle, or breach.',
      );
      expect(draft.text, isNot(contains('offline')));
      expect(draft.text, isNot(contains('no movement is currently detected')));
    },
  );

  test(
    'unconfigured assistant uses recent semantic detections to qualify active watch movement replies',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchHotAreaLabel: 'Front Gate',
        continuousVisualWatchHotCameraChangeStage: 'persistent',
        continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
        continuousVisualWatchCorrelatedChangeStage: 'persistent',
        recentMovementObjectLabel: 'person',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('recent person activity'));
      expect(draft.text, contains('whether this is a breach'));
      expect(
        draft.text,
        isNot(contains('whether it is a person, vehicle, or breach')),
      );
    },
  );

  test(
    'unconfigured assistant treats weapon-class semantic detections as potential threats',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchHotAreaLabel: 'Front Gate',
        continuousVisualWatchHotCameraChangeStage: 'persistent',
        continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
        continuousVisualWatchCorrelatedChangeStage: 'persistent',
        recentMovementObjectLabel: 'firearm',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('recent firearm activity'));
      expect(draft.text, contains('potential threat'));
      expect(
        draft.text,
        isNot(contains('whether it is a person, vehicle, or breach')),
      );
    },
  );

  test(
    'openai assistant falls back to continuous visual watch facts when the model denies live change',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'No movement is currently detected at MS Vallee Residence. The local camera bridge is still offline.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchHotAreaLabel: 'Front Gate',
        continuousVisualWatchHotCameraChangeStage: 'persistent',
        continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
        continuousVisualWatchCorrelatedChangeStage: 'persistent',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        contains('I am seeing live activity around Front Gate'),
      );
      expect(draft.text, contains('something active is happening there'));
      expect(draft.text, contains('cannot confirm from this signal alone'));
      expect(draft.text, isNot(contains('No movement is currently detected')));
      expect(draft.text, isNot(contains('camera bridge is still offline')));
    },
  );

  test(
    'unconfigured assistant acknowledges recent motion alerts before drawing a visual boundary',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        currentVisualSnapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 44),
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Check for any movement',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX Control: ONYX has detected movement on Camera 11 at MS Vallee Residence.',
          'ONYX Control: ONYX has identified repeat movement activity on Camera 11 following the initial alert.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'ONYX did receive recent motion alerts on Camera 11. What I cannot confirm from the current frame alone is who or what triggered those alerts.',
      );
    },
  );

  test(
    'unconfigured assistant corrects missed-detection pushback when recent motion alerts exist',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        currentVisualSnapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 50),
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final challengeDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I just walked past 3 cameras. You picked up nothing?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX Control: ONYX has detected movement on Camera 11 at MS Vallee Residence.',
          'ONYX Control: ONYX has identified repeat movement activity on Camera 11 following the initial alert.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        challengeDraft.text,
        'ONYX did receive recent motion alerts on Camera 11. It would be wrong to say nothing was picked up. What I cannot confirm from the current frame alone is who or what triggered those alerts.',
      );

      final countCorrectionDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: '4 cameras',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: I just walked past 3 cameras. You picked up nothing?',
          'ONYX AI: ONYX did receive recent motion alerts on Camera 11. It would be wrong to say nothing was picked up. What I cannot confirm from the current frame alone is who or what triggered those alerts.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        countCorrectionDraft.text,
        'ONYX did receive recent motion alerts on Camera 11. It would be wrong to say nothing was picked up. What I cannot confirm from the current frame alone is who or what triggered those alerts.',
      );
    },
  );

  test(
    'openai assistant falls back when the model claims movement certainty from a single frame',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We have visual confirmation at MS Vallee Residence through a temporary local recorder bridge and no movement is currently detected in the backyard. I will update you here with the next movement update.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        currentVisualSnapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 15),
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'i see someone in backyard. can you confirm?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: [Image] Current verified frame from Camera 11 at MS Vallee Residence.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Not confirmed from the current frame alone. I cannot confirm a person in the backyard from a single image.',
      );
      expect(draft.text, isNot(contains('no movement is currently detected')));
      expect(draft.text, isNot(contains('next movement update')));
    },
  );

  test(
    'openai assistant falls back when the model denies detection despite recent motion alerts',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We currently have visual confirmation through a temporary local recorder bridge, but no confirmed movement was detected on those cameras at the time you passed. The next step is to continue monitoring and perform a manual follow-up if anything unusual appears.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        currentVisualSnapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 11, 50),
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I just walked past 3 cameras. You picked up nothing?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX Control: ONYX has detected movement on Camera 11 at MS Vallee Residence.',
          'ONYX Control: ONYX has identified repeat movement activity on Camera 11 following the initial alert.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        'ONYX did receive recent motion alerts on Camera 11. It would be wrong to say nothing was picked up. What I cannot confirm from the current frame alone is who or what triggered those alerts.',
      );
      expect(draft.text, isNot(contains('no confirmed movement was detected')));
    },
  );

  test(
    'unconfigured assistant explains recorder telemetry when the camera is offline but a signal was still logged',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        currentVisualSnapshotUri: Uri.parse(
          'http://127.0.0.1:11635/ISAPI/Streaming/channels/1101/picture',
        ),
        currentVisualVerifiedAtUtc: DateTime.utc(2026, 4, 4, 12, 12),
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'Camera 11 is currently offline. How did you detect a signal?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: I do not have a usable current verified image to send right now.',
          'ONYX: The latest logged signal was a recorder event on Camera 11 at 14:11.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'A signal can still be logged from the recorder even if Camera 11 is not giving us a usable live picture right now. For MS Vallee Residence, that update came from recorder telemetry, not a clean current view from Camera 11.',
      );
    },
  );

  test(
    'unconfigured assistant keeps safety reassurance constrained when one camera is down',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the site safe?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: Camera 11 is currently down, but we have visual confirmation through a temporary local recorder bridge covering other cameras at MS Vallee Residence. I am sending the latest available image now for your review.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('Camera 11 is down.'));
      expect(draft.text, contains('partial camera coverage alone'));
      expect(draft.text, isNot(contains('nine other cameras')));
      expect(draft.text, isNot(contains('continuous visual watch is active')));
    },
  );

  test(
    'unconfigured assistant keeps current site view replies honest when the current image is unusable',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'what are you seeing on site now?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: I do not have a usable current verified image to send right now.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I do not have a usable current image to share right now. I do not want to overstate what is visible from here.',
      );
    },
  );

  test(
    'unconfigured assistant treats whats happening on site as a packet-grounded current-view ask',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'active',
        continuousVisualWatchSummary:
            'Continuous visual watch remains active across the perimeter baseline.',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: "what's happening on site?",
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am not seeing active movement on site at MS Vallee Residence right now. That does not by itself prove the site is clear, but nothing in the current signals confirms an issue on site.',
      );
      expect(draft.text, isNot(contains('remote visibility is limited')));
      expect(draft.text, isNot(contains('under watch')));
    },
  );

  test(
    'unconfigured assistant treats how is the site as a packet-grounded current-view ask',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'active',
        continuousVisualWatchSummary:
            'Continuous visual watch remains active across the perimeter baseline.',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'how is the site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am not seeing active movement on site at MS Vallee Residence right now. That does not by itself prove the site is clear, but nothing in the current signals confirms an issue on site.',
      );
      expect(draft.text, isNot(contains('under watch')));
      expect(draft.text, isNot(contains('remote visibility is limited')));
    },
  );

  test(
    'unconfigured assistant treats is the site okay as a packet-grounded current-view ask',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'active',
        continuousVisualWatchSummary:
            'Continuous visual watch remains active across the perimeter baseline.',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the site okay?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am not seeing active movement on site at MS Vallee Residence right now. That does not by itself prove the site is clear, but nothing in the current signals confirms an issue on site.',
      );
      expect(draft.text, isNot(contains('latest logged signal')));
    },
  );

  test(
    'unconfigured assistant surfaces recent movement signals for current site-view asks',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 4, 17, 58),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel:
            '2 recent movement signals around Front Gate',
        recentMovementHotspotLabel: 'Front Gate',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: "what's happening on site?",
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing 2 recent movement signals around Front Gate at MS Vallee Residence. That means recent activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(draft.text, isNot(contains('Nothing in the current signals')));
      expect(draft.text, isNot(contains('remote visibility is limited')));
    },
  );

  test(
    'unconfigured assistant normalizes typoed current-site-view asks into packet-grounded status',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.hikConnectApi,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 6, 57),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel: 'recent activity near Camera 4',
        recentMovementHotspotLabel: 'Camera 4',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'whats happenong now?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing recent activity near Camera 4 at MS Vallee Residence. That means recent activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(draft.text, isNot(contains('There is no confirmed issue')));
    },
  );

  test(
    'unconfigured assistant treats hows everything on site as a recent-activity current-view ask instead of a stability reassurance',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.hikConnectApi,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 6, 57),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel: 'recent activity near Camera 4',
        recentMovementHotspotLabel: 'Camera 4',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'hows everything on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing recent activity near Camera 4 at MS Vallee Residence. That means recent activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(draft.text, isNot(contains('stable')));
      expect(draft.text, isNot(contains('all clear')));
    },
  );

  test(
    'unconfigured assistant answers semantic movement-identification asks from fused live site state',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.hikConnectApi,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 7, 0),
        recentMovementSignalCount: 1,
        recentMovementSignalLabel: 'recent movement near Camera 4',
        recentMovementHotspotLabel: 'Camera 4',
        recentMovementObjectLabel: 'vehicle',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'any movement identifying vehicles or humans?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, 'I am seeing recent vehicle activity near Camera 4.');
      expect(draft.text, isNot(contains('current frame alone')));
      expect(draft.text, isNot(contains('single image')));
    },
  );

  test(
    'unconfigured assistant answers issue-on-site asks from fused live site issue signals',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchHotAreaLabel: 'Front Gate',
        continuousVisualWatchHotCameraChangeStage: 'persistent',
        continuousVisualWatchCorrelatedContextLabel: 'Front Gate',
        continuousVisualWatchCorrelatedChangeStage: 'persistent',
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.active,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.activeSignals,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing live activity around Front Gate right now. That means something active is happening there, but I cannot confirm from this signal alone whether it is a person, vehicle, or breach.',
      );
      expect(draft.text, isNot(contains('no confirmed active issue')));
      expect(draft.text, isNot(contains('camera bridge is offline')));
    },
  );

  test(
    'unconfigured assistant uses recent semantic detections to qualify active site-issue replies',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'alerting',
        continuousVisualWatchHotAreaLabel: 'Driveway',
        continuousVisualWatchHotCameraChangeStage: 'persistent',
        continuousVisualWatchCorrelatedContextLabel: 'Driveway',
        continuousVisualWatchCorrelatedChangeStage: 'persistent',
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.active,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.activeSignals,
        recentMovementObjectLabel: 'vehicle',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('recent vehicle activity'));
      expect(draft.text, contains('whether this is a breach'));
      expect(
        draft.text,
        isNot(contains('whether it is a breach, person, or vehicle')),
      );
    },
  );

  test(
    'openai assistant falls back on current-view asks when the model replies with quick-action remote-visibility wording',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is under watch, but remote visibility is limited right now. I do not have full remote visibility, and nothing here confirms an issue on site. I will update you here if anything needs your attention.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'active',
        continuousVisualWatchSummary:
            'Continuous visual watch remains active across the perimeter baseline.',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: "what's happening on site?",
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('I am not seeing active movement on site'));
      expect(draft.text, contains('confirms an issue on site'));
      expect(draft.text, isNot(contains('remote visibility is limited')));
      expect(draft.text, isNot(contains('under watch')));
    },
  );

  test(
    'openai assistant normalizes typoed current-view asks before rejecting quick-action remote-visibility wording',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is under watch, but remote visibility is limited right now. I do not have full remote visibility, and nothing here confirms an issue on site. I will update you here if anything needs your attention.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.hikConnectApi,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 6, 57),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel: 'recent activity near Camera 4',
        recentMovementHotspotLabel: 'Camera 4',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'whats happenong now?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        'I am seeing recent activity near Camera 4 at MS Vallee Residence. That means recent activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(draft.text, isNot(contains('remote visibility is limited')));
      expect(draft.text, isNot(contains('under watch')));
    },
  );

  test(
    'openai assistant falls back on issue-on-site asks when the model ignores recent live site issue signals',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'There is no confirmed active issue at MS Vallee Residence right now. The cameras are currently offline due to a local bridge issue.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 4, 18, 4),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel:
            '2 recent movement signals around Front Gate',
        recentMovementHotspotLabel: 'Front Gate',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        'I am seeing 2 recent movement signals around Front Gate at MS Vallee Residence. That means a recent site signal was picked up, but I do not yet have a confirmed active issue from the current view alone.',
      );
      expect(draft.text, isNot(contains('cameras are currently offline')));
      expect(draft.text, isNot(contains('no confirmed active issue')));
    },
  );

  test(
    'unconfigured assistant uses tactical issue labels for recent site-issue asks',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.limited,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 7, 12),
        recentMovementSignalCount: 1,
        recentMovementSignalLabel:
            'recent line-crossing signals around Front Gate',
        recentIssueSignalLabel:
            'recent line-crossing signals around Front Gate',
        recentMovementHotspotLabel: 'Front Gate',
        safeClientExplanation:
            'Live camera visibility at MS Vallee Residence is limited right now.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there an issue on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am seeing recent line-crossing signals around Front Gate at MS Vallee Residence. That means a recent site signal was picked up, but I do not yet have a confirmed active issue from the current view alone.',
      );
      expect(draft.text, isNot(contains('recent activity was picked up')));
    },
  );

  test(
    'openai assistant rejects stable site-view language when recent live activity exists',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Everything on site is stable with recent movement signals near Camera 4. I will update you here with the next movement update.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.hikConnectApi,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.recentSignals,
        liveSiteIssueStatus: ClientLiveSiteIssueStatus.recentSignals,
        lastMovementSignalAtUtc: DateTime.utc(2026, 4, 5, 6, 57),
        recentMovementSignalCount: 2,
        recentMovementSignalLabel: 'recent activity near Camera 4',
        recentMovementHotspotLabel: 'Camera 4',
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'hows everything on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        'I am seeing recent activity near Camera 4 at MS Vallee Residence. That means recent activity was picked up on site, but I still cannot confirm from the current view who or what is moving right now.',
      );
      expect(draft.text, isNot(contains('stable')));
    },
  );

  test(
    'unconfigured assistant explains recorded event visual limits when asked why an image cannot be sent',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'there has been 14 separate events on hikconnect with visuals... why cant you send me one?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX Control: ONYX has detected movement on Camera 11 at MS Vallee Residence. A verification image has been retrieved and submitted for AI-assisted review.',
          'ONYX: I do not have a usable current verified image to send right now.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        contains(
          'I can see recorded event visuals were logged for MS Vallee Residence',
        ),
      );
      expect(draft.text, contains('usable exported image'));
      expect(draft.text, isNot(contains('bridge is offline')));
      expect(
        draft.text,
        isNot(contains('I do not have live visual confirmation right now')),
      );
      expect(draft.text, isNot(contains('nothing was detected')));
    },
  );

  test(
    'unconfigured assistant uses continuous-watch coverage for movement asks before camera-offline fallback wording',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        continuousVisualWatchStatus: 'active',
        continuousVisualWatchSummary:
            'Continuous visual watch remains active across the perimeter baseline.',
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is offline.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there any movement?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I am not seeing active movement on site at MS Vallee Residence right now. That does not by itself prove the site is clear, and I do not have a fresh movement confirmation to share right now.',
      );
      expect(draft.text, isNot(contains('camera bridge is offline')));
      expect(
        draft.text,
        isNot(contains('cannot confirm movement visually right now')),
      );
    },
  );

  test(
    'unconfigured assistant answers no-signal movement asks with movement-first visibility boundaries',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.offline,
        reason: ClientCameraHealthReason.bridgeOffline,
        path: ClientCameraHealthPath.legacyLocalProxy,
        liveSiteMovementStatus: ClientLiveSiteMovementStatus.unknown,
        safeClientExplanation:
            'Live camera access at MS Vallee Residence is currently unavailable because the local camera bridge is not responding.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there any movement on site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'I do not have confirmed movement on site at MS Vallee Residence from the current signals I can see right now. Live camera visibility is unavailable right now, so I cannot verify movement visually at this moment.',
      );
      expect(
        draft.text,
        isNot(contains('local camera bridge is not responding')),
      );
      expect(
        draft.text,
        isNot(contains('cannot confirm movement visually right now')),
      );
    },
  );

  test(
    'openai assistant falls back when the model invents camera coverage counts in a safety reply',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while Camera 11 is down. Continuous visual watch is active on nine other cameras, and we are staying close on this. I will update you here with the next confirmed camera check.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the site safe?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: Camera 11 is currently down, but we have visual confirmation through a temporary local recorder bridge covering other cameras at MS Vallee Residence.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('Camera 11 is down.'));
      expect(draft.text, isNot(contains('nine other cameras')));
      expect(draft.text, isNot(contains('staying close on this')));
    },
  );

  test(
    'unconfigured assistant answers overnight alert asks with grounded short wording',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'if im asleep and something happens, you will alert me right?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        draft.text,
        'Yes. If ONYX receives a confirmed alert for MS Vallee Residence, we will message you here right away.',
      );
    },
  );

  test(
    'openai assistant falls back on overnight alert asks when the model overpromises blanket alerting',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'Yes, if something happens while you’re asleep, we will alert you right away. I will update you here with the next confirmed camera check.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'if im asleep and something happens, you will alert me right?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'fallback');
      expect(draft.text, contains('confirmed alert'));
      expect(draft.text, contains('message you here right away'));
      expect(draft.text, isNot(contains('next confirmed camera check')));
      expect(draft.text, isNot(contains('if something happens while you')));
    },
  );

  test(
    'unconfigured assistant keeps baseline sweep wording grounded instead of claiming an active check',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final requestDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'can you do a quick sweep to see that the sites baseline is normal',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        requestDraft.text,
        'Yes. I can do a quick camera check and send you the confirmed result here.',
      );
      expect(requestDraft.text, isNot(contains('checking the baseline now')));

      final followUpDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'did you check?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: can you do a quick sweep to see that the sites baseline is normal',
          'ONYX AI: Yes. I can do a quick camera check and send you the confirmed result here.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        followUpDraft.text,
        'Not yet confirmed. I do not have a baseline result to send you yet.',
      );

      final etaDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'how long will you take?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: can you do a quick sweep to see that the sites baseline is normal',
          'ONYX AI: Yes. I can do a quick camera check and send you the confirmed result here.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        etaDraft.text,
        'A quick camera check should only take a few minutes. I will send the result here once it is confirmed.',
      );
    },
  );

  test(
    'openai assistant falls back on baseline sweep asks when the model invents an in-progress check',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'I’m checking the baseline at MS Vallee Residence now using the local recorder bridge. I will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'can you do a quick sweep to see that the sites baseline is normal',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(draft.providerLabel, 'fallback');
      expect(draft.text, contains('quick camera check'));
      expect(draft.text, contains('confirmed result'));
      expect(draft.text, isNot(contains('checking the baseline now')));
      expect(draft.text, isNot(contains('using the local recorder bridge')));
    },
  );

  test('unconfigured assistant keeps whole-site breach review wording grounded', () async {
    const service = UnconfiguredTelegramAiAssistantService();
    final packet = _cameraHealthFactPacket(
      status: ClientCameraHealthStatus.live,
      reason: ClientCameraHealthReason.legacyProxyActive,
      path: ClientCameraHealthPath.legacyLocalProxy,
      safeClientExplanation:
          'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
    );

    final requestDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'check every area',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Client: there was an alarm at around 4am. can you check if there was any breach?',
        'ONYX AI: The confirmed alert closest to 04:00 was a recorder event on Camera 11 at 04:03. I do not have evidence here confirming a breach from that logged history alone.',
      ],
      cameraHealthFactPacket: packet,
    );

    expect(
      requestDraft.text,
      'Yes. I can review the site signals and send you the confirmed result here.',
    );

    final followUpDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'have you checked?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Client: there was an alarm at around 4am. can you check if there was any breach?',
        'Client: check every area',
        'ONYX AI: Yes. I can review the site signals and send you the confirmed result here.',
      ],
      cameraHealthFactPacket: packet,
    );

    expect(
      followUpDraft.text,
      'Not yet confirmed. I do not have a full-site breach result to send you yet.',
    );

    final etaDraft = await service.draftReply(
      audience: TelegramAiAudience.client,
      messageText: 'how long will you take?',
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      recentConversationTurns: const [
        'Client: there was an alarm at around 4am. can you check if there was any breach?',
        'Client: check every area',
        'ONYX AI: Yes. I can review the site signals and send you the confirmed result here.',
      ],
      cameraHealthFactPacket: packet,
    );

    expect(
      etaDraft.text,
      'I do not have a confirmed timing for that yet. I will send the result here once it is confirmed.',
    );
  });

  test(
    'openai assistant falls back on whole-site breach review asks when the model invents an in-progress review',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We are reviewing all areas at MS Vallee Residence now for any signs of breach following the alarm at 4am. I will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );
      final packet = _cameraHealthFactPacket(
        status: ClientCameraHealthStatus.live,
        reason: ClientCameraHealthReason.legacyProxyActive,
        path: ClientCameraHealthPath.legacyLocalProxy,
        safeClientExplanation:
            'We currently have visual confirmation at MS Vallee Residence through a temporary local recorder bridge while the newer API credentials are still pending.',
      );

      final requestDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'check every area',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: there was an alarm at around 4am. can you check if there was any breach?',
          'ONYX AI: The confirmed alert closest to 04:00 was a recorder event on Camera 11 at 04:03. I do not have evidence here confirming a breach from that logged history alone.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        requestDraft.text,
        'Yes. I can review the site signals and send you the confirmed result here.',
      );

      final followUpDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'have you checked?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: there was an alarm at around 4am. can you check if there was any breach?',
          'Client: check every area',
          'ONYX AI: Yes. I can review the site signals and send you the confirmed result here.',
        ],
        cameraHealthFactPacket: packet,
      );

      expect(
        followUpDraft.text,
        'Not yet confirmed. I do not have a full-site breach result to send you yet.',
      );
      expect(followUpDraft.text, isNot(contains('reviewing all areas now')));
      expect(followUpDraft.text, isNot(contains('signs of breach')));
    },
  );

  test(
    'unconfigured assistant keeps historical alarm review wording tied to the 4am window',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'im asking you to check last night activity while setup was live',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: there was an alarm trigger at around 4am. can you check perimeter - all outdoor cameras',
          'ONYX AI: I do not have a confirmed alert tied to Perimeter or the outdoor cameras around 04:00 in the logged history I can see right now. I do not have live visual confirmation on Perimeter right now.',
        ],
      );

      expect(
        draft.text,
        'Understood. You are asking about the 4am window, not the current site status. I do not have a confirmed historical review result for the perimeter and outdoor cameras yet.',
      );
    },
  );

  test(
    'openai assistant falls back on historical alarm review asks when the model drifts into current outdoor-camera review language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The latest confirmed activity near the perimeter was a recorded event on Camera 11 at 09:42, with no open incidents at that time. We are reviewing all outdoor cameras around the 4am alarm trigger and will update you with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText:
            'im asking you to check last night activity while setup was live',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: there was an alarm trigger at around 4am. can you check perimeter - all outdoor cameras',
          'ONYX AI: I do not have a confirmed alert tied to Perimeter or the outdoor cameras around 04:00 in the logged history I can see right now. I do not have live visual confirmation on Perimeter right now.',
        ],
      );

      expect(
        draft.text,
        'Understood. You are asking about the 4am window, not the current site status. I do not have a confirmed historical review result for the perimeter and outdoor cameras yet.',
      );
      expect(draft.text, isNot(contains('09:42')));
      expect(draft.text, isNot(contains('reviewing all outdoor cameras')));
    },
  );

  test(
    'unconfigured assistant keeps historical alarm escalation wording grounded',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'escalate',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Client: there was an alarm trigger at around 4am. can you check perimeter - all outdoor cameras',
          'Client: im asking you to check last night activity while setup was live',
          'ONYX AI: Understood. You are asking about the 4am window, not the current site status. I do not have a confirmed historical review result for the perimeter and outdoor cameras yet.',
        ],
      );

      expect(
        draft.text,
        'Understood. You are asking for manual control review of the 4am alarm window. I do not have a confirmed historical review result for the perimeter and outdoor cameras yet.',
      );
    },
  );

  test(
    'openai assistant rewrites urgent camera repair requests into connection-check language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The latest verified activity near Camera was community reports suspicious vehicle scouting the estate entrance at 11:15. That area is not sitting as an open incident at the moment.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'can you check asap and rewire cameras if needed',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: I do not have live camera confirmation for MS Vallee Residence right now.',
          'ONYX: The monitoring path is offline for this site right now.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('camera connection'));
      expect(draft.text, contains('as a priority'));
      expect(draft.text, contains('on-site fix'));
      expect(draft.text, isNot(contains('community reports')));
      expect(draft.text, isNot(contains('near Camera')));
    },
  );

  test(
    'openai assistant answers connection-restored asks without drifting into generic holding copy',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'We are checking the connection and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is the connection fixed?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: I cannot see live cameras for MS Vallee Residence right now because the monitoring connection is offline.',
          'ONYX: I will update you here as soon as live camera access is confirmed again.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(draft.text, contains('cannot say the connection is restored yet'));
      expect(draft.text, contains('live camera confirmation'));
      expect(draft.text, isNot(contains('We are checking the connection')));
    },
  );

  test(
    'openai assistant rewrites telemetry reassurance replies that overclaim security on site even without an open-incident line',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is secure right now, with security on site and no new alerts. The team is conducting a thorough camera check as the next step and will update you if anything changes.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'everything okay?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed yet.'));
      expect(
        draft.text,
        contains('latest ONYX telemetry includes a response-arrival signal'),
      );
      expect(draft.text, contains('do not have live visual confirmation'));
      expect(draft.text, isNot(contains('security on site')));
      expect(draft.text, isNot(contains('thorough camera check')));
    },
  );

  test(
    'openai assistant corrects telemetry-summary movement claims into no-confirmed-unit language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'The team is on their way to MS Vallee Residence now and will be on site shortly. I will update you here with the next on-site step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'why are they coming here?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('do not have a confirmed unit moving'));
      expect(draft.text, contains('recorded ONYX field telemetry'));
      expect(draft.text, contains('not a confirmed active dispatch'));
      expect(draft.text, contains('current position'));
      expect(draft.text, isNot(contains('on their way')));
      expect(draft.text, isNot(contains('next on-site step')));
    },
  );

  test(
    'openai assistant answers issue-at-site asks without inventing a live dispatch from telemetry summary',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'There is a team moving toward the site now and we will update you with the next on-site step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'is there an issue at my site?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
          'ONYX AI: It is not sitting as an open incident now.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(
        draft.text,
        contains(
          'There is no confirmed active issue at MS Vallee Residence right now.',
        ),
      );
      expect(draft.text, contains('recorded ONYX field telemetry'));
      expect(draft.text, contains('not a confirmed active dispatch'));
      expect(draft.text, isNot(contains('moving toward the site')));
      expect(draft.text, isNot(contains('next on-site step')));
    },
  );

  test(
    'unconfigured assistant corrects no-unit-on-site pushback after telemetry summary',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'there is no unit on site',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX AI: Site activity summary: MS Vallee Residence',
          'ONYX AI: 19 guard or response-team activity signals were logged through ONYX field telemetry.',
          'ONYX AI: Latest field signal: A field response unit arrived on site.',
        ],
      );

      expect(
        draft.text,
        contains(
          'I do not have a confirmed unit on site at MS Vallee Residence from that earlier summary alone.',
        ),
      );
      expect(draft.text, contains('recorded ONYX field telemetry'));
      expect(draft.text, contains('current position'));
      expect(draft.text, contains('next confirmed step'));
    },
  );

  test(
    'fallback thanks reply stays brief and does not switch into a status readout',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'okay, i will let you know if i need anything thanks',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );

      expect(draft.text, contains('You are welcome.'));
      expect(draft.text, contains('keep you posted here'));
      expect(draft.text, isNot(contains('Everything is stable')));
      expect(draft.text, isNot(contains('monitoring the situation')));
    },
  );

  test(
    'openai assistant rewrites community-report reassurance replies into direct no-visual-confirmation language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is stable. We are reviewing recent community reports and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'everything okay?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: MS Vallee Residence is stable at the moment. The latest confirmed activity was community reports suspicious vehicle scouting the estate entrance at 11:15, and it is not sitting as an open incident now.',
          'ONYX: I do not have live visual confirmation at this moment, so I am grounding this on the current operational picture rather than a live camera check.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('Not confirmed visually'));
      expect(draft.text, contains('latest logged report'));
      expect(draft.text, contains('do not have live visual confirmation'));
      expect(
        draft.text,
        isNot(contains('stable. We are reviewing recent community reports')),
      );
    },
  );

  test(
    'openai assistant explains current operational picture in plain client language',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'output_text':
                'MS Vallee Residence is stable. We are reviewing recent community reports of a suspicious vehicle scouting the estate and will update you here with the next confirmed step.',
          }),
          200,
        );
      });
      final service = OpenAiTelegramAiAssistantService(
        client: client,
        apiKey: 'sk-test',
        model: 'gpt-5.4',
      );

      final draft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'what current operational picture?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'ONYX: The latest confirmed activity was community reports suspicious vehicle scouting the estate entrance at 11:15, and it is not sitting as an open incident now.',
          'ONYX: I do not have live visual confirmation at this moment, so I am grounding this on the current operational picture rather than a live camera check.',
        ],
      );

      expect(draft.providerLabel, 'openai:gpt-5.4');
      expect(draft.text, contains('By current operational picture'));
      expect(draft.text, contains('latest logged report'));
      expect(draft.text, contains('do not have live visual confirmation'));
      expect(
        draft.text,
        isNot(contains('We are reviewing recent community reports')),
      );
    },
  );

  test('voice review transcript fixture stays current', () async {
    final transcript = await buildVoiceReviewTranscript();
    final fixture = File(
      'test/fixtures/telegram_ai_voice_review_transcripts.txt',
    ).readAsStringSync().trimRight();

    expect(transcript.trimRight(), fixture);
  });

  test(
    'Vallee journey regression keeps reassurance, learned pressure, and closure distinct',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();
      const learnedExample =
          'We are checking MS Vallee Residence now. I will share the next confirmed step here when it is confirmed.';

      final intakeDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'I am scared, what is happening?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
      );
      final pressuredDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'still waiting?',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        preferredReplyExamples: const [learnedExample],
        learnedReplyExamples: const [learnedExample],
        recentConversationTurns: const [
          'Telegram Inbound • telegram • Resident: still waiting',
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are on it at MS Vallee Residence and control is checking the latest position now. I will send the next confirmed update as soon as control has it.',
        ],
      );
      final closureDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Thank you',
        clientId: 'CLIENT-MS-VALLEE',
        siteId: 'SITE-MS-VALLEE-RESIDENCE',
        recentConversationTurns: const [
          'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at MS Vallee Residence.',
        ],
      );

      expect(intakeDraft.text, contains('You are not alone.'));
      expect(intakeDraft.text, contains('MS Vallee Residence'));
      expect(pressuredDraft.usedLearnedApprovalStyle, isTrue);
      expect(
        pressuredDraft.text,
        contains(
          'I will share the next confirmed step here when it is confirmed.',
        ),
      );
      expect(
        pressuredDraft.text,
        isNot(
          contains(
            'I will send the next confirmed update as soon as control has it.',
          ),
        ),
      );
      expect(closureDraft.text, contains('secure right now'));
      expect(closureDraft.text, contains('secure'));
      expect(closureDraft.text, isNot(contains('You are not alone.')));
    },
  );

  test(
    'enterprise tower journey regression stays formal from access to closure',
    () async {
      const service = UnconfiguredTelegramAiAssistantService();

      final accessDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'The gate is not opening',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
      );
      final statusDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Any update?',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
        recentConversationTurns: const [
          'Reply Sent • openai:gpt-4.1-mini • ONYX AI: We are actively checking access-control status for Sandton Tower now. I will share the next confirmed step the moment control has it.',
        ],
      );
      final closureDraft = await service.draftReply(
        audience: TelegramAiAudience.client,
        messageText: 'Thanks',
        clientId: 'CLIENT-SANDTON',
        siteId: 'SITE-SANDTON-TOWER',
        recentConversationTurns: const [
          'Incident Resolved • onyx_monitoring • ONYX AI: Incident resolved at Sandton Tower.',
        ],
      );

      expect(
        accessDraft.text,
        contains('checking access at Sandton Tower now'),
      );
      expect(accessDraft.text, isNot(contains('You are not alone.')));
      expect(
        statusDraft.text,
        anyOf(
          contains('checking Sandton Tower now'),
          contains('update you here with the next confirmed step'),
        ),
      );
      expect(
        statusDraft.text,
        isNot(contains('We are on it at Sandton Tower')),
      );
      expect(closureDraft.text, contains('Sandton Tower is secure'));
      expect(closureDraft.text, isNot(contains('You are not alone.')));
    },
  );
}
