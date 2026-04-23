import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 부팅 이후 누적 걸음 수를 기반으로 "오늘의 걸음 수"를 계산한다.
///
/// pedometer 패키지의 [stepCountStream]은 디바이스 부팅 시점부터의 누적값만 제공한다.
/// 자정을 지나면 그 순간의 누적값을 그날의 baseline으로 저장하고,
/// 이후 (현재 누적값 - baseline)이 오늘의 걸음 수가 된다.
class StepCounterService {
  static const _baselineKey = 'step_baseline';
  static const _baselineDateKey = 'step_baseline_date';

  /// 현재까지의 오늘 걸음 수를 반환. 실패 시 null.
  static Future<int?> getTodaySteps() async {
    try {
      final event = await Pedometer.stepCountStream.first
          .timeout(const Duration(seconds: 3));
      final current = event.steps;

      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayKey();
      final savedDate = prefs.getString(_baselineDateKey);
      final savedBaseline = prefs.getInt(_baselineKey);

      if (savedDate != todayKey ||
          savedBaseline == null ||
          current < savedBaseline) {
        // 하루가 바뀌었거나 기기가 리부팅되어 누적값이 더 작아진 경우 baseline 재설정
        await prefs.setInt(_baselineKey, current);
        await prefs.setString(_baselineDateKey, todayKey);
        return 0;
      }
      return current - savedBaseline;
    } catch (_) {
      return null;
    }
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
