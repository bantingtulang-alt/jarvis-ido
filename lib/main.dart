import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'layar_chat.dart';
import 'layar_masuk.dart';
import 'reaktor.dart';
import 'tema.dart';

// Versi diagnostik: bingkai pertama digambar SEGERA (sebelum memuat apa pun) dan setiap tahap dicatat ke logcat dengan awalan "JARVIS:".
void _catat(String s) => print('JARVIS: $s');

/// Galat ditampilkan di layar (bukan layar kosong), supaya bisa difoto dan dilaporkan.
Widget _kotakGalat(String pesan) => Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF2A0A12),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Jarvis mengalami galat:\n\n$pesan',
              style: const TextStyle(color: Color(0xFFFFC2C9), fontSize: 13, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    _catat('main mulai');
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      _catat('FlutterError: ${d.exceptionAsString()}');
    };
    ErrorWidget.builder = (d) => _kotakGalat(d.exceptionAsString());
    runApp(const _Pemuat());
    _catat('runApp dipanggil');
  }, (e, st) {
    _catat('galat tak tertangani: $e\n$st');
  });
}

/// Layar pertama: latar BIRU TERANG dan tulisan besar. Jika layar HP tetap hitam polos, berarti Flutter tidak bisa menggambar di HP ini (masalah grafis), bukan masalah kode.
class _Pemuat extends StatefulWidget {
  const _Pemuat();
  @override
  State<_Pemuat> createState() => _PemuatState();
}

class _PemuatState extends State<_Pemuat> {
  ApiKlien? _api;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      _catat('memuat penyimpanan');
      final api = await ApiKlien.buka().timeout(const Duration(seconds: 10));
      _catat('penyimpanan siap, token ada: ${api.token != null}');
      if (mounted) setState(() => _api = api);
    } on TimeoutException {
      _catat('penyimpanan tidak merespons');
      if (mounted) setState(() => _galat = 'Penyimpanan tidak merespons dalam 10 detik.');
    } catch (e, st) {
      _catat('penyimpanan gagal: $e\n$st');
      if (mounted) setState(() => _galat = 'Gagal memuat penyimpanan:\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = _api;
    if (api != null) return JarvisApp(api: api);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF1E5AA8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _galat ?? 'MEMULAI JARVIS…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}

class JarvisApp extends StatefulWidget {
  const JarvisApp({super.key, required this.api});
  final ApiKlien api;
  @override
  State<JarvisApp> createState() => _JarvisAppState();
}

class _JarvisAppState extends State<JarvisApp> {
  bool? _masuk;

  @override
  void initState() {
    super.initState();
    _periksa();
  }

  Future<void> _periksa() async {
    if (widget.api.token == null) {
      _catat('tidak ada token -> layar masuk');
      setState(() => _masuk = false);
      return;
    }
    _catat('memeriksa sesi ke server');
    // Tidak ada koneksi atau server lambat: tetap masuk, chat akan menampilkan pesan jaringan
    final ok = await widget.api.sesiAktif().timeout(const Duration(seconds: 10), onTimeout: () => null);
    _catat('hasil sesi: $ok');
    if (mounted) setState(() => _masuk = ok ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final m = _masuk;
    return MaterialApp(
      title: 'Jarvis',
      debugShowCheckedModeBanner: false,
      theme: buatTema(),
      home: m == null
          ? const Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Reaktor(mode: ModeJarvis.mikir, ukuran: 120),
                  SizedBox(height: 12),
                  Text('MENGHUBUNGKAN…', style: TextStyle(color: W.glow, letterSpacing: 3)),
                ]),
              ),
            )
          : m
              ? LayarChat(api: widget.api, onKeluar: () => setState(() => _masuk = false))
              : LayarMasuk(api: widget.api, onMasuk: () => setState(() => _masuk = true)),
    );
  }
}
