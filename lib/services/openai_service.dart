import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';

class OpenAiService {
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const _apiKeyStorageKey = 'openai_api_key';
  static const _legacyApiKeyPref = 'openai_api_key';
  static const _modelPref = 'openai_model';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> getApiKey() async {
    final existing = await _secure.read(key: _apiKeyStorageKey);
    if (existing != null) return existing;

    // 과거 SharedPreferences 평문 저장분 → 보안 저장소로 일회성 마이그레이션
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyApiKeyPref);
    if (legacy != null && legacy.isNotEmpty) {
      await _secure.write(key: _apiKeyStorageKey, value: legacy);
      await prefs.remove(_legacyApiKeyPref);
      return legacy;
    }
    return null;
  }

  static Future<void> saveApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secure.delete(key: _apiKeyStorageKey);
    } else {
      await _secure.write(key: _apiKeyStorageKey, value: trimmed);
    }
    // 혹시 남아있을 수 있는 레거시 평문 제거
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyApiKeyPref);
  }

  static Future<String> getModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPref) ?? 'gpt-4o-mini';
  }

  static Future<void> saveModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, model);
  }

  /// 일기 내용 + 사진을 받아 SNS 스타일의 자연스러운 글로 변환한다.
  static Future<String> enhanceDiary(
    DiaryEntry entry, {
    List<String> photoPaths = const [],
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다.\n설정에서 API 키를 입력해주세요.');
    }

    final model = await getModel();
    final prompt = _buildPrompt(entry);

    // 사진을 base64로 인코딩 (vision 지원 모델: gpt-4o, gpt-4o-mini)
    final List<Map<String, dynamic>> userContent = [];
    userContent.add({'type': 'text', 'text': prompt});

    for (final path in photoPaths.take(4)) {
      // 최대 4장
      try {
        final file = File(path);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        final ext = path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        userContent.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/$ext;base64,$base64Image',
            'detail': 'low', // 비용 절감
          },
        });
      } catch (_) {}
    }

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
                'content': _systemPrompt,
              },
              {
                'role': 'user',
                'content': userContent,
              },
            ],
            'temperature': 0.8,
            'max_tokens': 1200,
          }),
        )
        .timeout(const Duration(seconds: 60));

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

  static const String _systemPrompt = '''당신은 감성적이고 따뜻한 SNS 포스팅 작가입니다.
사용자의 하루 일기와 함께 제공된 맥락 정보(위치, 시간대, 날씨, 기분, 배터리 상태 등)와 사진을 종합적으로 분석하여 인스타그램이나 블로그에 올릴 것처럼 자연스럽고 공감 가는 글로 다듬어주세요.

규칙:
- 사진이 제공된 경우 사진 속 장소, 분위기, 색감, 피사체를 글에 자연스럽게 녹여주세요.
- 위치 정보가 있으면 그 장소의 분위기를 묘사에 활용하세요.
- 시간대(아침/점심/저녁 등)를 글의 감성에 반영하세요.
- 원문의 핵심 내용과 감정은 반드시 유지하세요.
- 딱딱한 문어체 대신 부드럽고 따뜻한 구어체로 작성하세요.
- 감정을 더 풍부하게 표현하되 과장하지 마세요.
- 적절한 이모지를 자연스럽게 섞어 사용하세요 (과하지 않게 2~4개).
- 해시태그는 마지막에 3~5개만 추가하세요.
- 전체 길이는 원문과 비슷하게 유지하세요.
- 한국어로 작성하세요.''';

  static String _buildPrompt(DiaryEntry entry) {
    final buffer = StringBuffer();

    buffer.writeln('━━━ 수집된 맥락 정보 ━━━');
    buffer.writeln('【날짜】${_formatDate(entry.date)}');

    if (entry.timeContext != null) {
      buffer.writeln('【시간대】${entry.timeContext}');
    }

    // 위치 정보 (상세)
    final locationParts = <String>[];
    if (entry.location != null && entry.location!.isNotEmpty) {
      locationParts.add(entry.location!);
    }
    if (entry.district != null && entry.district!.isNotEmpty) {
      locationParts.add(entry.district!);
    }
    if (entry.city != null && entry.city!.isNotEmpty) {
      locationParts.add(entry.city!);
    }
    if (entry.country != null && entry.country!.isNotEmpty) {
      locationParts.add(entry.country!);
    }
    if (locationParts.isNotEmpty) {
      buffer.writeln('【위치】${locationParts.join(', ')}');
    }

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

    if (entry.batteryLevel != null) {
      final chargingStr =
          (entry.batteryLevel! < 20) ? ' (배터리 부족 - 바쁜 하루였을 수도)' : '';
      buffer.writeln('【배터리】${entry.batteryLevel}%$chargingStr');
    }

    if (entry.photoPaths.isNotEmpty) {
      buffer.writeln('【첨부 사진】${entry.photoPaths.length}장 (아래 이미지 참고)');
    }

    buffer.writeln();
    buffer.writeln('━━━ 일기 내용 ━━━');
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
