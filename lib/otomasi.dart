import 'package:flutter/services.dart';
import 'model.dart';

/// Jembatan ke kode Kotlin (MainActivity, JarvisService, JarvisAccessibilityService).
class Otomasi {
  static const _ch = MethodChannel('id.pusakabakery.jarvis/otomasi');

  /// "langsung" (panggilan lewat kontak WhatsApp), "chat" (jalur cadangan lewat chat + aksesibilitas) atau "gagal".
  static String jalurTerakhir = '';

  static Future<bool> _bool(String m) async {
    try {
      return (await _ch.invokeMethod<bool>(m)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> aksesibilitasAktif() => _bool('aksesibilitasAktif');
  static Future<void> bukaPengaturanAksesibilitas() async => _bool('bukaPengaturanAksesibilitas');

  /// Meminta izin mikrofon, kontak, dan notifikasi sekaligus. true jika mikrofon dan kontak diberikan.
  static Future<bool> izinInti() => _bool('izinInti');

  /// Mencari kontak yang punya WhatsApp (baris data WhatsApp di Kontak Android). Kosong jika tidak ada atau izin ditolak.
  static Future<List<KontakHp>> cariKontakWa(String nama) async {
    try {
      final r = await _ch.invokeMethod<List>('cariKontakWa', {'nama': nama});
      return (r ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return KontakHp(m['nama'] as String, m['nomor'] as String);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Membuka chat WhatsApp berisi teks lalu menekan Kirim otomatis (jika aksesibilitas aktif).
  static Future<bool> kirimWa(String nomor, String pesan, {String? nama}) async {
    try {
      return (await _ch.invokeMethod<bool>('kirimWa', {'nomor': nomor, 'pesan': pesan})) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Memulai panggilan suara atau video WhatsApp. Jalur yang dipakai ada di [jalurTerakhir].
  static Future<bool> teleponWa(String nomor, {bool video = false, String? nama}) async {
    try {
      jalurTerakhir = (await _ch.invokeMethod<String>('teleponWa', {'nomor': nomor, 'video': video})) ?? 'gagal';
    } catch (_) {
      jalurTerakhir = 'gagal';
    }
    return jalurTerakhir != 'gagal';
  }

  static Future<Map<String, dynamic>> statusHp() async {
    try {
      return Map<String, dynamic>.from(await _ch.invokeMethod<Map>('statusHp') ?? {});
    } catch (_) {
      return {};
    }
  }

  /// true = dijalankan otomatis (Paksa berhenti), false = pengguna harus menekan sendiri.
  static Future<bool> tutupApp(String paket) async {
    try {
      return (await _ch.invokeMethod<bool>('tutupApp', {'paket': paket})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> minimize() async => _bool('minimize');

  // ---- Jarvis di latar belakang
  static Future<bool> izinOverlay() => _bool('izinOverlay');
  static Future<void> bukaIzinOverlay() async => _bool('bukaIzinOverlay');

  /// Menyalakan/mematikan tombol melayang dan pendengar latar belakang. Mengembalikan "ok" atau pesan galat.
  static Future<String> aturLatar({required bool bubble, required bool dengar}) async {
    try {
      return (await _ch.invokeMethod<String>('aturLatar', {'bubble': bubble, 'dengar': dengar})) ?? 'Tidak ada jawaban dari sistem';
    } catch (e) {
      return '$e';
    }
  }

  /// {bubble, dengar, jalan, galat, jalur}
  static Future<Map<String, dynamic>> statusLatar() async {
    try {
      return Map<String, dynamic>.from(await _ch.invokeMethod<Map>('statusLatar') ?? {});
    } catch (_) {
      return {};
    }
  }
}
