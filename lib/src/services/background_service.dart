import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
// ▼▼▼ 이 패키지가 꼭 있어야 AndroidServiceInstance 기능을 쓸 수 있습니다 ▼▼▼
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'notification_service.dart';

// 서비스 진입점 (최상위 레벨 함수여야 함)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 백그라운드에서도 알림 기능을 써야 하므로 초기화
  await NotificationService.initialize();

  // service 객체를 Android 전용으로 캐스팅 (알림 텍스트 변경 기능을 쓰기 위해)
  // 기본 알림이 아니라 새로운 알림을 띄우면 기본으로 떠있는 알림이랑 새로운 알림이랑 두개가 떠버릴 수 있음
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  Timer? _bgTimer;
  DateTime? _targetTime;

  // 1. UI로부터 'startTimer' 신호를 받았을 때
  service.on('startTimer').listen((event) async {
    if (event == null) return;

    // 목표 시간(String)을 받아서 DateTime으로 변환
    final targetIso = event['targetTime'] as String;
    _targetTime = DateTime.parse(targetIso);

    // 타이머가 돌기 시작하면, 먼저 서비스를 포그라운드로 확실히 전환
    // Q. 왜 여기서 포그라운드로 확실히 전환하나요?
    // A. 앱을 켜놓고 있다가 백그라운드로 갔을 때, OS가 배터리 절약을 위해 서비스를 잠시 죽일 수 있습니다.
    //    "나 지금 중요한 일(타이머) 시작하니까 절대 죽이지 마!"라고 OS에 강력하게 어필하는 과정입니다.
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService() == false) {
        service.setAsForegroundService();
      }
    }

    // 1초마다 알림 갱신 시작
    _bgTimer?.cancel();
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_targetTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final diff = _targetTime!.difference(now).inSeconds;
      if (service is AndroidServiceInstance) {
        if (diff > 0) {
          // 남은 시간을 00:00 형식으로 변환
          final minutes = (diff ~/ 60).toString().padLeft(2, '0');
          final seconds = (diff % 60).toString().padLeft(2, '0');

          // ▼▼▼ [핵심 수정] NotificationService를 호출하는 게 아니라,
          // 서비스 자신이 가지고 있는 알림의 텍스트만 바꿉니다. ▼▼▼
          service.setForegroundNotificationInfo(
            title: '타이머 작동 중',
            content: '남은 시간: $minutes:$seconds',
          );
        } else {
          // 시간이 다 됨
          timer.cancel();
          _targetTime = null;

          // 1. 카운트다운 알림(서비스)은 이제 필요 없으므로 종료
          service.stopSelf();
          // 2. "종료 알림"은 소리가 나야 하므로 NotificationService를 통해 새로 띄움
           await NotificationService.showTimerNotification(
            title: '타이머 종료!',
            body: '설정한 시간이 되었습니다.',
          );

          // UI 쪽에 "끝났다"고 알려줄 수도 있음 (양방향 통신)
          service.invoke('timerFinished');
        }
      }
    });
  });

  // 2. UI로부터 'stopTimer' 신호를 받았을 때
  service.on('stopTimer').listen((event) {
    _bgTimer?.cancel();
    _targetTime = null;
    NotificationService.cancelNotification(); // 알림 제거

    // 서비스 자체를 종료시켜서 알림을 상단바에서 제거 ▼▼▼
    service.stopSelf();
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // ▼▼▼ [핵심 수정] 서비스 설정 전에 알림 채널을 먼저 만듭니다! ▼▼▼
    await NotificationService.initialize();

    // ▲▲▲ 중요: 여기서 채널 ID를 NotificationService와 맞춰줍니다 ▲▲▲
    const String channelId = 'timer_channel'; // NotificationService.channelId 와 동일하게

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // 이 함수가 백그라운드 격리 공간에서 실행됨
        onStart: onStart,

        // 서비스가 죽지 않도록 설정
        autoStart: false,
        isForegroundMode: true,

        // 알림 설정 (초기값)
        // 백그라운드에서 돌려면 항상 기본으로 켜있는 알림이 필요함
        notificationChannelId: channelId, // 이 채널 ID가 NotificationService와 겹치지 않게 주의
        initialNotificationTitle: '타이머 준비',
        initialNotificationContent: '대기 중...',
        foregroundServiceNotificationId: 888, // NotificationService의 ID와 동일하게
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        // ios도 넣으려면 추후에 추가해야될듯?
      ),
    );
  }

  // 서비스 시작 (타이머 시작 시 호출)
  static Future<void> startService(DateTime targetTime) async {
    final service = FlutterBackgroundService();
    // 서비스가 꺼져있다면 켬
    if (!await service.isRunning()) {
      await service.startService();

      // [중요] 서비스가 완전히 켜지고 리스너를 등록할 때까지 잠시 대기
      // 이 딜레이가 없으면 데이터가 유실됩니다.
      // (아.. 근데 아무래도 이렇게 0.5ms 기다리고 하는 방식은 제일 비선호 하는 방식인데)
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // 목표 시간을 백그라운드로 전달
    service.invoke(
      'startTimer',
      {'targetTime': targetTime.toIso8601String()},
    );
  }

  // 서비스 정지 (타이머 정지/취소 시 호출)
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopTimer');
    // 완전히 끄고 싶으면 service.invoke('stopService') 호출 가능하나,
    // 보통은 상태만 리셋하고 서비스는 살려두기도 함. 여기선 알림만 끔.
  }
}