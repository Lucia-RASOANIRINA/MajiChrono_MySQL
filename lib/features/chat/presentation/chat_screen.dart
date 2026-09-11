import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/chat/presentation/chat_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Discussion en direct entre l'expediteur et le livreur d'une course.
///
/// Elle s'ouvre a l'acceptation et vit le temps de la course : le contexte,
/// c'est le colis en chemin. Les messages relus toutes les trois secondes
/// suffisent a une conversation utilitaire — « je suis en bas », « troisieme
/// etage » — sans le cout d'un canal permanent sur un reseau instable.
///
/// Elle porte les codes d'une messagerie ordinaire : bulles cote a cote,
/// separateurs de jour, regroupement des messages consecutifs d'un meme
/// auteur, accuse de lecture (un crochet « envoye », deux crochets « lu »), et
/// un appel direct de l'interlocuteur quand son numero est connu.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.deliveryId,
    this.title,
    this.phone,
    super.key,
  });

  final String deliveryId;
  final String? title;

  /// Numero de l'interlocuteur, si l'appelant le connait. Present, il affiche
  /// un bouton d'appel dans l'en-tete ; absent, la discussion reste par ecrit.
  final String? phone;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    unawaited(HapticFeedback.selectionClick());
    final ok = await ref
        .read(chatControllerProvider(widget.deliveryId).notifier)
        .send(text);
    if (!ok && mounted) {
      _input.text = text; // On rend le texte pour ne pas le perdre.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).chatSendError)),
      );
    }
  }

  Future<void> _call() async {
    final phone = widget.phone;
    if (phone == null) return;
    unawaited(HapticFeedback.selectionClick());
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  String? _accountId() {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    return switch (auth) {
      AuthAuthenticated(:final account) => account.id,
      AuthLocked(:final account) => account.id,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(chatControllerProvider(widget.deliveryId));
    final me = _accountId();

    if (state.messages.length != _lastCount) {
      _lastCount = state.messages.length;
      _scrollToEnd();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(widget.title ?? l10n.chatTitle),
        actions: [
          if (widget.phone != null)
            IconButton(
              tooltip: l10n.chatCall,
              icon: const Icon(Icons.call_outlined),
              onPressed: _call,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body(context, state, me, isDark, l10n)),
          _Composer(
            controller: _input,
            sending: state.sending,
            onSend: _send,
            isDark: isDark,
            hint: l10n.chatInputHint,
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ChatState state,
    String? me,
    bool isDark,
    AppLocalizations l10n,
  ) {
    if (state.loading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      return _Empty(error: state.error, isDark: isDark, l10n: l10n);
    }

    final locale = Localizations.localeOf(context).toLanguageTag();
    final messages = state.messages;

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previous = index > 0 ? messages[index - 1] : null;

        // Un separateur de jour ouvre chaque journee : « Aujourd'hui »,
        // « Hier », puis la date pleine au-dela.
        final showDay =
            previous == null || !_sameDay(previous.createdAt, message.createdAt);

        // Messages colles : meme auteur, moins de cinq minutes, meme jour. On
        // resserre l'espacement et on masque le rappel d'entete implicite.
        final grouped =
            !showDay &&
            previous.senderId == message.senderId &&
            message.createdAt.difference(previous.createdAt).inMinutes < 5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay)
              _DaySeparator(
                label: _dayLabel(message.createdAt, l10n, locale),
                isDark: isDark,
              ),
            _Bubble(
              message: message,
              mine: message.senderId == me,
              grouped: grouped,
              isDark: isDark,
              l10n: l10n,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  String _dayLabel(DateTime when, AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    final day = when.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return l10n.chatToday;
    if (diff == 1) return l10n.chatYesterday;
    return DateFormat.yMMMMd(locale).format(day);
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label, required this.isDark});

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.grouped,
    required this.isDark,
    required this.l10n,
  });

  final ChatMessage message;
  final bool mine;
  final bool grouped;
  final bool isDark;
  final AppLocalizations l10n;

  String _time(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theirBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final theirBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final theirText = isDark ? Colors.white : const Color(0xFF0F172A);
    final onMine = Colors.white;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: grouped ? 2 : AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : theirBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine || !grouped ? 18 : 4),
            topRight: Radius.circular(!mine || !grouped ? 18 : 4),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: theirBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: mine ? onMine : theirText,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: (mine ? onMine : theirText).withValues(alpha: 0.6),
                  ),
                ),
                // Accuse de lecture, sur mes seuls messages : un crochet des
                // l'envoi, deux crochets colores une fois lu par l'autre.
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.check,
                    size: 14,
                    color: message.isRead
                        ? const Color(0xFF7DD3FC)
                        : onMine.withValues(alpha: 0.6),
                    semanticLabel: message.isRead ? l10n.chatRead : l10n.chatSent,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.error, required this.isDark, required this.l10n});

  final Object? error;
  final bool isDark;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: muted),
            const SizedBox(height: AppSpacing.md),
            Text(
              error != null ? l10n.chatUnavailable : l10n.chatEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              error != null ? l10n.chatUnavailableHint : l10n.chatEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.isDark,
    required this.hint,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool isDark;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: surface,
          border: Border(top: BorderSide(color: border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
