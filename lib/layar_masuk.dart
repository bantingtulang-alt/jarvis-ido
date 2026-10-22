import 'package:flutter/material.dart';
import 'api.dart';
import 'reaktor.dart';
import 'tema.dart';

class LayarMasuk extends StatefulWidget {
  const LayarMasuk({super.key, required this.api, required this.onMasuk});
  final ApiKlien api;
  final VoidCallback onMasuk;
  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  late final TextEditingController _server = TextEditingController(text: widget.api.server);
  final _sandi = TextEditingController();
  bool _sibuk = false;
  String _galat = '';

  Future<void> _masuk() async {
    if (_sibuk || _sandi.text.isEmpty) return;
    setState(() {
      _sibuk = true;
      _galat = '';
    });
    try {
      await widget.api.simpanServer(_server.text);
      await widget.api.masuk(_sandi.text);
      widget.onMasuk();
    } catch (e) {
      if (mounted) setState(() => _galat = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  void dispose() {
    _server.dispose();
    _sandi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Reaktor(mode: ModeJarvis.siaga, ukuran: 160),
                  const SizedBox(height: 12),
                  const Text('JARVIS', style: TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w800, shadows: [Shadow(color: W.glow, blurRadius: 14)])),
                  const Text('AUTENTIKASI DIPERLUKAN', style: TextStyle(color: W.redup, fontSize: 12, letterSpacing: 2)),
                  const SizedBox(height: 24),
                  TextField(controller: _server, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Alamat server')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sandi,
                    obscureText: true,
                    onSubmitted: (_) => _masuk(),
                    decoration: const InputDecoration(labelText: 'Sandi'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: TombolIsi(_sibuk ? 'Memeriksa…' : 'Masuk', _sibuk ? null : _masuk)),
                  if (_galat.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_galat, style: const TextStyle(color: W.peringatan), textAlign: TextAlign.center)),
                ]),
              ),
            ),
          ),
        ),
      );
}
