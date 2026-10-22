import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'aksi.dart';
import 'api.dart';
import 'daftar_app.dart';
import 'model.dart';
import 'otomasi.dart';
import 'perintah.dart';
import 'siaga.dart';
import 'pengaturan.dart';
import 'reaktor.dart';
import 'suara.dart';
import 'tema.dart';

const _saran = ['Kabar teknologi AI hari ini', 'Jam berapa sekarang?', 'Telepon ibu', 'Buka YouTube'];
const _label = {'pptx': 'Presentasi PowerPoint', 'xlsx': 'Spreadsheet Excel', 'docx': 'Dokumen Word'};

Map<String, dynamic>? _peta(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
String _pesanGalat(Object e) => e.toString().replaceFirst('Exception: ', '');

class LayarChat extends StatefulWidget {
  const LayarChat({super.key, required this.api, required this.onKeluar});
  final ApiKlien api;
  final VoidCallback onKeluar;
  @override
  State<LayarChat> createState() => _LayarChatState();
}

class _LayarChatState extends State<LayarChat> {
  final _pesan = <Pesan>[
    Pesan(
      pengirim: 'jarvis',
      sambutan: true,
      teks: 'Halo, saya Jarvis. Saya bisa membuat dokumen, mengirimnya, menyiapkan telepon dan WhatsApp, atau membuka aplikasi. Mau apa hari ini?',
    ),
  ];
  final _input = TextEditingController();
  final _gulir = ScrollController();
  final _suara = Suara();
  bool _sibuk = false;
  bool _mendengar = false;
  String _catatan = '';
  Pesan? _draf;
  late final Siaga _siaga = Siaga(widget.api.prefs);
  KontakHp? _menungguPesanWa; // setelah "kirim WA ke Budi" tanpa isi, ucapan berikutnya = isi pesan

  ModeJarvis get _mode => _mendengar ? ModeJarvis.dengar : (_sibuk ? ModeJarvis.mikir : ModeJarvis.siaga);

  @override
  void initState() {
    super.initState();
    _suara.onBerhenti = () {
      if (mounted) setState(() => _mendengar = false);
    };
    _suara.init(widget.api.prefs).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _gulir.dispose();
    _suara.diam();
    super.dispose();
  }

  void _tambah(Pesan p) {
    if (!mounted) return;
    setState(() => _pesan.add(p));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gulir.hasClients) {
        _gulir.animateTo(_gulir.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _balas(String teks, {bool suara = false, bool galat = false}) {
    _tambah(Pesan(pengirim: 'jarvis', teks: teks, galat: galat));
    if (suara && !galat) _suara.ucap(teks);
  }

  Future<void> _mic() async {
    if (_mendengar) {
      await _suara.berhenti();
      if (mounted) setState(() => _mendengar = false);
      return;
    }
    if (!await _suara.siapMendengar()) {
      setState(() => _catatan = 'Pengenalan suara tidak tersedia. Periksa izin mikrofon dan pastikan layanan suara Google terpasang.');
      return;
    }
    setState(() {
      _mendengar = true;
      _catatan = '';
    });
    await _suara.dengar((teks, akhir) {
      if (!mounted) return;
      setState(() => _input.text = teks);
      if (akhir) {
        setState(() => _mendengar = false);
        _kirim(teks, suara: true);
      }
    });
  }

  Future<void> _pilihKontak() async {
    try {
      final c = await FlutterContacts.native.showPicker(
  properties: {ContactProperty.phone, ContactProperty.name},
);
      if (c == null) return;
      final nomor = c.phones.isEmpty ? '' : rapikanNomor(c.phones.first.number);
      if (nomor.length < 9) {
        setState(() => _catatan = 'Kontak itu tidak punya nomor yang valid.');
        return;
      }
      final p = Pesan(pengirim: 'jarvis', teks: 'Kontak dipilih: ${c.displayName}. Mau telepon atau chat lewat WhatsApp?');
      p.telp = {'nama': c.displayName, 'nomor': nomor};
      _tambah(p);
    } catch (e) {
      setState(() => _catatan = 'Daftar kontak tidak bisa dibuka: ${_pesanGalat(e)}');
    }
  }

  // ---------- Perintah lokal (tanpa server) ----------

  /// Mengembalikan true jika perintah sudah ditangani di HP.
  Future<bool> _jalankanLokal(String teks, {bool suara = false}) async {
    // Menunggu isi pesan WhatsApp ("Apa pesannya?")
    final tujuan = _menungguPesanWa;
    if (tujuan != null) {
      _menungguPesanWa = null;
      if (RegExp(r'^(batal|tidak|jangan)\b', caseSensitive: false).hasMatch(teks)) {
        _balas('Baik, dibatalkan.', suara: suara);
        return true;
      }
      await _kirimWaLokal(tujuan, teks, suara: suara);
      return true;
    }

    final c = PenguraiPerintah.urai(teks);

    if (_siaga.aktif) {
      if (c.niat == Niat.bangun) {
        await _siaga.atur(false);
        if (mounted) setState(() {});
        _balas('Jarvis aktif kembali. Siap menerima perintah.', suara: true);
      }
      return true; // saat siaga, semua perintah lain diabaikan
    }

    switch (c.niat) {
      case Niat.siaga:
        await _siaga.atur(true);
        if (mounted) setState(() {});
        _balas("Jarvis siaga. Katakan 'Jarvis mulai' untuk mengaktifkan kembali.", suara: suara);
        return true;
      case Niat.bangun:
        _balas('Jarvis sudah aktif.', suara: suara);
        return true;
      case Niat.sapa:
        _balas('Halo, saya Jarvis. Ada yang bisa saya bantu?', suara: suara);
        return true;
      case Niat.waktu:
        _balas(kalimatWaktu(c.asli, DateTime.now()), suara: suara);
        return true;
      case Niat.status:
        final st = await Otomasi.statusHp();
        final b = st['baterai'];
        _balas(b == null ? 'Status baterai tidak tersedia.' : 'Baterai HP ada di $b persen.', suara: suara);
        return true;
      case Niat.bukaApp:
        final a = cariAppLokal(c.nama);
        if (a == null) return false; // nama tidak dikenal: biar server yang menjawab
        _balas('Membuka ${a.label}.', suara: suara);
        await AksiHp.bukaAplikasi(paket: a.paket, web: a.web);
        return true;
      case Niat.minimize:
        _balas('Baik.', suara: suara);
        await _suara.diam();
        await Otomasi.minimize();
        return true;
      case Niat.tutupApp:
        final a = cariAppLokal(c.nama);
        if (a == null) return false;
        final otomatis = await Otomasi.tutupApp(a.paket);
        _balas(
          otomatis
              ? 'Menutup ${a.label}.'
              : 'Layanan aksesibilitas belum aktif, jadi saya hanya bisa membuka layar info ${a.label}. Tekan Paksa berhenti sendiri, atau aktifkan Jarvis Otomasi di Pengaturan > Aksesibilitas.',
          suara: suara,
          galat: !otomatis,
        );
        return true;
      case Niat.teleponWa:
      case Niat.videoWa:
        await _denganKontak(c.nama, (k) => _teleponWa(k, video: c.niat == Niat.videoWa, suara: suara), suara: suara);
        return true;
      case Niat.kirimWa:
        await _denganKontak(c.nama, (k) => _kirimWaLokal(k, c.pesan, suara: suara), suara: suara);
        return true;
      case Niat.mulaiWa:
        await _denganKontak(c.nama, (k) => _tanyaPesanWa(k), suara: suara);
        return true;
      case Niat.server:
        return false;
    }
  }

  /// Mencari kontak di HP. Satu hasil -> langsung [lanjut]; beberapa -> tampilkan pilihan; nol -> beri tahu.
  Future<void> _denganKontak(String nama, Future<void> Function(KontakHp) lanjut, {bool suara = false}) async {
    try {
      final k = await AksiHp.cariKontak(nama);
      if (k.isEmpty) {
        _balas('Kontak "$nama" tidak ditemukan di HP. Sebutkan nama persis seperti di kontak, atau tekan tombol Kontak.', galat: true);
        return;
      }
      if (k.length > 1) {
        final p = Pesan(pengirim: 'jarvis', teks: 'Ada beberapa kontak "$nama". Pilih salah satu:');
        p.telp = {'nama': nama, 'nomor': ''};
        p.kandidat = k;
        p.pilih = lanjut;
        _tambah(p);
        if (suara) _suara.ucap('Ada beberapa kontak $nama. Silakan pilih di layar.');
        return;
      }
      await lanjut(k.first);
    } catch (e) {
      _balas(_pesanGalat(e), galat: true);
    }
  }

  Future<void> _teleponWa(KontakHp k, {bool video = false, bool suara = false}) async {
    _balas('${video ? 'Video call ke' : 'Menelepon'} ${k.nama} lewat WhatsApp.', suara: suara);
    final ok = await Otomasi.teleponWa(k.nomor, video: video, nama: k.nama);
    if (!ok) _balas('WhatsApp tidak terpasang atau tidak bisa dibuka.', galat: true);
    await _ingatkanAksesibilitas();
    if (ok && Otomasi.jalurTerakhir == 'chat' && mounted) {
      setState(() => _catatan = 'Kontak ini belum punya baris panggilan WhatsApp di Kontak Android, jadi panggilan lewat chat (cadangan). Pastikan Jarvis Otomasi aktif di Aksesibilitas.');
    }
  }

  /// Tahap 1 pesan dua tahap: tanya isi pesan, lalu langsung mendengar jawabannya.
  Future<void> _tanyaPesanWa(KontakHp k) async {
    _menungguPesanWa = k;
    _tambah(Pesan(pengirim: 'jarvis', teks: 'Apa pesan untuk ${k.nama}?'));
    await _suara.ucap('Apa pesannya?'); // menunggu selesai bicara agar mikrofon tidak merekam suara Jarvis
    if (mounted && _menungguPesanWa != null && !_mendengar) await _mic();
  }

  /// Tahap 2: konfirmasi lisan, buka chat, lalu tekan Kirim otomatis.
  Future<void> _kirimWaLokal(KontakHp k, String isi, {bool suara = false}) async {
    _balas('Baik, mengirim pesan ke ${k.nama}: $isi', suara: suara);
    final ok = await Otomasi.kirimWa(k.nomor, isi, nama: k.nama);
    if (!ok) _balas('WhatsApp tidak terpasang atau tidak bisa dibuka.', galat: true);
    await _ingatkanAksesibilitas();
  }

  Future<void> _ingatkanAksesibilitas() async {
    if (await Otomasi.aksesibilitasAktif()) return;
    if (!mounted) return;
    setState(() => _catatan = 'Layanan aksesibilitas Jarvis belum aktif, jadi tombol Kirim/Telepon harus ditekan sendiri. Aktifkan di Pengaturan > Aksesibilitas > Jarvis Otomasi.');
  }

  Future<void> _kirim(String teks, {bool suara = false}) async {
    teks = teks.trim();
    if (teks.isEmpty || _sibuk) return;

    final draf = _draf;
    if (draf != null) {
      final ya = RegExp(r'^(ya|iya|ok|oke|kirim|setuju|lanjut)\b', caseSensitive: false).hasMatch(teks);
      final tidak = RegExp(r'^(tidak|batal|jangan)\b', caseSensitive: false).hasMatch(teks);
      if (ya || tidak) {
        _tambah(Pesan(pengirim: 'user', teks: teks));
        _input.clear();
        if (ya) {
          await _kirimEmail(draf, suara: suara);
        } else {
          setState(() => _draf = null);
          _balas('Baik, email dibatalkan.', suara: suara);
        }
        return;
      }
    }

    // Saat siaga, ucapan yang bukan "Jarvis mulai" tidak ditampilkan sama sekali
    if (!(_siaga.aktif && suara)) _tambah(Pesan(pengirim: 'user', teks: teks));
    _input.clear();
    if (await _jalankanLokal(teks, suara: suara)) return;
    setState(() {
      _sibuk = true;
      _catatan = '';
    });
    try {
      final riwayat = _pesan.where((m) => !m.sambutan && !m.galat).map((m) => m.keServer()).toList();
      String? fileId;
      for (final m in _pesan.reversed) {
        if (m.berkas != null) {
          fileId = m.berkas!['id'] as String?;
          break;
        }
      }
      final d = await widget.api.chat(riwayat, fileId: fileId);
      final p = Pesan(
        pengirim: 'jarvis',
        teks: (d['reply'] ?? '').toString(),
        berkas: _peta(d['file']),
        telp: _peta(d['telp']),
        app: _peta(d['app']),
        wa: _peta(d['wa']),
        email: _peta(d['email']),
        spec: d['spec'],
        data: d['data'] as String?,
      );
      _tambah(p);
      if (p.email != null) _draf = p;
      if (suara) _suara.ucap(p.teks);
      if (p.app != null) {
        // Aplikasi dibuka otomatis; kartunya tetap ada untuk membuka lagi
        AksiHp.bukaAplikasi(paket: p.app!['paket'] as String, web: p.app!['web'] as String);
      }
      final t = p.telp;
      if (t != null) {
        final nama = (t['nama'] ?? '').toString();
        final nomor = (t['nomor'] ?? '').toString();
        if (t['lokal'] == true || nomor.isEmpty) {
          p.telp = null; // kartu tidak perlu; panggilan langsung dari pencarian kontak HP
          await _denganKontak(nama, (k) => _teleponWa(k, suara: false), suara: suara);
        } else {
          await Otomasi.teleponWa(rapikanNomor(nomor), nama: nama);
        }
      }
    } on SesiHabis {
      widget.onKeluar();
      return;
    } catch (e) {
      _balas('Maaf, terjadi masalah: ${_pesanGalat(e)}', galat: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _kirimEmail(Pesan p, {bool suara = false}) async {
    final d = p.email!;
    setState(() {
      _draf = null;
      _sibuk = true;
    });
    try {
      await widget.api.kirimEmail(d);
      _balas('Email terkirim ke ${d['kepada']}.', suara: suara);
    } on SesiHabis {
      widget.onKeluar();
      return;
    } catch (e) {
      _balas('Email gagal dikirim: ${_pesanGalat(e)}', galat: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _unduh(Map<String, dynamic> b) async {
    try {
      final bytes = await widget.api.unduh(b['id'] as String);
      final dir = await getTemporaryDirectory();
      final nama = (b['nama'] as String).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final f = File('${dir.path}/$nama');
      await f.writeAsBytes(bytes);
      final r = await OpenFilex.open(f.path);
      if (r.type != ResultType.done && mounted) {
        setState(() => _catatan = 'Tidak bisa membuka $nama. Pasang aplikasi pembuka (WPS Office, Google Docs, dll). ${r.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _catatan = _pesanGalat(e));
    }
  }

  void _kirimWa({String? nomor, String? pesan, required String fileId, required String fileNama}) {
    final isi = (pesan == null || pesan.isEmpty) ? 'Halo, berikut dokumen "$fileNama".' : pesan;
    final link = '${widget.api.server}/api/files/$fileId';
    AksiHp.bukaAplikasi(
      paket: 'com.whatsapp',
      web: 'https://wa.me/${rapikanNomor(nomor ?? '')}?text=${Uri.encodeComponent('$isi\n\nUnduh dokumen: $link')}',
    );
  }

  // ---------- Tampilan ----------

  Widget _gelembung(Pesan m) {
    final user = m.pengirim == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: user ? W.glow.withAlpha(40) : W.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: m.galat ? W.buruk : (user ? W.glow : W.garis)),
          ),
          child: Text(m.teks, style: TextStyle(fontSize: 16, color: m.galat ? const Color(0xFFFFC2C9) : W.teks)),
        ),
      ),
    );
  }

  Widget _kartu(Pesan m) {
    final w = <Widget>[];
    final b = m.berkas;
    if (b != null) {
      final ringkasan = (b['ringkasan'] as List?)?.map((e) => e.toString()).toList() ?? [];
      w.add(Panel(
        terang: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b['nama'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(_label[b['jenis']] ?? '', style: const TextStyle(color: W.redup)),
          const SizedBox(height: 6),
          for (var i = 0; i < ringkasan.length; i++) Text('${i + 1}. ${ringkasan[i]}', style: const TextStyle(color: W.redup, fontSize: 14)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TombolIsi('Buka file', () => _unduh(b)),
            TombolIsi('Kirim lewat WhatsApp', () => _kirimWa(fileId: b['id'].toString(), fileNama: b['nama'].toString()), garis: true),
          ]),
        ]),
      ));
    }
    final e = m.email;
    if (e != null) {
      w.add(Panel(
        terang: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Draf email', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Kepada: ${e['kepada']}', style: const TextStyle(color: W.redup)),
          Text('Subjek: ${e['subjek']}', style: const TextStyle(color: W.redup)),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
            child: Text(e['isi'].toString(), style: const TextStyle(fontSize: 14)),
          ),
          Text('Lampiran: ${e['fileNama']}', style: const TextStyle(color: W.redup)),
          const SizedBox(height: 8),
          if (identical(_draf, m))
            Wrap(spacing: 8, children: [
              TombolIsi('Kirim email', () => _kirimEmail(m)),
              TombolIsi('Batal', () => setState(() => _draf = null), garis: true),
            ])
          else
            const Text('Sudah diproses', style: TextStyle(color: W.redup)),
        ]),
      ));
    }
    final wa = m.wa;
    if (wa != null) {
      w.add(Panel(
        terang: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
          Text((wa['nomor'] ?? '').toString().isEmpty ? 'Pilih kontak di WhatsApp' : 'Ke ${wa['nomor']}', style: const TextStyle(color: W.redup)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text((wa['pesan'] ?? '').toString())),
          TombolIsi('Buka WhatsApp', () => _kirimWa(nomor: wa['nomor']?.toString(), pesan: wa['pesan']?.toString(), fileId: wa['fileId'].toString(), fileNama: wa['fileNama'].toString())),
        ]),
      ));
    }
    final t = m.telp;
    if (t != null) {
      final nomor = (t['nomor'] ?? '').toString();
      if (nomor.isEmpty && m.kandidat.isNotEmpty) {
        w.add(Panel(
          terang: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pilih kontak', style: TextStyle(fontWeight: FontWeight.w700)),
            for (final k in m.kandidat)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(k.nama),
                subtitle: Text('+${k.nomor}', style: const TextStyle(color: W.redup)),
                onTap: () {
                  final lanjut = m.pilih;
                  setState(() {
                    m.telp = {'nama': k.nama, 'nomor': k.nomor};
                    m.kandidat = [];
                    m.pilih = null;
                  });
                  if (lanjut != null) lanjut(k);
                },
              ),
          ]),
        ));
      } else if (nomor.isNotEmpty) {
        w.add(Panel(
          terang: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((t['nama'] ?? '+$nomor').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('+$nomor', style: const TextStyle(color: W.redup)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              TombolIsi('Telepon WA', () => Otomasi.teleponWa(nomor, nama: (t['nama'] ?? nomor).toString())),
              TombolIsi('Chat WA', () => AksiHp.chatWa(nomor), garis: true),
            ]),
          ]),
        ));
      }
    }
    final a = m.app;
    if (a != null) {
      w.add(Panel(
        terang: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['label'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          if ((a['cari'] ?? '').toString().isNotEmpty) Text('Cari: ${a['cari']}', style: const TextStyle(color: W.redup)),
          const SizedBox(height: 8),
          TombolIsi('Buka ${a['label']}', () => AksiHp.bukaAplikasi(paket: a['paket'].toString(), web: a['web'].toString())),
        ]),
      ));
    }
    return Column(children: [for (final x in w) Padding(padding: const EdgeInsets.only(top: 8), child: x)]);
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_mode) { ModeJarvis.siaga => 'MENUNGGU PERINTAH…', ModeJarvis.dengar => 'MENDENGARKAN…', ModeJarvis.mikir => 'LAGI MIKIR…' };
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -0.6), radius: 1.2, colors: [Color(0xFF0A2640), Color(0xFF04101E), Color(0xFF02060D)])),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(children: [
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('JARVIS', style: TextStyle(fontSize: 24, letterSpacing: 7, fontWeight: FontWeight.w800, shadows: [Shadow(color: W.glow, blurRadius: 14)])),
                    Text('ASISTEN DOKUMEN & PERINTAH', style: TextStyle(color: W.redup, fontSize: 11, letterSpacing: 2)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: W.glow),
                  tooltip: 'Pengaturan',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF06182A),
                    isScrollControlled: true,
                    builder: (_) => Pengaturan(api: widget.api, suara: _suara, onKeluar: widget.onKeluar),
                  ),
                ),
              ]),
            ),
            Reaktor(mode: _mode, ukuran: 110),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(status, style: const TextStyle(color: W.glow, letterSpacing: 3, fontSize: 13, shadows: [Shadow(color: W.glow, blurRadius: 8)])),
            ),
            Expanded(
              child: ListView(
                controller: _gulir,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  for (final m in _pesan) ...[
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: _gelembung(m)),
                    if (m.sambutan && _pesan.length == 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in _saran) ActionChip(label: Text(s), onPressed: () => _kirim(s), side: const BorderSide(color: W.glow), backgroundColor: Colors.transparent, labelStyle: const TextStyle(color: W.glow)),
                        ]),
                      ),
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: _kartu(m)),
                  ],
                  if (_sibuk) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Lagi mikir…', style: TextStyle(color: W.glow))),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final a in daftarApp)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                      child: OutlinedButton(
                        onPressed: () => AksiHp.bukaAplikasi(paket: a.paket, web: a.web),
                        style: OutlinedButton.styleFrom(foregroundColor: W.glow, side: const BorderSide(color: W.garis), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: Text(a.label),
                      ),
                    ),
                ],
              ),
            ),
            if (_catatan.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), child: Text(_catatan, style: const TextStyle(color: W.peringatan, fontSize: 13))),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(children: [
                IconButton.outlined(
                  onPressed: _mic,
                  tooltip: 'Bicara',
                  style: IconButton.styleFrom(side: BorderSide(color: _mendengar ? W.buruk : W.glow), backgroundColor: _mendengar ? W.buruk : Colors.transparent),
                  icon: Icon(_mendengar ? Icons.stop : Icons.mic, color: _mendengar ? Colors.white : W.glow),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: _pilihKontak,
                  tooltip: 'Pilih kontak',
                  style: IconButton.styleFrom(side: const BorderSide(color: W.glow)),
                  icon: const Icon(Icons.contacts_outlined, color: W.glow),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (t) => _kirim(t),
                    decoration: const InputDecoration(hintText: 'Tulis perintah Anda…'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sibuk ? null : () => _kirim(_input.text),
                  style: IconButton.styleFrom(backgroundColor: W.glow, foregroundColor: const Color(0xFF02101C)),
                  icon: const Icon(Icons.send),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
