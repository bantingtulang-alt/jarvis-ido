// Parser perintah lokal (diport dari JarvisCommandParser.kt, diperluas).
// Perintah sederhana dijalankan langsung di HP tanpa server: cepat dan jalan saat offline.
// Selain itu (pencarian, berita, tanya jawab, dokumen) diteruskan ke server.

enum Niat { siaga, bangun, teleponWa, videoWa, kirimWa, mulaiWa, bukaApp, tutupApp, minimize, waktu, status, sapa, server }

class Perintah {
  const Perintah(this.niat, {this.nama = '', this.pesan = '', this.asli = ''});
  final Niat niat;
  final String nama; // nama kontak / nama aplikasi
  final String pesan; // isi pesan WA
  final String asli;
}

class PenguraiPerintah {
  static final _wake = RegExp(r'^\s*(?:hey\s+jarvis|hai\s+jarvis|halo\s+jarvis|ok\s+jarvis|jarvis)\b[,\s]*');
  static final _sopan = RegExp(r'^(?:tolong|coba|bisa|minta\s+tolong)\b[,\s]*');

  static bool adaKataPanggil(String s) => s.toLowerCase().contains('jarvis');

  static Perintah urai(String mentah) {
    final asli = mentah.trim();
    final lower = asli.toLowerCase();
    final panggil = adaKataPanggil(lower);
    var t = lower.replaceFirst(_wake, '').replaceAll(RegExp(r'\bjarvis\b[,\s]*'), '').trim();
    t = t.replaceFirst(_sopan, '').trim();

    // Siaga / bangun
    if (RegExp(r'\b(?:jarvis\s+(?:stop|diam|istirahat|tidur|jeda|pause|berhenti)|(?:stop|diam|istirahat|tidur|jeda|berhenti)\s+jarvis)\b')
            .hasMatch(lower) ||
        (panggil && const {'stop', 'diam', 'istirahat', 'tidur', 'jeda'}.contains(t))) {
      return Perintah(Niat.siaga, asli: asli);
    }
    if (RegExp(r'\b(?:jarvis\s+(?:mulai|aktif|bangun|hidup|lanjut)|(?:mulai|aktifkan|bangun|hidupkan)\s+jarvis)\b').hasMatch(lower)) {
      return Perintah(Niat.bangun, asli: asli);
    }

    // Waktu: dibaca dari jam HP (real time)
    if (RegExp(r'\b(jam berapa|pukul berapa|tanggal berapa|hari apa|bulan apa|tahun berapa|tanggal hari ini|waktu sekarang|hari ini tanggal|sekarang jam|sekarang tanggal|sekarang hari)\b')
        .hasMatch(t)) {
      return Perintah(Niat.waktu, asli: t);
    }

    // Telepon / video WhatsApp (tidak ada telepon biasa)
    final tel = RegExp(r'^(video\s+call|vc|telpon|telepon|menelepon|menelpon|panggil|hubungi|call)\s+(?:wa\s+|whatsapp\s+)?(?:ke\s+)?(.+)$').firstMatch(t);
    if (tel != null) {
      final nama = _bersihNama(tel.group(2)!);
      if (nama.isNotEmpty) {
        final video = tel.group(1)!.startsWith('v');
        return Perintah(video ? Niat.videoWa : Niat.teleponWa, nama: nama, asli: asli);
      }
    }

    // Kirim WA dengan isi: "kirim wa ke budi pesan saya otw" / "kirim wa ke budi: saya otw"
    final denganIsi = RegExp(
            r'^(?:kirim\s+(?:pesan\s+)?(?:wa|whatsapp)|wa|kirim\s+pesan|chat\s+wa)\s+(?:ke\s+)?([a-z0-9 _]+?)\s*(?::|\s(?:pesan|isi|bilang|teks)\s)\s*(.+)$')
        .firstMatch(t);
    if (denganIsi != null) {
      final nama = _bersihNama(denganIsi.group(1)!);
      final isi = denganIsi.group(2)!.trim();
      if (nama.isNotEmpty && isi.isNotEmpty) return Perintah(Niat.kirimWa, nama: nama, pesan: isi, asli: asli);
    }
    // Kirim WA tanpa isi -> Jarvis bertanya "Apa pesannya?" lalu langsung mendengar
    final tanpaIsi = RegExp(r'^(?:kirim\s+(?:pesan\s+)?(?:wa|whatsapp)|kirim\s+pesan|chat\s+wa)\s+(?:ke\s+)?([a-z0-9 _]+)$').firstMatch(t);
    if (tanpaIsi != null) {
      final nama = _bersihNama(tanpaIsi.group(1)!);
      if (nama.isNotEmpty) return Perintah(Niat.mulaiWa, nama: nama, asli: asli);
    }

    // Minimize: "minimize", "kecilkan youtube", "sembunyikan aplikasi"
    if (RegExp(r'^(?:minimize|minimalkan|kecilkan|sembunyikan)\b').hasMatch(t)) return Perintah(Niat.minimize, asli: asli);

    // Tutup aplikasi: "tutup WA", "matikan youtube", "paksa berhenti spotify"
    final tutup = RegExp(r'^(?:tutup|matikan|hentikan|paksa\s+(?:tutup|berhenti)|keluar\s+dari)\s+(?:aplikasi\s+)?(.+)$').firstMatch(t);
    if (tutup != null) return Perintah(Niat.tutupApp, nama: tutup.group(1)!.trim(), asli: asli);

    // Status HP
    if (RegExp(r'\b(baterai|battery|status\s+(?:hp|sistem))\b').hasMatch(t)) return Perintah(Niat.status, asli: asli);

    // Sapaan
    if (panggil && (t.isEmpty || t == 'halo' || t == 'hai' || t == 'siapa kamu')) return Perintah(Niat.sapa, asli: asli);

    // "buka youtube" langsung dibuka. "buka youtube cari lagu ..." diserahkan ke server (pencarian di dalam aplikasi).
    final buka = RegExp(r'^(?:buka(?:\s+aplikasi)?|jalankan(?:\s+aplikasi)?|open|launch)\s+(.+)$').firstMatch(t);
    if (buka != null && !buka.group(1)!.contains(RegExp(r'\b(cari|carikan|putar)\b'))) {
      return Perintah(Niat.bukaApp, nama: buka.group(1)!.trim(), asli: asli);
    }

    // Pencarian web, berita, tanya jawab, dokumen: server (punya tool cari_web)
    return Perintah(Niat.server, asli: asli);
  }

  static String _bersihNama(String s) => s
      .replaceAll(RegExp(r'\b(lewat|pakai|melalui|di|via|dengan)\s*(wa|whatsapp)\b.*'), '')
      .replaceAll(RegExp(r'\b(wa|whatsapp|ke|dong|sekarang)\b'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Kalimat waktu dari jam HP, mis. "Sekarang hari Rabu, 21 Oktober 2026, pukul 14.35 WIB."
String kalimatWaktu(String tanya, DateTime d) {
  const hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const bulan = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  final off = d.timeZoneOffset.inHours;
  final zona = off == 7 ? ' WIB' : off == 8 ? ' WITA' : off == 9 ? ' WIT' : '';
  final jam = '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}$zona';
  final tgl = '${d.day} ${bulan[d.month - 1]} ${d.year}';
  final h = hari[d.weekday - 1];
  if (RegExp(r'jam|pukul').hasMatch(tanya)) return 'Sekarang pukul $jam.';
  if (tanya.contains('hari apa')) return 'Hari ini hari $h.';
  if (tanya.contains('tahun')) return 'Sekarang tahun ${d.year}.';
  if (tanya.contains('bulan apa')) return 'Sekarang bulan ${bulan[d.month - 1]}.';
  if (RegExp(r'tanggal').hasMatch(tanya)) return 'Hari ini $h, $tgl.';
  return 'Sekarang hari $h, $tgl, pukul $jam.';
}
