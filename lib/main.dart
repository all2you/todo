import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'services/auth_service.dart';
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
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _AppRoot(),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF1A1C1A) : const Color(0xFFF7F3EE);
    final surface = isDark ? const Color(0xFF262826) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B9B7A),
        brightness: brightness,
      ),
      fontFamily: 'NotoSansKR',
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        foregroundColor: isDark ? Colors.white : const Color(0xFF2C2C2C),
      ),
      cardTheme: CardThemeData(
        color: surface,
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
        fillColor: surface,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),
    );
  }
}

/// 앱 진입점 + 잠금 라이프사이클 관리.
/// - 시작 시 잠금 활성화 여부 확인
/// - 백그라운드 → 포그라운드 복귀 시 다시 잠금
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _lockRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLockOnStart() async {
    final enabled = await AuthService.isLockEnabled();
    final hasPin = await AuthService.hasPin();
    if (!mounted) return;
    setState(() {
      _lockRequired = enabled && hasPin;
      _initialized = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _maybeLock();
    }
  }

  Future<void> _maybeLock() async {
    if (_lockRequired) return; // 이미 잠금 상태
    final enabled = await AuthService.isLockEnabled();
    final hasPin = await AuthService.hasPin();
    if (enabled && hasPin && mounted) {
      setState(() => _lockRequired = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F3EE),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_lockRequired) {
      return LockScreen(
        onUnlocked: () => setState(() => _lockRequired = false),
      );
    }
    return const HomeScreen();
  }
}
