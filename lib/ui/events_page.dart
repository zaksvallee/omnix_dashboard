import 'package:flutter/material.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/dispatch_event.dart';

class EventsPage extends StatelessWidget {
  final List<DispatchEvent> events;

  const EventsPage({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];

        if (event is DecisionCreated) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'DECISION → ${event.clientId} / ${event.regionId} / ${event.siteId} / ${event.dispatchId}',
            ),
          );
        }

        if (event is ExecutionCompleted) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'EXECUTION → ${event.clientId} / ${event.regionId} / ${event.siteId} / ${event.dispatchId}',
            ),
          );
        }

        if (event is ExecutionDenied) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'DENIED → ${event.clientId} / ${event.regionId} / ${event.siteId} / ${event.dispatchId}',
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
