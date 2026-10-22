import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SuaraTts {
  SuaraTts(this.nama, this.locale);
  final String nama;
  final String locale;
}

/// Suara Jarvis (TTS) dan pengenalan ucapan (STT).
class Suara {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  late SharedPreferences _prefs;
  bool _sttSiap = false;
  void Function()? onBerhenti;
  List<SuaraTts> daftar = [];

  bool aktif = true;
  String? namaPilihan;
  double nada = 0.8; // di bawah 1.0 = lebih berat/dalam

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    aktif = prefs.getBool('suara_aktif') ?? true;
    namaPilihan = prefs.getString('suara_nama');
    nada = prefs.getDouble('suara_nada') ?? 0.8;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      final v = await _tts.getVoices;
      if (v is List) {
        daftar = v
            .whereType<Map>()
            .map((e) => SuaraTts(e['name'].toString(), e['locale'].toString()))
            .where((e) => e.locale.toLowerCase().startsWith('id'))
            .toList()
          ..sort((a, b) => a.nama.compareTo(b.nama));
      }
      await terapkan();
    } catch (_) {}
  }

  Future<void> terapkan() async {
    try {
      final n = namaPilihan;
      if (n != null) {
        final s = daftar.where((e) => e.nama == n);
        if (s.isNotEmpty) await _tts.setVoice({'name': s.first.nama, 'locale': s.first.locale});
      }
      await _tts.setPitch(nada);
    } catch (_) {}
  }

  Future<void> simpan() async {
    await _prefs.setBool('suara_aktif', aktif);
    await _prefs.setDouble('suara_nada', nada);
    final n = namaPilihan;
    if (n == null) {
      await _prefs.remove('suara_nama');
    } else {
      await _prefs.setString('suara_nama', n);
    }
  }

  Future<void> ucap(String teks) async {
    if (!aktif || teks.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(teks);
    } catch (_) {}
  }

  Future<void> diam() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<bool> siapMendengar() async {
    if (_sttSiap) return true;
    _sttSiap = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') onBerhenti?.call();
      },
      onError: (_) => onBerhenti?.call(),
    );
    return _sttSiap;
  }

  Future<void> dengar(void Function(String teks, bool akhir) hasil) async {
    await diam();
    await _stt.listen(
      onResult: (r) => hasil(r.recognizedWords, r.finalResult),
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> berhenti() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
