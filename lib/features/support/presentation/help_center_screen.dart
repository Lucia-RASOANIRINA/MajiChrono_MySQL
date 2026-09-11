import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/support/support_contact.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Centre d'aide (§13) : les reponses aux questions courantes, et le moyen de
/// joindre le support quand elles ne suffisent pas.
///
/// L'aide vient **avant** le contact : la plupart des questions (creer une
/// course, payer, annuler) ont une reponse immediate, et n'ont pas a passer par
/// un appel. Le support reste a une touche pour le reste.
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: SupportContact.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _copyFallback(context, SupportContact.phone);
    }
  }

  Future<void> _email(BuildContext context, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SupportContact.email,
      query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      _copyFallback(context, SupportContact.email);
    }
  }

  void _copyFallback(BuildContext context, String value) {
    // Sur un appareil sans application de telephone ou de messagerie, on ne
    // laisse pas l'utilisateur sans recours : on lui montre la coordonnee.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  List<(String, String)> _faq(AppLocalizations l10n) => [
    (l10n.helpFaqQ1, l10n.helpFaqA1),
    (l10n.helpFaqQ2, l10n.helpFaqA2),
    (l10n.helpFaqQ3, l10n.helpFaqA3),
    (l10n.helpFaqQ4, l10n.helpFaqA4),
    (l10n.helpFaqQ5, l10n.helpFaqA5),
    (l10n.helpFaqQ6, l10n.helpFaqA6),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpCenterTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Contact support.
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.helpContactTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.helpContactHelp,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _call(context),
                          icon: const Icon(Icons.call_outlined),
                          label: Text(l10n.helpCall),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _email(context),
                          icon: const Icon(Icons.mail_outline),
                          label: Text(l10n.helpEmail),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.gavel_outlined, color: AppColors.primary),
            title: Text(l10n.disputesManage),
            subtitle: Text(l10n.disputesEmptyHelp),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.disputes),
          ),
          const Divider(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.report_problem_outlined,
                color: AppColors.warning),
            title: Text(l10n.helpReportProblem),
            subtitle: Text(l10n.helpReportProblemHelp),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _email(context, subject: l10n.helpReportSubject),
          ),

          const SizedBox(height: AppSpacing.lg),
          Text(l10n.helpFaqTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, entry) in _faq(l10n).indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ExpansionTile(
                    title: Text(entry.$1),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
