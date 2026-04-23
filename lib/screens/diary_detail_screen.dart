import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/diary_entry.dart';
import '../services/openai_service.dart';
import 'diary_edit_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final DiaryEntry entry;

  const DiaryDetailScreen({super.key, required this.entry});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen>
    with SingleTickerProviderStateMixin {
  late DiaryEntry _entry;
  int _currentPhotoIndex = 0;
  late TabController _tabController;
  bool _enhancing = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    // AI 글이 있으면 탭 2개, 없으면 1개
    _tabController = TabController(
      length: _entry.aiContent != null ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _rebuildTabs() {
    final newLength = _entry.aiContent != null ? 2 : 1;
    if (_tabController.length != newLength) {
      _tabController.dispose();
      _tabController = TabController(length: newLength, vsync: this);
    }
  }

  Future<void> _enhanceWithAi() async {
    setState(() => _enhancing = true);
    try {
      final result = await OpenAiService.enhanceDiary(_entry);
      if (mounted) {
        setState(() {
          _entry = _entry.copyWith(aiContent: result);
          _rebuildTabs();
          // 생성 직후 AI 탭으로 전환
          if (_tabController.length == 2) {
            _tabController.animateTo(1);
          }
        });
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

  Future<void> _shareToSns(String text, BuildContext btnContext) async {
    final box = btnContext.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(100, 400, 200, 50);

    // 사진이 있으면 함께 공유
    final photos = _entry.photoPaths
        .where((p) => File(p).existsSync())
        .take(4)
        .map((p) => XFile(p))
        .toList();

    if (photos.isNotEmpty) {
      await Share.shareXFiles(
        photos,
        text: text,
        subject: _entry.title,
        sharePositionOrigin: origin,
      );
    } else {
      await Share.share(
        text,
        subject: _entry.title,
        sharePositionOrigin: origin,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTabs = _entry.aiContent != null;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverAppBar(),
        ],
        body: Column(
          children: [
            if (hasTabs) _buildTabBar(),
            Expanded(
              child: hasTabs
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOriginalTab(),
                        _buildAiTab(),
                      ],
                    )
                  : _buildOriginalTab(),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI 다듬기 버튼
          FloatingActionButton.small(
            heroTag: 'ai',
            onPressed: _enhancing ? null : _enhanceWithAi,
            backgroundColor: Colors.purple.shade400,
            child: _enhancing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'edit',
            onPressed: _editEntry,
            backgroundColor: const Color(0xFF6B9B7A),
            child: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final hasPhotos = _entry.photoPaths.isNotEmpty;
    return SliverAppBar(
      expandedHeight: hasPhotos ? 300 : 0,
      pinned: true,
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

  Widget _buildTabBar() {
    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF6B9B7A),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF6B9B7A),
        tabs: const [
          Tab(icon: Icon(Icons.edit_note, size: 18), text: '내 일기'),
          Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'AI 버전'),
        ],
      ),
    );
  }

  Widget _buildOriginalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 32),
          _buildTextContent(_entry.content),
          const SizedBox(height: 24),
          _buildInfoCards(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAiTab() {
    final aiText = _entry.aiContent ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade300,
                  const Color(0xFF6B9B7A),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('AI가 다듬은 SNS 버전',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildHeader(showWeather: false),
          const Divider(height: 32),
          // AI 본문
          SelectableText(
            aiText,
            style: const TextStyle(
              fontSize: 15,
              height: 1.9,
              color: Color(0xFF3A3A3A),
            ),
          ),
          const SizedBox(height: 20),
          // SNS 공유 버튼 (강조)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _shareToSns(aiText, context),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('SNS에 공유하기',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9B7A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 복사 & 다시 생성
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: aiText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('클립보드에 복사되었습니다'),
                        backgroundColor: Color(0xFF6B9B7A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B9B7A),
                    side: const BorderSide(color: Color(0xFF6B9B7A)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _enhancing ? null : _enhanceWithAi,
                  icon: _enhancing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('다시 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader({bool showWeather = true}) {
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
        if (showWeather && _entry.weather != null) ...[
          const SizedBox(height: 4),
          Text(_entry.weather!, style: const TextStyle(fontSize: 20)),
        ],
        if (_entry.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _entry.tags
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9B7A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('#$t',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B9B7A))),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTextContent(String text) {
    if (text.isEmpty) {
      return Text(
        '내용이 없습니다.',
        style:
            TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic),
      );
    }
    return Text(
      text,
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
      infos.add(_InfoItem(Icons.battery_std, '배터리', '${_entry.batteryLevel}%'));
    }
    if (_entry.steps != null && _entry.steps! > 0) {
      infos.add(_InfoItem(Icons.directions_walk, '걸음', '${_entry.steps}보'));
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
      MaterialPageRoute(builder: (_) => DiaryEditScreen(existing: _entry)),
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
