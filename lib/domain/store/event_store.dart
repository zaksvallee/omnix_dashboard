import '../events/dispatch_event.dart';

abstract class EventStore {
  void append(DispatchEvent event);
  List<DispatchEvent> allEvents();
}
