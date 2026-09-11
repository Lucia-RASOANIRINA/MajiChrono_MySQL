import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/i18n/mg_material_localizations.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';
import 'package:majichrono/features/delivery/domain/entities/shopping_order.dart';
import 'package:majichrono/features/delivery/presentation/providers/relay_providers.dart';
import 'package:majichrono/features/delivery/presentation/widgets/delivery_options_step.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Pas « Options » de la creation de course (module 9).
///
/// Ce que ces tests protegent, c'est la discipline de l'ecran : chaque option
/// n'apparait que lorsqu'elle s'applique, et les conditions qui engagent
/// quelqu'un — le plafond du livreur, le port du — sont annoncees avant
/// l'envoi.
void main() {
  final relays = [
    const RelayPoint(
      id: 'rel_1',
      name: 'Epicerie Tsiky',
      district: 'Ambohipo',
      landmark: 'Portail vert',
      point: GeoPoint(-18.91, 47.55),
      openingHours: 'Lun-Sam 7h-19h',
      maxWeightKg: 15,
    ),
    const RelayPoint(
      id: 'rel_3',
      name: 'Kiosque Ivandry',
      district: 'Ivandry',
      landmark: 'Mur blanc',
      point: GeoPoint(-18.87, 47.53),
      openingHours: '6h-20h',
      // Trop petit pour un colis de 5 a 15 kg.
      maxWeightKg: 5,
    ),
  ];

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    DeliveryKind kind = DeliveryKind.standard,
    WeightCategory weight = WeightCategory.upTo2,
    Payer payer = Payer.sender,
    List<ShoppingItem> items = const [],
    String cap = '',
  }) async {
    late AppLocalizations l10n;

    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          relayPointsProvider((
            district: null,
            lat: null,
            lng: null,
          )).overrideWith((ref) async => relays),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            MgMaterialLocalizationsDelegate(),
            MgCupertinoLocalizationsDelegate(),
            MgWidgetsLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                l10n = AppLocalizations.of(context);
                return DeliveryOptionsStep(
                  kind: kind,
                  weight: weight,
                  dropoffDistrict: 'Ambohipo',
                  dropoffPoint: null,
                  payer: payer,
                  items: items,
                  cap: TextEditingController(text: cap),
                  storeHint: TextEditingController(),
                  relayPointId: null,
                  onPayer: (_) {},
                  onItems: (_) {},
                  onRelay: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  group('achat pour compte (EXI-C07, D5)', () {
    testWidgets('la section n apparait que pour ce type de course', (
      tester,
    ) async {
      // Afficher une liste de courses sur un envoi de colis ferait chercher
      // pourquoi elle ne sert a rien.
      final l10n = await pump(tester);
      expect(find.text(l10n.shoppingTitle), findsNothing);

      await pump(tester, kind: DeliveryKind.shopping);
      expect(find.text(l10n.shoppingTitle), findsOneWidget);
      expect(find.text(l10n.shoppingCap), findsOneWidget);
    });

    testWidgets('un plafond hors bornes est signale', (tester) async {
      final l10n = await pump(
        tester,
        kind: DeliveryKind.shopping,
        cap: '100',
      );

      expect(
        find.text(
          l10n.shoppingCapOutOfRange(
            '5 000 Ar',
            '500 000 Ar',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('un plafond sous l estimation est signale avant l envoi', (
      tester,
    ) async {
      // Presque toujours une erreur de saisie. Le livreur ne doit pas le
      // decouvrir devant la caisse.
      final l10n = await pump(
        tester,
        kind: DeliveryKind.shopping,
        cap: '10000',
        items: const [
          ShoppingItem(label: 'Riz', quantity: 2, estimatedUnitAriary: 12000),
        ],
      );

      expect(find.text(l10n.shoppingCapTooLow), findsOneWidget);
    });

    testWidgets('un plafond suffisant ne signale rien', (tester) async {
      final l10n = await pump(
        tester,
        kind: DeliveryKind.shopping,
        cap: '50000',
        items: const [
          ShoppingItem(label: 'Riz', quantity: 2, estimatedUnitAriary: 12000),
        ],
      );

      expect(find.text(l10n.shoppingCapTooLow), findsNothing);
    });

    testWidgets('le plafond explique pourquoi il existe', (tester) async {
      // « Le livreur avance son propre argent » : sans cette phrase, le champ
      // passe pour une contrainte administrative.
      final l10n = await pump(tester, kind: DeliveryKind.shopping);
      expect(find.text(l10n.shoppingCapHelp), findsOneWidget);
    });
  });

  group('payeur designable (EXI-C42)', () {
    testWidgets('les deux options sont offertes', (tester) async {
      final l10n = await pump(tester);

      expect(find.text(l10n.payerSender), findsOneWidget);
      expect(find.text(l10n.payerRecipient), findsOneWidget);
    });

    testWidgets('le port du previent de son risque', (tester) async {
      // Un destinataire qui decouvre un prix sur le pas de sa porte refuse le
      // colis, et c'est le livreur qui perd sa course.
      final l10n = await pump(tester);
      expect(find.text(l10n.payerRecipientNotice), findsNothing);

      await pump(tester, payer: Payer.recipient);
      expect(find.text(l10n.payerRecipientNotice), findsOneWidget);
    });
  });

  group('points relais (D6)', () {
    testWidgets('la livraison a l adresse reste le defaut', (tester) async {
      final l10n = await pump(tester);
      expect(find.text(l10n.relayNone), findsOneWidget);
    });

    testWidgets('les relais du reseau sont proposes', (tester) async {
      await pump(tester);

      expect(find.text('Epicerie Tsiky'), findsOneWidget);
      expect(find.text('Kiosque Ivandry'), findsOneWidget);
    });

    testWidgets('un relais trop petit est visible mais inerte', (tester) async {
      // Le masquer laisserait croire qu'il n'existe pas ; l'activer laisserait
      // decouvrir le refus a la remise.
      final l10n = await pump(tester, weight: WeightCategory.from5to15);

      expect(find.text('Kiosque Ivandry'), findsOneWidget);
      expect(find.text(l10n.relayTooHeavy), findsOneWidget);

      final tiles = tester
          .widgetList<RadioListTile<String?>>(
            find.byType(RadioListTile<String?>),
          )
          .toList();

      final small = tiles.firstWhere((t) => t.value == 'rel_3');
      final big = tiles.firstWhere((t) => t.value == 'rel_1');
      expect(small.enabled, isFalse);
      expect(big.enabled, isTrue);
    });

    testWidgets('un colis leger passe partout', (tester) async {
      final l10n = await pump(tester);
      expect(find.text(l10n.relayTooHeavy), findsNothing);
    });
  });
}
