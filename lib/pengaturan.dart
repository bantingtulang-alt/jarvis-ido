import 'package:flutter/material.dart';
import 'api.dart';
import 'otomasi.dart';
import 'suara.dart';
import 'tema.dart';

class Pengaturan extends StatefulWidget {
  const Pengaturan({super.key, required this.api, required this.suara, required this.onKeluar});
  final ApiKlien api;
  final Suara suara;
  final VoidCallback onKeluar;
  @override
  State<Pengaturan> createState() => _PengaturanState();
}

class _PengaturanState extends State<Pengaturan> with WidgetsBindingObserver {
  Suara get s => widget.suara;
  bool _bubble = false;
  bool _dengar = false;
  bool _jalan = false;
  bool _akses = false;
  String _galat = '';
  String _jalur = '';
  List<bool>? _tunda; // sakelar yang menunggu izin "tampil di atas aplikasi lain"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kembali dari layar izin Android: lanjutkan otomatis
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    final t = _tunda;
    if (t != null && await Otomasi.izinOverlay()) {
      _tunda = null;
      await _terapkan(t[0], t[1]);
    }
    await _muat();
  }

  Future<void> _muat() async {
    final st = await Otomasi.statusLatar();
    final a = await Otomasi.aksesibilitasAktif();
    if (!mounted) return;
    setState(() {
      _bubble = st['bubble'] == true;
      _dengar = st['dengar'] == true;
      _jalan = st['jalan'] == true;
      _jalur = (st['jalur'] ?? '').toString();
      final g = (st['galat'] ?? '').toString();
      if (g.isNotEmpty) _galat = g;
      _akses = a;
    });
  }

  Future<void> _terapkan(bool bubble, bool dengar) async {
    if (bubble || dengar) {
      if (!await Otomasi.izinOverlay()) {
        _tunda = [bubble, dengar];
        setState(() => _galat = 'Aktifkan izin "Tampil di atas aplikasi lain" untuk Jarvis, lalu kembali ke sini. Sakelar akan menyala otomatis.');
        await Otomasi.bukaIzinOverlay();
        return;
      }
      if (dengar && !await Otomasi.izinInti()) {
        setState(() => _galat = 'Izin mikrofon dan kontak ditolak. Aktifkan di Pengaturan HP > Aplikasi > Jarvis > Izin.');
        await _muat();
        return;
      }
    }
    final r = await Otomasi.aturLatar(bubble: bubble, dengar: dengar);
    await Future.delayed(const Duration(milliseconds: 600));
    await _muat();
    if (mounted) setState(() => _galat = r == 'ok' ? (_jalan || (!bubble && !dengar) ? '' : _galat) : r);
  }

  @override
  Widget build(BuildContext context) {
    final nilai = s.daftar.any((e) => e.nama == s.namaPilihan) ? s.namaPilihan : null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const Text('PENGATURAN', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suara Jarvis'),
            value: s.aktif,
            onChanged: (v) async {
              setState(() => s.aktif = v);
              if (!v) await s.diam();
              await s.simpan();
            },
          ),
          const Text('Pilih suara', style: TextStyle(color: W.redup)),
          DropdownButton<String?>(
            isExpanded: true,
            value: nilai,
            dropdownColor: const Color(0xFF06182A),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Bawaan perangkat')),
              for (final v in s.daftar) DropdownMenuItem<String?>(value: v.nama, child: Text(v.nama, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) async {
              setState(() => s.namaPilihan = v);
              await s.terapkan();
              await s.simpan();
            },
          ),
          Text('Nada: ${s.nada.toStringAsFixed(2)} (lebih kecil = lebih berat)', style: const TextStyle(color: W.redup)),
          Slider(
            min: 0.5,
            max: 1.2,
            value: s.nada.clamp(0.5, 1.2),
            onChanged: (v) => setState(() => s.nada = v),
            onChangeEnd: (_) async {
              await s.terapkan();
              await s.simpan();
            },
          ),
          Row(children: [
            TombolIsi('Coba suara', () => s.ucap('Halo, saya Jarvis. Siap membantu Anda.')),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Nama suara Google tidak mencantumkan jenis kelamin. Coba satu per satu varian suara Indonesia sampai terdengar suara pria, lalu atur nada.',
            style: TextStyle(color: W.redup, fontSize: 12),
          ),
          const Divider(height: 28, color: W.garis),
          const Text('OTOMASI', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jarvis di latar belakang'),
            subtitle: const Text('Mendengar kata "Jarvis" terus-menerus, bahkan saat aplikasi ditutup. Contoh: "Jarvis, telepon ibu". Perlu izin mikrofon, kontak, dan tampil di atas aplikasi lain.', style: TextStyle(color: W.redup, fontSize: 12)),
            value: _dengar,
            onChanged: (v) => _terapkan(_bubble, v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tombol melayang'),
            subtitle: const Text('Tombol Arc Reactor yang bisa digeser di atas aplikasi lain. Ketuk lalu ucapkan perintah, tanpa membuka aplikasi.', style: TextStyle(color: W.redup, fontSize: 12)),
            value: _bubble,
            onChanged: (v) => _terapkan(v, _dengar),
          ),
          Text(
            (_bubble || _dengar) ? (_jalan ? 'Layanan berjalan.' : 'Layanan belum berjalan.') : 'Layanan mati.',
            style: TextStyle(color: _jalan ? W.ok : W.redup, fontSize: 12),
          ),
          if (_galat.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(_galat, style: const TextStyle(color: W.peringatan, fontSize: 12))),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Layanan aksesibilitas'),
            subtitle: Text(
              _akses
                  ? 'Aktif. Jarvis bisa menekan Kirim, ikon telepon WhatsApp, dan Paksa berhenti.'
                  : 'Belum aktif. Tanpa ini Anda harus menekan tombol WhatsApp sendiri. Aktifkan "Jarvis Otomasi".',
              style: const TextStyle(color: W.redup, fontSize: 12),
            ),
            trailing: Icon(_akses ? Icons.check_circle : Icons.error_outline, color: _akses ? W.glow : W.buruk),
            onTap: Otomasi.bukaPengaturanAksesibilitas,
          ),
          if (_jalur.isNotEmpty) Text('Panggilan WhatsApp terakhir lewat jalur: $_jalur', style: const TextStyle(color: W.redup, fontSize: 12)),
          const Divider(height: 28, color: W.garis),
          Text('Server: ${widget.api.server}', style: const TextStyle(color: W.redup, fontSize: 13)),
          const SizedBox(height: 8),
          TombolIsi('Keluar', () async {
            await widget.api.keluar();
            if (context.mounted) Navigator.pop(context);
            widget.onKeluar();
          }, garis: true),
        ]),
      ),
    );
  }
}
