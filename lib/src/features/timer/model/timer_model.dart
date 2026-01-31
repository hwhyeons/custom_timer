class TimerModel {
  final int initialDuration; // 최초 설정 시간 (초)
  final int remainingTime;   // 남은 시간 (초)
  final bool isRunning;      // 작동 여부
  final bool isSetup;        // 시간 설정 모드인가? (false면 타이머 화면 표시)


  // ▼▼▼ 정확한 시간 계산을 위한 필드 ▼▼▼
  // count방식은 앱이 백그라운드에 들어갔다가 다시 돌아올 때
  // 타이머가 멈추는 문제가 있음. 이를 해결하기 위한 절대 시간 필드
  final DateTime? targetTime;   // 타이머가 끝나는 절대 시간

  final bool isFinished; // 타이머가 끝났는지 확인하는 변수


  const TimerModel({
    this.initialDuration = 60, // 기본 1분
    this.remainingTime = 60,
    this.isRunning = false,
    this.isSetup = true, // 기본값은 시간 설정 모드
    this.targetTime,
    this.isFinished = false, // 기본값 false
  });

  // 상태 복사를 위한 메서드 (불변성 유지)
  // 필요한 필드만 변경하고 나머지는 기존 값 유지
  // 예) state = state.copyWith(remainingTime: 30, isRunning: true);
  TimerModel copyWith({
    int? initialDuration,
    int? remainingTime,
    bool? isRunning,
    bool? isSetup,
    DateTime? targetTime,
    bool? isFinished,
  }) {
    return TimerModel(
      initialDuration: initialDuration ?? this.initialDuration,
      remainingTime: remainingTime ?? this.remainingTime,
      isRunning: isRunning ?? this.isRunning,
      isSetup: isSetup ?? this.isSetup,
      targetTime: targetTime ?? this.targetTime,
      isFinished: isFinished ?? this.isFinished,
    );
  }}