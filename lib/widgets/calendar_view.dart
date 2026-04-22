import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class CalendarView extends StatefulWidget {
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onEntryTap;
  final void Function(DateTime) onDaySelected;

  const CalendarView({
    super.key,
    required this.entries,
    required this.onEntryTap,
    required this.onDaySelected,
  });

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 날짜별 일기 맵
  Map<DateTime, List<DiaryEntry>> get _eventMap {
    final map = <DateTime, List<DiaryEntry>>{};
    for (final e in widget.entries) {
      final key = _normalizeDate(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DiaryEntry> _getEntriesForDay(DateTime day) {
    return _eventMap[_normalizeDate(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntries =
        _selectedDay != null ? _getEntriesForDay(_selectedDay!) : <DiaryEntry>[];

    return Column(
      children: [
        _buildCalendar(),
        const Divider(height: 1),
        if (_selectedDay != null) _buildDayHeader(selectedEntries),
        Expanded(
          child: selectedEntries.isEmpty
              ? _buildNoDiaryPrompt()
              : _buildEntryList(selectedEntries),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return TableCalendar<DiaryEntry>(
      locale: 'ko_KR',
      firstDay: DateTime(2000),
      lastDay: DateTime.now().add(const Duration(days: 1)),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      eventLoader: _getEntriesForDay,
      calendarStyle: CalendarStyle(
        // 오늘 날짜
        todayDecoration: BoxDecoration(
          color: const Color(0xFF6B9B7A).withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
            color: Color(0xFF2C2C2C), fontWeight: FontWeight.bold),
        // 선택한 날짜
        selectedDecoration: const BoxDecoration(
          color: Color(0xFF6B9B7A),
          shape: BoxShape.circle,
        ),
        // 이벤트 점
        markerDecoration: const BoxDecoration(
          color: Color(0xFF6B9B7A),
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        outsideDaysVisible: false,
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF6B9B7A)),
        rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF6B9B7A)),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle:
            TextStyle(fontSize: 12, color: Colors.grey.shade600),
        weekendStyle:
            const TextStyle(fontSize: 12, color: Color(0xFFD45F5F)),
      ),
      calendarBuilders: CalendarBuilders(
        // 일기가 있는 날 배경 살짝 표시
        defaultBuilder: (ctx, day, focusedDay) {
          final hasEntry = _getEntriesForDay(day).isNotEmpty;
          if (!hasEntry) return null;
          return Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B7A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
        widget.onDaySelected(selected);
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
    );
  }

  Widget _buildDayHeader(List<DiaryEntry> entries) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF7F3EE),
      child: Row(
        children: [
          Text(
            DateFormat('MM월 dd일 (E)', 'ko').format(_selectedDay!),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B7A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entries.length}개',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDiaryPrompt() {
    final isToday = _selectedDay != null &&
        isSameDay(_selectedDay!, DateTime.now());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            isToday ? '오늘 아직 일기가 없어요' : '이 날 일기가 없어요',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList(List<DiaryEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6B9B7A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              e.mood ?? '📖',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          title: Text(e.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: e.content.isNotEmpty
              ? Text(e.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12))
              : null,
          trailing: e.photoPaths.isNotEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo, size: 14, color: Colors.grey),
                    const SizedBox(width: 2),
                    Text('${e.photoPaths.length}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                )
              : null,
          onTap: () => widget.onEntryTap(e),
        );
      },
    );
  }
}
