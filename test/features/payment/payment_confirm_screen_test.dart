import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/core/i18n/mg_material_localizations.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/features/payment/presentation/screens/payment_confirm_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Ecran de confirmation du payeur.
///
/// Ce que ces tests protegent est l'invariant du module : le scan a seulement
/// apparie les appareils, et c'est **ici**, apres saisie du code, que le debit
/// devient possible. Un ecran qui accepterait de confirmer sans code
/// transformerait un geste d'appariement en autorisation de prelevement.
void main() {
  final intent = PaymentIntent(
    id: 'pay_1',
    deliveryId: 'dlv_77',
    amountAriary: 7500,
    direction: PaymentDirection.collect,
    status: PaymentStatus.claimed,
    createdAt: DateTime(2026, 8, 17, 9),
    expiresAt: DateTime(2026, 8, 17, 9, 5),
    payeeLabel: 'Rakoto le livreur',
  );

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    int available = 42000,
  }) async {
    late AppLocalizations l10n;

    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          majiPayBalanceProvider(UserRole.client).overrideWith(
            (ref) async => MajiPayBalance(
              availableAriary: available,
              accountRef: 'MP ** ** 4821',
              fetchedAt: DateTime(2026, 8, 17),
            ),
          ),
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
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return PaymentConfirmScreen(intent: intent);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('on voit ce qu on paie avant qu on demande le code', (
    tester,
  ) async {
    // Demander un code avant de montrer le montant et le beneficiaire
    // reviendrait a faire signer un cheque en blanc.
    final l10n = await pump(tester);

    expect(find.textContaining('7'), findsWidgets);
    expect(find.textContaining('Rakoto le livreur'), findsOneWidget);
    expect(find.text(l10n.payConfirmPin), findsOneWidget);

    final amountY = tester.getTopLeft(find.text(l10n.payAmount)).dy;
    final pinY = tester.getTopLeft(find.text(l10n.payConfirmPin)).dy;
    expect(amountY, lessThan(pinY));
  });

  testWidgets('sans code complet, la confirmation reste impossible', (
    tester,
  ) async {
    final l10n = await pump(tester);

    FilledButton button() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.textContaining(l10n.payConfirmAction('').split(' ').first),
        matching: find.byType(FilledButton),
      ),
    );

    expect(button().onPressed, isNull, reason: 'aucun chiffre saisi');

    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'code incomplet');

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('le code saisi est masque', (tester) async {
    await pump(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.maxLength, 4);
  });

  testWidgets('l ecran dit que scanner ne suffit pas', (tester) async {
    // C'est la phrase qui explique a l'utilisateur pourquoi on lui demande son
    // code alors qu'il vient de scanner. Sans elle, la saisie passe pour une
    // formalite de plus.
    final l10n = await pump(tester);

    expect(find.text(l10n.payConfirmNever), findsOneWidget);
  });

  testWidgets('le repli especes est offert avant tout echec', (tester) async {
    // EXI-MP08 : un client sans solde ne doit pas avoir a echouer d'abord pour
    // decouvrir qu'il peut payer autrement.
    final l10n = await pump(tester);

    expect(find.text(l10n.payCashFallback), findsOneWidget);
    expect(find.text(l10n.payCashHelp), findsOneWidget);
  });

  testWidgets('un solde insuffisant est annonce avant la saisie', (
    tester,
  ) async {
    final l10n = await pump(tester, available: 500);

    expect(find.text(l10n.payFailedInsufficient), findsOneWidget);
  });

  testWidgets('un solde suffisant n annonce aucun manque', (tester) async {
    final l10n = await pump(tester);

    expect(find.text(l10n.payFailedInsufficient), findsNothing);
  });

  testWidgets('le compte n est montre que masque (EXI-MP11)', (tester) async {
    await pump(tester);

    expect(find.text('MP ** ** 4821'), findsOneWidget);
  });
}
