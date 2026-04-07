import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/authority/onyx_route.dart';
import 'package:omnix_dashboard/ui/onyx_route_registry.dart';
import 'package:omnix_dashboard/ui/onyx_route_registry_sections.dart';

void main() {
  group('route registry sections', () {
    test('mirror shell navigation section titles and route order', () {
      final sections = buildOnyxRouteRegistrySections(
        builders: _routeBuilders(),
      );

      expect(
        sections.map((section) => section.section.title).toList(),
        OnyxRouteSection.values.map((section) => section.title).toList(),
      );

      for (var index = 0; index < sections.length; index++) {
        expect(
          sections[index].registrations
              .map((registration) => registration.route)
              .toList(growable: false),
          OnyxRouteSection.values[index].routes,
        );
      }

      expect(
        sections
            .expand((section) => section.registrations)
            .map((registration) => registration.route)
            .toSet(),
        OnyxRoute.values.toSet(),
      );
    });

    test('build registry returns a page for every onyx route', () {
      final registry = buildOnyxRouteRegistry(
        sections: buildOnyxRouteRegistrySections(builders: _routeBuilders()),
      );

      for (final route in OnyxRoute.values) {
        final page = registry.build(route);

        expect(page, isA<SizedBox>());
        expect((page as SizedBox).key, ValueKey<String>(route.name));
      }
    });

    test('registry section lists are unmodifiable', () {
      final sections = buildOnyxRouteRegistrySections(
        builders: _routeBuilders(),
      );

      expect(
        () => sections.add(
          _section(OnyxRouteSection.system, <OnyxRoute>[OnyxRoute.admin]),
        ),
        throwsUnsupportedError,
      );
    });

    test('registry sections defensively copy builder maps', () {
      final builders = _routeBuilders();
      final sections = buildOnyxRouteRegistrySections(builders: builders);

      builders.remove(OnyxRoute.dashboard);

      expect(
        sections.first.registrations
            .map((registration) => registration.route)
            .toList(growable: false),
        OnyxRouteSection.commandCenter.routes,
      );
    });

    test('duplicate registry sections throw a state error', () {
      expect(
        () => buildOnyxRouteRegistry(
          sections: <OnyxRouteRegistrySection>[
            _section(OnyxRouteSection.commandCenter, <OnyxRoute>[
              OnyxRoute.dashboard,
            ]),
            _section(OnyxRouteSection.commandCenter, <OnyxRoute>[
              OnyxRoute.dashboard,
            ]),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('Duplicate route registry section') &&
                error.toString().contains('COMMAND CENTER'),
          ),
        ),
      );
    });

    test('duplicate route registrations in a section throw a state error', () {
      expect(
        () => OnyxRouteRegistrySection(
          section: OnyxRouteSection.commandCenter,
          registrations: <OnyxRouteRegistration>[
            _registrationFor(OnyxRoute.dashboard),
            _registrationFor(OnyxRoute.dashboard),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('Duplicate route registration') &&
                error.toString().contains('dashboard') &&
                error.toString().contains('COMMAND CENTER'),
          ),
        ),
      );
    });

    test('empty registry sections throw a state error', () {
      expect(
        () => OnyxRouteRegistrySection(
          section: OnyxRouteSection.commandCenter,
          registrations: <OnyxRouteRegistration>[],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('must include at least one route') &&
                error.toString().contains('COMMAND CENTER'),
          ),
        ),
      );
    });

    test('wrong-section registrations throw at section construction time', () {
      expect(
        () => OnyxRouteRegistrySection(
          section: OnyxRouteSection.system,
          registrations: <OnyxRouteRegistration>[
            _registrationFor(OnyxRoute.dashboard),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('dashboard') &&
                error.toString().contains('SYSTEM') &&
                error.toString().contains('COMMAND CENTER'),
          ),
        ),
      );
    });

    test('out-of-order section routes throw at section construction time', () {
      expect(
        () => OnyxRouteRegistrySection(
          section: OnyxRouteSection.commandCenter,
          registrations: <OnyxRouteRegistration>[
            _registrationFor(OnyxRoute.agent),
            _registrationFor(OnyxRoute.dashboard),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('COMMAND CENTER') &&
                error.toString().contains('dashboard, agent') &&
                error.toString().contains('agent, dashboard'),
          ),
        ),
      );
    });

    test('skipped section routes throw at section construction time', () {
      expect(
        () => OnyxRouteRegistrySection(
          section: OnyxRouteSection.commandCenter,
          registrations: <OnyxRouteRegistration>[
            _registrationFor(OnyxRoute.dashboard),
            _registrationFor(OnyxRoute.aiQueue),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('COMMAND CENTER') &&
                error.toString().contains('dashboard, agent') &&
                error.toString().contains('dashboard, aiQueue'),
          ),
        ),
      );
    });

    test('out-of-order registry sections throw a state error', () {
      expect(
        () => buildOnyxRouteRegistry(
          sections: <OnyxRouteRegistrySection>[
            _section(
              OnyxRouteSection.system,
              OnyxRouteSection.system.routes,
            ),
            _section(
              OnyxRouteSection.commandCenter,
              OnyxRouteSection.commandCenter.routes,
            ),
            _section(
              OnyxRouteSection.operations,
              OnyxRouteSection.operations.routes,
            ),
            _section(
              OnyxRouteSection.governance,
              OnyxRouteSection.governance.routes,
            ),
            _section(
              OnyxRouteSection.evidence,
              OnyxRouteSection.evidence.routes,
            ),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains(
                  'COMMAND CENTER, OPERATIONS, GOVERNANCE, EVIDENCE, SYSTEM',
                ) &&
                error.toString().contains(
                  'SYSTEM, COMMAND CENTER, OPERATIONS, GOVERNANCE, EVIDENCE',
                ),
          ),
        ),
      );
    });

    test('route registration helper throws on route and builder mismatch', () {
      expect(
        () => onyxRouteRegistrations(
          routes: OnyxRouteSection.commandCenter.routes,
          builders: <OnyxRouteBuilder>[_builderFor(OnyxRoute.dashboard)],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('count mismatch'),
          ),
        ),
      );
    });

    test(
      'building registry sections throws when a section route is missing',
      () {
        final builders = _routeBuilders()..remove(OnyxRoute.admin);

        expect(
          () => buildOnyxRouteRegistrySections(builders: builders),
          throwsA(
            predicate<Object>(
              (error) =>
                  error is StateError &&
                  error.toString().contains('admin') &&
                  error.toString().contains('SYSTEM'),
            ),
          ),
        );
      },
    );

    test('building a registry with missing sections throws a state error', () {
      expect(
        () => buildOnyxRouteRegistry(
          sections: <OnyxRouteRegistrySection>[
            _section(OnyxRouteSection.commandCenter, <OnyxRoute>[
              OnyxRoute.dashboard,
            ]),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains(
                  'Missing route registry sections registered for',
                ) &&
                error.toString().contains('OPERATIONS') &&
                error.toString().contains('SYSTEM'),
          ),
        ),
      );
    });

    test('building a registry with an incomplete section throws a state error', () {
      expect(
        () => buildOnyxRouteRegistry(
          sections: <OnyxRouteRegistrySection>[
            _section(
              OnyxRouteSection.commandCenter,
              OnyxRouteSection.commandCenter.routes,
            ),
            _section(OnyxRouteSection.operations, <OnyxRoute>[
              OnyxRoute.vip,
              OnyxRoute.intel,
            ]),
            _section(
              OnyxRouteSection.governance,
              OnyxRouteSection.governance.routes,
            ),
            _section(
              OnyxRouteSection.evidence,
              OnyxRouteSection.evidence.routes,
            ),
            _section(
              OnyxRouteSection.system,
              OnyxRouteSection.system.routes,
            ),
          ],
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains(
                  'Incomplete route registry section OPERATIONS',
                ) &&
                error.toString().contains('clients') &&
                error.toString().contains('events'),
          ),
        ),
      );
    });

    test('constructing a partial registry throws a state error', () {
      expect(
        () => OnyxRouteRegistry(
          builders: <OnyxRoute, OnyxRouteBuilder>{
            OnyxRoute.dashboard: _builderFor(OnyxRoute.dashboard),
          },
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error is StateError &&
                error.toString().contains('agent') &&
                error.toString().contains('admin'),
          ),
        ),
      );
    });

    test('registry sections expose unmodifiable registration lists', () {
      final section = _section(OnyxRouteSection.commandCenter, <OnyxRoute>[
        OnyxRoute.dashboard,
      ]);

      expect(
        () => section.registrations.add(_registrationFor(OnyxRoute.agent)),
        throwsUnsupportedError,
      );
    });

    test('registry sections defensively copy registration lists', () {
      final registrations = <OnyxRouteRegistration>[
        _registrationFor(OnyxRoute.dashboard),
      ];
      final section = OnyxRouteRegistrySection(
        section: OnyxRouteSection.commandCenter,
        registrations: registrations,
      );

      registrations.add(_registrationFor(OnyxRoute.agent));

      expect(
        section.registrations
            .map((registration) => registration.route)
            .toList(growable: false),
        <OnyxRoute>[OnyxRoute.dashboard],
      );
    });

    test('route registration helper returns an unmodifiable list', () {
      final registrations = onyxRouteRegistrations(
        routes: <OnyxRoute>[OnyxRoute.dashboard],
        builders: <OnyxRouteBuilder>[_builderFor(OnyxRoute.dashboard)],
      );

      expect(
        () => registrations.add(_registrationFor(OnyxRoute.agent)),
        throwsUnsupportedError,
      );
    });

    test('registry defensively copies builder maps', () {
      final builders = _routeBuilders();
      final registry = OnyxRouteRegistry(builders: builders);

      builders
        ..remove(OnyxRoute.admin)
        ..[OnyxRoute.dashboard] = _builderFor(OnyxRoute.admin);

      final adminPage = registry.build(OnyxRoute.admin);
      expect(adminPage, isA<SizedBox>());
      expect((adminPage as SizedBox).key, ValueKey<String>(OnyxRoute.admin.name));

      final page = registry.build(OnyxRoute.dashboard);
      expect(page, isA<SizedBox>());
      expect((page as SizedBox).key, ValueKey<String>(OnyxRoute.dashboard.name));
    });
  });
}

Map<OnyxRoute, OnyxRouteBuilder> _routeBuilders() {
  return <OnyxRoute, OnyxRouteBuilder>{
    for (final route in OnyxRoute.values) route: _builderFor(route),
  };
}

OnyxRouteRegistrySection _section(
  OnyxRouteSection section,
  List<OnyxRoute> routes,
) {
  return OnyxRouteRegistrySection(
    section: section,
    registrations: routes.map(_registrationFor).toList(growable: false),
  );
}

OnyxRouteRegistration _registrationFor(OnyxRoute route) {
  return OnyxRouteRegistration(
    route: route,
    builder: _builderFor(route),
  );
}

OnyxRouteBuilder _builderFor(
  OnyxRoute route,
) => () => SizedBox(key: ValueKey<String>(route.name));
