import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../firebase_options.dart';
import 'crm_api.dart';

/// Background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  // System tray display is handled by FCM for `notification` payloads.
}

/// FCM push: permission, device registration with the backend
/// (/api/v1/devices/register), foreground display and tap-to-open routing.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channel = AndroidNotificationChannel(
    'crm_default',
    'CRM alerts',
    description: 'New leads, chat assignments and follow-up reminders',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  String? _token;
  String? _registeredForUid;
  StreamSubscription? _tokenSub;
  StreamSubscription? _fgSub;
  StreamSubscription? _openSub;

  /// Called with a route (e.g. `/lead/abc`) when the user taps a push.
  void Function(String route)? onNavigate;

  Future<void> init() async {
    if (_initialised || kIsWeb) return;
    _initialised = true;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_notify'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) => _handlePayload(r.payload),
      );
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // iOS: show banners while the app is in the foreground.
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      _fgSub = FirebaseMessaging.onMessage.listen(_showForeground);
      _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => _routeFor(m.data));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Delay so the router is mounted.
        Future.delayed(const Duration(milliseconds: 900), () => _routeFor(initial.data));
      }
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Ask permission + register this device for [uid]. Safe to call repeatedly.
  Future<void> registerFor({required String uid, String? orgId}) async {
    if (kIsWeb || _registeredForUid == uid) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (Platform.isAndroid) {
        await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
      if (Platform.isIOS) {
        // APNs token must exist before an FCM token can be minted.
        for (var i = 0; i < 6; i++) {
          if (await FirebaseMessaging.instance.getAPNSToken() != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _send(token, orgId);
      _registeredForUid = uid;
      _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _token = t;
        _send(t, orgId);
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  Future<void> _send(String token, String? orgId) async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    await DevicesApi.register(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: version,
      orgId: orgId,
    );
  }

  /// Call BEFORE Firebase sign-out (needs a valid ID token).
  Future<void> unregister() async {
    final t = _token;
    _registeredForUid = null;
    _tokenSub?.cancel();
    if (t == null) return;
    try {
      await DevicesApi.unregister(t);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    // iOS presents foreground banners natively (see presentation options).
    if (!kIsWeb && Platform.isIOS) return;
    await _local.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFFFF6B1A),
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _routeFor(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {}
  }

  void _routeFor(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final leadId = data['leadId']?.toString() ?? '';
    String route = '/notifications';
    if (leadId.isNotEmpty) {
      route = (type.startsWith('chat') || type.contains('escalation')) ? '/conversation/$leadId' : '/lead/$leadId';
    } else if (type.startsWith('follow_up')) {
      route = '/followups';
    }
    onNavigate?.call(route);
  }

  void dispose() {
    _tokenSub?.cancel();
    _fgSub?.cancel();
    _openSub?.cancel();
  }
}
