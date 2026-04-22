import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
  await NotificationService.init();

  // 저장된 알림 설정이 있으면 재등록 (앱 재시작 시)
  final notif = await NotificationService.loadSettings();
  if (notif.enabled) {
    await NotificationService.scheduleDailyReminder(
      TimeOfDay(hour: notif.hour, minute: notif.minute),
    );
  }

  runApp(const DailyDiaryApp());
}

class DailyDiaryApp extends StatelessWidget {
  const DailyDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '나의 하루 일기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B9B7A),
          brightness: Brightness.light,
        ),
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: const Color(0xFFF7F3EE),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6B9B7A),
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
