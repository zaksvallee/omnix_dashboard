import 'crm_event.dart';
import 'store/crm_event_log.dart';

class CRMService {
  final CRMEventLog eventLog;

  CRMService(this.eventLog);

  void handle(CRMEvent event) {
    eventLog.append(event);
  }
}
