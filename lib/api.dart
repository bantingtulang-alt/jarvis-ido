import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SesiHabis implements Exception {}

/// POST yang mengikuti pengalihan 301/302/307/308 (paket http tidak mengikutinya untuk POST).
/// Hanya diikuti jika host tujuan sama (boleh beda "www." atau http -> https), agar token tidak bocor ke situs lain.
Future<http.Response> _post(Uri u, Map<String, String> header, String body, Duration batas) async {
  var tujuan = u;
  for (var i = 0; i < 4; i++) {
    final req = http.Request('POST', tujuan)
      ..followRedirects = false
      ..headers.addAll(header)
      ..body = body;
    final r = await http.Response.fromStream(await req.send().timeout(batas));
    if (![301, 302, 307, 308].contains(r.statusCode)) return r;
    final lok = r.headers['location'];
    if (lok == null) return r;
    final baru = tujuan.resolve(lok);
    String inti(String h) => h.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (inti(baru.host) != inti(u.host)) return r;
    tujuan = baru;
  }
  throw Exception('Server mengalihkan terlalu banyak kali. Periksa alamat server di layar masuk.');
}

Map<String, dynamic> _json(String body) {
  try {
    final d = jsonDecode(body);
    return d is Map<String, dynamic> ? d : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

class ApiKlien {
  ApiKlien._(this.prefs);
  final SharedPreferences prefs;
  static Future<ApiKlien> buka() async => ApiKlien._(await SharedPreferences.getInstance());

  static const serverBawaan = 'https://jarvis.pusakabakery.com';
  String get server => (prefs.getString('server') ?? serverBawaan).replaceAll(RegExp(r'/+$'), '');
  String? get token => prefs.getString('token');
  Future<void> simpanServer(String s) {
    var a = s.trim().replaceAll(RegExp(r'/+$'), '');
    if (a.isNotEmpty && !a.startsWith('http')) a = 'https://$a';
    return prefs.setString('server', a);
  }

  Uri _u(String path) => Uri.parse('$server$path');
  Map<String, String> get _header => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<void> masuk(String sandi) async {
    final r = await _post(_u('/api/login'), {'Content-Type': 'application/json'}, jsonEncode({'sandi': sandi}), const Duration(seconds: 20));
    final j = _json(r.body);
    if (r.statusCode != 200 || j['token'] is! String) {
      throw Exception((j['error'] as String?) ?? 'Gagal masuk (kode ${r.statusCode})');
    }
    await prefs.setString('token', j['token'] as String);
  }

  Future<void> keluar() => prefs.remove('token');

  /// true = sesi sah, false = ditolak server, null = tidak bisa menghubungi server.
  Future<bool?> sesiAktif() async {
    try {
      final r = await http.get(_u('/api/sesi'), headers: _header).timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> chat(List<Map<String, dynamic>> pesan, {String? fileId}) async {
    final r = await _post(_u('/api/chat'), _header,
        jsonEncode({'klien': 'android', if (fileId != null) 'fileId': fileId, 'messages': pesan}), const Duration(seconds: 120));
    if (r.statusCode == 401) {
      await keluar();
      throw SesiHabis();
    }
    final j = _json(r.body);
    if (r.statusCode != 200) throw Exception((j['error'] as String?) ?? 'Server menjawab kode ${r.statusCode}');
    return j;
  }

  Future<void> kirimEmail(Map<String, dynamic> d) async {
    final r = await _post(_u('/api/email'), _header,
        jsonEncode({'kepada': d['kepada'], 'subjek': d['subjek'], 'isi': d['isi'], 'fileId': d['fileId']}), const Duration(seconds: 60));
    if (r.statusCode == 401) {
      await keluar();
      throw SesiHabis();
    }
    if (r.statusCode != 200) throw Exception((_json(r.body)['error'] as String?) ?? 'Gagal mengirim email');
  }

  /// Unduhan tidak butuh login (ID berkas acak dan kedaluwarsa otomatis di server).
  Future<List<int>> unduh(String id) async {
    final r = await http.get(_u('/api/files/$id')).timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) throw Exception('File tidak ditemukan atau sudah kedaluwarsa. Minta Jarvis membuatnya lagi.');
    return r.bodyBytes;
  }

  Future<Map<String, dynamic>?> status() async {
    try {
      final r = await http.get(_u('/api/status'), headers: _header).timeout(const Duration(seconds: 15));
      return r.statusCode == 200 ? _json(r.body) : null;
    } catch (_) {
      return null;
    }
  }
}
