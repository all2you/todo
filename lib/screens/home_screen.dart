import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../widgets/diary_card.dart';
import '../widgets/calendar_view.dart';
import 'diary_edit_screen.dart';
import 'diary_detail_screen.dart';
import 'map_overview_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

enum _ViewMode { list, calendar }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService();
  List<DiaryEntry> _entries = [];
  List<DiaryEntry> _onThisDay = [];
  bool _onThisDayDismissed = false;
  bool _loading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  _ViewMode _viewMode = _ViewMode.list;
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadOnThisDay();
  }

  Future<void> _loadOnThisDay() async {
    final entries = await _db.getOnThisDay(DateTime.now());
    if (!mounted) return;
    setState(() => _onThisDay = entries);
    // 한 번만 알림
    if (entries.isNotEmpty) {
      final latest = entries.first;
      final yearsAgo = DateTime.now().year - latest.date.year;
      await NotificationService.showOnThisDay(
        yearsAgo: yearsAgo,
        entryTitle: latest.title,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final entries = _searchQuery.isEmpty
        ? await _db.getAllEntries()
        : await _db.searchEntries(_searchQuery);
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _deleteEntry(DiaryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일기 삭제'),
        content: Text('"${entry.title}" 일기를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm == true && entry.id != null) {
      await _db.deleteEntry(entry.id!);
      _loadEntries();
    }
  }

  Map<String, List<DiaryEntry>> _groupByMonth() {
    final grouped = <String, List<DiaryEntry>>{};
    for (final entry in _entries) {
      final key = DateFormat('yyyy년 MM월', 'ko').format(entry.date);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '나의 하루',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // 캘린더/목록 토글
          IconButton(
            icon: Icon(
              _viewMode == _ViewMode.list
                  ? Icons.calendar_month
                  : Icons.view_list,
            ),
            tooltip: _viewMode == _ViewMode.list ? '캘린더 보기' : '목록 보기',
            onPressed: () => setState(() {
              _viewMode = _viewMode == _ViewMode.list
                  ? _ViewMode.calendar
                  : _ViewMode.list;
              // 캘린더 모드에선 검색 초기화
              if (_viewMode == _ViewMode.calendar) {
                _searchQuery = '';
                _searchController.clear();
                _loadEntries();
              }
            }),
          ),
          if (_viewMode == _ViewMode.list)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showSearchBar,
            ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: '지도 보기',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapOverviewScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: '통계',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _viewMode == _ViewMode.calendar
              ? _buildCalendarBody()
              : _buildListBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => DiaryEditScreen(
                initialDate: _selectedCalendarDate,
              ),
            ),
          );
          if (created == true) _loadEntries();
        },
        icon: const Icon(Icons.edit),
        label: const Text('오늘 일기 쓰기'),
        backgroundColor: const Color(0xFF6B9B7A),
      ),
    );
  }

  // ── 캘린더 뷰 ──────────────────────────────────────────
  Widget _buildCalendarBody() {
    return CalendarView(
      entries: _entries,
      onEntryTap: _openDetail,
      onDaySelected: (date) => setState(() => _selectedCalendarDate = date),
    );
  }

  // ── 목록 뷰 ────────────────────────────────────────────
  Widget _buildListBody() {
    return Column(
      children: [
        if (_searchQuery.isNotEmpty) _buildSearchBanner(),
        if (_searchQuery.isEmpty &&
            _onThisDay.isNotEmpty &&
            !_onThisDayDismissed)
          _buildOnThisDayBanner(),
        Expanded(
          child: _entries.isEmpty ? _buildEmptyState() : _buildEntryList(),
        ),
      ],
    );
  }

  Widget _buildOnThisDayBanner() {
    final entry = _onThisDay.first;
    final yearsAgo = DateTime.now().year - entry.date.year;
    final label = yearsAgo == 1 ? '작년 오늘' : '$yearsAgo년 전 오늘';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade100,
            const Color(0xFF6B9B7A).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(entry),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF6B9B7A)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B9B7A))),
                    const SizedBox(height: 2),
                    Text(
                      entry.title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_onThisDay.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('+ ${_onThisDay.length - 1}개 더',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700)),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _onThisDayDismissed = true),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBanner() {
    return Container(
      color: const Color(0xFF6B9B7A).withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('"$_searchQuery" 검색 결과: ${_entries.length}개'),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              _searchController.clear();
              _loadEntries();
            },
            child: const Text('검색 초기화'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? '아직 작성된 일기가 없어요' : '검색 결과가 없어요',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              '오늘 하루를 기록해보세요 ✨',
              style: TextStyle(color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryList() {
    if (_searchQuery.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _entries.length,
        itemBuilder: (_, i) => DiaryCard(
          entry: _entries[i],
          onTap: () => _openDetail(_entries[i]),
          onDelete: () => _deleteEntry(_entries[i]),
        ),
      );
    }

    final grouped = _groupByMonth();
    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: months.fold<int>(0, (sum, m) => sum + 1 + grouped[m]!.length),
      itemBuilder: (_, index) {
        int cursor = 0;
        for (final month in months) {
          if (index == cursor) return _buildMonthHeader(month);
          cursor++;
          final list = grouped[month]!;
          if (index < cursor + list.length) {
            final entry = list[index - cursor];
            return DiaryCard(
              entry: entry,
              onTap: () => _openDetail(entry),
              onDelete: () => _deleteEntry(entry),
            );
          }
          cursor += list.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMonthHeader(String month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        month,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B9B7A),
        ),
      ),
    );
  }

  void _openDetail(DiaryEntry entry) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DiaryDetailScreen(entry: entry)),
    );
    if (updated == true) _loadEntries();
  }

  void _showSearchBar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일기 검색'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '제목 또는 내용 검색',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (val) {
            Navigator.pop(ctx);
            setState(() => _searchQuery = val.trim());
            _loadEntries();
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              final val = _searchController.text.trim();
              Navigator.pop(ctx);
              setState(() => _searchQuery = val);
              _loadEntries();
            },
            child: const Text('검색'),
          ),
        ],
      ),
    );
  }
}
