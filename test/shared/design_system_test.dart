// Tests de fumee du design system : chaque composant se monte sans deborder
// ni jeter, dans les deux themes. Ils figent le contrat minimal (icone +
// libelle sur les statuts, repli initiales sur l'avatar) sur lequel les ecrans
// s'appuieront.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/app/theme/app_theme.dart';
import 'package:majichrono/shared/widgets/mc_app_header.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_delivery_card.dart';
import 'package:majichrono/shared/widgets/mc_driver_card.dart';
import 'package:majichrono/shared/widgets/mc_section_header.dart';
import 'package:majichrono/shared/widgets/mc_stat_tile.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

Future<void> _pump(WidgetTester tester, Widget child, {required bool dark}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'sombre' : 'clair';

    testWidgets('McCard se monte et reagit au toucher ($mode)', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        McCard(onTap: () => tapped++, child: const Text('Contenu')),
        dark: dark,
      );
      expect(find.text('Contenu'), findsOneWidget);
      await tester.tap(find.text('Contenu'));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('McStatusBadge montre toujours icone + libelle ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        const McStatusBadge(
          label: 'Livre',
          icon: Icons.check_circle,
          tone: McStatusTone.success,
        ),
        dark: dark,
      );
      expect(find.text('Livre'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('McSectionHeader affiche titre et action ($mode)', (
      tester,
    ) async {
      var seen = 0;
      await _pump(
        tester,
        McSectionHeader(
          title: 'Courses',
          subtitle: 'Aujourd hui',
          actionLabel: 'Tout voir',
          onAction: () => seen++,
        ),
        dark: dark,
      );
      expect(find.text('Courses'), findsOneWidget);
      await tester.tap(find.text('Tout voir'));
      expect(seen, 1);
    });

    testWidgets('McStatTile affiche valeur et libelle ($mode)', (tester) async {
      await _pump(
        tester,
        const McStatTile(
          value: '12 500 Ar',
          label: 'Gains du jour',
          icon: Icons.payments,
        ),
        dark: dark,
      );
      expect(find.text('12 500 Ar'), findsOneWidget);
      expect(find.text('Gains du jour'), findsOneWidget);
    });

    testWidgets('McDeliveryCard montre statut, trajet et faits ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        const McDeliveryCard(
          statusLabel: 'En cours',
          statusIcon: Icons.local_shipping,
          statusTone: McStatusTone.info,
          origin: 'Analakely',
          destination: 'Ivandry',
          facts: [
            McDeliveryFact(Icons.route, '4,2 km'),
            McDeliveryFact(Icons.schedule, '18 min'),
          ],
        ),
        dark: dark,
      );
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Analakely'), findsOneWidget);
      expect(find.text('Ivandry'), findsOneWidget);
      expect(find.text('4,2 km'), findsOneWidget);
    });

    testWidgets('McAppHeader montre salutation et statut ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        const McAppHeader(
          greeting: 'Bonjour Naina',
          subtitle: 'Expediteur',
          statusLabel: 'En ligne',
          statusIcon: Icons.cloud_done,
          actions: [Icon(Icons.settings)],
        ),
        dark: dark,
      );
      expect(find.text('Bonjour Naina'), findsOneWidget);
      expect(find.text('En ligne'), findsOneWidget);
      expect(find.text('Expediteur'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('McDriverCard retombe sur les initiales sans photo ($mode)', (
      tester,
    ) async {
      await _pump(
        tester,
        const McDriverCard(
          name: 'Naina Rakoto',
          rating: 4.8,
          vehicle: 'Moto',
          plate: '1234 TBA',
        ),
        dark: dark,
      );
      expect(find.text('Naina Rakoto'), findsOneWidget);
      expect(find.text('NR'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('Moto · 1234 TBA'), findsOneWidget);
    });
  }
}
