import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

class LocationPickerResult {
  final double lat;
  final double lon;
  final String? address;
  final String? district;
  final String? city;
  final String? country;
  final String display;

  const LocationPickerResult({
    required this.lat,
    required this.lon,
    this.address,
    this.district,
    this.city,
    this.country,
    required this.display,
  });
}

class MapLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const MapLocationPicker({super.key, this.initialLat, this.initialLon});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  LatLng _center = const LatLng(37.5665, 126.9780); // 서울 기본

  String? _addressText;
  bool _locating = false;
  bool _searching = false;
  bool _reversing = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLon != null) {
      _center = LatLng(widget.initialLat!, widget.initialLon!);
    }
    _reverseGeocode(_center);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _scheduleReverse(LatLng pos) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 700), () => _reverseGeocode(pos));
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _reversing = true);
    try {
      final marks =
          await geo.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
          p.country,
        ].whereType<String>().where((e) => e.isNotEmpty).take(3).join(', ');
        setState(() => _addressText = parts.isEmpty ? null : parts);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _reversing = false);
    }
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final locs = await geo.locationFromAddress(q);
      if (locs.isNotEmpty && mounted) {
        final pos = LatLng(locs.first.latitude, locs.first.longitude);
        _mapController.move(pos, 15.0);
        setState(() => _center = pos);
        _reverseGeocode(pos);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 찾을 수 없어요. 다른 검색어를 시도해보세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _myLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      _mapController.move(latLng, 16.0);
      setState(() => _center = latLng);
      _reverseGeocode(latLng);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _locating = true);
    try {
      String? address, district, city, country;
      final marks = await geo.placemarkFromCoordinates(
          _center.latitude, _center.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final addrParts = [p.subLocality, p.thoroughfare]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' ');
        address = addrParts.isEmpty ? p.locality : addrParts;
        district = (p.subAdministrativeArea?.isNotEmpty ?? false)
            ? p.subAdministrativeArea
            : null;
        final cityVal = p.administrativeArea ?? p.locality;
        city = (cityVal?.isNotEmpty ?? false) ? cityVal : null;
        country = (p.country?.isNotEmpty ?? false) ? p.country : null;
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        LocationPickerResult(
          lat: _center.latitude,
          lon: _center.longitude,
          address: address,
          district: district,
          city: city,
          country: country,
          display: _addressText ?? '선택된 위치',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(
        context,
        LocationPickerResult(
          lat: _center.latitude,
          lon: _center.longitude,
          display:
              '위치 (${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)})',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ─── 지도 영역 ───
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15.0,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture && camera.center != null) {
                        setState(() => _center = camera.center!);
                        _scheduleReverse(camera.center!);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.all2you.todo',
                    ),
                  ],
                ),

                // 중앙 핀 (터치 무시)
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_pin,
                            size: 48,
                            color: const Color(0xFF6B9B7A),
                            shadows: const [
                              Shadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3))
                            ],
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 상단 검색창
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: '장소나 주소를 검색하세요',
                                border: InputBorder.none,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: _search,
                            ),
                          ),
                          if (_searching)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.search,
                                  color: Color(0xFF6B9B7A)),
                              onPressed: () => _search(_searchCtrl.text),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 내 위치 버튼
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'mapMyLoc',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6B9B7A),
                    elevation: 4,
                    onPressed: _locating ? null : _myLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),

          // ─── 하단 주소 + 확인 패널 ───
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '핀을 이동하거나 위에서 검색하세요',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF6B9B7A), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _reversing
                              ? const Text('주소 확인 중...',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey))
                              : Text(
                                  _addressText ?? '지도를 이동하여 위치를 선택하세요',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _locating ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B9B7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('이 위치로 선택',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
