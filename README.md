# 나의 하루 일기 (Daily Diary)

하루를 사진과 글로 정리하는 Flutter 일기 앱입니다. 위치 · 날씨 · 기분 · 기기 정보 같은 주변 맥락을 함께 기록하고, OpenAI로 다듬어 SNS 스타일의 감성 글로도 만들 수 있습니다.

## 주요 기능

- **일기 작성 / 편집 / 삭제**: 제목, 본문, 최대 여러 장의 사진, 기분, 날씨, 위치를 한 화면에서 기록
- **자동 맥락 수집**: 작성 시점의 기기 정보(모델, 배터리, 네트워크), GPS 위치(동/구/시/국가), 시간대(아침·오후·밤 등)를 자동으로 스냅샷
- **지도 기반 위치 선택**: `flutter_map` 기반 지도에서 위치를 직접 고르거나 현재 위치를 사용
- **OpenAI로 글 다듬기**: 작성한 일기와 사진을 GPT-4o / GPT-4o-mini / GPT-3.5 중 선택한 모델로 보내 SNS 포스팅 스타일의 글로 변환 (사진 4장까지 Vision 분석)
- **캘린더 뷰 / 목록 뷰**: `table_calendar`로 달력에서 날짜별 일기 확인, 월별 그룹화된 목록 뷰 토글
- **검색**: 제목 · 본문 · AI 다듬은 글 전체에서 키워드 검색
- **매일 알림**: 원하는 시간에 매일 일기 작성 리마인더 (시간대별 다른 메시지)
- **공유**: `share_plus`로 작성한 일기를 다른 앱으로 공유
- **한국어 로컬라이제이션**

## 기술 스택

- **Framework**: Flutter (SDK `>=3.0.0 <4.0.0`), Material 3
- **로컬 저장소**: `sqflite` (SQLite, schema v3)
- **AI**: OpenAI Chat Completions API (`http` 직접 호출, Vision 멀티모달)
- **위치**: `geolocator`, `geocoding`, `flutter_map`, `latlong2`
- **기기 정보**: `device_info_plus`, `battery_plus`, `connectivity_plus`
- **UI 보조**: `table_calendar`, `flutter_staggered_grid_view`, `cached_network_image`
- **기타**: `flutter_local_notifications`, `timezone`, `image_picker`, `share_plus`, `shared_preferences`, `intl`

## 프로젝트 구조

```
lib/
├── main.dart                        # 앱 진입점, 테마/알림 초기화
├── models/
│   └── diary_entry.dart             # DiaryEntry 모델, 기분/날씨 상수
├── services/
│   ├── database_service.dart        # SQLite CRUD, 마이그레이션(v1→v3)
│   ├── device_info_service.dart     # 기기·배터리·네트워크·위치·시간대 스냅샷
│   ├── openai_service.dart          # OpenAI 연동, 프롬프트 구성
│   └── notification_service.dart    # 매일 알림 스케줄링
├── screens/
│   ├── home_screen.dart             # 메인 (목록/캘린더 토글, 검색)
│   ├── diary_edit_screen.dart       # 일기 작성/편집
│   ├── diary_detail_screen.dart     # 상세 보기, AI 다듬기, 공유
│   └── settings_screen.dart         # API 키·모델·알림 설정
└── widgets/
    ├── calendar_view.dart           # 달력 위젯
    ├── diary_card.dart              # 목록 카드
    └── map_location_picker.dart     # 지도 위치 선택
```

## 시작하기

### 1. 의존성 설치

```bash
flutter pub get
```

### 2. 플랫폼 권한 설정

- **Android**: `android/app/src/main/AndroidManifest.xml`에 위치(`ACCESS_FINE_LOCATION`), 인터넷, 카메라/사진, 알림(`POST_NOTIFICATIONS`) 권한이 필요합니다.
- **iOS**: `ios/Runner/Info.plist`에 `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` 항목이 필요합니다.

### 3. 실행

```bash
flutter run
```

### 4. OpenAI API 키 설정 (선택)

AI 글 다듬기 기능을 사용하려면 앱 내 **설정** 화면에서 OpenAI API 키를 입력하세요. 키는 기기 내부의 `SharedPreferences`에만 저장됩니다.

지원 모델:
- `gpt-4o-mini` (기본값, 빠르고 경제적)
- `gpt-4o` (Vision 지원, 가장 똑똑함)
- `gpt-3.5-turbo` (텍스트 전용)

## 데이터 모델

`DiaryEntry` (`lib/models/diary_entry.dart:1`)는 다음 필드를 포함합니다.

| 구분 | 필드 |
| --- | --- |
| 기본 | `id`, `title`, `content`, `date`, `photoPaths` |
| AI | `aiContent` (OpenAI로 다듬은 글) |
| 감성 | `mood`, `weather`, `timeContext` |
| 위치 | `location`(동/읍), `district`(구/군), `city`(시/도), `country`, `latitude`, `longitude` |
| 기기 | `batteryLevel`, `deviceModel`, `steps` |

DB 스키마 변경 이력은 [database_service.dart](lib/services/database_service.dart)의 `onUpgrade`에서 관리됩니다.

## 라이선스

개인 프로젝트입니다.
