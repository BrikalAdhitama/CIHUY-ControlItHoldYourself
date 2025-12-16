// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'education_screen.dart';
import 'login_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _quitDate;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  int _selectedIndex = 0;

  String? _displayName;
  String? _email;
  String? _avatarUrl;
  bool _profileLoading = true;

  final TextEditingController _rokokController = TextEditingController();
  final TextEditingController _vapeController = TextEditingController();

  List<Map<String, dynamic>> _history7Days = [];

  String _motivationText =
      '"Berhenti merokok bukanlah pengorbanan; itu adalah pembebasan."';

  static const _kLocalQuitDateKey = 'local_quit_date';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        _initAll();
      });
    });
  }

  Future<void> _initAll() async {
    await _loadQuitDate();
    await _loadHistoryAndProgress();
    await _loadMotivationQuote();
    await _loadProfile();
    _startTimer();
  }

  // Parse server timestamp safely when server returns String
  DateTime? _parseServerTimestampAsUtcThenLocal(String? s) {
    if (s == null) return null;
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;

    final hasTz = RegExp(r'Z$|[+\-]\d{2}:\d{2}$').hasMatch(trimmed);
    try {
      if (hasTz) {
        return DateTime.parse(trimmed).toLocal();
      } else {
        // assume UTC if no timezone info
        return DateTime.parse(trimmed + 'Z').toLocal();
      }
    } catch (_) {
      return DateTime.tryParse(trimmed)?.toLocal();
    }
  }

  // ---------------------
  // SharedPreferences
  // ---------------------
  Future<void> _saveQuitDateLocally(DateTime dtLocal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalQuitDateKey, dtLocal.toIso8601String());
    } catch (_) {}
  }

  Future<DateTime?> _loadLocalQuitDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_kLocalQuitDateKey);
      if (s == null) return null;
      return DateTime.tryParse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeLocalQuitDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocalQuitDateKey);
    } catch (_) {}
  }

  // ---------------------
  // Load quit date (server first, fallback local)
  // ---------------------
  Future<void> _loadQuitDate() async {
    try {
      final serverVal =
          await AuthService.getQuitDate(); // may return DateTime? or String? depending impl
      DateTime? serverLocal;

      if (serverVal is DateTime) {
        serverLocal = serverVal.toLocal();
      } else if (serverVal is String) {
        serverLocal = _parseServerTimestampAsUtcThenLocal(serverVal);
      } else {
        serverLocal = null;
      }

      final localParsed = await _loadLocalQuitDate();

      DateTime? finalQuitLocal;

      if (serverLocal != null) {
        finalQuitLocal = serverLocal;
        await _saveQuitDateLocally(finalQuitLocal);
      } else if (localParsed != null) {
        finalQuitLocal = localParsed;
      } else {
        finalQuitLocal = null;
      }

      if (!mounted) return;

      if (finalQuitLocal != null) {
        final nowLocal = DateTime.now();
        final diff = nowLocal.difference(finalQuitLocal);
        setState(() {
          _quitDate = finalQuitLocal;
          _elapsed = diff.isNegative ? Duration.zero : diff;
        });
      } else {
        setState(() {
          _quitDate = null;
          _elapsed = Duration.zero;
        });
      }
    } catch (_) {}
  }

  // ---------------------
  // Timer
  // ---------------------
  void _startTimer() {
    _timer?.cancel();

    if (_quitDate == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _quitDate == null) return;
      final nowLocal = DateTime.now();
      final diff = nowLocal.difference(_quitDate!);
      setState(() {
        _elapsed = diff.isNegative ? Duration.zero : diff;
      });
    });
  }

  void _resetLocalTimerToNow() async {
    final now = DateTime.now();
    await _saveQuitDateLocally(now);
    setState(() {
      _quitDate = now;
      _elapsed = Duration.zero;
    });
    _startTimer();
  }

  // ==========================
  // ESTIMATED CIGARETTES AVOIDED
  // ==========================
  // 1 batang per 1 jam
  int get _estimatedCigsAvoided {
    return _elapsed.inHours;
  }

  Future<void> _loadHistoryAndProgress() async {
    try {
      final history = await AuthService.get7DayHistory();
      if (!mounted) return;
      setState(() {
        _history7Days = history.map<Map<String, dynamic>>((h) {
          return {
            'day': h['day'],
            'date': h['date'],
            'status': h['status'],
            'detail': h['detail'],
          };
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadMotivationQuote() async {
    try {
      final quote = await AuthService.getRandomQuote();
      if (!mounted) return;
      setState(() {
        _motivationText = quote;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _motivationText =
            '"Berhenti merokok bukanlah pengorbanan; itu adalah pembebasan."';
      });
    }
  }


  Future<void> _loadProfile() async {
    try {
      final data = await AuthService.getCurrentProfile();

      String? displayName = widget.username;
      String? email;
      String? avatarUrl;

      if (data != null) {
        final username = data['username'] as String?;
        final dName = data['display_name'] as String?;

        // prioritas: display_name -> username -> yang dikirim dari login
        displayName = dName ?? username ?? widget.username;
        email = data['email'] as String?;
        avatarUrl = data['avatar_url'] as String?;
      }

      if (!mounted) return;
      setState(() {
        _displayName = displayName ?? widget.username;
        _email = email;
        _avatarUrl = avatarUrl;
        _profileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileLoading = false;
      });
    }
  }

  // ---------------------
  // NAV BAWAH
  // ---------------------
  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        setState(() => _selectedIndex = 0);
        break;
      case 1:
        setState(() => _selectedIndex = 1);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        ).then((_) {
          if (mounted) setState(() => _selectedIndex = 0);
        });
        break;
      case 2:
        setState(() => _selectedIndex = 2);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EducationScreen()),
        ).then((_) {
          if (mounted) setState(() => _selectedIndex = 0);
        });
        break;
    }
  }

  // ---------------------
  // Helpers date
  // ---------------------
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKeyFromDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _normalizeDateKey(String isoDate) {
    try {
      if (isoDate.isEmpty) return '';
      // isoDate bisa datang sebagai "2025-11-26" atau "2025-11-26T12:34:56Z"
      final dateOnly = isoDate.split('T')[0];
      // basic validation: must match yyyy-mm-dd
      final parts = dateOnly.split('-');
      if (parts.length == 3) {
        final y = parts[0].padLeft(4, '0');
        final m = parts[1].padLeft(2, '0');
        final d = parts[2].padLeft(2, '0');
        return '$y-$m-$d';
      }
      return dateOnly;
    } catch (e) {
      return isoDate;
    }
  }

  // ---------------------
  // Relapse dialogs
  // ---------------------
  void _showRelapseTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apa yang Anda konsumsi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.smoke_free, color: Colors.orange),
              title: const Text('Rokok'),
              onTap: () {
                Navigator.pop(context);
                _showRelapseAmountDialog(isRokok: true, isVape: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vaping_rooms, color: Colors.blue),
              title: const Text('Vape'),
              onTap: () {
                Navigator.pop(context);
                _showRelapseAmountDialog(isRokok: false, isVape: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: const Text('Keduanya'),
              onTap: () {
                Navigator.pop(context);
                _showRelapseAmountDialog(isRokok: true, isVape: true);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
        ],
      ),
    );
  }

  void _showRelapseAmountDialog(
        {required bool isRokok, required bool isVape}) {
      _rokokController.clear();
      _vapeController.clear();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Berapa banyak?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRokok)
                TextField(
                  controller: _rokokController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Jumlah Batang Rokok',
                      icon: Icon(Icons.smoke_free)),
                ),
              if (isVape)
                TextField(
                  controller: _vapeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Jumlah Hisapan Vape',
                      icon: Icon(Icons.vaping_rooms)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                // [UPDATE DI SINI] Kirim status mode ke fungsi process
                _processRelapse(reqRokok: isRokok, reqVape: isVape);
              },
              child: const Text('Reset Timer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

// [PERBAIKAN] Tambahkan parameter reqRokok dan reqVape
  Future<void> _processRelapse({required bool reqRokok, required bool reqVape}) async {
    final rokokText = _rokokController.text.trim();
    final vapeText = _vapeController.text.trim();

    // Default ke 0 jika kosong/error, biar mudah divalidasi
    int rokokCount = int.tryParse(rokokText) ?? 0;
    int vapeCount = int.tryParse(vapeText) ?? 0;

    // ================= VALIDASI KETAT (INI YANG BARU) =================

    // 1. Validasi Mode "KEDUANYA" (Wajib Dua-duanya > 0)
    if (reqRokok && reqVape) {
      if (rokokCount <= 0 || vapeCount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih "Keduanya" wajib isi jumlah Rokok DAN Vape (min 1).'),
            backgroundColor: Colors.red,
          ),
        );
        return; // ⛔ STOP DI SINI
      }
    } 
    // 2. Validasi Mode "ROKOK SAJA"
    else if (reqRokok) {
      if (rokokCount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah rokok minimal 1 batang.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // ⛔ STOP
      }
      vapeCount = 0; // Pastikan vape 0 (bersih-bersih data)
    } 
    // 3. Validasi Mode "VAPE SAJA"
    else if (reqVape) {
      if (vapeCount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jumlah hisapan vape minimal 1.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // ⛔ STOP
      }
      rokokCount = 0; // Pastikan rokok 0 (bersih-bersih data)
    }

    // ================= CALL API =================
    // (Kode ke bawah sama persis, cuma copy paste aja biar lengkap)

    final dynamic res = await AuthService.resetTimer(
      widget.username,
      rokok: rokokCount,
      vape: vapeCount,
    );

    bool success = false;
    String? errMsg;
    String? serverQuitIso;
    String? serverQuitLocalIso;

    if (res is bool) {
      success = res;
    } else if (res is Map<String, dynamic>) {
      success = res['success'] == true;
      if (res['message'] is String) errMsg = res['message'] as String;
      if (res['quit_date'] is String) {
        serverQuitIso = res['quit_date'] as String;
      }
      if (res['quit_date_local'] is String) {
        serverQuitLocalIso = res['quit_date_local'] as String;
      }
    }

    if (!mounted) return;

    // ================= SUCCESS =================
    if (success) {
      _rokokController.clear();
      _vapeController.clear();

      DateTime newQuitLocal;
      if (serverQuitLocalIso != null) {
        newQuitLocal =
            DateTime.tryParse(serverQuitLocalIso)?.toLocal() ?? DateTime.now();
      } else if (serverQuitIso != null) {
        final parsed = _parseServerTimestampAsUtcThenLocal(serverQuitIso);
        newQuitLocal = parsed ?? DateTime.now();
      } else {
        newQuitLocal = DateTime.now();
      }

      await _saveQuitDateLocally(newQuitLocal);

      setState(() {
        _quitDate = newQuitLocal;
        _elapsed = Duration.zero;
      });

      _startTimer();
      await _loadHistoryAndProgress();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data tercatat. Jujur itu awal kesembuhan!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } 
    // ================= FAILED =================
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg ?? 'Gagal me-reset timer (cek koneksi)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------
  // Logout
  // ---------------------
  void _logout() async {
    _timer?.cancel();
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false);
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yakin ingin logout?'),
        content: const Text(
            'Lu bakal keluar dari akun dan balik ke halaman login.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (result == true) _logout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadQuitDate().then((_) => _startTimer());
      _loadHistoryAndProgress();
      _loadProfile(); // <-- biar avatar ke-refresh kalau berubah
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<bool> _onWillPop() async {
    await _confirmLogout();
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _rokokController.dispose();
    _vapeController.dispose();
    super.dispose();
  }

  // ---------------------
  // UI builders
  // ---------------------
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    final scaffoldBg =
        isDarkMode ? const Color(0xFF071012) : const Color(0xFFE0F2F1);
    final drawerHeaderColor =
        isDarkMode ? const Color(0xFF004D40) : const Color(0xFF00796B);
    final panicButtonColor =
        isDarkMode ? const Color(0xFF00796B) : Colors.black87;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: _buildAppBar(isDarkMode, scaffoldBg),
        drawer: _buildDrawer(context, drawerHeaderColor, isDarkMode),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 20.0, vertical: 16.0),
            child: Column(
              children: [
                _buildTimerCard(cardColor, textColor),
                const SizedBox(height: 20),
                _buildProgressCard(cardColor, textColor),
                const SizedBox(height: 20),
                _buildMotivationCard(textColor),
                const SizedBox(height: 20),
                _buildHistoryCard(cardColor, textColor),
                const SizedBox(height: 20),
                _buildEducationCard(cardColor, textColor, isDarkMode),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildPanicButton(panicButtonColor),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: SafeArea(
          top: false,
          child: _buildBottomNavigationBar(
              isDarkMode ? const Color(0xFF121212) : Colors.white,
              isDarkMode),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, Color scaffoldBg) {
    return AppBar(
      backgroundColor: scaffoldBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white70 : Colors.black87),
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu,
              color: isDarkMode ? Colors.white70 : Colors.black87),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20.0),
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(username: widget.username),
                ),
              );
              if (mounted) {
                _loadProfile(); // refresh avatar setelah balik dari profil
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isDarkMode
                  ? Colors.grey.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.3),
              backgroundImage:
                  _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
              child: _avatarUrl == null
                  ? Icon(
                      Icons.person,
                      color: isDarkMode ? Colors.white70 : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(
      BuildContext context, Color headerColor, bool isDarkMode) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: headerColor),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Halo, ${_displayName ?? widget.username}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Semangat terus ya 🔥',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings,
                color: isDarkMode ? Colors.white70 : null),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(username: widget.username),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.help_outline, color: isDarkMode ? Colors.white70 : null),
            title: const Text('Bantuan & Info'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HelpScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context);
              await _confirmLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(Color bgColor, Color txtColor) {
    String two(int n) => n.toString().padLeft(2, '0');

    final hours = two(_elapsed.inHours);
    final minutes = two(_elapsed.inMinutes.remainder(60));
    final seconds = two(_elapsed.inSeconds.remainder(60));

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'Berhenti Sejak',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              color: txtColor,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _timeBox(hours, 'Jam', txtColor),
              _timeBox(minutes, 'Menit', txtColor),
              _timeBox(seconds, 'Detik', txtColor),
            ],
          )
        ],
      ),
    );
  }

  Widget _timeBox(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        )
      ],
    );
  }

  Widget _buildProgressCard(Color bgColor, Color txtColor) {
    final streakDays = _elapsed.inHours ~/ 24;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Streak & Ringkasan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: txtColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressItem(
                Icons.calendar_today,
                '$streakDays',
                'Hari\nBebas',
                txtColor,
              ),
              _buildProgressItem(
                Icons.smoke_free,
                '$_estimatedCigsAvoided',
                'Rokok\nDihindari',
                txtColor,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProgressItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 35, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        )
      ],
    );
  }

  Widget _buildMotivationCard(Color txtColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDarkMode
        ? Colors.grey.withOpacity(0.08)
        : const Color(0xFFE0F2F1);
    final borderColor =
        isDarkMode ? Colors.white12 : const Color(0xFFB2DFDB);
    final titleColor =
        isDarkMode ? const Color(0xFF80CBC4) : const Color(0xFF00796B);

    return InkWell(
      onTap: _loadMotivationQuote,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Motivasi Harian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _motivationText,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: txtColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Color bgColor, Color txtColor) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const monthNames = [
      "Januari",
      "Februari",
      "Maret",
      "April",
      "Mei",
      "Juni",
      "Juli",
      "Agustus",
      "September",
      "Oktober",
      "November",
      "Desember"
    ];

    final currentMonthYear =
        "${monthNames[today.month - 1]} ${today.year}";

    // ===== 7 HARI TERAKHIR (today - 6 s/d today)
    final daysToShow = List.generate(
      7,
      (i) => today.subtract(Duration(days: 6 - i)),
    );

    // ===== MAP HISTORY (yyyy-MM-dd -> data)
    final Map<String, Map<String, dynamic>> historyMap = {
      for (final h in _history7Days)
        _normalizeDateKey((h['date'] ?? '') as String): h,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          // ===== HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat 7 Hari',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: txtColor,
                ),
              ),
              Row(
                children: [
                  Text(
                    currentMonthYear,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: txtColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00796B),
                    ),
                    child: const Text(
                      'Lihat Semua >',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ===== BULATAN 7 HARI
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: daysToShow.map((date) {
              final key = _dateKeyFromDate(date);
              final data = historyMap[key];

              // ===== STATUS PURE DARI DATA
              String status;
              if (data == null) {
                status = 'neutral';
              } else {
                status = (data['status'] as String?) ?? 'neutral';
              }

              Color circleColor;
              switch (status) {
                case 'success':
                  circleColor = const Color(0xFF00796B); // hijau CIHUY
                  break;
                case 'relapse':
                  circleColor = Colors.redAccent;
                  break;
                default:
                  circleColor = Colors.grey.withOpacity(0.25);
              }

              final isToday = _isSameDay(date, today);

              return GestureDetector(
                onTap: () {
                  if (data != null &&
                      (data['detail'] as String?)?.isNotEmpty == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(data['detail']),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 35,
                  height: 35,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    border: isToday
                        ? Border.all(
                            color: Colors.black.withOpacity(0.35),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: (status == 'success' || status == 'relapse')
                          ? Colors.white
                          : txtColor.withOpacity(0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanicButton(Color backgroundColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 70.0),
      child: FloatingActionButton.extended(
        onPressed: _showRelapseTypeDialog,
        label: const Text(
          'Saya Merokok/Vape Lagi',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _buildBottomNavigationBar(
      Color bgColor, bool isDarkMode) {
    return BottomNavigationBar(
      backgroundColor: bgColor,
      currentIndex: _selectedIndex,
      selectedItemColor: const Color(0xFF00796B),
      unselectedItemColor:
          isDarkMode ? Colors.white54 : Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      onTap: _onItemTapped,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_filled, size: 28),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset(
            'assets/chatbot.svg',
            width: 28,
            colorFilter: ColorFilter.mode(
              _selectedIndex == 1
                  ? const Color(0xFF00796B)
                  : (isDarkMode
                      ? Colors.white54
                      : Colors.grey),
              BlendMode.srcIn,
            ),
          ),
          label: 'Chat AI',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_rounded, size: 26),
          label: 'Edukasi',
        ),
      ],
    );
  }

  BoxDecoration _card(Color bg) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
    );
  }

  Widget _buildEducationCard(
        Color bgColor, Color txtColor, bool isDarkMode) {
      const heroAssetPath =
          'assets/edu_hero.svg'; // <-- ganti kalau nama file beda

      final gradient = LinearGradient(
        colors: isDarkMode
            ? const [Color(0xFF1B3C36), Color(0xFF0F2A26)]
            : const [Color(0xFFB2DFDB), Color(0xFFE0F2F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

      final titleColor =
          isDarkMode ? Colors.white : const Color(0xFF004D40);
      final subtitleColor = isDarkMode
          ? Colors.white70
          : const Color(0xFF004D40).withOpacity(0.8);

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EducationScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 16),
            child: Row(
              children: [
                // TEKS KIRI (TIDAK BERUBAH)
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edukasi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bahaya Rokok & Vape',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lihat video & artikel singkat buat bantu kamu berhenti.',
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // ===================================================
                // BAGIAN ILUSTRASI KANAN (YANG DIPERBAIKI)
                // ===================================================
                SizedBox(
                  height: 100,
                  width: 100,
                  // Bungkus dengan ClipRRect untuk membuat sudut tumpul
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // <-- Atur tingkat tumpul di sini
                    child: SvgPicture.asset(
                      heroAssetPath,
                      // Gunakan BoxFit.cover agar gambar mengisi penuh kotak rounded-nya
                      fit: BoxFit.cover, 
                    ),
                  ),
                ),
                // ===================================================
              ],
            ),
          ),
        ),
      );
    }
}