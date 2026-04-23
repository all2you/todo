import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class DeviceSnapshot {
  final String deviceModel;
  final String osVersion;
  final int batteryLevel;
  final bool isCharging;
  final String connectivity;
  final double? latitude;
  final double? longitude;
  final String? address; // 동/읍/면 수준
  final String? district; // 구/군
  final String? city; // 시/도
  final String? country; // 국가
  final String timeOfDay; // 아침/오전/점심/오후/저녁/밤
  final String localTime; // HH:mm
  final String dayOfWeek; // 월요일 등

  const DeviceSnapshot({
    required this.deviceModel,
    required this.osVersion,
    required this.batteryLevel,
    required this.isCharging,
    required this.connectivity,
    this.latitude,
    this.longitude,
    this.address,
    this.district,
    this.city,
    this.country,
    required this.timeOfDay,
    required this.localTime,
    required this.dayOfWeek,
  });
}

class DeviceInfoService {
  static final _battery = Battery();
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<DeviceSnapshot> getSnapshot() async {
    final now = DateTime.now();

    final results = await Future.wait([
      _getDeviceModel(),
      _getBatteryInfo(),
      _getConnectivity(),
    ]);

    final deviceModel = results[0] as String;
    final batteryInfo = results[1] as (int, bool);
    final connectivity = results[2] as String;

    final location = await _getLocation();

    return DeviceSnapshot(
      deviceModel: deviceModel,
      osVersion: Platform.operatingSystemVersion,
      batteryLevel: batteryInfo.$1,
      isCharging: batteryInfo.$2,
      connectivity: connectivity,
      latitude: location?.$1,
      longitude: location?.$2,
      address: location?.$3,
      district: location?.$4,
      city: location?.$5,
      country: location?.$6,
      timeOfDay: _getTimeOfDay(now),
      localTime: _formatTime(now),
      dayOfWeek: _getDayOfWeek(now),
    );
  }

  static String _getTimeOfDay(DateTime t) {
    final h = t.hour;
    if (h >= 5 && h < 8) return '이른 아침';
    if (h >= 8 && h < 11) return '아침';
    if (h >= 11 && h < 13) return '점심';
    if (h >= 13 && h < 17) return '오후';
    if (h >= 17 && h < 20) return '저녁';
    if (h >= 20 && h < 23) return '밤';
    return '새벽';
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _getDayOfWeek(DateTime t) {
    const days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return days[t.weekday - 1];
  }

  static Future<String> _getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.utsname.machine;
      }
    } catch (_) {}
    return '알 수 없는 기기';
  }

  static Future<(int, bool)> _getBatteryInfo() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      return (level, state == BatteryState.charging);
    } catch (_) {
      return (0, false);
    }
  }

  static Future<String> _getConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.wifi) return 'Wi-Fi';
      if (result == ConnectivityResult.mobile) return '모바일 데이터';
      return '오프라인';
    } catch (_) {
      return '알 수 없음';
    }
  }

  // (lat, lon, 동/읍, 구/군, 시/도, 국가)
  static Future<(double, double, String?, String?, String?, String?)?>
      _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      String? address;
      String? district;
      String? city;
      String? country;

      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          // 동/읍/면 수준 (가장 상세)
          address = [p.subLocality, p.thoroughfare]
              .where((e) => e != null && e.isNotEmpty)
              .join(' ');
          if (address.isEmpty) address = p.locality;
          // 구/군
          district = p.subAdministrativeArea;
          // 시/도
          city = p.administrativeArea ?? p.locality;
          // 국가
          country = p.country;
        }
      } catch (_) {}

      return (pos.latitude, pos.longitude, address, district, city, country);
    } catch (_) {
      return null;
    }
  }
}
