// lib/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;
  // ==========================
  // Helper: parse server timestamp robustly
  // ==========================
  static DateTime? _parseServerTimestampAsUtcThenLocal(dynamic serverVal) {
    if (serverVal == null) return null;
    try {
      if (serverVal is DateTime) {
        return serverVal.toLocal();
      }
      final s = serverVal.toString().trim();
      if (s.isEmpty) return null;
      final hasTz = RegExp(r'Z$|[+\-]\d{2}:\d{2}$').hasMatch(s);
      if (hasTz) {
        return DateTime.parse(s).toLocal();
      } else {
        return DateTime.parse(s + 'Z').toLocal();
      }
    } catch (_) {
      try {
        return DateTime.tryParse(serverVal.toString())?.toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  // ==========================
  // 1. AUTHENTICATION
  // ==========================

  // --- REGISTER (kirim OTP) ---
  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return {
        'success': true,
        'message': 'Kode OTP telah dikirim ke email Anda.'
      };
    } catch (e) {
      return {'success': false, 'message': 'Gagal: ${e.toString()}'};
    }
  }

  // --- cek username sudah dipakai atau belum ---
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', username.trim())
          .maybeSingle();

      return res == null;
    } catch (_) {
      // kalau error, anggap ga available biar aman
      return false;
    }
  }

  // --- VERIFIKASI OTP REGISTER + BUAT PROFILE (SET quit_date & updated_at AWAL) ---
  static Future<Map<String, dynamic>> verifyOtpAndCreateProfile(
      String email, String token, String username) async {
    try {
      final available = await isUsernameAvailable(username);
      if (!available) {
        return {
          'success': false,
          'message': 'Username sudah dipakai, silakan pilih yang lain.'
        };
      }

      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: email,
      );

      if (response.user != null) {
        final nowUtcIso = DateTime.now().toUtc().toIso8601String();

        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'username': username,
          'email': email,
          'quit_date': nowUtcIso,
          'updated_at': nowUtcIso,
        });

        return {'success': true, 'message': 'Verifikasi Berhasil!'};
      }
      return {'success': false, 'message': 'Kode OTP salah.'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Verifikasi Gagal: ${e.toString()}'
      };
    }
  }

  // --- LOGIN (Email / Username) ---
  static Future<Map<String, dynamic>> login(
      String identifier, String password) async {
    try {
      String emailToLogin = identifier.trim();

      // Kalau yang diinput BUKAN email → anggap username
      if (!identifier.contains('@')) {
        final response = await _supabase
            .from('profiles')
            .select('email')
            .eq('username', identifier.trim())
            .maybeSingle();

        if (response == null || response['email'] == null) {
          return {'success': false, 'message': 'Username tidak ditemukan.'};
        }
        emailToLogin = response['email'];
      }

      final authResponse = await _supabase.auth.signInWithPassword(
        email: emailToLogin,
        password: password,
      );

      if (authResponse.user == null) throw Exception("Login gagal");

      final profileData = await _supabase
          .from('profiles')
          .select('username')
          .eq('id', authResponse.user!.id)
          .single();

      return {
        'success': true,
        'message': 'Login Berhasil',
        'username': profileData['username'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login Gagal. Cek email/username & password.'
      };
    }
  }

  // --- LOGOUT ---
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ==========================
  // 2. PASSWORD RECOVERY
  // ==========================

  static Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> verifyRecoveryOtp(
      String email, String token) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      if (response.user != null) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Kode salah atau kadaluarsa.'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Verifikasi gagal: ${e.toString()}'
      };
    }
  }

  static Future<bool> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==========================
  // 3. TRACKING CIHUY
  // ==========================

  // --- AMBIL TANGGAL BERHENTI (quit_date) ---
  static Future<DateTime?> getQuitDate() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return null;
      }

      final data = await _supabase
          .from('profiles')
          .select('quit_date')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      if (data['quit_date'] == null) {
        final nowUtcIso = DateTime.now().toUtc().toIso8601String();
        await _supabase
            .from('profiles')
            .update({
              'quit_date': nowUtcIso,
              'updated_at': nowUtcIso,
            })
            .eq('id', user.id);
        return DateTime.now();
      }

      final parsedLocal =
          _parseServerTimestampAsUtcThenLocal(data['quit_date']);
      return parsedLocal;
    } catch (_) {
      return null;
    }
  }

  // --- RESET TIMER (KAMBUH) ---
  static Future<Map<String, dynamic>> resetTimer(
    String username, {
    int rokok = 0,
    int vape = 0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'User tidak login (session habis).',
        };
      }

      final userId = user.id;

      final nowLocal = DateTime.now();
      final nowUtcIso = nowLocal.toUtc().toIso8601String();

      final dateString =
          '${nowLocal.year.toString().padLeft(4, '0')}-'
          '${nowLocal.month.toString().padLeft(2, '0')}-'
          '${nowLocal.day.toString().padLeft(2, '0')}';

      final existing = await _supabase
          .from('daily_records')
          .select()
          .eq('user_id', userId)
          .eq('date', dateString)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? inserted;
      Map<String, dynamic>? updated;

      if (existing != null && existing is Map && existing.containsKey('id')) {
        final prevCigs = (existing['cigarette_count'] ?? 0) as int;
        final prevVape = (existing['vape_puff_count'] ?? 0) as int;

        updated = await _supabase
            .from('daily_records')
            .update({
              'status': 'relapse',
              'cigarette_count': prevCigs + rokok,
              'vape_puff_count': prevVape + vape,
              'updated_at': nowUtcIso,
            })
            .eq('id', existing['id'])
            .select()
            .maybeSingle();
      } else {
        inserted = await _supabase
            .from('daily_records')
            .insert({
              'user_id': userId,
              'date': dateString,
              'status': 'relapse',
              'cigarette_count': rokok,
              'vape_puff_count': vape,
              'updated_at': nowUtcIso,
            })
            .select()
            .maybeSingle();
      }

      final profileUpdate = await _supabase
          .from('profiles')
          .update({
            'quit_date': nowUtcIso,
            'updated_at': nowUtcIso,
          })
          .eq('id', userId)
          .select('quit_date')
          .maybeSingle();

      final returnedQuitIso = profileUpdate?['quit_date'] ?? nowUtcIso;

      return {
        'success': true,
        'quit_date': returnedQuitIso,
        'quit_date_local': nowLocal.toIso8601String(),
        'inserted': inserted,
        'updated': updated,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal reset timer: ${e.toString()}',
      };
    }
  }

  // --- AMBIL RIWAYAT 7 HARI (YANG DIPERBAIKI) ---
  static Future<List<Map<String, dynamic>>> get7DayHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Ambil tanggal user join untuk validasi (agar user baru ga langsung hijau semua)
      DateTime? userJoinDate;
      if (user.createdAt.isNotEmpty) {
        try {
          final parsed = DateTime.parse(user.createdAt).toLocal();
          // Kita ambil tanggalnya saja (tanpa jam) biar adil
          userJoinDate = DateTime(parsed.year, parsed.month, parsed.day);
        } catch (_) {}
      }

      final nowLocal = DateTime.now();
      List<Map<String, dynamic>> history = [];

      for (int i = 6; i >= 0; i--) {
        final d = nowLocal.subtract(Duration(days: i));
        // Normalisasi tanggal yang sedang dicek (tanpa jam)
        final currentDateOnly = DateTime(d.year, d.month, d.day);

        final dateString = '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

        final rows = await _supabase
            .from('daily_records')
            .select('status, cigarette_count, vape_puff_count')
            .eq('user_id', user.id)
            .eq('date', dateString);

        String status;
        String detail;

        if (rows != null && rows.isNotEmpty) {
          // --- ADA DATA DI DB (Biasanya Relapse) ---
          bool anyRelapse = false;
          int totalCigs = 0;
          int totalVape = 0;

          for (final r in rows) {
            final s = (r['status'] ?? 'relapse') as String;
            if (s == 'relapse') anyRelapse = true;
            totalCigs += (r['cigarette_count'] ?? 0) as int;
            totalVape += (r['vape_puff_count'] ?? 0) as int;
          }

          status = anyRelapse ? 'relapse' : 'success';

          List<String> parts = [];
          if (totalCigs > 0) parts.add('$totalCigs rokok');
          if (totalVape > 0) parts.add('$totalVape hisapan vape');
          detail = parts.isNotEmpty ? parts.join(', ') : 'Kambuh';
        } else {
          // --- TIDAK ADA DATA DI DB (Harusnya Sukses) ---
          
          // Logika Baru:
          // 1. Jika tanggal ini < tanggal join user -> Netral (belum main app)
          // 2. Jika tanggal ini >= tanggal join user -> Sukses (Hijau)
          
          bool isBeforeJoin = false;
          if (userJoinDate != null) {
            // Jika tanggal yg dicek lebih kecil dari tanggal join
            if (currentDateOnly.isBefore(userJoinDate)) {
              isBeforeJoin = true;
            }
          }

          if (isBeforeJoin) {
            status = 'neutral';
            detail = '';
          } else {
            status = 'success'; // <--- INI KUNCI PERBAIKANNYA
            detail = 'Bebas (sukses)';
          }
        }

        history.add({
          'day': d.day,
          'date': dateString,
          'status': status,
          'detail': detail,
        });
      }

      return history;
    } catch (e) {
      return [];
    }
  }

  // --- AMBIL RIWAYAT FULL (UNTUK HISTORY SCREEN) ---
  static Future<List<Map<String, dynamic>>> getFullHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final res = await _supabase
          .from('daily_records')
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false);

      return res.map<Map<String, dynamic>>((row) {
        int rokok = row['cigarette_count'] ?? 0;
        int vape = row['vape_puff_count'] ?? 0;

        String detail = '';
        if (rokok > 0) detail += "$rokok rokok";
        if (vape > 0) {
          detail += detail.isEmpty
              ? "$vape hisapan vape"
              : ", $vape hisapan vape";
        }

        return {
          'date': row['date'],
          'status': row['status'],
          'detail': detail.isEmpty ? 'Tidak ada data' : detail,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // --- AMBIL PROFIL USER SAAT INI ---
  static Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final data = await _supabase
          .from('profiles')
          .select('display_name, username, email, avatar_url, quit_date')
          .eq('id', user.id)
          .single();

      // convert quit_date to local before returning (if present)
      if (data != null && data['quit_date'] != null) {
        final parsedLocal =
            _parseServerTimestampAsUtcThenLocal(data['quit_date']);
        if (parsedLocal != null) {
          data['quit_date_local'] = parsedLocal.toIso8601String();
        }
      }

      return data;
    } catch (_) {
      return null;
    }
  }

  // --- UPDATE DISPLAY NAME ---
  static Future<bool> updateDisplayName(String displayName) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('profiles')
          .update({
            'display_name': displayName,
            'updated_at': nowUtcIso,
          })
          .eq('id', user.id);

      return true;
    } catch (_) {
      return false;
    }
  }

  // --- UPLOAD AVATAR & SIMPAN URL KE profiles ---
  static Future<Map<String, dynamic>> uploadAvatar(String filePath) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('[uploadAvatar] ERROR: user not logged in');
        return {
          'success': false,
          'message': 'Session kamu habis, silakan login ulang.'
        };
      }

      final file = File(filePath);
      if (!file.existsSync()) {
        print('[uploadAvatar] ERROR: file not found at $filePath');
        return {
          'success': false,
          'message': 'File gambar tidak ditemukan di perangkat.'
        };
      }

      // ambil ekstensi (jpg/png)
      final ext = filePath.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

      final fileName =
          "avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext";

      print(
          '[uploadAvatar] start upload to bucket profile-avatars, name=$fileName');

      final storage = _supabase.storage.from('profile-avatars');

      // upload ke Supabase Storage
      final uploadRes = await storage.upload(
        fileName,
        file,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      print('[uploadAvatar] upload result: $uploadRes');

      // ambil public URL
      final publicUrl = storage.getPublicUrl(fileName);
      print('[uploadAvatar] public url: $publicUrl');

      // update kolom avatar_url di tabel profiles
      final updateRes = await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id)
          .select()
          .maybeSingle();

      print('[uploadAvatar] profile update result: $updateRes');

      return {
        'success': true,
        'url': publicUrl,
      };
    } catch (e, st) {
      print('[uploadAvatar] ERROR: $e');
      print(st);
      return {
        'success': false,
        'message': 'Gagal upload ke server: $e',
      };
    }
  }

  // --- RANDOM QUOTE MOTIVASI ---
  static Future<String> getRandomQuote() async {
    try {
      final data = await _supabase
          .from('motivational_quotes')
          .select('text')
          .order('id', ascending: true);

      if (data.isEmpty) {
        return '"Berhenti merokok bukanlah pengorbanan; itu adalah pembebasan."';
      }

      final rand = Random();
      final picked = data[rand.nextInt(data.length)];
      return picked['text'] as String;
    } catch (_) {
      return '"Berhenti merokok bukanlah pengorbanan; itu adalah pembebasan."';
    }
  }

  static Future<bool> deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final userId = user.id;

      await _supabase
          .from('daily_records')
          .delete()
          .eq('user_id', userId);

      await _supabase
          .from('profiles')
          .delete()
          .eq('id', userId);

      await _supabase.auth.signOut();

      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================
  // 4. CHAT AI CIHUY (GEMINI)
  // ==========================
  static Future<Map<String, dynamic>> chatToCihuy({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final url = Uri.parse('$cihuyBaseUrl/chat');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'HTTP ${res.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}