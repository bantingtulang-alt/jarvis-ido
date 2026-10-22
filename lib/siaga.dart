import 'package:shared_preferences/shared_preferences.dart';

/// Mode siaga: Jarvis diam sampai mendengar "Jarvis mulai". Diport dari JarvisStandbyController.kt.
class Siaga {
  Siaga(this._prefs) : aktif = _prefs.getBool('siaga') ?? false;
  final SharedPreferences _prefs;
  bool aktif;

  Future<void> atur(bool nilai) async {
    aktif = nilai;
    await _prefs.setBool('siaga', nilai);
  }
}
