import 'package:flutter/material.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/execution_completed.dart';

class DispatchPage extends StatelessWidget {
  final String clientId;
  final String regionId;
  final String siteId;

  final VoidCallback onGenerate;
  final List events;
  final void Function(String dispatchId) onExecute;

  const DispatchPage({
    super.key,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.onGenerate,
    required this.events,
    required this.onExecute,
  });

  @override
  Widget build(BuildContext context) {
    final decisions = events.whereType<DecisionCreated>().where((d) {
      return d.clientId == clientId &&
          d.regionId == regionId &&
          d.siteId == siteId;
    }).toList();

    final executions = events.whereType<ExecutionCompleted>().where((e) {
      return e.clientId == clientId &&
          e.regionId == regionId &&
          e.siteId == siteId;
    }).toList();

    final executedIds =
        executions.map((e) => e.dispatchId).toSet();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Dispatches — $clientId / $regionId / $siteId",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onGenerate,
              child: const Text("Generate Dispatch"),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: decisions.map((d) {
                  final isExecuted =
                      executedIds.contains(d.dispatchId);

                  return Card(
                    child: ListTile(
                      title: Text(d.dispatchId),
                      subtitle: Text(
                          isExecuted ? "EXECUTED" : "DECIDED"),
                      trailing: isExecuted
                          ? const SizedBox.shrink()
                          : ElevatedButton(
                              onPressed: () =>
                                  onExecute(d.dispatchId),
                              child: const Text("Execute"),
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
