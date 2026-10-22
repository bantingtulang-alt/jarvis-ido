import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'model.dart';
import 'otomasi.dart';

String rapikanNomor(String s) {
  final n = s.replaceAll(RegExp(r'\D'), '');
  return n.startsWith('0') ? '62${n.substring(1)}' : n;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Aksi yang dijalankan di HP: kontak, buka aplikasi, telepon.
class AksiHp {
  static List<Contact>? _cache;
  static DateTime? _waktu;

  // FIX: Menggunakan ContactProperty.phone dan ContactProperty.name (Tunggal / Tanpa 's')
  static Future<List<Contact>> _semuaKontak() async {
    final c = _cache;
    final w = _waktu;
    if (c != null && w != null && DateTime.now().difference(w) < const Duration(minutes: 5)) return c;
    
    // Meminta izin baca (read-only)
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted) {
      throw Exception('Izin membaca kontak ditolak. Aktifkan di Pengaturan > Aplikasi > Jarvis > Izin > Kontak.');
    }
    
    // Mengambil kontak beserta properti spesifik yang dibutuhkan
    final hasil = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.name},
    );
    _cache = hasil;
    _waktu = DateTime.now();
    return hasil;
  }

  /// Mencari kontak di HP. Nama persis menang; jika ada beberapa yang mirip, semuanya dikembalikan (maks. 6) agar pengguna memilih.
  static Future<List<KontakHp>> cariKontak(String nama) async {
    final q = _norm(nama);
    if (q.isEmpty) return [];
    // 1) Kontak yang punya WhatsApp (dari baris data WhatsApp di Kontak Android)
    await Otomasi.izinInti();
    final wa = await Otomasi.cariKontakWa(nama);
    if (wa.isNotEmpty) return wa;
    // 2) Cadangan: buku telepon biasa
    final kata = q.split(' ');
    final hasil = <MapEntry<int, KontakHp>>[];
    for (final c in await _semuaKontak()) {
      // FIX NULL SAFETY: Pastikan displayName tidak null dengan memberikan fallback string kosong
      final namaDisplay = c.displayName ?? '';
      final n = _norm(namaDisplay); 
      
      if (n.isEmpty || c.phones.isEmpty) continue;
      
      var skor = 0;
      if (n == q) {
        skor = 3;
      } else if (n.startsWith(q)) {
        skor = 2;
      } else if (kata.every((k) => n.contains(k))) {
        skor = 1;
      }
      if (skor == 0) continue;
      
      final hp = c.phones.firstWhere(
        (p) => p.label == PhoneLabel.mobile, 
        orElse: () => c.phones.first,
      );
      final nomor = rapikanNomor(hp.number);
      if (nomor.length < 9) continue;
      hasil.add(MapEntry(skor, KontakHp(namaDisplay, nomor)));
    }
    if (hasil.isEmpty) return [];
    hasil.sort((a, b) => b.key.compareTo(a.key));
    final atas = hasil.first.key;
    final terbaik = hasil.where((e) => e.key == atas).map((e) => e.value).toList();
    return terbaik.length > 6 ? terbaik.sublist(0, 6) : terbaik;
  }

  /// Membuka aplikasi lewat tautan https yang ditangani paket tertentu; jika tidak terpasang, dibuka di browser.
  static Future<bool> bukaAplikasi({required String paket, required String web}) async {
    try {
      final intent = AndroidIntent(action: 'action_view', data: web, package: paket);
      if (await intent.canResolveActivity() ?? false) {
        await intent.launch();
        return true;
      }
    } catch (_) {}
    try {
      return await launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> chatWa(String nomor, {String? teks}) {
    final q = (teks == null || teks.isEmpty) ? '' : '?text=${Uri.encodeComponent(teks)}';
    return bukaAplikasi(paket: 'com.whatsapp', web: 'https://wa.me/$nomor$q');
  }
}
