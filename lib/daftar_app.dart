// Pintasan aplikasi di layar utama. Server punya daftar yang sama (aplikasi.ts) untuk perintah suara.
class AppPintasan {
  const AppPintasan(this.label, this.paket, this.web, [this.alias = const []]);
  final String label;
  final String paket;
  final String web;
  final List<String> alias;
}

const daftarApp = <AppPintasan>[
  AppPintasan('YouTube', 'com.google.android.youtube', 'https://www.youtube.com/', ['yt', 'you tube']),
  AppPintasan('WhatsApp', 'com.whatsapp', 'https://wa.me/', ['wa', 'whats app']),
  AppPintasan('Maps', 'com.google.android.apps.maps', 'https://www.google.com/maps', ['google maps', 'peta', 'gmaps']),
  AppPintasan('Spotify', 'com.spotify.music', 'https://open.spotify.com/'),
  AppPintasan('Instagram', 'com.instagram.android', 'https://www.instagram.com/', ['ig']),
  AppPintasan('TikTok', 'com.zhiliaoapp.musically', 'https://www.tiktok.com/', ['tik tok']),
  AppPintasan('Gmail', 'com.google.android.gm', 'https://mail.google.com/', ['email', 'surel']),
  AppPintasan('Drive', 'com.google.android.apps.docs', 'https://drive.google.com/', ['google drive']),
  AppPintasan('Chrome', 'com.android.chrome', 'https://www.google.com/', ['browser', 'peramban']),
  AppPintasan('Gojek', 'com.gojek.app', 'https://www.gojek.com/', ['gojeg']),
  AppPintasan('Shopee', 'com.shopee.id', 'https://shopee.co.id/'),
  AppPintasan('Tokopedia', 'com.tokopedia.tkpd', 'https://www.tokopedia.com/', ['tokped']),
  AppPintasan('Facebook', 'com.facebook.katana', 'https://www.facebook.com/', ['fb']),
  AppPintasan('Telegram', 'org.telegram.messenger', 'https://web.telegram.org/'),
  AppPintasan('Grab', 'com.grabtaxi.passenger', 'https://www.grab.com/id/'),
];

/// Mencari aplikasi dari nama yang diucapkan (label atau alias). null jika tidak dikenal.
AppPintasan? cariAppLokal(String ucapan) {
  final k = ucapan.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (k.isEmpty) return null;
  for (final a in daftarApp) {
    if (a.label.toLowerCase() == k || a.alias.contains(k)) return a;
  }
  return null;
}
