import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class OpenAiService {
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const _apiKeyPref = 'openai_api_key';
  static const _modelPref = 'openai_model';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyPref);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPref, key.trim());
  }

  static Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPref) ?? 'gpt-4o-mini';
  }

  static Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, model);
  }

  /// 일기 내용을 받아 SNS 스타일의 자연스러운 글로 변환한다.
  static Future<String> enhanceDiary(DiaryEntry entry) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다.\n설정에서 API 키를 입력해주세요.');
    }

    final model = await getModel();
    final prompt = _buildPrompt(entry);

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': '''당신은 감성적이고 따뜻한 SNS 포스팅 작가입니다.
사용자의 하루 일기를 읽고, 인스타그램이나 블로그에 올릴 것처럼 자연스럽고 공감 가는 글로 다듬어주세요.

규칙:
- 원문의 핵심 내용과 감정은 반드시 유지하세요.
- 딱딱한 문어체 대신 부드럽고 따뜻한 구어체로 작성하세요.
- 감정을 더 풍부하게 표현하되 과장하지 마세요.
- 적절한 이모지를 자연스럽게 섞어 사용하세요 (과하지 않게 2~4개).
- 해시태그는 마지막에 3~5개만 추가하세요.
- 전체 길이는 원문과 비슷하게 유지하세요.
- 한국어로 작성하세요.''',
              },
              {
                'role': 'user',
                'content': prompt,
              },
            ],
            'temperature': 0.8,
            'max_tokens': 1000,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'] as String;
    } else if (response.statusCode == 401) {
      throw Exception('API 키가 유효하지 않습니다. 설정에서 확인해주세요.');
    } else if (response.statusCode == 429) {
      throw Exception('요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.');
    } else {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final msg = body['error']?['message'] ?? '알 수 없는 오류';
      throw Exception('OpenAI 오류: $msg');
    }
  }

  static String _buildPrompt(DiaryEntry entry) {
    final buffer = StringBuffer();

    buffer.writeln('【날짜】${_formatDate(entry.date)}');

    if (entry.mood != null) {
      final idx = kMoods.indexOf(entry.mood!);
      final label = idx >= 0 ? kMoodLabels[idx] : '';
      buffer.writeln('【기분】${entry.mood} $label');
    }

    if (entry.weather != null) {
      final idx = kWeathers.indexOf(entry.weather!);
      final label = idx >= 0 ? kWeatherLabels[idx] : '';
      buffer.writeln('【날씨】${entry.weather} $label');
    }

    if (entry.location != null && entry.location!.isNotEmpty) {
      buffer.writeln('【위치】${entry.location}');
    }

    if (entry.batteryLevel != null) {
      buffer.writeln('【배터리】${entry.batteryLevel}%');
    }

    buffer.writeln();
    buffer.writeln('【제목】${entry.title}');
    buffer.writeln();
    buffer.writeln('【내용】');
    buffer.writeln(entry.content.isEmpty ? '(내용 없음)' : entry.content);

    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdays[date.weekday - 1];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($wd)';
  }
}
