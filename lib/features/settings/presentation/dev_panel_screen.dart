import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/core/network/network_profile.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/storage/prefs_store.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Panneau developpeur — absent des compilations de production.
///
/// Ce n'est pas un gadget : sans lui, les scenarios de recette obligatoires du
/// §16.2 (course complete sans reseau, reseau instable a 2G, coupure en plein
/// constat) ne seraient jouables qu'en emportant un telephone hors couverture.
/// Il pilote le profil reseau simule et le taux d'echec injecte.
class DevPanelScreen extends ConsumerStatefulWidget {
  const DevPanelScreen({super.key});

  @override
  ConsumerState<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends ConsumerState<DevPanelScreen> {
  late NetworkProfile _profile;
  late double _failureRate;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsStoreProvider);
    final stored = prefs.getString(PrefsStore.keyDevNetworkProfile);
    _profile = NetworkProfile.values.firstWhere(
      (p) => p.name == stored,
      orElse: () => NetworkProfile.fourG,
    );
    _failureRate = prefs.getDouble(PrefsStore.keyDevFailureRate);
    // Reapplique l'etat persiste au client, afin qu'un redemarrage de
    // l'application ne remette pas silencieusement le reseau en 4G parfaite.
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  void _apply() {
    ref.read(apiClientProvider)
      ..simulatedProfile = _profile
      ..simulatedFailureRate = _failureRate;
    final prefs = ref.read(prefsStoreProvider);
    unawaited(prefs.setString(PrefsStore.keyDevNetworkProfile, _profile.name));
    unawaited(prefs.setDouble(PrefsStore.keyDevFailureRate, _failureRate));
    // Une sonde immediate rend le changement visible dans le bandeau EXI-T06.
    unawaited(ref.read(networkStatusServiceProvider).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final client = ref.watch(apiClientProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devPanelTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.devApiMode} : ${config.apiMode.name}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    config.isMock
                        ? 'Transport simule : la pile Dio reelle est traversee, '
                              'seul le socle reseau est remplace.'
                        : 'Transport reel : ${config.apiBaseUrl}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.devNetworkProfile, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final profile in NetworkProfile.values)
            ListTile(
              enabled: config.isMock,
              onTap: config.isMock
                  ? () {
                      setState(() => _profile = profile);
                      _apply();
                    }
                  : null,
              leading: Icon(
                _profile == profile
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _profile == profile ? theme.colorScheme.primary : null,
              ),
              title: Text(switch (profile) {
                NetworkProfile.fourG => l10n.devProfile4g,
                NetworkProfile.threeG => l10n.devProfile3g,
                NetworkProfile.twoG => l10n.devProfile2g,
                NetworkProfile.offline => l10n.devProfileOffline,
              }),
              subtitle: Text(
                profile.isOnline
                    ? '${profile.minLatencyMs}-${profile.maxLatencyMs} ms · '
                          '${profile.kbps} kbit/s · suivi ${profile.trackingRefreshInterval.inSeconds} s'
                    : 'Aucune requete n\'aboutit (scenario §16.2-1)',
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${l10n.devFailureRate} : ${(_failureRate * 100).round()} %',
            style: theme.textTheme.titleMedium,
          ),
          Slider(
            value: _failureRate,
            max: 0.9,
            divisions: 9,
            label: '${(_failureRate * 100).round()} %',
            onChanged: config.isMock
                ? (value) => setState(() => _failureRate = value)
                : null,
            onChangeEnd: (_) => _apply(),
          ),
          Text(
            'Coupure aleatoire en cours de requete — scenario §16.2-3 : '
            'aucune double transition, aucun double debit.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: const Text('Routes simulees enregistrees'),
                  trailing: Text(
                    '${client.mockBackend.registeredRoutes.length}',
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => ListView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: [
                        for (final route in client.mockBackend.registeredRoutes)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              route,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: Text(l10n.devResetMock),
                  onTap: () async {
                    await client.mockBackend.reset();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.devResetMock)));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Copier le journal local (EXI-P10)'),
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: AppLogger.instance.exportBuffer()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Journal copie')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
