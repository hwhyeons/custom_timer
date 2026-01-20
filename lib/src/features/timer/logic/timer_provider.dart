import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/timer_model.dart';
import '../../../services/background_service.dart';

// 타이머 상태를 관리하는 Provider 정의
final timerProvider = NotifierProvider<TimerNotifier, TimerModel>(() {
  return TimerNotifier();
});

class TimerNotifier extends Notifier<TimerModel> {
  Timer? _ticker;

  @override
  TimerModel build() {
    return const TimerModel(isSetup: true);
  }

  // 시간 설정 (Picker에서 돌릴 때 호출)
  void setDuration(Duration duration) {
    if (!state.isSetup) return; // 설정 모드가 아니면 무시
    final seconds = duration.inSeconds;
    state = state.copyWith(
      initialDuration: seconds,
      remainingTime: seconds,
    );
  }

  // 타이머 시작
  void startTimer() {
    if (state.remainingTime <= 0) return;

    final now = DateTime.now();
    final target = state.targetTime ?? now.add(Duration(seconds: state.remainingTime));

    state = state.copyWith(
      isRunning: true,
      isSetup: false,
      isFinished: false, // 시작할 땐 종료 상태 해제
      targetTime: target,
    );

    _startTicker();

    // 백그라운드 서비스에 알림 시작 요청
    BackgroundService.startService(target);
  }
// 1초마다 화면 갱신 (실제 계산은 DateTime으로 함)
  void _startTicker() {
    // _ticker 내부 로직은 "화면 갱신용"이므로 그대로 둡니다.
    // 실제 알림 갱신은 BackgroundService가 알아서 합니다.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // milliseconds: 100으로 줄여서 더 반응성 좋게 만듦

      if (!state.isRunning || state.targetTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      // 목표 시간 - 현재 시간 = 진짜 남은 시간
      final diff = state.targetTime!.difference(now).inSeconds;

      // 남은 시간이 0보다 크면 계속 갱신
      if (diff >= 0) {
        // UI 렌더링 최적화를 위해 초 단위가 바뀔 때만 상태 업데이트
        if (diff != state.remainingTime) {
          state = state.copyWith(remainingTime: diff);
        }
      } else {
        // 타이머 종료
        timer.cancel();
        state = state.copyWith(
          isRunning: false,
          remainingTime: 0,
          isFinished: true,
          targetTime: null,
        );
        // TODO: 종료 알림 발생 위치
      }
    });
  }

  // 일시정지
  void pauseTimer() {
    _ticker?.cancel();
    // 일시정지는 남은 시간(remainingTime)은 기억해야 하므로 copyWith를 쓰되,
    // targetTime을 지우기 위해 '새로운 객체 생성' 방식을 응용하거나
    // Model의 copyWith를 수정해야 합니다.
    // 여기서는 가장 간단하게 객체를 새로 만드는 방식으로 해결합시다.
    state = TimerModel(
      initialDuration: state.initialDuration,
      remainingTime: state.remainingTime, // 현재 남은 시간 유지
      isSetup: false,                     // 타이머 화면 유지
      isRunning: false,
      targetTime: null,                   // ★ 확실하게 null로 초기화
    );
    // ▼▼▼ 백그라운드 서비스 알림 중지 ▼▼▼
    BackgroundService.stopService();
  }

  // 재개 (로직이 startTimer와 같음)
  void resumeTimer() {
    startTimer();
  }

  // 취소
  void cancelTimer() {
    _ticker?.cancel();
    // ▼▼▼ 수정된 부분: copyWith 대신 새로운 TimerModel 객체를 생성해서 덮어씌움 ▼▼▼
    // 이렇게 해야 targetTime이 확실하게 null이 됩니다.
    state = TimerModel(
      initialDuration: state.initialDuration, // 원래 설정 시간(예: 60초) 유지
      remainingTime: state.initialDuration,   // 남은 시간도 60초로 리셋
      isSetup: true,                          // 설정 화면으로 복귀
      isRunning: false,
      targetTime: null,                       // ★ 확실하게 null로 초기화
    );
    BackgroundService.stopService();
  }

  // 시간 조작 (요구사항 4번) - 실행 중에도 작동
  void adjustTime(int seconds) {
    // 1. 현재 남은 시간에 더하기/빼기
    var newRemaining = state.remainingTime + seconds;
    if (newRemaining < 0) newRemaining = 0;

    // 2. 실행 중이라면 targetTime도 수정해줘야 함
    if (state.isRunning) {
      final now = DateTime.now();
      final newTarget = now.add(Duration(seconds: newRemaining));
      state = state.copyWith(
        remainingTime: newRemaining,
        targetTime: newTarget,
      );

      // ▼▼▼ 추가: 변경된 시간으로 백그라운드 서비스 업데이트 ▼▼▼
      // 다시 startService를 호출하면 내부적으로 새로운 targetTime으로 갱신됨
      // (여기서 왜 startService또 하는거지..?)
      BackgroundService.startService(newTarget);
    } else {
      // 멈춰있을 때는 남은 시간만 수정
      state = state.copyWith(remainingTime: newRemaining);
    }
  }

  // ▼▼▼ 종료 팝업에서 '확인' 눌렀을 때 초기화하는 함수 ▼▼▼
  void resetToSetup() {
    state = TimerModel(
      initialDuration: state.initialDuration,
      remainingTime: state.initialDuration,
      isSetup: true,
      isRunning: false,
      targetTime: null,
      isFinished: false,
    );
    BackgroundService.stopService();
  }
}