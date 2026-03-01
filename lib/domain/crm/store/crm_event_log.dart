import '../crm_event.dart';

class CRMEventLog {
  final List<CRMEvent> _events = [];

  void append(CRMEvent event) {
    _events.add(event);
  }

  List<CRMEvent> all() {
    return List.unmodifiable(_events);
  }

  List<CRMEvent> byClient(String clientId) {
    return _events
        .where((e) => e.aggregateId == clientId)
        .toList();
  }
}
