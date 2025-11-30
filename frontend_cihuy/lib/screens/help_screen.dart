// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;

  /// Semua riwayat dari Supabase
  List<Map<String, dynamic>> _allHistory = [];

  /// Bulan yang sedang dipilih (disimpan sebagai tgl 1)
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Map dateString (yyyy-MM-dd) -> data
  final Map<String, Map<String, dynamic>> _historyByDate = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final data = await AuthService.getFullHistory(); // sudah ada di AuthService

    _allHistory = data;

    _historyByDate.clear();
    for (final row in _allHistory) {
      final String dateStr = (row['date'] ?? '').toString();
      if (dateStr.isEmpty) continue;
      _historyByDate[dateStr] = row;
    }

    if (mounted) setState(() => _loading = false);
  }

  void _changeMonth(int delta) {
    // delta: -1 = bulan sebelumnya, +1 = bulan berikutnya
    final year = _selectedMonth.year;
    final month = _selectedMonth.month + delta;

    final newDate = DateTime(year, month, 1);
    setState(() {
      _selectedMonth = newDate;
    });
  }

  Future<void> _pickMonthYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: 'Pilih Bulan & Tahun',
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  /// Format bulan-tahun dalam Bahasa Indonesia, contoh: "November 2025"
  String _formatMonthYear(DateTime d) {
    final fmt = DateFormat('MMMM yyyy', 'id_ID');
    return fmt.format(d);
  }

  /// Helper: buat key yyyy-MM-dd
  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFE0F2F1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Riwayat Perjalanan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMonthHeader(theme),
                  const SizedBox(height: 12),
                  _buildLegend(theme),
                  const SizedBox(height: 12),
                  _buildCalendar(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthHeader(ThemeData theme) {
    final title = _formatMonthYear(_selectedMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          InkWell(
            onTap: _pickMonthYear,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.calendar_month, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        item(const Color(0xFF00796B), 'Bebas (sukses)'),
        item(Colors.redAccent, 'Relapse'),
        item(Colors.grey, 'Tidak ada data'),
      ],
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;

    final firstDay = DateTime(year, month, 1);
    final nextMonth = DateTime(year, month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    final daysInMonth = lastDay.day;

    // weekday: 1=Mon ... 7=Sun
    final int startWeekday = firstDay.weekday;
    final totalCells = daysInMonth + (startWeekday - 1);
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header hari
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _DayHeader('S'),
              _DayHeader('S'),
              _DayHeader('R'),
              _DayHeader('K'),
              _DayHeader('J'),
              _DayHeader('S'),
              _DayHeader('M'),
            ],
          ),
          const SizedBox(height: 8),
          // Grid tanggal
          Column(
            children: List.generate(rows, (row) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (col) {
                  final cellIndex = row * 7 + col; // 0-based
                  final dayNumber = cellIndex - (startWeekday - 2);

                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const _EmptyDayCell();
                  }

                  final date = DateTime(year, month, dayNumber);
                  final key = _dateKey(date);
                  final data = _historyByDate[key];

                  String status = 'neutral';
                  String detail = '';

                  if (data != null) {
                    status = (data['status'] ?? 'neutral') as String;
                    detail = (data['detail'] ?? '').toString();
                  }

                  Color circleColor;
                  switch (status) {
                    case 'relapse':
                      circleColor = Colors.redAccent;
                      break;
                    case 'success':
                      circleColor = const Color(0xFF00796B);
                      break;
                    default:
                      circleColor = Colors.grey.withOpacity(0.4);
                  }

                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return _DayCell(
                    day: dayNumber,
                    color: circleColor,
                    isToday: isToday,
                    detail: detail,
                    status: status,
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _EmptyDayCell extends StatelessWidget {
  const _EmptyDayCell();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 36,
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final Color color;
  final bool isToday;
  final String detail;
  final String status;

  const _DayCell({
    super.key,
    required this.day,
    required this.color,
    required this.isToday,
    required this.detail,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final border = isToday
        ? Border.all(color: Colors.black.withOpacity(0.4), width: 1.5)
        : null;

    return GestureDetector(
      onTap: () {
        if (detail.isNotEmpty && status != 'neutral') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(detail),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '$day',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}