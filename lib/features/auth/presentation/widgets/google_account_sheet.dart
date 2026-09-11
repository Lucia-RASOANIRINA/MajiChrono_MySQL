import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/auth/presentation/widgets/auth_branding.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_loader.dart';

/// Choix du compte Google, en feuille basse.
///
/// Une feuille et non un ecran : le choix du compte n'est pas une etape du
/// parcours, c'est une precision apportee a une intention deja exprimee. Elle se
/// referme d'un glissement, et l'ecran du numero est toujours derriere — celui
/// qui hesite n'a rien perdu.
///
/// Retourne l'adresse choisie, ou `null` si la feuille est fermee sans choix.
Future<String?> showGoogleAccountSheet(
  BuildContext context, {
  SocialProvider provider = SocialProvider.google,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _GoogleAccountSheet(provider: provider),
);

class _GoogleAccountSheet extends ConsumerStatefulWidget {
  const _GoogleAccountSheet({required this.provider});

  final SocialProvider provider;

  @override
  ConsumerState<_GoogleAccountSheet> createState() =>
      _GoogleAccountSheetState();
}

class _GoogleAccountSheetState extends ConsumerState<_GoogleAccountSheet> {
  final TextEditingController _manual = TextEditingController();
  bool _typing = false;

  /// Meme regle que le serveur. La verifier ici evite un aller-retour reseau
  /// pour une faute de frappe evidente — sur 2G, cet aller-retour coute quelques
  /// secondes d'attente pour rien.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hints = ref.watch(googleAccountHintsProvider);

    return SafeArea(
      child: Padding(
        // La marge du clavier : sans elle, le champ de saisie manuelle disparait
        // sous le clavier des qu'il prend le focus.
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SocialMark(provider: widget.provider, size: 24),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.authGoogleSheetTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.authGoogleSheetSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (!_typing)
              hints.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: McLoader()),
                ),
                // Une detection en echec n'est pas une impasse : la saisie
                // manuelle reste ouverte juste en dessous.
                error: (_, _) => const SizedBox.shrink(),
                data: (accounts) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final account in accounts)
                      _AccountTile(
                        hint: account,
                        onTap: () => Navigator.of(context).pop(account.email),
                      ),
                  ],
                ),
              ),

            if (_typing) ...[
              TextField(
                controller: _manual,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.authGoogleOtherAccountLabel,
                  prefixIcon: const Icon(Icons.alternate_email),
                  errorText:
                      _manual.text.isNotEmpty &&
                          !_emailPattern.hasMatch(_manual.text.trim())
                      ? l10n.authGoogleEmailInvalid
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submitManual(),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _emailPattern.hasMatch(_manual.text.trim())
                    ? _submitManual
                    : null,
                child: Text(l10n.commonContinue),
              ),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: Text(l10n.authGoogleOtherAccount),
                onTap: () => setState(() => _typing = true),
              ),
          ],
        ),
      ),
    );
  }

  void _submitManual() {
    final email = _manual.text.trim();
    if (!_emailPattern.hasMatch(email)) return;
    Navigator.of(context).pop(email);
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.hint, required this.onTap});

  final GoogleAccountHint hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundImage: hint.avatarUrl == null
            ? null
            : NetworkImage(hint.avatarUrl!),
        child: Text(
          hint.initial,
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(hint.label),
      // L'adresse complete est toujours montree, meme quand un nom existe :
      // c'est elle qui recevra le code, et deux comptes peuvent porter le meme
      // nom.
      subtitle: Text(hint.email),
      onTap: onTap,
    );
  }
}
