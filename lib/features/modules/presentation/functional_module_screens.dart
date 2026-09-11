import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

class ResourceListScreen extends ConsumerStatefulWidget {
  const ResourceListScreen({
    required this.title,
    required this.endpoint,
    this.action,
    this.actionLabel,
    this.itemAction,
    this.statusAction,
    super.key,
  });

  final String title;
  final String endpoint;
  final VoidCallback? action;
  final String? actionLabel;
  final Future<void> Function(Map<String, dynamic> item)? itemAction;
  final Future<void> Function(Map<String, dynamic> item)? statusAction;

  @override
  ConsumerState<ResourceListScreen> createState() => _ResourceListScreenState();
}

class AvailableDeliveriesScreen extends ConsumerWidget {
  const AvailableDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ResourceListScreen(
    title: AppLocalizations.of(context).navDeliveries,
    endpoint: ApiEndpoints.deliveriesAvailable,
    itemAction: (item) => ref
        .read(apiClientProvider)
        .post<dynamic>(ApiEndpoints.deliveryAccept(item['id'].toString())),
  );
}

class DriverDeliveriesScreen extends ConsumerWidget {
  const DriverDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = AppLocalizations.of(context).navDeliveries;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: ResourceListScreen(
              title: title,
              endpoint: ApiEndpoints.deliveriesAvailable,
              itemAction: (item) => ref
                  .read(apiClientProvider)
                  .post<dynamic>(
                    ApiEndpoints.deliveryAccept(item['id'].toString()),
                  ),
            ),
          ),
          Expanded(
            child: ResourceListScreen(
              title: title,
              endpoint: ApiEndpoints.deliveries,
              statusAction: (item) => ref
                  .read(apiClientProvider)
                  .post<dynamic>(
                    ApiEndpoints.deliveryStatus(item['id'].toString()),
                    body: {'status': 'in_transit'},
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceListScreenState extends ConsumerState<ResourceListScreen> {
  List<Map<String, dynamic>> _items = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiClientProvider)
          .get<dynamic>(widget.endpoint);
      final raw = result is Map<String, dynamic> ? result['items'] : result;
      final items = raw is List
          ? raw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).errorUnknown);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _summary(Map<String, dynamic> item) {
    final values = [
      item['status'],
      item['pickup'],
      item['dropoff'],
      item['reason'],
      item['name'],
    ].where((value) => value != null && value.toString().isNotEmpty);
    return values
        .map((value) => value is String ? value : jsonEncode(value))
        .join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.action == null
          ? null
          : FloatingActionButton.extended(
              onPressed: widget.action,
              icon: const Icon(Icons.add),
              label: Text(widget.actionLabel ?? l10n.commonContinue),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: AppSpacing.xxl),
                        Center(
                          child: Text(
                            l10n.emptyDeliveries,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.12),
                              foregroundColor: theme.colorScheme.primary,
                              child: const Icon(Icons.inventory_2_outlined),
                            ),
                            title: Text(item['id']?.toString() ?? widget.title),
                            subtitle: Text(
                              _summary(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing:
                                widget.itemAction == null &&
                                    widget.statusAction == null
                                ? null
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.itemAction != null)
                                        IconButton(
                                          icon: const Icon(Icons.arrow_forward),
                                          tooltip: l10n.commonContinue,
                                          onPressed: () async {
                                            await widget.itemAction!(item);
                                            if (mounted) await _load();
                                          },
                                        ),
                                      if (widget.statusAction != null)
                                        IconButton(
                                          icon: const Icon(Icons.update),
                                          tooltip: l10n.commonSave,
                                          onPressed: () async {
                                            await widget.statusAction!(item);
                                            if (mounted) await _load();
                                          },
                                        ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class NewDeliveryScreen extends ConsumerStatefulWidget {
  const NewDeliveryScreen({super.key});

  @override
  ConsumerState<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends ConsumerState<NewDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .post<dynamic>(
            ApiEndpoints.deliveries,
            body: {
              'pickup': _pickup.text.trim(),
              'dropoff': _dropoff.text.trim(),
              'notes': _notes.text.trim(),
            },
            idempotencyKey: '${DateTime.now().microsecondsSinceEpoch}',
          );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorUnknown)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.clientNewDelivery)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _pickup,
              decoration: InputDecoration(labelText: l10n.navHome),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.errorUnknown
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dropoff,
              decoration: InputDecoration(labelText: l10n.navTracking),
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.errorUnknown
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.commonSave),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(l10n.commonConfirm),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final user = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(ApiEndpoints.me);
      _name.text = user['name']?.toString() ?? '';
      _email.text = user['email']?.toString() ?? '';
    } catch (_) {
      // The form remains usable for a first local/demo profile.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch<dynamic>(
            ApiEndpoints.me,
            body: {'name': _name.text.trim(), 'email': _email.text.trim()},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).commonSave)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).errorUnknown)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.roleClient),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: InputDecoration(labelText: l10n.commonContinue),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
    );
  }
}

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEarnings)),
      body: FutureBuilder<dynamic>(
        future: ref
            .read(apiClientProvider)
            .get<dynamic>(ApiEndpoints.deliveries),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorUnknown));
          }
          final body = snapshot.data;
          final items = body is Map
              ? body['items'] as List? ?? const []
              : const [];
          final delivered = items
              .where((item) => item is Map && item['status'] == 'delivered')
              .length;
          return Center(
            child: Text([delivered.toString(), l10n.navEarnings].join(' • ')),
          );
        },
      ),
    );
  }
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _JsonResourceScreen(
    title: AppLocalizations.of(context).navDashboard,
    endpoint: ApiEndpoints.adminDashboard,
    ref: ref,
  );
}

class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ResourceListScreen(
    title: AppLocalizations.of(context).navFleet,
    endpoint: ApiEndpoints.adminFleet,
  );
}

class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ResourceListScreen(
    title: AppLocalizations.of(context).navDisputes,
    endpoint: ApiEndpoints.disputes,
  );
}

class PublicTrackingScreen extends ConsumerWidget {
  const PublicTrackingScreen({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _JsonResourceScreen(
    title: AppLocalizations.of(context).navTracking,
    endpoint: ApiEndpoints.publicTrack(token),
    ref: ref,
  );
}

class _JsonResourceScreen extends StatelessWidget {
  const _JsonResourceScreen({
    required this.title,
    required this.endpoint,
    required this.ref,
  });

  final String title;
  final String endpoint;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder<dynamic>(
      future: ref.read(apiClientProvider).get<dynamic>(endpoint),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(AppLocalizations.of(context).errorUnknown));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            JsonEncoder.withIndent('  ').convert(snapshot.data),
          ),
        );
      },
    ),
  );
}
