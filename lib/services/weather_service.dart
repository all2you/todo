import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// OpenWeatherMap API를 사용하여 현재 위치의 날씨를 가져옵니다.
class WeatherService {
  static const _apiKeyPref = 'openweather_api_key';
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_apiKeyPref);
    } else {
      await prefs.setString(_apiKeyPref, key.trim());
    }
  }

  /// 위도/경도로 현재 날씨 이모지를 반환합니다.
  /// API 키가 없거나 오류 시 null 반환.
  static Future<String?> fetchWeatherEmoji(double lat, double lon) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'lat': lat.toStringAsFixed(6),
        'lon': lon.toStringAsFixed(6),
        'appid': apiKey,
        'units': 'metric',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final id = (data['weather'] as List?)?.firstOrNull?['id'] as int?;
      if (id == null) return null;

      return _idToEmoji(id);
    } catch (_) {
      return null;
    }
  }

  /// OpenWeatherMap condition ID → 앱 날씨 이모지 변환
  /// kWeathers: ['☀️', '⛅', '🌧️', '⛈️', '❄️', '🌫️', '🌈']
  static String _idToEmoji(int id) {
    if (id >= 200 && id < 300) return '⛈️'; // Thunderstorm
    if (id >= 300 && id < 600) return '🌧️'; // Drizzle / Rain
    if (id >= 600 && id < 700) return '❄️'; // Snow
    if (id >= 700 && id < 800) return '🌫️'; // Atmosphere (fog, mist…)
    if (id == 800) return '☀️'; // Clear sky
    return '⛅'; // 801-899 Clouds
  }
}
