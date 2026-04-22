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
  final String? address;

  const DeviceSnapshot({
    required this.deviceModel,
    required this.osVersion,
    required this.batteryLevel,
    required this.isCharging,
    required this.connectivity,
    this.latitude,
    this.longitude,
    this.address,
  });
}

class DeviceInfoService {
  static final _battery = Battery();
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<DeviceSnapshot> getSnapshot() async {
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
    );
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
      if (result.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
      if (result.contains(ConnectivityResult.mobile)) return '모바일 데이터';
      return '오프라인';
    } catch (_) {
      return '알 수 없음';
    }
  }

  static Future<(double, double, String?)?> _getLocation() async {
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      String? address;
      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [p.locality, p.subLocality, p.thoroughfare]
              .where((e) => e != null && e.isNotEmpty)
              .join(' ');
        }
      } catch (_) {}

      return (pos.latitude, pos.longitude, address);
    } catch (_) {
      return null;
    }
  }
}
