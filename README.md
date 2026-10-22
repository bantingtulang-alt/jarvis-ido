# Jarvis (aplikasi Android, Flutter)

Aplikasi ini adalah "tangan" Jarvis di HP. Otaknya tetap server `jarvis.pusakabakery.com`.

## Isi tahap ini (Tahap 1 dan 2)
- Login sandi ke server (token disimpan di HP), chat, tampilan HUD dengan reaktor "J".
- Suara Jarvis (TTS) dengan pemilih suara dan atur nada; input suara (STT, bahasa Indonesia).
- Buat dokumen: tombol **Buka file** (mengunduh lalu membuka di aplikasi Office), **Kirim lewat WhatsApp** (pesan berisi tautan unduh), draf email.
- Kontak HP: "Telepon Julian" mencari nama di kontak HP; ada tombol **Kontak** untuk memilih manual.
- Buka aplikasi otomatis ("buka YouTube, cari lagu santai") dan pintasan aplikasi di layar.

Belum ada (Tahap 3): menekan ikon telepon WhatsApp otomatis. Sekarang kartu kontak punya tombol **Telepon** (membuka tampilan telepon dengan nomor terisi) dan **WhatsApp** (membuka chat).

## Cara membuatnya di PC
1. Pastikan `flutter doctor` tidak menunjukkan masalah di bagian Android.
2. Buat proyek kosong, lalu salin isi folder ini ke dalamnya:
   ```
   flutter create --org id.pusakabakery --project-name jarvis_app jarvis_app
   ```
   - Ganti `jarvis_app/pubspec.yaml` dengan `pubspec.yaml` dari sini.
   - Hapus folder `jarvis_app/lib` bawaan, lalu salin folder `lib` dari sini.
   - Ganti `jarvis_app/android/app/src/main/AndroidManifest.xml` dengan `android_patch/AndroidManifest.xml`.
   - Hapus `jarvis_app/test/widget_test.dart` (menunjuk ke aplikasi bawaan).
3. Di folder `jarvis_app`: `flutter pub get`, sambungkan HP (mode pengembang + debug USB), lalu `flutter run`.
4. File APK untuk dipasang: `flutter build apk --release`, hasilnya di `build/app/outputs/flutter-apk/app-release.apk`.

## Server
Server harus memakai zip `jarvis-dokumen-hosting.zip` terbaru (login token + mode Android). Alamat server bawaan: `https://jarvis.pusakabakery.com` (bisa diubah di layar masuk).

## Jika build gagal
Kirim teks error lengkap dari terminal. Penyebab umum: versi Gradle/Kotlin untuk plugin, atau `minSdk` yang perlu dinaikkan di `android/app/build.gradle`.
