import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/profile/presentation/avatar_image.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Edition des informations personnelles : nom, photo, adresse e-mail, numero.
///
/// Le nom et la photo se modifient directement ; l'adresse et le numero passent
/// par une re-verification (code recu a la nouvelle adresse, SMS au nouveau
/// numero), parce que ce sont des cles d'identite : les deplacer sur simple
/// saisie ouvrirait la porte a un detournement de compte.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _picker = ImagePicker();
  bool _nameInit = false;
  bool _busy = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  UserAccount? _account() {
    final state = ref.read(authControllerProvider).valueOrNull;
    return switch (state) {
      AuthAuthenticated(:final account) => account,
      AuthLocked(:final account) => account,
      _ => null,
    };
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on Failure catch (failure) {
      _snack(failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    final l10n = AppLocalizations.of(context);
    final first = _firstName.text.trim();
    final last = _lastName.text.trim();
    if (first.isEmpty && last.isEmpty) {
      _snack(l10n.profileNameEmpty);
      return;
    }
    await _guard(() async {
      final account = await ref
          .read(authRepositoryProvider)
          .updateName(firstName: first, lastName: last);
      ref.read(authControllerProvider.notifier).applyAccount(account);
      _snack(l10n.profileSaved);
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    // image_picker redimensionne et recompresse a la source : l'image repart en
    // JPEG sous la limite du serveur, sans traitement supplementaire.
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _guard(() async {
      final account = await ref
          .read(authRepositoryProvider)
          .uploadAvatar(bytes: bytes, contentType: 'image/jpeg');
      ref.read(authControllerProvider.notifier).applyAccount(account);
      _snack(l10n.profileSaved);
    });
  }

  Future<void> _removePhoto() async {
    final l10n = AppLocalizations.of(context);
    await _guard(() async {
      final account = await ref.read(authRepositoryProvider).deleteAvatar();
      ref.read(authControllerProvider.notifier).applyAccount(account);
      _snack(l10n.profileSaved);
    });
  }

  Future<void> _changeEmail() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(authRepositoryProvider);
    final account = await showModalBottomSheet<UserAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactChangeSheet(
        title: l10n.emailChangeTitle,
        label: l10n.emailNew,
        keyboardType: TextInputType.emailAddress,
        onRequest: (value) async =>
            (await repo.requestEmailChange(value.trim())).challengeId,
        onConfirm: (challengeId, code) =>
            repo.confirmEmailChange(challengeId: challengeId, code: code),
        sentMessage: (dest) => l10n.codeSentToEmail(dest),
      ),
    );
    if (account != null) {
      ref.read(authControllerProvider.notifier).applyAccount(account);
      _snack(l10n.changeSaved);
    }
  }

  /// Ajouter un numero manquant n'ouvre pas le meme flux qu'en changer un :
  /// la passerelle SMS n'est pas encore branchee (elle journalise sans rien
  /// envoyer, `app/core/sms.py`), un code n'arriverait donc jamais. Mieux
  /// vaut le dire clairement que de laisser l'utilisateur attendre un SMS
  /// qui ne viendra pas.
  void _onPhoneTileTap() {
    final l10n = AppLocalizations.of(context);
    _snack(l10n.phoneVerificationUnavailable);
  }

  Future<void> _changePhone() async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(authRepositoryProvider);
    final account = await showModalBottomSheet<UserAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ContactChangeSheet(
        title: l10n.phoneChangeTitle,
        label: l10n.phoneNew,
        keyboardType: TextInputType.phone,
        onRequest: (value) async {
          final phone = MalagasyPhone.tryParse(value.trim());
          if (phone == null) {
            throw ValidationFailure(fieldErrors: {'phone': l10n.phoneInvalid});
          }
          return (await repo.requestPhoneChange(phone)).challengeId;
        },
        onConfirm: (challengeId, code) =>
            repo.confirmPhoneChange(challengeId: challengeId, code: code),
        sentMessage: (dest) => l10n.codeSentToPhone(dest),
      ),
    );
    if (account != null) {
      ref.read(authControllerProvider.notifier).applyAccount(account);
      _snack(l10n.changeSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = _account();
    if (account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_nameInit) {
      // On part du prenom/nom quand ils existent ; sinon on scinde l'ancien nom
      // d'usage, pour ne pas presenter des champs vides a qui en avait un.
      if (account.firstName != null || account.lastName != null) {
        _firstName.text = account.firstName ?? '';
        _lastName.text = account.lastName ?? '';
      } else {
        final parts = account.displayName.trim().split(RegExp(r'\s+'));
        _firstName.text = parts.isEmpty ? '' : parts.first;
        _lastName.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
      _nameInit = true;
    }
    final avatar = avatarImage(account.avatarUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = isDark ? const Color(0xFF60A5FA) : AppColors.primary;
    final displayName = account.displayName.trim();
    final initial = displayName.isEmpty
        ? '?'
        : displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEdit)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Center(
              child: CircleAvatar(
                radius: AppSizes.avatarLg / 2,
                backgroundColor: avatarColor.withValues(alpha: isDark ? 0.18 : 0.12),
                foregroundColor: avatarColor,
                foregroundImage: avatar,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor.withValues(alpha: 0.45), width: 2),
                  ),
                  child: Center(
                    child: avatar == null
                        ? Text(
                            initial,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: avatarColor,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.profilePhotoFromGallery),
                ),
                TextButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.profilePhotoFromCamera),
                ),
                if (account.avatarUrl != null)
                  TextButton.icon(
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.profilePhotoRemove),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _firstName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.profileFirstName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.profileLastName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy ? null : _saveName,
                child: Text(l10n.commonSave),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            _ContactTile(
              icon: Icons.alternate_email,
              label: l10n.profileEmailLabel,
              value: account.email ?? l10n.profileEmailNone,
              actionLabel: account.email == null
                  ? l10n.profileAdd
                  : l10n.profileChange,
              onTap: _busy ? null : _changeEmail,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ContactTile(
              icon: Icons.smartphone,
              label: l10n.profilePhoneLabel,
              value: account.phone?.displayNational ?? l10n.profilePhoneNone,
              actionLabel: account.phone == null
                  ? l10n.profileAdd
                  : l10n.profileChange,
              onTap: _busy
                  ? null
                  : (account.phone == null ? _onPhoneTileTap : _changePhone),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onTap, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

/// Feuille de changement d'une cle de contact (adresse ou numero) : saisie de la
/// nouvelle valeur, envoi d'un code, puis verification. Rend le compte a jour au
/// `Navigator.pop`, ou rien si l'utilisateur renonce.
class _ContactChangeSheet extends StatefulWidget {
  const _ContactChangeSheet({
    required this.title,
    required this.label,
    required this.keyboardType,
    required this.onRequest,
    required this.onConfirm,
    required this.sentMessage,
  });

  final String title;
  final String label;
  final TextInputType keyboardType;
  final Future<String> Function(String value) onRequest;
  final Future<UserAccount> Function(String challengeId, String code) onConfirm;
  final String Function(String dest) sentMessage;

  @override
  State<_ContactChangeSheet> createState() => _ContactChangeSheetState();
}

class _ContactChangeSheetState extends State<_ContactChangeSheet> {
  final _value = TextEditingController();
  final _code = TextEditingController();
  String? _challengeId;
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _code.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final id = await widget.onRequest(_value.text);
      setState(() => _challengeId = id);
      _snack(widget.sentMessage(_value.text.trim()));
    } on Failure catch (failure) {
      // Une validation locale (numero mal forme) porte son message dans
      // `fieldErrors` ; sinon on rend la phrase standard de l'erreur.
      final message =
          failure is ValidationFailure && failure.fieldErrors.isNotEmpty
          ? failure.fieldErrors.values.first
          : failure.localizedMessage(l10n);
      _snack(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final account = await widget.onConfirm(_challengeId!, _code.text.trim());
      navigator.pop(account);
    } on Failure catch (failure) {
      _snack(failure.localizedMessage(l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sent = _challengeId != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _value,
            enabled: !sent,
            keyboardType: widget.keyboardType,
            decoration: InputDecoration(labelText: widget.label),
          ),
          if (sent) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.codeEnterTitle),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy
                ? null
                : sent
                ? _confirm
                : _send,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(sent ? l10n.commonVerify : l10n.commonSend),
          ),
        ],
      ),
    );
  }
}
