import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../services/device_info_service.dart';
import '../services/openai_service.dart';
import '../services/step_counter_service.dart';
import '../services/weather_service.dart';
import '../widgets/map_location_picker.dart';

class DiaryEditScreen extends StatefulWidget {
  final DiaryEntry? existing;
  final DateTime? initialDate;

  const DiaryEditScreen({super.key, this.existing, this.initialDate});

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
  int? _todaySteps;
  List<String> _tags = [];
  bool _loadingDevice = false;
  bool _saving = false;

  // 위치 수동 변경
  String? _overrideAddress;
  String? _overrideDistrict;
  String? _overrideCity;
  String? _overrideCountry;
  double? _overrideLat;
  double? _overrideLon;

  // 실제 작성 시각
  late final DateTime _writtenAt;

  // AI 다듬기 상태
  String? _aiContent;
  bool _enhancing = false;
  bool _showAiPreview = false;

  @override
  void initState() {
    super.initState();
    _writtenAt = DateTime.now();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      _selectedDate = e.date;
      _photos = List.from(e.photoPaths);
      _mood = e.mood;
      _weather = e.weather;
      _tags = List.from(e.tags);
      if (e.aiContent != null) {
        _aiContent = e.aiContent;
        _showAiPreview = true;
      }
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _titleCtrl.text = DateFormat('yyyy년 MM월 dd일', 'ko').format(_selectedDate);
      _fetchDeviceInfo();
      _fetchTodaySteps();
    }
  }

  Future<void> _fetchTodaySteps() async {
    final steps = await StepCounterService.getTodaySteps();
    if (mounted) setState(() => _todaySteps = steps);
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
      if (mounted) {
        setState(() => _deviceSnapshot = snap);
        // 위치 정보가 있으면 날씨 자동 감지
        if (snap.latitude != null && snap.longitude != null) {
          _fetchWeatherForLocation(snap.latitude!, snap.longitude!);
        }
      }
    } finally {
      if (mounted) setState(() => _loadingDevice = false);
    }
  }

  Future<void> _fetchWeatherForLocation(double lat, double lon) async {
    final emoji = await WeatherService.fetchWeatherEmoji(lat, lon);
    if (emoji != null && mounted && _weather == null) {
      setState(() => _weather = emoji);
    }
  }

  Future<void> _enhanceWithAi() async {
    if (_contentCtrl.text.trim().isEmpty && _titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 일기 내용을 작성해주세요')),
      );
      return;
    }

    setState(() {
      _enhancing = true;
      _showAiPreview = false;
      _aiContent = null;
    });

    // 현재 입력 내용으로 임시 entry 생성
    final tempEntry = DiaryEntry(
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      date: _selectedDate,
      mood: _mood,
      weather: _weather,
      location: _overrideAddress ?? _deviceSnapshot?.address,
      district: _overrideDistrict ?? _deviceSnapshot?.district,
      city: _overrideCity ?? _deviceSnapshot?.city,
      country: _overrideCountry ?? _deviceSnapshot?.country,
      batteryLevel: _deviceSnapshot?.batteryLevel,
      timeContext: _deviceSnapshot?.timeOfDay,
      photoPaths: _photos,
    );

    try {
      final result = await OpenAiService.enhanceDiary(
        tempEntry,
        photoPaths: _photos,
      );
      if (mounted) {
        setState(() {
          _aiContent = result;
          _showAiPreview = true;
        });
        // 미리보기 패널로 스크롤
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final files = await _picker.pickMultiImage(imageQuality: 80);
      if (files.isNotEmpty) {
        setState(() => _photos.addAll(files.map((f) => f.path)));
      }
    } else {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요')));
      return;
    }

    setState(() => _saving = true);

    final entry = DiaryEntry(
      id: widget.existing?.id,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      aiContent: _aiContent,
      date: _selectedDate,
      photoPaths: _photos,
      mood: _mood,
      weather: _weather,
      location: _overrideAddress ?? _deviceSnapshot?.address,
      district: _overrideDistrict ?? _deviceSnapshot?.district,
      city: _overrideCity ?? _deviceSnapshot?.city,
      country: _overrideCountry ?? _deviceSnapshot?.country,
      latitude: _overrideLat ?? _deviceSnapshot?.latitude,
      longitude: _overrideLon ?? _deviceSnapshot?.longitude,
      batteryLevel: _deviceSnapshot?.batteryLevel,
      deviceModel: _deviceSnapshot?.deviceModel,
      timeContext: _deviceSnapshot?.timeOfDay,
      steps: _todaySteps ?? widget.existing?.steps,
      tags: _tags,
    );

    if (widget.existing == null) {
      await _db.insertEntry(entry);
    } else {
      await _db.updateEntry(entry);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _selectDate() async {
    final oldStr =
        DateFormat('yyyy\ub144 MM\uc6d4 dd\uc77c', 'ko').format(_selectedDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      final newStr =
          DateFormat('yyyy\ub144 MM\uc6d4 dd\uc77c', 'ko').format(picked);
      setState(() {
        if (_titleCtrl.text == oldStr) _titleCtrl.text = newStr;
        _selectedDate = picked;
      });
    }
  }

  Future<void> _showLocationSearch() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          initialLat: _overrideLat ?? _deviceSnapshot?.latitude,
          initialLon: _overrideLon ?? _deviceSnapshot?.longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _overrideLat = result.lat;
        _overrideLon = result.lon;
        _overrideAddress = result.address;
        _overrideDistrict = result.district;
        _overrideCity = result.city;
        _overrideCountry = result.country;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existing == null ? '새 일기' : '일기 수정',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
            const SizedBox(height: 12),
            _buildTagsSection(),
            const SizedBox(height: 12),
            _buildAiEnhanceButton(),
            if (_showAiPreview && _aiContent != null) ...[
              const SizedBox(height: 16),
              _buildAiPreviewCard(),
            ],
            const SizedBox(height: 16),
            _buildPhotoSection(),
            const SizedBox(height: 8),
            _buildWrittenAtRow(),
            const SizedBox(height: 40),
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
    if (snap == null) {
      // GPS/기기 정보 없을 때도 위치 직접 설정 가능
      return GestureDetector(
        onTap: _showLocationSearch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, size: 16, color: const Color(0xFF6B9B7A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _overrideAddress != null
                      ? [_overrideAddress, _overrideCity, _overrideCountry]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(', ')
                      : '위치를 탭하여 검색하세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: _overrideAddress != null
                        ? const Color(0xFF4A4A4A)
                        : Colors.grey,
                  ),
                ),
              ),
              Icon(Icons.edit_location_alt,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6B9B7A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B9B7A).withOpacity(0.2)),
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
              _infoChip(Icons.battery_std,
                  '배터리 ${snap.batteryLevel}%${snap.isCharging ? " ⚡" : ""}'),
              _infoChip(Icons.wifi, snap.connectivity),
              if (_todaySteps != null)
                _infoChip(Icons.directions_walk, '$_todaySteps보'),
              GestureDetector(
                onTap: _showLocationSearch,
                child: _infoChip(
                  Icons.location_on,
                  _overrideAddress ??
                      (snap.address?.isNotEmpty == true
                          ? snap.address!
                          : '위치 설정 ✏️'),
                ),
              ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF6B9B7A).withOpacity(0.15)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.blue.withOpacity(0.1)
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

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('태그',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Text('(${_tags.length}개)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addTag,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('추가'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B9B7A)),
              ),
            ],
          ),
          if (_tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '태그로 일기를 분류해보세요 (예: 여행, 운동, 일상)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags
                  .map((t) => Chip(
                        label:
                            Text('#$t', style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            const Color(0xFF6B9B7A).withOpacity(0.1),
                        side: BorderSide(
                            color: const Color(0xFF6B9B7A).withOpacity(0.3)),
                        labelStyle: const TextStyle(color: Color(0xFF6B9B7A)),
                        deleteIconColor: const Color(0xFF6B9B7A),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onDeleted: () => setState(() => _tags.remove(t)),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _addTag() async {
    final tag = await showDialog<String>(
      context: context,
      builder: (_) => const _TagInputDialog(),
    );
    if (tag == null) return;
    final cleaned = tag.trim().replaceAll(RegExp(r'[,#\s]+'), '').toLowerCase();
    if (cleaned.isEmpty) return;
    if (_tags.contains(cleaned)) return;
    setState(() => _tags.add(cleaned));
  }

  Widget _buildAiEnhanceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _enhancing ? null : _enhanceWithAi,
        icon: _enhancing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(_enhancing
            ? 'AI가 글을 다듬는 중...'
            : (_aiContent != null ? 'AI 글 다시 다듬기' : 'AI로 SNS 글 다듬기')),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6B9B7A),
          side: const BorderSide(color: Color(0xFF6B9B7A)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildAiPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B9B7A).withOpacity(0.05),
            Colors.purple.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B9B7A).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B7A).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 16, color: Color(0xFF6B9B7A)),
                const SizedBox(width: 8),
                const Text(
                  'AI가 다듬은 SNS 글',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF6B9B7A),
                  ),
                ),
                const Spacer(),
                // 복사 버튼
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _aiContent!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('클립보드에 복사되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF6B9B7A).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: Color(0xFF6B9B7A)),
                        SizedBox(width: 4),
                        Text('복사',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF6B9B7A))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 닫기
                GestureDetector(
                  onTap: () => setState(() => _showAiPreview = false),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          // 본문
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _aiContent!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.8,
                color: Color(0xFF3A3A3A),
              ),
            ),
          ),
          // 원본으로 교체 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  _contentCtrl.text = _aiContent!;
                  setState(() {
                    _showAiPreview = false;
                    _aiContent = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AI 글이 본문에 적용되었습니다'),
                      backgroundColor: Color(0xFF6B9B7A),
                    ),
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('이 글로 본문 교체하기'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B9B7A),
                  backgroundColor: const Color(0xFF6B9B7A).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      onTap: () => setState(() => _photos.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
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

  Widget _buildWrittenAtRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.history, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          '작성: ${DateFormat('yyyy.MM.dd HH:mm').format(_writtenAt)}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
      ],
    );
  }
}

class _TagInputDialog extends StatefulWidget {
  const _TagInputDialog();

  @override
  State<_TagInputDialog> createState() => _TagInputDialogState();
}

class _TagInputDialogState extends State<_TagInputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('태그 추가'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 20,
        decoration: const InputDecoration(
          hintText: '예: 여행, 운동, 일상',
          prefixText: '#',
          counterText: '',
        ),
        onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('추가'),
        ),
      ],
    );
  }
}
