import 'package:flutter/material.dart';

import '../../domain/store/in_memory_event_store.dart';
import '../../domain/events/dispatch_event.dart';

class ManualIncidentPage extends StatefulWidget {
  final InMemoryEventStore store;
  final String selectedClient;
  final String selectedSite;

  const ManualIncidentPage({
    super.key,
    required this.store,
    required this.selectedClient,
    required this.selectedSite,
  });

  @override
  State<ManualIncidentPage> createState() => _ManualIncidentPageState();
}

class _ManualIncidentPageState extends State<ManualIncidentPage> {
  final TextEditingController _descriptionController =
      TextEditingController();

  bool _loading = false;
  String? _error;

  void _createIncident() {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final description = _descriptionController.text.trim();

      if (description.isEmpty) {
        throw Exception("Description required");
      }

      final now = DateTime.now().toUtc();

      final event = _ManualIncidentCreated(
        eventId: "MANUAL-INC-${now.millisecondsSinceEpoch}",
        sequence: 0,
        version: 1,
        occurredAt: now,
        clientId: widget.selectedClient,
        siteId: widget.selectedSite,
        description: description,
      );

      widget.store.append(event);

      setState(() {
        _loading = false;
        _descriptionController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incident created")),
      );
    } catch (_) {
      setState(() {
        _loading = false;
        _error = "Failed to create incident";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manual Incident Entry"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Create Incident",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Incident Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _createIncident,
                child: const Text("Submit Incident"),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualIncidentCreated extends DispatchEvent {
  final String clientId;
  final String siteId;
  final String description;

  const _ManualIncidentCreated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.clientId,
    required this.siteId,
    required this.description,
  });

  @override
  _ManualIncidentCreated copyWithSequence(int sequence) {
    return _ManualIncidentCreated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      clientId: clientId,
      siteId: siteId,
      description: description,
    );
  }
}
