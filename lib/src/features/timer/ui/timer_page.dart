import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/timer_provider.dart';

class TimerPage extends ConsumerWidget {
  const TimerPage({super.key});

  // 시간을 00:00 형태로 변환하는 함수
  String _formatTime(int totalSeconds) {
    // 이 시간변환 부분도 평소에 내가 하던 몫,나머지 방식이랑 한번 비교해보기
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    if (hours == '00') {
      return '$minutes:$seconds';
    }
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final timerNotifier = ref.read(timerProvider.notifier);

    // ▼▼▼ 추가: 종료 상태 감지 리스너 ▼▼▼
    ref.listen(timerProvider, (previous, next) {
      // "방금 전까진 안 끝났는데(false), 지금 끝났다(true)"면 팝업 띄우기
      if ((previous?.isFinished == false) && next.isFinished) {
        _showFinishedDialog(context, timerNotifier);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('타이머')),
      body: Center(
        child: timerState.isSetup
            ? _buildSetupView(context, timerState, timerNotifier)
            : _buildRunningView(context, timerState, timerNotifier),
      ),
    );
  }

  // ▼▼▼ 추가: 심플한 종료 알림 팝업 ▼▼▼
  void _showFinishedDialog(BuildContext context, TimerNotifier notifier) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 눌러도 안 꺼지게
      builder: (context) {
        return AlertDialog(
          title: const Text('타이머 종료', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.alarm_on, size: 60, color: Colors.deepPurple),
              SizedBox(height: 16),
              Text('설정한 시간이 되었습니다.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            // 스톱워치 없이 깔끔하게 '확인' 버튼 하나만 둡니다.
            Center(
              child: FilledButton(
                onPressed: () {
                  notifier.resetToSetup(); // 초기 화면으로 리셋
                  Navigator.of(context).pop(); // 팝업 닫기
                },
                child: const Text('확인'),
              ),
            ),
          ],
        );
      },
    );
  }

  // 1. 시간 설정 화면 (Picker)
  Widget _buildSetupView(BuildContext context, dynamic state, dynamic notifier) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          // 아이폰 스타일의 깔끔한 피커 사용 (안드로이드에서도 잘 어울림)
          child: CupertinoTimerPicker(
            mode: CupertinoTimerPickerMode.hms, // 시:분:초 모드
            initialTimerDuration: Duration(seconds: state.initialDuration),
            onTimerDurationChanged: (Duration changedTimer) {
              notifier.setDuration(changedTimer);
            },
          ),
        ),
        const SizedBox(height: 40),
        FilledButton.icon(
          onPressed: state.initialDuration > 0 ? notifier.startTimer : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('시작'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  // 2. 타이머 작동 화면 (Countdown + 조작 버튼)
  Widget _buildRunningView(BuildContext context, dynamic state, dynamic notifier) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 남은 시간 표시
        Text(
          _formatTime(state.remainingTime),
          style: const TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 20),

        // 시간 추가 버튼들 (요구사항 4번 구현)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _QuickAddButton(label: '+1분', seconds: 60, onTap: notifier.adjustTime),
              const SizedBox(width: 8),
              _QuickAddButton(label: '+5분', seconds: 300, onTap: notifier.adjustTime),
              const SizedBox(width: 8),
              _QuickAddButton(label: '+10분', seconds: 600, onTap: notifier.adjustTime),
              const SizedBox(width: 8),
              _QuickAddButton(label: '-10초', seconds: -10, onTap: notifier.adjustTime),
            ],
          ),
        ),

        const SizedBox(height: 50),

        // 제어 버튼 (일시정지 / 취소)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: notifier.cancelTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('취소'),
            ),
            const SizedBox(width: 20),
            if (state.isRunning)
              ElevatedButton.icon(
                onPressed: notifier.pauseTimer,
                icon: const Icon(Icons.pause),
                label: const Text('일시정지'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: notifier.resumeTimer,
                icon: const Icon(Icons.play_arrow),
                label: const Text('계속'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// 퀵 시간 추가 버튼 위젯
class _QuickAddButton extends StatelessWidget {
  final String label;
  final int seconds;
  final Function(int) onTap;

  const _QuickAddButton({
    required this.label,
    required this.seconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => onTap(seconds),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label),
    );
  }
}