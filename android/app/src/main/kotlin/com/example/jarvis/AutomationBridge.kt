package com.example.jarvis

/** Tugas yang ditunggu layanan aksesibilitas. Kedaluwarsa 15 detik agar tidak menekan tombol secara tak sengaja. */
object AutomationBridge {
    enum class Aksi { KIRIM, TELEPON, KONFIRMASI, PAKSA_BERHENTI }

    @Volatile var aksi: Aksi? = null
    @Volatile var video = false
    @Volatile var pemicuDengar = false // dipertahankan agar kompatibel
    @Volatile var appTampil = false    // layar aplikasi Jarvis sedang terbuka: layanan latar belakang melepas mikrofon
    @Volatile private var dibuat = 0L

    fun tunggu(a: Aksi, v: Boolean = false) { aksi = a; video = v; dibuat = System.currentTimeMillis() }
    fun batal() { aksi = null }
    fun aktifMenunggu(): Aksi? {
        val a = aksi ?: return null
        if (System.currentTimeMillis() - dibuat > 15_000) { aksi = null; return null }
        return a
    }
}
