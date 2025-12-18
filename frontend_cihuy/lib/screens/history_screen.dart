// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Pastikan import ini ada

import '../services/auth_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;

  /// Map tanggal (date-only) -> data record
  Map<DateTime, Map<String, dynamic>> _historyByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  /// tanggal dimulainya tracking (berdasarkan tgl daftar akun)
  DateTime? _minTrackedDate;

  /// relapse terakhir yang tercatat di DB
  DateTime? _lastRelapseDate;

  @override
  void initState() {
    super.initState();
    _loadFullHistory();
  }

  /// Normalisasi supaya jamnya 00:00
  DateTime _normalizeDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Convert "YYYY-MM-DD" -> DateTime local (00:00)
  DateTime? _parseDateOnly(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      final year = int.tryParse(parts[0]) ?? 1970;
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFullHistory() async {
    setState(() => _loading = true);

    // 1. Ambil history dari Database
    final raw = await AuthService.getFullHistory();

    final temp = <DateTime, Map<String, dynamic>>{};
    DateTime? minDateFromDb;
    DateTime? lastRelapse;

    for (final row in raw) {
      final dateStr = (row['date'] ?? '').toString();
      final d = _parseDateOnly(dateStr);
      if (d == null) continue;

      final key = _normalizeDate(d);

      // Simpan data DB ke map sementara
      temp[key] = {
        'date': dateStr,
        'status': row['status'],
        'detail': row['detail'],
      };

      // Cari tanggal paling tua yang ada di DB
      if (minDateFromDb == null || key.isBefore(minDateFromDb)) {
        minDateFromDb = key;
      }

      // Cari tanggal relapse terakhir
      final status = row['status']?.toString() ?? '';
      if (status == 'relapse') {
        if (lastRelapse == null || key.isAfter(lastRelapse)) {
          lastRelapse = key;
        }
      }
    }

    final today = _normalizeDate(DateTime.now());

    // 2. Tentukan START DATE Tracking
    //    Logic: Mulai tracking dari "Tanggal Pembuatan Akun"
    DateTime startCursor = today;

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.createdAt.isNotEmpty) {
      try {
        final created = DateTime.parse(user.createdAt).toLocal();
        startCursor = _normalizeDate(created);
      } catch (_) {
        // Fallback ke hari ini kalau gagal parse
        startCursor = today;
      }
    }

    // Tapi, kalau ternyata di DB ada data yang LEBIH TUA dari tanggal pembuatan akun
    // (misal karena input manual mundur tanggal), kita pakai tanggal dari DB.
    if (minDateFromDb != null && minDateFromDb.isBefore(startCursor)) {
      startCursor = minDateFromDb;
    }

    // 3. Loop dari StartDate s/d Hari Ini
    final fullMap = <DateTime, Map<String, dynamic>>{};
    DateTime cursor = startCursor;

    // Safety: jangan biarkan loop kalau cursor di masa depan
    if (cursor.isAfter(today)) cursor = today;

    while (!cursor.isAfter(today)) {
      final key = _normalizeDate(cursor);

      if (temp.containsKey(key)) {
        // Ada data di DB (Relapse / Manual Success) -> Pakai data DB
        fullMap[key] = temp[key]!;
      } else {
        // Tidak ada data di DB -> Otomatis dianggap SUKSES
        // (Asumsinya kalau user sudah punya akun tapi gak lapor relapse, berarti dia aman)
        fullMap[key] = {
          'date': DateFormat('yyyy-MM-dd').format(cursor),
          'status': 'success',
          'detail': '',
        };
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    setState(() {
      _historyByDate = fullMap;
      _minTrackedDate = startCursor;
      _lastRelapseDate = lastRelapse;
      _focusedDay = today;
      _selectedDay = today;
      _loading = false;
    });
  }

  /// Helper penentuan status untuk UI Kalender
  String _statusForDay(DateTime day) {
    final d = _normalizeDate(day);
    final today = _normalizeDate(DateTime.now());

    // Masa depan -> Abu-abu
    if (d.isAfter(today)) return 'neutral';

    final data = _historyByDate[d];
    
    // Kalau tidak ada di map (berarti sebelum tanggal daftar akun) -> Abu-abu
    if (data == null) return 'neutral';

    final rawStatus = data['status']?.toString() ?? '';
    if (rawStatus == 'relapse') return 'relapse';
    if (rawStatus == 'success') return 'success';

    return 'neutral';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Perjalanan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                _buildLegendRow(isDark),
                
                // ====== KALENDER ======
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: TableCalendar<Map<String, dynamic>>(
                    locale: 'id_ID',
                    firstDay: DateTime(2020),
                    lastDay: DateTime(2100),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _normalizeDate(day) == _normalizeDate(_selectedDay),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Bulan',
                    },
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextFormatter: (date, locale) {
                        final fmt = DateFormat.yMMMM('id_ID');
                        return fmt.format(date);
                      },
                      leftChevronIcon: const Icon(Icons.chevron_left),
                      rightChevronIcon: const Icon(Icons.chevron_right),
                    ),
                    calendarStyle: const CalendarStyle(
                      markerDecoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final status = _statusForDay(day);
                        final colors = _colorsForStatus(status, isDark);
                        return _buildDayCircle(
                          day.day,
                          bgColor: colors.bg,
                          textColor: colors.text,
                        );
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        final status = _statusForDay(day);
                        final colors = _colorsForStatus(status, isDark)
                            .copyWith(bgOverride: Colors.grey.withOpacity(0.15));
                        return _buildDayCircle(
                          day.day,
                          bgColor: colors.bg,
                          textColor: colors.text,
                        );
                      },
                      todayBuilder: (context, day, focusedDay) {
                        final status = _statusForDay(day);
                        final colors = _colorsForStatus(status, isDark);
                        return _buildDayCircle(
                          day.day,
                          bgColor: colors.bg,
                          textColor: colors.text,
                          borderColor: const Color(0xFF00796B),
                        );
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final status = _statusForDay(day);
                        final colors = _colorsForStatus(status, isDark);
                        return _buildDayCircle(
                          day.day,
                          bgColor: colors.bg,
                          textColor: colors.text,
                          borderColor: isDark ? Colors.white : Colors.black87,
                        );
                      },
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = _normalizeDate(selectedDay);
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // ====== DETAIL UNTUK TANGGAL YANG DIKLIK ======
                Expanded(
                  child: _buildSelectedDayDetailCard(isDark),
                ),
              ],
            ),
    );
  }

  /// Warna untuk status
  _StatusColors _colorsForStatus(String status, bool isDark) {
    switch (status) {
      case 'relapse':
        return _StatusColors(
          bg: Colors.redAccent,
          text: Colors.white,
        );
      case 'success':
        return _StatusColors(
          bg: const Color(0xFF00796B),
          text: Colors.white,
        );
      default:
        // Status Neutral (sebelum tracking / masa depan)
        return _StatusColors(
          bg: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          text: isDark ? Colors.white70 : Colors.black87,
        );
    }
  }

  Widget _buildLegendRow(bool isDark) {
    final textColor = isDark ? Colors.white70 : Colors.black87;

    Widget item(Color color, String label) => Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          item(const Color(0xFF00796B), 'Bebas (sukses)'),
          item(Colors.redAccent, 'Relapse'),
          item(Colors.grey, 'Tidak ada data'),
        ],
      ),
    );
  }

  Widget _buildDayCircle(
    int day, {
    Color? bgColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayDetailCard(bool isDark) {
    final key = _normalizeDate(_selectedDay);
    final data = _historyByDate[key];

    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textMain = isDark ? Colors.white : Colors.black87;
    final textSub = Colors.grey;

    final dateLabel = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(key);

    final uiStatus = _statusForDay(key);

    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    String detail;

    if (uiStatus == 'relapse') {
      statusLabel = 'Relapse';
      statusColor = Colors.redAccent;
      statusIcon = Icons.warning_amber_rounded;
      detail = data?['detail']?.toString() ?? 'Hari ini terjadi relapse.';
    } else if (uiStatus == 'success') {
      statusLabel = 'Bebas (sukses)';
      statusColor = const Color(0xFF00796B);
      statusIcon = Icons.check_circle_rounded;
      detail = data?['detail']?.toString() ??
          'Hari bebas dari rokok/vape, tidak ada relapse yang tercatat.';
    } else {
      statusLabel = 'Tidak ada catatan';
      statusColor = Colors.grey;
      statusIcon = Icons.radio_button_unchecked;
      detail =
          'Hari ini (atau tanggal ini) belum ada riwayat karena belum tracking.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textMain,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: TextStyle(
                fontSize: 14,
                color: textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusColors {
  final Color bg;
  final Color text;

  _StatusColors({required this.bg, required this.text});

  _StatusColors copyWith({Color? bgOverride, Color? textOverride}) {
    return _StatusColors(
      bg: bgOverride ?? bg,
      text: textOverride ?? text,
    );
  }
}