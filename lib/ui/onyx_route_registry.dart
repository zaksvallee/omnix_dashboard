import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import '../domain/authority/onyx_route.dart';

typedef OnyxRouteBuilder = Widget Function();

class OnyxRouteRegistration {
  final OnyxRoute route;
  final OnyxRouteBuilder builder;

  const OnyxRouteRegistration({required this.route, required this.builder});
}

class OnyxRouteRegistrySection {
  final OnyxRouteSection section;
  final List<OnyxRouteRegistration> registrations;

  OnyxRouteRegistrySection({
    required this.section,
    required List<OnyxRouteRegistration> registrations,
  }) : registrations = List<OnyxRouteRegistration>.unmodifiable(registrations) {
    if (this.registrations.isEmpty) {
      throw StateError(
        'Route registry section ${section.title} must include at least one route registration.',
      );
    }

    final sectionRoutes = <OnyxRoute>[];
    final seenRoutes = <OnyxRoute>{};
    for (final registration in this.registrations) {
      if (registration.route.section != section) {
        throw StateError(
          'Route ${registration.route.name} was registered in ${section.title} '
          'but belongs to ${registration.route.section.title}.',
        );
      }
      if (!seenRoutes.add(registration.route)) {
        throw StateError(
          'Duplicate route registration for ${registration.route.name} '
          'in ${section.title}.',
        );
      }
      sectionRoutes.add(registration.route);
    }

    final expectedSectionRoutes = section.routes
        .take(sectionRoutes.length)
        .toList(growable: false);
    if (!listEquals(sectionRoutes, expectedSectionRoutes)) {
      throw StateError(
        'Route registrations in ${section.title} must follow shared route '
        'order: expected ${expectedSectionRoutes.map((route) => route.name).join(', ')} '
        'but got ${sectionRoutes.map((route) => route.name).join(', ')}.',
      );
    }
  }
}

class OnyxRouteRegistry {
  final Map<OnyxRoute, OnyxRouteBuilder> _builders;

  OnyxRouteRegistry({required Map<OnyxRoute, OnyxRouteBuilder> builders})
    : _builders = Map<OnyxRoute, OnyxRouteBuilder>.unmodifiable(builders) {
    final missingRoutes = OnyxRoute.values
        .where((route) => !_builders.containsKey(route))
        .map((route) => route.name)
        .toList(growable: false);
    if (missingRoutes.isNotEmpty) {
      throw StateError(
        'Missing route builders registered for: ${missingRoutes.join(', ')}.',
      );
    }
  }

  Widget build(OnyxRoute route) => _builders[route]!();
}

List<OnyxRouteRegistration> onyxRouteRegistrations({
  required List<OnyxRoute> routes,
  required List<OnyxRouteBuilder> builders,
}) {
  if (routes.length != builders.length) {
    throw StateError(
      'Route registration count mismatch: '
      '${routes.length} routes for ${builders.length} builders.',
    );
  }

  return List<OnyxRouteRegistration>.unmodifiable(
    List<OnyxRouteRegistration>.generate(
      routes.length,
      (index) =>
          OnyxRouteRegistration(route: routes[index], builder: builders[index]),
      growable: false,
    ),
  );
}

OnyxRouteRegistry buildOnyxRouteRegistry({
  required List<OnyxRouteRegistrySection> sections,
}) {
  final builders = <OnyxRoute, OnyxRouteBuilder>{};
  final seenSections = <OnyxRouteSection>{};
  final sectionOrder = <OnyxRouteSection>[];
  for (final section in sections) {
    if (!seenSections.add(section.section)) {
      throw StateError(
        'Duplicate route registry section registered for '
        '${section.section.title}.',
      );
    }
    sectionOrder.add(section.section);
    for (final registration in section.registrations) {
      builders[registration.route] = registration.builder;
    }
  }

  final missingSections = OnyxRouteSection.values
      .where((section) => !seenSections.contains(section))
      .map((section) => section.title)
      .toList(growable: false);
  if (missingSections.isNotEmpty) {
    throw StateError(
      'Missing route registry sections registered for: '
      '${missingSections.join(', ')}.',
    );
  }

  for (final section in sections) {
    final expectedRoutes = section.section.routes;
    if (section.registrations.length == expectedRoutes.length) {
      continue;
    }

    final missingRoutes = expectedRoutes
        .skip(section.registrations.length)
        .map((route) => route.name)
        .toList(growable: false);
    throw StateError(
      'Incomplete route registry section ${section.section.title}: missing '
      '${missingRoutes.join(', ')}.',
    );
  }

  final expectedSectionOrder = OnyxRouteSection.values
      .where(sectionOrder.contains)
      .toList(growable: false);
  if (!listEquals(sectionOrder, expectedSectionOrder)) {
    throw StateError(
      'Route registry sections must follow shared section order: '
      'expected ${expectedSectionOrder.map((section) => section.title).join(', ')} '
      'but got ${sectionOrder.map((section) => section.title).join(', ')}.',
    );
  }

  return OnyxRouteRegistry(builders: builders);
}
