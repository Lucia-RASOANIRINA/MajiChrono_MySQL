import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/delivery/domain/entities/address.dart';
import 'package:majichrono/features/delivery/presentation/providers/delivery_providers.dart';
import 'package:majichrono/features/delivery/presentation/widgets/address_form.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';

/// Carnet d'adresses (EXI-C05) : consulter, ajouter, modifier, supprimer les
/// adresses enregistrees, et distinguer domicile / travail / favoris.
class AddressBookScreen extends ConsumerStatefulWidget {
  const AddressBookScreen({super.key});

  @override
  ConsumerState<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends ConsumerState<AddressBookScreen> {
  @override
  void initState() {
    super.initState();
    // Recharge depuis le serveur ; en cas d'echec reseau, le flux local prend
    // le relais et le carnet reste consultable hors ligne.
    Future.microtask(
      () => ref.read(deliveryRepositoryProvider).fetchAddresses().ignore(),
    );
  }

  Future<void> _edit([SavedAddress? existing]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _AddressEditorScreen(existing: existing)),
    );
    ref.read(deliveryRepositoryProvider).fetchAddresses().ignore();
  }

  Future<void> _delete(SavedAddress entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(deliveryRepositoryProvider).deleteAddress(entry.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.addressDeleted)));
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final book = ref.watch(addressBookProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addressBookTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.addressAdd),
      ),
      body: book.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.errorNetwork)),
        data: (entries) {
          if (entries.isEmpty) {
            return McEmptyState(
              icon: Icons.location_off_outlined,
              title: l10n.addressEmpty,
              message: l10n.addressEmptyHelp,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _AddressTile(
              entry: entries[i],
              onEdit: () => _edit(entries[i]),
              onDelete: () => _delete(entries[i]),
            ),
          );
        },
      ),
    );
  }
}

String kindLabel(AppLocalizations l10n, AddressKind kind) => switch (kind) {
  AddressKind.home => l10n.addressKindHome,
  AddressKind.work => l10n.addressKindWork,
  AddressKind.favorite => l10n.addressKindFavorite,
  AddressKind.other => l10n.addressKindOther,
};

IconData kindIcon(AddressKind kind) => switch (kind) {
  AddressKind.home => Icons.home_outlined,
  AddressKind.work => Icons.work_outline,
  AddressKind.favorite => Icons.star_outline,
  AddressKind.other => Icons.place_outlined,
};

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedAddress entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Icon(kindIcon(entry.kind), color: AppColors.primary),
        ),
        title: Text(
          entry.label.isEmpty ? kindLabel(l10n, entry.kind) : entry.label,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          entry.address.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onEdit,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: AppColors.danger,
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// Editeur d'une entree : nom, nature, et l'adresse composite (formulaire +
/// carte). Un seul ecran pour l'ajout et la modification.
class _AddressEditorScreen extends ConsumerStatefulWidget {
  const _AddressEditorScreen({this.existing});

  final SavedAddress? existing;

  @override
  ConsumerState<_AddressEditorScreen> createState() =>
      _AddressEditorScreenState();
}

class _AddressEditorScreenState extends ConsumerState<_AddressEditorScreen> {
  late final TextEditingController _label = TextEditingController(
    text: widget.existing?.label ?? '',
  );
  late AddressKind _kind = widget.existing?.kind ?? AddressKind.other;
  late Address? _address = widget.existing?.address;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_address == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.addressNeedPoint)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(deliveryRepositoryProvider)
          .saveAddress(
            id: widget.existing?.id,
            label: _label.text.trim(),
            kind: _kind,
            address: _address!,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.addressSaved)));
      navigator.pop();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNew = widget.existing == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l10n.addressAdd : l10n.addressEditTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.addressLabelField,
              prefixIcon: const Icon(Icons.bookmark_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.addressKindLabel),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final kind in AddressKind.values)
                ChoiceChip(
                  avatar: Icon(kindIcon(kind), size: 18),
                  label: Text(kindLabel(l10n, kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AddressForm(
            initial: widget.existing?.address,
            onChanged: (a) => _address = a,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
