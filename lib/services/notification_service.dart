import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'family_service.dart';

/// 백그라운드 메시지 핸들러 (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // 알림 채널 정의 (안드로이드 메트릭스)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  static const String _keyAiNotify = 'notify_ai';
  static const String _keyFamilyNotify = 'notify_family';
  static const String _keyAllNotify = 'notify_all';

  // 캐시된 설정값 (메모리상 유지)
  bool _isAiEnabled = true;
  bool _isFamilyEnabled = true;

  bool get isAiEnabled => _isAiEnabled;
  bool get isFamilyEnabled => _isFamilyEnabled;

  /// FCM 토큰을 Realtime Database에 저장합니다.
  Future<void> saveTokenToDatabase() async {
    try {
      final familyService = FamilyService();
      await familyService.smartUpdateFcmToken();
    } catch (e) {
      debugPrint('[FCM] Error saving token: $e');
    }
  }

  /// 알림 서비스 초기화 (권한 요청, 리스너 설정, 토큰 저장)
  Future<void> initialize() async {
    // 0. 로컬 저장소에서 설정 로드
    final status = await fetchNotificationStatus();
    _isAiEnabled = status['ai'] ?? true;
    _isFamilyEnabled = status['family'] ?? true;

    // 1. 알림 권한 요청 (FCM)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('[FCM] User granted permission');
    } else {
      debugPrint('[FCM] User declined or has not accepted permission');
    }

    // 2. 안드로이드 로컬 알림 초기화 및 채널 생성
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[FCM] Notification tapped: ${response.payload}');
        // 알림 클릭 시 추가 로직 필요 시 여기에 작성
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. 백그라운드 메시지 핸들러 설정 (initialize 내부에서 호출)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. 초기 토큰 저장
    await saveTokenToDatabase();

    // 5. 토큰 갱신 시 자동 저장 리스너
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] Token refreshed. Saving new token.');
      await saveTokenToDatabase();
    });

    // 6. 포그라운드 메시지 처리 리스너
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // FCM 메타데이터(data)에서 타입 확인 (서버에서 'type'을 보내준다고 가정)
        final String type = message.data['type']?.toString() ?? 'unknown';
        
        bool shouldNotify = true;
        if (type == 'ai' && !_isAiEnabled) shouldNotify = false;
        if (type == 'family' && !_isFamilyEnabled) shouldNotify = false;
        
        if (shouldNotify) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            payload: type, // 페이로드 추가
          );
        }
      }
    });

    // 7. 앱이 종료된 상태에서 알림을 통해 열렸을 때 처리
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App opened via notification: ${initialMessage.notification?.title}');
    }

    // 8. 백그라운드 상태에서 알림을 통해 열렸을 때 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] App opened from background notification: ${message.notification?.title}');
    });
  }

  /// 알림을 화면에 표시합니다 (로컬 기반)
  Future<void> showNotification(String title, String body, {String type = 'unknown'}) async {
    // 설정 확인
    if (type == 'ai' && !_isAiEnabled) return;
    if (type == 'family' && !_isFamilyEnabled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      '가족 챗 알림',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond + title.hashCode, // 더 고유한 ID
      title,
      body,
      platformDetails,
      payload: type,
    );
  }

  Future<String?> getFcmToken() async {
    return await _messaging.getToken();
  }

  /// 알림 설정을 불러옵니다 (SharedPreferences 사용)
  Future<Map<String, bool>> fetchNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final status = {
      'all': prefs.getBool(_keyAllNotify) ?? true,
      'ai': prefs.getBool(_keyAiNotify) ?? true,
      'family': prefs.getBool(_keyFamilyNotify) ?? prefs.getBool('notify_parent') ?? true,
    };
    // 캐시 업데이트
    _isAiEnabled = status['ai']! || status['all']!;
    _isFamilyEnabled = status['family']! || status['all']!;
    return status;
  }

  /// 알림 설정을 저장합니다 (SharedPreferences 사용)
  Future<void> updateNotificationStatus(Map<String, bool> status) async {
    final prefs = await SharedPreferences.getInstance();
    if (status.containsKey('all')) {
      await prefs.setBool(_keyAllNotify, status['all']!);
    }
    if (status.containsKey('ai')) {
      await prefs.setBool(_keyAiNotify, status['ai']!);
      _isAiEnabled = status['ai']!;
    }
    if (status.containsKey('family')) {
      await prefs.setBool(_keyFamilyNotify, status['family']!);
      _isFamilyEnabled = status['family']!;
    }
    
    debugPrint("NotificationService: Push notifications updated in SharedPreferences $status");
  }
}
