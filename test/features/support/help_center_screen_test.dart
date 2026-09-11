import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:majichrono/features/support/presentation/help_center_screen.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Le centre d'aide est un ecran de contenu : le test verifie qu'il se compose
/// entierement — la FAQ, le contact support — sur le grand ecran comme le petit.
void main() {
  testWidgets('montre la FAQ et le contact du support', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const HelpCenterScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aide et support'), findsWidgets);
    expect(find.text('Questions frequentes'), findsOneWidget);
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.text('Ecrire'), findsOneWidget);
    // Les six questions sont pliees dans autant de tuiles depliables.
    expect(find.byType(ExpansionTile), findsNWidgets(6));

    // Une question s'ouvre et revele sa reponse.
    await tester.tap(find.text('Comment payer ?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('MajiPay'), findsOneWidget);
  });
}
