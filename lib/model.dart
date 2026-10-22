class KontakHp {
  KontakHp(this.nama, this.nomor);
  final String nama;
  final String nomor; // sudah dirapikan, mis. 62812...
}

class Pesan {
  Pesan({
    required this.pengirim,
    required this.teks,
    this.berkas,
    this.telp,
    this.app,
    this.wa,
    this.email,
    this.spec,
    this.data,
    this.galat = false,
    this.sambutan = false,
  });

  final String pengirim; // 'user' atau 'jarvis'
  final String teks;
  final Map<String, dynamic>? berkas; // {id, nama, jenis, ringkasan[]}
  Map<String, dynamic>? telp; // {nomor, nama, lokal?}
  List<KontakHp> kandidat = [];
  Future<void> Function(KontakHp)? pilih; // dipanggil saat pengguna memilih salah satu kandidat
  final Map<String, dynamic>? app; // {id, label, paket, web, cari?}
  final Map<String, dynamic>? wa; // {nomor?, pesan?, fileId, fileNama}
  final Map<String, dynamic>? email; // {kepada, subjek, isi, fileId, fileNama}
  final dynamic spec; // dikirim balik ke server agar dokumen bisa direvisi
  final String? data;
  final bool galat;
  final bool sambutan;

  Map<String, dynamic> keServer() => {
        'sender': pengirim,
        'text': teks,
        if (spec != null) 'spec': spec,
        if (data != null) 'data': data,
      };
}
