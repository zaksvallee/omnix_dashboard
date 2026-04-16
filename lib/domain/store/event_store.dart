import 'dart:async';

import '../events/dispatch_event.dart';

abstract class EventStore {
  void append(DispatchEvent event);
  List<DispatchEvent> allEvents();
  Stream<List<DispatchEvent>> watchAllEvents();
}
