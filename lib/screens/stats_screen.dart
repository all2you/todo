import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/database_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _db = DatabaseService();
  List<DiaryEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _db.getAllEntries();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통계', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeadline(),
                    const SizedBox(height: 16),
                    _buildMoodSection(),
                    const SizedBox(height: 16),
                    _buildLocationSection(),
                    const SizedBox(height: 16),
                    _buildMonthlySection(),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('일기를 써야 통계가 쌓여요', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // ── 요약 (총 개수 + streak) ──────────────────────────
  Widget _buildHeadline() {
    final total = _entries.length;
    final streak = _computeStreak();
    final firstDate =
        _entries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final days = DateTime.now().difference(firstDate).inDays + 1;

    return Row(
      children: [
        _statCard('총 일기', '$total', '개', Icons.menu_book),
        const SizedBox(width: 12),
        _statCard('연속 작성', '$streak', '일', Icons.local_fire_department,
            highlight: streak > 0),
        const SizedBox(width: 12),
        _statCard('함께한 날', '$days', '일', Icons.calendar_today),
      ],
    );
  }

  Widget _statCard(String title, String value, String unit, IconData icon,
      {bool highlight = false}) {
    final color = highlight ? Colors.orange.shade600 : const Color(0xFF6B9B7A);
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  const SizedBox(width: 2),
                  Text(unit,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              Text(title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  int _computeStreak() {
    if (_entries.isEmpty) return 0;
    final dates = _entries
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    // 오늘 일기가 없으면 어제부터 세어도 streak으로 인정
    if (!dates.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── 기분 분포 ────────────────────────────────────────
  Widget _buildMoodSection() {
    final counts = <String, int>{};
    for (final e in _entries) {
      if (e.mood != null) counts[e.mood!] = (counts[e.mood!] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final max = counts.values.reduce((a, b) => a > b ? a : b);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _sectionCard(
      title: '기분 분포',
      icon: Icons.mood,
      child: Column(
        children: sorted.map((e) {
          final idx = kMoods.indexOf(e.key);
          final label = idx >= 0 ? kMoodLabels[idx] : '';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 28,
                    child: Text(e.key, style: const TextStyle(fontSize: 20))),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  child: Text(label,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF6B9B7A)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text('${e.value}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 자주 간 장소 TOP 5 ──────────────────────────────
  Widget _buildLocationSection() {
    final counts = <String, int>{};
    for (final e in _entries) {
      final place = e.city ?? e.district ?? e.location;
      if (place != null && place.trim().isNotEmpty) {
        counts[place] = (counts[place] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    return _sectionCard(
      title: '자주 간 장소',
      icon: Icons.location_on,
      child: Column(
        children: top.asMap().entries.map((entry) {
          final i = entry.key;
          final place = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        i == 0 ? Colors.orange.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: i == 0
                              ? Colors.orange.shade700
                              : Colors.grey.shade700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(place.key,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                Text('${place.value}회',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 최근 6개월 작성 빈도 ────────────────────────────
  Widget _buildMonthlySection() {
    final now = DateTime.now();
    final months =
        List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
    final counts = <DateTime, int>{for (final m in months) m: 0};
    for (final e in _entries) {
      final key = DateTime(e.date.year, e.date.month, 1);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    if (max == 0) return const SizedBox.shrink();

    return _sectionCard(
      title: '최근 6개월 작성',
      icon: Icons.bar_chart,
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: counts.entries.map((e) {
            final h = (e.value / max) * 90;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Container(
                      height: h < 3 ? 3 : h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B9B7A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('M월').format(e.key),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF6B9B7A), size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
