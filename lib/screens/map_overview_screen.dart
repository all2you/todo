import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import 'diary_detail_screen.dart';

class MapOverviewScreen extends StatefulWidget {
  const MapOverviewScreen({super.key});

  @override
  State<MapOverviewScreen> createState() => _MapOverviewScreenState();
}

class _MapOverviewScreenState extends State<MapOverviewScreen> {
  final _db = DatabaseService();
  final _mapController = MapController();
  List<DiaryEntry> _entries = [];
  bool _loading = true;
  DiaryEntry? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await _db.getAllEntries();
    final withLoc = all
        .where((e) => e.latitude != null && e.longitude != null)
        .toList();
    setState(() {
      _entries = withLoc;
      _loading = false;
    });
  }

  LatLng _centerFromEntries() {
    if (_entries.isEmpty) return const LatLng(37.5665, 126.9780); // 서울
    double lat = 0, lon = 0;
    for (final e in _entries) {
      lat += e.latitude!;
      lon += e.longitude!;
    }
    return LatLng(lat / _entries.length, lon / _entries.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일기 지도',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : Stack(
                  children: [
                    _buildMap(),
                    if (_selected != null) _buildSelectedCard(_selected!),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('위치가 기록된 일기가 없어요',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _centerFromEntries(),
        initialZoom: 10,
        onTap: (_, __) => setState(() => _selected = null),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.todo',
        ),
        MarkerLayer(
          markers: _entries
              .map((e) => Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(e.latitude!, e.longitude!),
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = e),
                      child: Icon(
                        Icons.location_on,
                        color: _selected?.id == e.id
                            ? Colors.orange.shade700
                            : const Color(0xFF6B9B7A),
                        size: _selected?.id == e.id ? 40 : 32,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedCard(DiaryEntry entry) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Card(
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DiaryDetailScreen(entry: entry)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (entry.photoPaths.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(entry.photoPaths.first),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B7A).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.book_outlined,
                        color: Color(0xFF6B9B7A)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('yyyy.MM.dd').format(entry.date),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      if (entry.location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [entry.location, entry.city]
                              .where((e) => e != null && e.isNotEmpty)
                              .join(', '),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
