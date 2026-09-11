import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';

/// Une notification conservee dans le **centre de notifications** (EXI-N06).
///
/// La notification systeme est ephemere : elle s'affiche, puis disparait des que
/// l'utilisateur balaie sa barre. Le centre, lui, en garde la trace — de quoi
/// retrouver « le livreur est arrive » une heure plus tard, et savoir ce qui n'a
/// pas encore ete lu. On stocke donc, en plus du contenu affiche, l'instant de
/// reception et l'etat de lecture.
class CenterNotification {
  const CenterNotification({
    required this.channel,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.route,
    this.read = false,
  });

  final McNotificationChannel channel;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Lien profond ouvert au toucher (EXI-N04). Absent, le toucher ne fait que
  /// marquer la ligne comme lue.
  final String? route;

  final bool read;

  CenterNotification copyWith({bool? read}) => CenterNotification(
    channel: channel,
    title: title,
    body: body,
    receivedAt: receivedAt,
    route: route,
    read: read ?? this.read,
  );

  /// Construit une entree du centre a partir d'une notification affichee.
  factory CenterNotification.fromDisplayed(AppNotification notification) =>
      CenterNotification(
        channel: notification.channel,
        title: notification.title,
        body: notification.body,
        route: notification.route,
        receivedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'channel': channel.id,
    'title': title,
    'body': body,
    'route': route,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    'read': read,
  };

  static CenterNotification? fromJson(Map<String, dynamic> json) {
    final channelId = json['channel'] as String?;
    McNotificationChannel? channel;
    for (final c in McNotificationChannel.values) {
      if (c.id == channelId) {
        channel = c;
        break;
      }
    }
    if (channel == null) return null;
    return CenterNotification(
      channel: channel,
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      route: json['route'] as String?,
      receivedAt:
          DateTime.tryParse('${json['receivedAt']}')?.toLocal() ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }
}
