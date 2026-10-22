package com.example.jarvis

import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

enum class Niat { SIAGA, BANGUN, WAKTU, TELEPON, VIDEO, KIRIM, MULAI_WA, MINIMIZE, TUTUP, STATUS, SAPA, BUKA, SERVER }

data class Perintah(val niat: Niat, val nama: String = "", val pesan: String = "", val asli: String = "")

data class AppInfo(val label: String, val paket: String, val web: String, val alias: List<String> = emptyList())

/** Port parser perintah Dart (lib/perintah.dart) agar Jarvis juga paham perintah saat aplikasi tertutup. */
object Parser {
    private val WAKE = Regex("""^\s*(?:hey\s+jarvis|hai\s+jarvis|halo\s+jarvis|ok\s+jarvis|jarvis)\b[,\s]*""")
    private val SOPAN = Regex("""^(?:tolong|coba|bisa|minta\s+tolong)\b[,\s]*""")
    private val SALAH_DENGAR = Regex("""\b(?:jervis|jarpis|jarfis|javis|jarvist|harvis|gervis|jarwis|jarvish)\b""")

    val DAFTAR = listOf(
        AppInfo("YouTube", "com.google.android.youtube", "https://www.youtube.com/", listOf("yt", "you tube")),
        AppInfo("WhatsApp", "com.whatsapp", "https://wa.me/", listOf("wa", "whats app")),
        AppInfo("Maps", "com.google.android.apps.maps", "https://www.google.com/maps", listOf("google maps", "peta", "gmaps")),
        AppInfo("Spotify", "com.spotify.music", "https://open.spotify.com/"),
        AppInfo("Instagram", "com.instagram.android", "https://www.instagram.com/", listOf("ig")),
        AppInfo("TikTok", "com.zhiliaoapp.musically", "https://www.tiktok.com/", listOf("tik tok")),
        AppInfo("Gmail", "com.google.android.gm", "https://mail.google.com/", listOf("email", "surel")),
        AppInfo("Drive", "com.google.android.apps.docs", "https://drive.google.com/", listOf("google drive")),
        AppInfo("Chrome", "com.android.chrome", "https://www.google.com/", listOf("browser", "peramban")),
        AppInfo("Gojek", "com.gojek.app", "https://www.gojek.com/", listOf("gojeg")),
        AppInfo("Shopee", "com.shopee.id", "https://shopee.co.id/"),
        AppInfo("Tokopedia", "com.tokopedia.tkpd", "https://www.tokopedia.com/", listOf("tokped")),
        AppInfo("Facebook", "com.facebook.katana", "https://www.facebook.com/", listOf("fb")),
        AppInfo("Telegram", "org.telegram.messenger", "https://web.telegram.org/"),
        AppInfo("Grab", "com.grabtaxi.passenger", "https://www.grab.com/id/"),
    )

    fun cariApp(ucapan: String): AppInfo? {
        val k = Aksi.norm(ucapan)
        if (k.isEmpty()) return null
        return DAFTAR.firstOrNull { it.label.lowercase() == k || it.alias.contains(k) }
    }

    fun normalisasi(s: String) = s.lowercase(Locale.ROOT).replace(SALAH_DENGAR, "jarvis")

    fun tanpaPanggil(s: String): String {
        val t = s.trim().lowercase(Locale.ROOT).replaceFirst(WAKE, "").replace(Regex("""\bjarvis\b[,\s]*"""), "").trim()
        return if (t.isEmpty()) s.trim() else t
    }

    private fun bersihNama(s: String) = s
        .replace(Regex("""\b(lewat|pakai|melalui|di|via|dengan)\s*(wa|whatsapp)\b.*"""), "")
        .replace(Regex("""\b(wa|whatsapp|ke|dong|sekarang)\b"""), "")
        .replace(Regex("""\s+"""), " ").trim()

    fun urai(mentah: String): Perintah {
        val asli = mentah.trim()
        val lower = asli.lowercase(Locale.ROOT)
        val panggil = lower.contains("jarvis")
        var t = lower.replaceFirst(WAKE, "").replace(Regex("""\bjarvis\b[,\s]*"""), "").trim()
        t = t.replaceFirst(SOPAN, "").trim()

        if (Regex("""\b(?:jarvis\s+(?:stop|diam|istirahat|tidur|jeda|pause|berhenti)|(?:stop|diam|istirahat|tidur|jeda|berhenti)\s+jarvis)\b""").containsMatchIn(lower) ||
            (panggil && t in setOf("stop", "diam", "istirahat", "tidur", "jeda"))) return Perintah(Niat.SIAGA, asli = asli)
        if (Regex("""\b(?:jarvis\s+(?:mulai|aktif|bangun|hidup|lanjut)|(?:mulai|aktifkan|bangun|hidupkan)\s+jarvis)\b""").containsMatchIn(lower)) return Perintah(Niat.BANGUN, asli = asli)

        if (Regex("""\b(jam berapa|pukul berapa|tanggal berapa|hari apa|bulan apa|tahun berapa|tanggal hari ini|waktu sekarang|hari ini tanggal|sekarang jam|sekarang tanggal|sekarang hari)\b""").containsMatchIn(t))
            return Perintah(Niat.WAKTU, asli = t)

        Regex("""^(video\s+call|vc|telpon|telepon|menelepon|menelpon|panggil|hubungi|call)\s+(?:wa\s+|whatsapp\s+)?(?:ke\s+)?(.+)$""").find(t)?.let {
            val nama = bersihNama(it.groupValues[2])
            if (nama.isNotEmpty()) return Perintah(if (it.groupValues[1].startsWith("v")) Niat.VIDEO else Niat.TELEPON, nama = nama, asli = asli)
        }

        Regex("""^(?:kirim\s+(?:pesan\s+)?(?:wa|whatsapp)|wa|kirim\s+pesan|chat\s+wa)\s+(?:ke\s+)?([a-z0-9 _]+?)\s*(?::|\s(?:pesan|isi|bilang|teks)\s)\s*(.+)$""").find(t)?.let {
            val nama = bersihNama(it.groupValues[1]); val isi = it.groupValues[2].trim()
            if (nama.isNotEmpty() && isi.isNotEmpty()) return Perintah(Niat.KIRIM, nama = nama, pesan = isi, asli = asli)
        }
        Regex("""^(?:kirim\s+(?:pesan\s+)?(?:wa|whatsapp)|kirim\s+pesan|chat\s+wa)\s+(?:ke\s+)?([a-z0-9 _]+)$""").find(t)?.let {
            val nama = bersihNama(it.groupValues[1])
            if (nama.isNotEmpty()) return Perintah(Niat.MULAI_WA, nama = nama, asli = asli)
        }

        if (Regex("""^(?:minimize|minimalkan|kecilkan|sembunyikan)\b""").containsMatchIn(t)) return Perintah(Niat.MINIMIZE, asli = asli)
        Regex("""^(?:tutup|matikan|hentikan|paksa\s+(?:tutup|berhenti)|keluar\s+dari)\s+(?:aplikasi\s+)?(.+)$""").find(t)?.let {
            return Perintah(Niat.TUTUP, nama = it.groupValues[1].trim(), asli = asli)
        }
        if (Regex("""\b(baterai|battery|status\s+(?:hp|sistem))\b""").containsMatchIn(t)) return Perintah(Niat.STATUS, asli = asli)
        if (panggil && (t.isEmpty() || t == "halo" || t == "hai" || t == "siapa kamu")) return Perintah(Niat.SAPA, asli = asli)

        Regex("""^(?:buka(?:\s+aplikasi)?|jalankan(?:\s+aplikasi)?|open|launch)\s+(.+)$""").find(t)?.let {
            if (!Regex("""\b(cari|carikan|putar)\b""").containsMatchIn(it.groupValues[1])) return Perintah(Niat.BUKA, nama = it.groupValues[1].trim(), asli = asli)
        }
        return Perintah(Niat.SERVER, asli = asli)
    }

    fun kalimatWaktu(tanya: String): String {
        val hari = listOf("Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu")
        val bulan = listOf("Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember")
        val c = Calendar.getInstance()
        val off = TimeZone.getDefault().getOffset(c.timeInMillis) / 3_600_000
        val zona = when (off) { 7 -> " WIB"; 8 -> " WITA"; 9 -> " WIT"; else -> "" }
        val jam = "%02d.%02d%s".format(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE), zona)
        val tgl = "${c.get(Calendar.DAY_OF_MONTH)} ${bulan[c.get(Calendar.MONTH)]} ${c.get(Calendar.YEAR)}"
        val h = hari[c.get(Calendar.DAY_OF_WEEK) - 1]
        return when {
            Regex("jam|pukul").containsMatchIn(tanya) -> "Sekarang pukul $jam."
            tanya.contains("hari apa") -> "Hari ini hari $h."
            tanya.contains("tahun") -> "Sekarang tahun ${c.get(Calendar.YEAR)}."
            tanya.contains("bulan apa") -> "Sekarang bulan ${bulan[c.get(Calendar.MONTH)]}."
            tanya.contains("tanggal") -> "Hari ini $h, $tgl."
            else -> "Sekarang hari $h, $tgl, pukul $jam."
        }
    }
}
