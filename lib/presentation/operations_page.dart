import 'package:flutter/material.dart';
import '../../domain/store/in_memory_event_store.dart';

class OperationsPage extends StatelessWidget {
  final InMemoryEventStore store;
  const OperationsPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => const Center(child: Text("Operations Page"));
}
