class DiaryEntry {
  final int? id;
  final String title;
  final String content;
  final String? aiContent; // OpenAI로 다듬은 SNS 스타일 글
  final DateTime date;
  final List<String> photoPaths;
  final String? mood;
  final String? weather;
  final String? location; // 동/읍/면
  final String? district; // 구/군
  final String? city; // 시/도
  final String? country; // 국가
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? deviceModel;
  final int? steps;
  final String? timeContext; // 아침/오후 등
  final List<String> tags;

  const DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    this.aiContent,
    required this.date,
    this.photoPaths = const [],
    this.mood,
    this.weather,
    this.location,
    this.district,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.deviceModel,
    this.steps,
    this.timeContext,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'ai_content': aiContent,
      'date': date.toIso8601String(),
      'photo_paths': photoPaths.join('|'),
      'mood': mood,
      'weather': weather,
      'location': location,
      'district': district,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'battery_level': batteryLevel,
      'device_model': deviceModel,
      'steps': steps,
      'time_context': timeContext,
      'tags': tags.join('|'),
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      aiContent: map['ai_content'] as String?,
      date: DateTime.parse(map['date'] as String),
      photoPaths: (map['photo_paths'] as String?)
              ?.split('|')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      mood: map['mood'] as String?,
      weather: map['weather'] as String?,
      location: map['location'] as String?,
      district: map['district'] as String?,
      city: map['city'] as String?,
      country: map['country'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      batteryLevel: map['battery_level'] as int?,
      deviceModel: map['device_model'] as String?,
      steps: map['steps'] as int?,
      timeContext: map['time_context'] as String?,
      tags: (map['tags'] as String?)
              ?.split('|')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
    );
  }

  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    String? aiContent,
    DateTime? date,
    List<String>? photoPaths,
    String? mood,
    String? weather,
    String? location,
    String? district,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    String? deviceModel,
    int? steps,
    String? timeContext,
    List<String>? tags,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      aiContent: aiContent ?? this.aiContent,
      date: date ?? this.date,
      photoPaths: photoPaths ?? this.photoPaths,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      location: location ?? this.location,
      district: district ?? this.district,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      deviceModel: deviceModel ?? this.deviceModel,
      steps: steps ?? this.steps,
      timeContext: timeContext ?? this.timeContext,
      tags: tags ?? this.tags,
    );
  }
}

const List<String> kMoods = ['😊', '😄', '😐', '😢', '😡', '😴', '🤒', '🥰'];
const List<String> kMoodLabels = [
  '좋음',
  '최고',
  '보통',
  '슬픔',
  '화남',
  '피곤',
  '아픔',
  '설렘'
];
const List<String> kWeathers = ['☀️', '⛅', '🌧️', '⛈️', '❄️', '🌫️', '🌈'];
const List<String> kWeatherLabels = ['맑음', '구름', '비', '폭풍', '눈', '안개', '무지개'];
