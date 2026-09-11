import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:majichrono/core/logging/app_logger.dart';
import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';

/// Libelles visibles par l'utilisateur pour un canal, dans sa langue.
///
/// Le nom et la description d'un canal apparaissent dans les reglages Android :
/// ils doivent donc etre traduits (EXI-N05). Ils sont fournis par la couche de
/// presentation, seule a connaitre la langue courante.
class NotificationChannelStrings {
  const NotificationChannelStrings({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;
}

/// Affichage des notifications locales et definition des canaux Android
/// (EXI-N01 a EXI-N05).
///
/// C'est la **couche d'affichage**, deliberement separee du transport. Que le
/// declencheur soit une notification distante (Firebase, a brancher), une regle
/// locale ou un test, il appelle [show] avec une [AppNotification] deja
/// traduite. Le jour ou le push distant arrive, seul son point d'entree
/// appellera ce meme service — rien ici ne change.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialised = false;

  /// Ouvre le lien profond porte par une notification touchee.
  void Function(String route)? _onSelectRoute;

  /// Appele avec chaque notification **effectivement affichee** (donc jamais une
  /// annonce commerciale coupee). C'est par la que le centre de notifications se
  /// remplit : la couche d'affichage signale ce qu'elle pose, sans connaitre le
  /// centre lui-meme.
  void Function(AppNotification notification)? onShown;

  /// Prepare le plugin, cree les quatre canaux, et branche le toucher.
  ///
  /// [onSelectRoute] est appele avec la route (lien profond) quand l'utilisateur
  /// touche une notification (EXI-N04). [channels] fournit les libelles traduits
  /// de chaque canal.
  Future<void> init({
    required void Function(String route) onSelectRoute,
    required Map<McNotificationChannel, NotificationChannelStrings> channels,
  }) async {
    _onSelectRoute = onSelectRoute;

    if (!_initialised) {
      const android = AndroidInitializationSettings('ic_launcher_monochrome');
      const darwin = DarwinInitializationSettings(
        // Les permissions iOS seront demandees explicitement, pas au demarrage.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
        onDidReceiveNotificationResponse: _handleTap,
      );
      _initialised = true;
    }

    await configureChannels(channels);
  }

  /// (Re)cree les canaux avec les libelles fournis. Rappele a chaque changement
  /// de langue pour que les noms suivent la langue du compte.
  Future<void> configureChannels(
    Map<McNotificationChannel, NotificationChannelStrings> channels,
  ) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    for (final channel in McNotificationChannel.values) {
      final strings = channels[channel];
      if (strings == null) continue;
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          strings.name,
          description: strings.description,
          importance: _importance(channel),
          playSound: channel != McNotificationChannel.commercial,
        ),
      );
    }
  }

  /// Demande l'autorisation d'afficher des notifications (Android 13+,
  /// POST_NOTIFICATIONS). Retourne `true` si accordee.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Affiche une notification. Le canal commercial est tu si l'utilisateur l'a
  /// coupe ([commercialEnabled] a faux) — jamais les canaux operationnels
  /// (EXI-N03).
  Future<void> show(
    AppNotification notification, {
    bool commercialEnabled = true,
  }) async {
    if (notification.channel == McNotificationChannel.commercial &&
        !commercialEnabled) {
      return;
    }

    final channel = notification.channel;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.id,
        importance: _importance(channel),
        priority: channel == McNotificationChannel.commercial
            ? Priority.low
            : Priority.high,
        playSound: channel != McNotificationChannel.commercial,
        icon: 'ic_launcher_monochrome',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // Sans id fourni, on derive un identifiant de la route ou du titre : deux
    // mises a jour d'une meme course se remplacent au lieu de s'empiler.
    final id =
        notification.id ??
        (notification.route ?? notification.title).hashCode & 0x7fffffff;

    await _plugin.show(
      id,
      notification.title,
      notification.body,
      details,
      payload: notification.route,
    );
    AppLogger.instance.info(
      'notification_shown',
      data: {'channel': channel.id, 'hasRoute': notification.route != null},
    );
    // On ne previent le centre qu'apres un affichage reussi : ce qui n'a pas pu
    // s'afficher n'a pas non plus a garnir l'historique.
    onShown?.call(notification);
  }

  /// Route portee par la notification qui a lance l'application (demarrage a
  /// froid depuis une notification). Nulle si l'application n'a pas ete ouverte
  /// ainsi.
  Future<String?> launchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  void _handleTap(NotificationResponse response) {
    final route = response.payload;
    if (route != null && route.isNotEmpty) {
      _onSelectRoute?.call(route);
    }
  }

  Importance _importance(McNotificationChannel channel) => switch (channel) {
    McNotificationChannel.courses => Importance.high,
    McNotificationChannel.payment => Importance.high,
    McNotificationChannel.incidents => Importance.high,
    McNotificationChannel.commercial => Importance.low,
  };
}
