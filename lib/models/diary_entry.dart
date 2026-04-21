class DiaryEntry {
  final int? id;
  final String title;
  final String content;
  final DateTime date;
  final List<String> photoPaths;
  final String? mood;
  final String? weather;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;
  final String? deviceModel;
  final int? steps;

  const DiaryEntry({
    this.id,
    required this.title,
    required this.content,
    required this.date,
    this.photoPaths = const [],
    this.mood,
    this.weather,
    this.location,
    this.latitude,
    this.longitude,
    this.batteryLevel,
    this.deviceModel,
    this.steps,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'photo_paths': photoPaths.join('|'),
      'mood': mood,
      'weather': weather,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'battery_level': batteryLevel,
      'device_model': deviceModel,
      'steps': steps,
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      date: DateTime.parse(map['date'] as String),
      photoPaths: (map['photo_paths'] as String?)
              ?.split('|')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      mood: map['mood'] as String?,
      weather: map['weather'] as String?,
      location: map['location'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      batteryLevel: map['battery_level'] as int?,
      deviceModel: map['device_model'] as String?,
      steps: map['steps'] as int?,
    );
  }

  DiaryEntry copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? date,
    List<String>? photoPaths,
    String? mood,
    String? weather,
    String? location,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    String? deviceModel,
    int? steps,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      photoPaths: photoPaths ?? this.photoPaths,
      mood: mood ?? this.mood,
      weather: weather ?? this.weather,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      deviceModel: deviceModel ?? this.deviceModel,
      steps: steps ?? this.steps,
    );
  }
}

const List<String> kMoods = ['😊', '😄', '😐', '😢', '😡', '😴', '🤒', '🥰'];
const List<String> kMoodLabels = ['좋음', '최고', '보통', '슬픔', '화남', '피곤', '아픔', '설렘'];
const List<String> kWeathers = ['☀️', '⛅', '🌧️', '⛈️', '❄️', '🌫️', '🌈'];
const List<String> kWeatherLabels = ['맑음', '구름', '비', '폭풍', '눈', '안개', '무지개'];
