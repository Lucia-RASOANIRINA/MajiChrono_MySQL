import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/settings/economy_mode.dart';
import 'package:majichrono/core/storage/prefs_store.dart';

/// Reglage du mode economie (EXI-T08), persiste entre deux lancements.
///
/// La cle `settings.saving_mode` existait depuis le module 0 sans personne pour
/// l'ecrire : le socle avait prevu la place, ce module la remplit.
final economySettingsProvider =
    NotifierProvider<EconomyController, EconomySettings>(EconomyController.new);

class EconomyController extends Notifier<EconomySettings> {
  @override
  EconomySettings build() {
    final raw = ref
        .watch(prefsStoreProvider)
        .getString(PrefsStore.keySavingMode);
    if (raw == null || raw.isEmpty) return const EconomySettings();

    try {
      return EconomySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // Un reglage illisible ne doit pas empecher l'application de demarrer :
      // on repart du defaut plutot que de tomber.
      return const EconomySettings();
    }
  }

  Future<void> update(EconomySettings settings) async {
    state = settings;
    await ref
        .read(prefsStoreProvider)
        .setString(PrefsStore.keySavingMode, jsonEncode(settings.toJson()));
  }

  Future<void> toggle({required bool enabled}) =>
      update(state.copyWith(enabled: enabled));
}
