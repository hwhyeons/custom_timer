import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static const String channelId = 'timer_channel';
  static const String channelName = '타이머 알림';

  // 초기화 (main.dart에서 호출)
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
    InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings);

    // 알림 채널 생성 (안드로이드 필수)
    final AndroidNotificationChannel channel = const AndroidNotificationChannel(
      channelId,
      channelName,
      description: '타이머 작동 중 표시',
      importance: Importance.low, // 소리 없이 조용히 업데이트하기 위함
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 알림 띄우기 (업데이트용)
  static Future<void> showTimerNotification({
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      888, // 알림 ID (고정)
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: '@mipmap/ic_launcher',
          ongoing: true, // 사용자가 못 지우게 고정 (Foreground Service 효과)
          autoCancel: false,
          onlyAlertOnce: true, // 업데이트할 때마다 소리/진동 안 울리게
          actions: [
            // 필요하면 여기에 '정지', '취소' 버튼 추가 가능
          ],
        ),
      ),
    );
  }

  // 알림 취소 (타이머 종료 시)
  static Future<void> cancelNotification() async {
    await _notificationsPlugin.cancel(888);
  }
}