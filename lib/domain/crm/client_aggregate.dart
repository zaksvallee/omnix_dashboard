import 'client.dart';
import 'site.dart';
import 'sla_profile.dart';
import 'crm_event.dart';
import 'client_contact.dart';

class ClientAggregate {
  final Client client;
  final List<Site> sites;
  final SLAProfile? slaProfile;
  final List<ClientContact> contacts;

  const ClientAggregate({
    required this.client,
    required this.sites,
    required this.slaProfile,
    required this.contacts,
  });

  static ClientAggregate rebuild(List<CRMEvent> events) {
    if (events.isEmpty) {
      throw Exception("Cannot rebuild ClientAggregate without events");
    }

    Client? client;
    final sites = <Site>[];
    SLAProfile? slaProfile;
    final contacts = <ClientContact>[];

    for (final event in events) {
      switch (event.type) {
        case CRMEventType.clientCreated:
          client = Client(
            clientId: event.aggregateId,
            name: event.payload['name'] as String,
            createdAt: event.timestamp,
          );
          break;

        case CRMEventType.siteAdded:
          sites.add(
            Site(
              siteId: event.payload['site_id'] as String,
              clientId: event.aggregateId,
              name: event.payload['name'] as String,
              geoReference: event.payload['geo_reference'] as String,
              createdAt: event.timestamp,
            ),
          );
          break;

        case CRMEventType.slaProfileAttached:
        case CRMEventType.slaProfileUpdated:
          slaProfile = SLAProfile(
            slaId: event.payload['sla_id'] as String,
            clientId: event.aggregateId,
            lowMinutes: event.payload['low'] as int,
            mediumMinutes: event.payload['medium'] as int,
            highMinutes: event.payload['high'] as int,
            criticalMinutes: event.payload['critical'] as int,
            createdAt: event.timestamp,
          );
          break;

        case CRMEventType.clientContactLogged:
          contacts.add(
            ClientContact(
              contactId: event.payload['contact_id'] as String,
              channel: event.payload['channel'] as String,
              summary: event.payload['summary'] as String,
              loggedAt: event.timestamp,
            ),
          );
          break;
      }
    }

    if (client == null) {
      throw Exception("ClientCreated event missing");
    }

    return ClientAggregate(
      client: client,
      sites: sites,
      slaProfile: slaProfile,
      contacts: contacts,
    );
  }
}
