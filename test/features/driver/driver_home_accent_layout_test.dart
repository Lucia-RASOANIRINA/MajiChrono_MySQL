import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/shared/widgets/mc_delivery_card.dart';

/// Regression : l'accueil livreur s'affichait entierement blanc quand une
/// course active (carte avec lisere `accent`) etait presente dans la liste
/// defilante — un plante de layout du viewport rendait tout le corps vide.
///
/// On reproduit la structure minimale de l'ecran : une `McDeliveryCard` avec
/// `accent` dans un `ListView` sous un `Expanded`, sur un grand ecran.
void main() {
  testWidgets(
    'carte de course avec lisere accent se pose sans planter dans un ListView',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 120),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      McDeliveryCard(
                        statusLabel: 'En transit',
                        statusIcon: Icons.local_shipping,
                        origin: 'Depart, Antananarivo',
                        destination: 'Arrivee, Andraharo',
                        accent: Colors.blue,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(McDeliveryCard), findsOneWidget);
    },
  );
}
