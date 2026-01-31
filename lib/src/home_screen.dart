import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/timer/logic/timer_provider.dart';
import 'features/timer/ui/timer_page.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TimerPage(),
    const Center(child: Text('스톱워치 화면 (준비중)')),
    const Center(child: Text('설정 화면 (준비중)')),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ▼▼▼ 앱 시작 시 백그라운드 서비스와 동기화하는 로직 ▼▼▼
  // 이미 백그라운드에서 타이머가 돌고 있을 때는 그 상태를 불러와서 동기화
  Future<void> _init() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    // 1. 서비스가 실행 중인지 확인
    if (isRunning) {
      // 2. 'currentState' 이벤트를 한번만 수신 대기
      //    (앱 켤 때 딱 한번만 상태를 받아오면 됨)
      service.on('currentState').first.then((event) {
        if (event == null) return;

        final targetTimeStr = event['targetTime'] as String?;
        if (targetTimeStr == null) return;

        final targetTime = DateTime.parse(targetTimeStr);

        // 3. 받아온 targetTime으로 TimerProvider 상태를 동기화
        ref.read(timerProvider.notifier).syncWithBackground(targetTime);
      });

      // 4. 백그라운드 서비스에 현재 상태를 요청 (UI와 백그라운드는 분리 되어있어서 양방향 통신을 하려면 invoke() - on() 조합을 사용해야 함)
      service.invoke('requestCurrentState');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer),
            label: '타이머',
          ),
          NavigationDestination(
            icon: Icon(Icons.watch_later_outlined),
            label: '스톱워치',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}