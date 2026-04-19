import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class FirebaseGenerator {
  Future<void> run(ProjectConfig config) async {
    final base = '${config.projectPath}/lib/core/notifications';

    await Future.wait([
      _writeLocalPushService(base, config.projectName),
      _writeNotificationProvider(base),
      _writeAndroidPlaceholders(config),
      _writeIosPlaceholders(config),
    ]);
  }

  Future<void> _writeLocalPushService(String base, String pkg) async {
    await FileUtils.writeFile(
      '$base/local_push_service.dart',
      '''
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/core/storage/preferences_service.dart';

/// Handles Firebase push notifications across all app lifecycle states.
@lazySingleton
final class LocalPushService {
  LocalPushService(this._prefs);

  final PreferencesService _prefs;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    final stored = _prefs.fcmToken;
    if (stored != null) {
      // ignore: avoid_print
      print('[FCM] Stored push token: \$stored');
    }

    await _requestPermission();

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    try {
      if (Platform.isIOS) {
        // APNS token is set asynchronously after permission grant — wait up to 10 s.
        String? apns;
        for (int i = 0; i < 10 && apns == null; i++) {
          apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns == null) await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (apns == null) {
          // ignore: avoid_print
          print('[FCM] APNS token unavailable — simulator or missing push entitlement.');
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // ignore: avoid_print
        print('[FCM] Push token: \$token');
        await _prefs.setFcmToken(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        // ignore: avoid_print
        print('[FCM] Push token refreshed: \$t');
        _prefs.setFcmToken(t);
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FCM] Failed to get push token: \$e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    // ignore: avoid_print
    print('[FCM] Notification permission: \${settings.authorizationStatus}');
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null || android == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          importance: _androidChannel.importance,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

/// Must be a top-level function — called by FCM when the app is terminated.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
''',
    );
  }

  Future<void> _writeNotificationProvider(String base) async {
    await FileUtils.writeFile(
      '$base/notification_provider.dart',
      '''
import 'package:flutter/foundation.dart';

/// Tracks the unread notification badge count across the app.
final class NotificationProvider extends ChangeNotifier {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    notifyListeners();
  }

  void updateCount(int newCount) {
    _count = newCount;
    notifyListeners();
  }
}
''',
    );
  }

  Future<void> _writeAndroidPlaceholders(ProjectConfig config) async {
    if (config.useFlavors) {
      for (final flavor in Flavor.values) {
        final dir =
            '${config.projectPath}/android/app/src/${flavor.gradleName}';
        await FileUtils.writeFile(
          '$dir/README.md',
          '# ${flavor.label} Firebase\n\n'
          'Place your `google-services.json` for the **${flavor.label}** '
          'environment here.\n\n'
          'Download it from the Firebase console.\n',
        );
      }
    } else {
      await FileUtils.writeFile(
        '${config.projectPath}/android/app/README.md',
        '# Firebase\n\n'
        'Place your `google-services.json` here.\n\n'
        'Download it from the Firebase console.\n',
      );
    }
  }

  Future<void> _writeIosPlaceholders(ProjectConfig config) async {
    if (config.useFlavors) {
      for (final flavor in Flavor.values) {
        final dir =
            '${config.projectPath}/ios/config/${flavor.gradleName}';
        await FileUtils.writeFile(
          '$dir/README.md',
          '# ${flavor.label} Firebase (iOS)\n\n'
          'Place your `GoogleService-Info.plist` for the **${flavor.label}** '
          'environment here.\n\n'
          'Download it from the Firebase console.\n',
        );
      }
    } else {
      await FileUtils.writeFile(
        '${config.projectPath}/ios/README.md',
        '# Firebase (iOS)\n\n'
        'Place your `GoogleService-Info.plist` here.\n\n'
        'Download it from the Firebase console.\n',
      );
    }
  }
}
