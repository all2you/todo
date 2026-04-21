import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../services/device_info_service.dart';

class DiaryEditScreen extends StatefulWidget {
  final DiaryEntry? existing;

  const DiaryEditScreen({super.key, this.existing});

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  final _db = DatabaseService();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _picker = ImagePicker();

  late DateTime _selectedDate;
  List<String> _photos = [];
  String? _mood;
  String? _weather;
  DeviceSnapshot? _deviceSnapshot;
  bool _loadingDevice = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      _selectedDate = e.date;
      _photos = List.from(e.photoPaths);
      _mood = e.mood;
      _weather = e.weather;
    } else {
      _selectedDate = DateTime.now();
      _titleCtrl.text = DateFormat('yyyy년 MM월 dd일', 'ko').format(_selectedDate);
      _fetchDeviceInfo();
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceInfo() async {
    setState(() => _loadingDevice = true);
    try {
      final snap = await DeviceInfoService.getSnapshot();
      if (mounted) setState(() => _deviceSnapshot = snap);
    } finally {
      if (mounted) setState(() => _loadingDevice = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final files = await _picker.pickMultiImage(imageQuality: 80);
      if (files.isNotEmpty) {
        setState(() => _photos.addAll(files.map((f) => f.path)));
      }
    } else {
      final file =
          await _picker.pickImage(source: source, imageQuality: 80);
      if (file != null) setState(() => _photos.add(file.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }

    setState(() => _saving = true);

    final entry = DiaryEntry(
      id: widget.existing?.id,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      date: _selectedDate,
      photoPaths: _photos,
      mood: _mood,
      weather: _weather,
      location: _deviceSnapshot?.address,
      latitude: _deviceSnapshot?.latitude,
      longitude: _deviceSnapshot?.longitude,
      batteryLevel: _deviceSnapshot?.batteryLevel,
      deviceModel: _deviceSnapshot?.deviceModel,
    );

    if (widget.existing == null) {
      await _db.insertEntry(entry);
    } else {
      await _db.updateEntry(entry);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing == null ? '새 일기' : '일기 수정',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF2C2C2C)),
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton(
                  onPressed: _save,
                  child: const Text('저장',
                      style: TextStyle(
                          color: Color(0xFF6B9B7A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRow(),
            const SizedBox(height: 16),
            _buildDeviceInfoCard(),
            const SizedBox(height: 16),
            _buildMoodRow(),
            const SizedBox(height: 16),
            _buildWeatherRow(),
            const SizedBox(height: 16),
            _buildTitleField(),
            const SizedBox(height: 12),
            _buildContentField(),
            const SizedBox(height: 16),
            _buildPhotoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF6B9B7A)),
            const SizedBox(width: 12),
            Text(
              DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(_selectedDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    if (_loadingDevice) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('기기 정보 수집 중...', style: TextStyle(color: Colors.grey)),
        ]),
      );
    }

    final snap = _deviceSnapshot;
    if (snap == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B9B7A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6B9B7A).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('지금 이 순간',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B9B7A))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _infoChip(Icons.phone_android, snap.deviceModel),
              _infoChip(Icons.battery_std, '배터리 ${snap.batteryLevel}%${snap.isCharging ? " ⚡" : ""}'),
              _infoChip(Icons.wifi, snap.connectivity),
              if (snap.address != null && snap.address!.isNotEmpty)
                _infoChip(Icons.location_on, snap.address!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B9B7A)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4A4A4A))),
      ],
    );
  }

  Widget _buildMoodRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘의 기분',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List.generate(kMoods.length, (i) {
              final selected = _mood == kMoods[i];
              return GestureDetector(
                onTap: () =>
                    setState(() => _mood = selected ? null : kMoods[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6B9B7A).withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF6B9B7A)
                            : Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      Text(kMoods[i], style: const TextStyle(fontSize: 20)),
                      Text(kMoodLabels[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: selected
                                  ? const Color(0xFF6B9B7A)
                                  : Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('날씨',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: List.generate(kWeathers.length, (i) {
              final selected = _weather == kWeathers[i];
              return GestureDetector(
                onTap: () =>
                    setState(() => _weather = selected ? null : kWeathers[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? Colors.blue : Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      Text(kWeathers[i], style: const TextStyle(fontSize: 20)),
                      Text(kWeatherLabels[i],
                          style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.blue : Colors.grey)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _titleCtrl,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          hintText: '제목을 입력하세요',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildContentField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: _contentCtrl,
        maxLines: null,
        minLines: 8,
        style: const TextStyle(fontSize: 15, height: 1.8),
        decoration: const InputDecoration(
          hintText: '오늘 하루를 기록해보세요...',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('사진',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Text('(${_photos.length}장)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('추가'),
            ),
          ],
        ),
        if (_photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_photos[i]),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
