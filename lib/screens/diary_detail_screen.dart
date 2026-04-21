import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import 'diary_edit_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;

  const DiaryDetailScreen({super.key, required this.entry});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late DiaryEntry _entry;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _editEntry,
        backgroundColor: const Color(0xFF6B9B7A),
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final hasPhotos = _entry.photoPaths.isNotEmpty;
    return SliverAppBar(
      expandedHeight: hasPhotos ? 300 : 0,
      pinned: true,
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Color(0xFF2C2C2C)),
      flexibleSpace: hasPhotos
          ? FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: _entry.photoPaths.length,
                    onPageChanged: (i) =>
                        setState(() => _currentPhotoIndex = i),
                    itemBuilder: (_, i) => Image.file(
                      File(_entry.photoPaths[i]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 60),
                      ),
                    ),
                  ),
                  if (_entry.photoPaths.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _entry.photoPaths.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPhotoIndex == i ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPhotoIndex == i
                                  ? Colors.white
                                  : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 32),
          _buildContent(),
          const SizedBox(height: 24),
          _buildInfoCards(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_entry.mood != null) ...[
              Text(_entry.mood!, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                _entry.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              DateFormat('yyyy년 MM월 dd일 EEEE', 'ko').format(_entry.date),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        if (_entry.weather != null) ...[
          const SizedBox(height: 4),
          Text(_entry.weather!, style: const TextStyle(fontSize: 20)),
        ],
      ],
    );
  }

  Widget _buildContent() {
    if (_entry.content.isEmpty) {
      return Text(
        '내용이 없습니다.',
        style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic),
      );
    }
    return Text(
      _entry.content,
      style: const TextStyle(
        fontSize: 16,
        height: 1.8,
        color: Color(0xFF3A3A3A),
      ),
    );
  }

  Widget _buildInfoCards() {
    final infos = <_InfoItem>[];

    if (_entry.location != null && _entry.location!.isNotEmpty) {
      infos.add(_InfoItem(Icons.location_on, '위치', _entry.location!));
    }
    if (_entry.deviceModel != null) {
      infos.add(_InfoItem(Icons.phone_android, '기기', _entry.deviceModel!));
    }
    if (_entry.batteryLevel != null) {
      infos.add(_InfoItem(
          Icons.battery_std, '배터리', '${_entry.batteryLevel}%'));
    }
    if (_entry.latitude != null && _entry.longitude != null) {
      infos.add(_InfoItem(
        Icons.map,
        '좌표',
        '${_entry.latitude!.toStringAsFixed(4)}, ${_entry.longitude!.toStringAsFixed(4)}',
      ));
    }

    if (infos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기록 정보',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF6B9B7A),
            ),
          ),
          const SizedBox(height: 12),
          ...infos.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: const Color(0xFF6B9B7A)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 50,
                      child: Text(item.label,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.value,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _editEntry() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => DiaryEditScreen(existing: _entry)),
    );
    if (updated == true && mounted) Navigator.pop(context, true);
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem(this.icon, this.label, this.value);
}
