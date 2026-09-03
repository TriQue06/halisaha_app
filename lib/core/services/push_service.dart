import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bildirim kanalı kimliği.
///
/// AndroidManifest'teki `default_notification_channel_id` ile **aynı** olmak
/// zorunda; uygulama kapalıyken FCM bu kanalı kullanıyor.
const String kMatchChannelId = 'japonkale_matches';

/// Uygulama arka plandayken/kapalıyken gelen mesajlar bu fonksiyonda işlenir.
///
/// Ayrı bir izolatta çalışır: burada UI'ya dokunulamaz ve provider'lara
/// erişilemez. Bildirimi zaten Android sistemi çizdiği için yapılacak bir şey
/// yok; yine de Firebase'i başlatmak gerekiyor, aksi halde çalışma zamanı
/// hatası veriyor. Top-level olmak ZORUNDA (sınıf içine alınamaz).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Push bildirimlerinin tek giriş noktası.
///
/// Sorumlulukları:
///  * Firebase'i başlatmak ve bildirim iznini istemek (Android 13+ zorunlu),
///  * FCM cihaz token'ını Supabase'e yazmak (`register_device_token`),
///  * uygulama ön plandayken bildirimi elle çizmek — FCM bu durumda
///    sistem bildirimi göstermez.
class PushService {
  PushService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _lastRegisteredToken;

  /// Ön planda bildirime dokunulduğunda çağrılır (uygulama içi yönlendirme).
  static void Function()? onNotificationTap;

  /// `main()` içinde, Supabase başlatıldıktan sonra bir kez çağrılır.
  ///
  /// Hiçbir adımı uygulamayı çökertmemeli: Firebase yapılandırması eksik bir
  /// derlemede bile uygulama normal çalışmaya devam etsin diye tüm gövde
  /// try/catch içinde.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _setupLocalNotifications();

      // Android 13+ ve iOS'ta çalışma zamanı izni. Reddedilirse token yine
      // alınır ama sistem bildirimi göstermez — bu bilinçli: kullanıcı daha
      // sonra ayarlardan izin verirse ekstra kod gerekmeden çalışmaya başlar.
      await FirebaseMessaging.instance.requestPermission();

      // Oturum açıldığında/kapandığında token'ı kaydet ya da sil.
      Supabase.instance.client.auth.onAuthStateChange.listen((AuthState state) {
        if (state.session != null) {
          syncToken();
        } else {
          _lastRegisteredToken = null;
        }
      });
      await syncToken();

      // Token bazen kendiliğinden yenilenir (uygulama verisi silinince vb.).
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage _) {
        onNotificationTap?.call();
      });
    } catch (error, stack) {
      debugPrint('PushService başlatılamadı: $error\n$stack');
    }
  }

  /// Mevcut cihaz token'ını Supabase'e yazar. Oturum yoksa hiçbir şey yapmaz.
  static Future<void> syncToken() async {
    if (Supabase.instance.client.auth.currentSession == null) return;
    try {
      // iOS'ta FCM token'ı ancak APNs token'ı geldikten sonra üretilebilir.
      // Bu beklenmezse getToken() null döner ve cihaz hiç kaydolmaz.
      if (Platform.isIOS) {
        String? apns = await FirebaseMessaging.instance.getAPNSToken();
        // APNs kaydı birkaç saniye sürebiliyor; kısa aralıklarla tekrar dene.
        for (int i = 0; apns == null && i < 5; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apns = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apns == null) {
          debugPrint('APNs token alınamadı; push kaydı atlandı.');
          return;
        }
      }

      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (error) {
      debugPrint('FCM token alınamadı: $error');
    }
  }

  /// Çıkış yapmadan **önce** çağrılır; bu cihaza artık bildirim gitmez.
  static Future<void> unregister() async {
    final String? token = _lastRegisteredToken;
    if (token == null) return;
    try {
      await Supabase.instance.client.rpc<dynamic>(
        'unregister_device_token',
        params: <String, dynamic>{'p_token': token},
      );
    } catch (error) {
      debugPrint('Token silinemedi: $error');
    } finally {
      _lastRegisteredToken = null;
    }
  }

  // -------------------------------------------------------------------
  // Yardımcılar
  // -------------------------------------------------------------------

  static Future<void> _saveToken(String token) async {
    // Aynı token'ı her açılışta tekrar yazmayalım.
    if (token == _lastRegisteredToken) return;
    try {
      await Supabase.instance.client.rpc<dynamic>(
        'register_device_token',
        params: <String, dynamic>{
          'p_token': token,
          'p_platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      _lastRegisteredToken = token;
    } catch (error) {
      debugPrint('Token kaydedilemedi: $error');
    }
  }

  static Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse _) =>
          onNotificationTap?.call(),
    );

    // Kanal önceden oluşturulmalı; yoksa Android 8+ bildirimi sessizce yutar.
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            kMatchChannelId,
            'Maç bildirimleri',
            description: 'Maç teklifleri ve maç durumu değişiklikleri',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          kMatchChannelId,
          'Maç bildirimleri',
          channelDescription: 'Maç teklifleri ve maç durumu değişiklikleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
