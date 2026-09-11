import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/i18n/mg_material_localizations.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/screens/custody_capture_screen.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/value_objects/geo_point.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Ecran de constat : issues de remise (EXI-CC26 a EXI-CC29).
///
/// Ce que ces tests protegent n'est pas l'esthetique de l'ecran, c'est sa
/// discipline : chaque issue fait apparaitre exactement les pieces qu'elle
/// exige, et rien de plus. Un champ de motif offert « au cas ou » finit vide ;
/// un cadre de signature laisse la ou personne ne doit signer finit rempli par
/// le livreur lui-meme.
void main() {
  Address address() => Address(
    point: const GeoPoint(-18.9010, 47.5490),
    district: 'Analakely',
    landmark: 'Face a la pharmacie',
    contactPhone: MalagasyPhone.tryParse('0341234567')!,
  );

  final delivery = Delivery(
    id: 'dlv_77',
    status: DeliveryStatus.inTransit,
    kind: DeliveryKind.standard,
    pickup: address(),
    dropoff: address(),
    package: const PackageDeclaration(weight: WeightCategory.from2to5),
    slot: const PickupSlot.immediate(),
    paymentMethod: PaymentMethod.cash,
    createdAt: DateTime(2026, 8, 14, 10),
  );

  Future<AppLocalizations> pumpScreen(
    WidgetTester tester, {
    CustodyStage stage = CustodyStage.handover,
  }) async {
    late AppLocalizations l10n;

    // Une surface haute plutot qu'un defilement pilote : ce qui est teste ici
    // est la presence et l'absence des champs selon l'issue choisie, pas la
    // capacite du test a faire glisser une liste jusqu'au bon pixel.
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
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
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return CustodyCaptureScreen(delivery: delivery, stage: stage);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    return l10n;
  }


  testWidgets('les cinq issues sont proposees, aucune pre-cochee', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    for (final label in [
      l10n.outcomeDelivered,
      l10n.outcomeWithReserves,
      l10n.outcomeRefused,
      l10n.outcomeThirdParty,
      l10n.outcomeNoSignature,
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    // Aucun defaut : « remis » doit etre affirme, pas suppose.
    final radios = tester.widgetList<RadioListTile<HandoverOutcome>>(
      find.byType(RadioListTile<HandoverOutcome>),
    );
    expect(radios, hasLength(HandoverOutcome.values.length));

    final group = tester.widget<RadioGroup<HandoverOutcome>>(
      find.byType(RadioGroup<HandoverOutcome>),
    );
    expect(group.groupValue, isNull);
  });

  testWidgets('une prise en charge ne propose aucune issue de remise', (
    tester,
  ) async {
    // L'issue n'a de sens qu'a la remise : la proposer au depart ferait
    // declarer une livraison avant meme d'avoir pris le colis.
    final l10n = await pumpScreen(tester, stage: CustodyStage.pickup);

    expect(find.text(l10n.custodyOutcomeTitle), findsNothing);
    expect(find.byType(RadioGroup<HandoverOutcome>), findsNothing);
    expect(find.text(l10n.custodyOtpTitle), findsNothing);
  });

  testWidgets('les reserves font apparaitre le motif et l avis de litige', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.custodyOutcomeReason), findsNothing);

    await tester.tap(find.text(l10n.outcomeWithReserves));
    await tester.pump();

    expect(find.text(l10n.custodyOutcomeReason), findsOneWidget);
    expect(find.text(l10n.custodyReservesNotice), findsOneWidget);
    // Les reserves restent une livraison : le code du destinataire est exige.
    expect(find.text(l10n.custodyOtpTitle), findsOneWidget);
  });

  testWidgets('un refus retire le code OTP et exige une photo', (tester) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.text(l10n.outcomeRefused));
    await tester.pump();

    expect(find.text(l10n.custodyRefusedNotice), findsOneWidget);
    expect(find.text(l10n.custodyOutcomeReason), findsOneWidget);
    // Un destinataire qui refuse ne confirmera pas la remise par un code :
    // l'exiger rendrait le refus impossible a consigner.
    expect(find.text(l10n.custodyOtpTitle), findsNothing);
  });

  testWidgets('la remise a un tiers demande identite, lien et piece', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    await tester.tap(find.text(l10n.outcomeThirdParty));
    await tester.pump();

    expect(find.text(l10n.custodyThirdPartyName), findsOneWidget);
    expect(find.text(l10n.custodyThirdPartyRelation), findsOneWidget);
    expect(find.text(l10n.custodyExtraPhotoId), findsOneWidget);
    expect(find.text(l10n.custodyOtpTitle), findsNothing);
  });

  testWidgets('le mode sans signature retire le pad du destinataire', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.custodySignerRecipient), findsOneWidget);

    await tester.tap(find.text(l10n.outcomeNoSignature));
    await tester.pump();

    // EXI-CC29 : un cadre de signature laisse vide invite a le faire remplir
    // par n'importe qui. Il disparait, et la photo le remplace.
    expect(find.text(l10n.custodySignerRecipient), findsNothing);
    expect(find.text(l10n.custodyExtraPhotoHandover), findsOneWidget);
    expect(find.text(l10n.custodySignerDriver), findsOneWidget);
  });

  testWidgets('un scelle rompu reclame sa propre photo (EXI-CC22)', (
    tester,
  ) async {
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.custodyExtraPhotoSeal), findsNothing);

    await tester.tap(find.text(l10n.sealBroken));
    await tester.pump();

    expect(find.text(l10n.custodySealIncident), findsOneWidget);
    expect(find.text(l10n.custodyExtraPhotoSeal), findsOneWidget);
  });

  testWidgets('la validation reste bloquee tant que le constat est incomplet', (
    tester,
  ) async {
    // EXI-CC03 : le statut ne progresse pas sans constat complet. Le bouton est
    // desactive, et l'ecran dit pourquoi — un bouton grise sans explication est
    // le meilleur moyen de faire cocher n'importe quoi.
    final l10n = await pumpScreen(tester);

    expect(find.text(l10n.custodyIncomplete), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(l10n.custodyValidate),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
