import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'src/home_screen.dart';
import 'src/services/background_service.dart';
import 'src/services/notification_service.dart';

void main() async {
  // 위젯 바인딩 초기화 (서비스, 네이티브 통신 전 필수)
  // 원래는 runApp()이 호출될 때 자동으로 실행되지만,
  // 비동기 초기화 작업이 있으므로 미리 호출
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 알림 서비스 초기화
  await NotificationService.initialize();

  // 2. 백그라운드 서비스 초기화 (설정만 로드, 자동시작 X)
  await BackgroundService.initialize();

  runApp(
    // Riverpod 상태 관리를 위한 스코프 설정 (ProviderScope은 Riverpod에서 제공함)
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // 알림 권한 요청 (안드로이드 13+)
  Future<void> _requestPermissions() async {
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}