package com.example.jarvis

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.provider.ContactsContract
import android.provider.Settings

/** Kontak yang punya akun WhatsApp, dibaca dari baris data WhatsApp di Kontak Android. */
data class KontakWa(val nama: String, val nomor: String, val idVoip: Long?, val idVideo: Long?, val paket: String)

/** Aksi di HP yang dipakai bersama oleh MainActivity (aplikasi) dan JarvisService (latar belakang). */
object Aksi {
    private const val P = "vnd.android.cursor.item/vnd.com.whatsapp."
    private const val PB = "vnd.android.cursor.item/vnd.com.whatsapp.w4b."
    private val MIME = listOf(P + "profile", P + "voip.call", P + "video.call", PB + "profile", PB + "voip.call", PB + "video.call")

    fun norm(s: String) = s.lowercase().replace(Regex("[^a-z0-9 ]"), " ").replace(Regex("\\s+"), " ").trim()

    /** Semua kontak WhatsApp. Lempar SecurityException jika izin kontak belum diberikan. */
    fun semuaKontakWa(ctx: Context): List<KontakWa> {
        class Isi(var nama: String, var nomor: String = "", var voip: Long? = null, var video: Long? = null, val paket: String)
        val peta = LinkedHashMap<String, Isi>()
        val sel = "${ContactsContract.Data.MIMETYPE} IN (${MIME.joinToString(",") { "?" }})"
        ctx.contentResolver.query(
            ContactsContract.Data.CONTENT_URI,
            arrayOf(ContactsContract.Data._ID, ContactsContract.Data.CONTACT_ID, ContactsContract.Data.MIMETYPE, ContactsContract.Data.DATA1, ContactsContract.Data.DISPLAY_NAME),
            sel, MIME.toTypedArray(), null
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                val kontak = c.getLong(1)
                val mime = c.getString(2) ?: continue
                val data1 = c.getString(3) ?: ""
                val nama = c.getString(4) ?: ""
                val paket = if (mime.contains(".w4b.")) "com.whatsapp.w4b" else "com.whatsapp"
                val it = peta.getOrPut("$kontak|$paket") { Isi(nama, paket = paket) }
                val digit = data1.substringBefore('@').filter { ch -> ch.isDigit() }
                if (digit.length >= 8) it.nomor = digit
                if (mime.endsWith("voip.call")) it.voip = id
                if (mime.endsWith("video.call")) it.video = id
            }
        }
        return peta.values.filter { it.nomor.isNotEmpty() && it.nama.isNotBlank() }.map { KontakWa(it.nama, it.nomor, it.voip, it.video, it.paket) }
    }

    /** Nama persis menang; jika ada beberapa yang mirip, semuanya dikembalikan (maks. 6) agar pengguna memilih. */
    fun cariKontak(ctx: Context, nama: String): List<KontakWa> {
        val q = norm(nama)
        if (q.isEmpty()) return emptyList()
        val kata = q.split(" ")
        val skor = ArrayList<Pair<Int, KontakWa>>()
        for (k in semuaKontakWa(ctx)) {
            val n = norm(k.nama)
            val s = when {
                n == q -> 3
                n.startsWith(q) -> 2
                kata.all { n.contains(it) } -> 1
                else -> 0
            }
            if (s > 0) skor.add(s to k)
        }
        if (skor.isEmpty()) return emptyList()
        val atas = skor.maxOf { it.first }
        return skor.filter { it.first == atas }.map { it.second }.distinctBy { it.nomor }.take(6)
    }

    fun bukaChatWa(ctx: Context, nomor: String, pesan: String?): Boolean {
        val q = if (pesan.isNullOrEmpty()) "" else "&text=" + Uri.encode(pesan)
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$nomor$q")
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            try {
                ctx.startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (_: Exception) {}
        }
        AutomationBridge.batal()
        return false
    }

    fun kirimWa(ctx: Context, nomor: String, pesan: String): Boolean {
        AutomationBridge.tunggu(AutomationBridge.Aksi.KIRIM)
        return bukaChatWa(ctx, nomor, pesan)
    }

    /**
     * Memulai panggilan WhatsApp. Jalur 1: langsung lewat baris data kontak WhatsApp ("langsung").
     * Jalur 2 (cadangan): buka chat lalu tekan ikon telepon lewat aksesibilitas ("chat"). Mengembalikan "langsung", "chat", atau "gagal".
     */
    fun panggilWa(ctx: Context, nomor: String, video: Boolean): String {
        val digit = nomor.filter { it.isDigit() }
        if (digit.length >= 8) {
            try {
                val k = semuaKontakWa(ctx).firstOrNull { it.nomor.endsWith(digit.takeLast(9)) }
                val id = if (video) k?.idVideo else k?.idVoip
                if (k != null && id != null) {
                    val w4b = k.paket == "com.whatsapp.w4b"
                    val mime = (if (w4b) PB else P) + (if (video) "video.call" else "voip.call")
                    AutomationBridge.tunggu(AutomationBridge.Aksi.KONFIRMASI)
                    ctx.startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(Uri.parse("content://com.android.contacts/data/$id"), mime)
                            .setPackage(k.paket)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    return "langsung"
                }
            } catch (_: Exception) {}
        }
        AutomationBridge.tunggu(AutomationBridge.Aksi.TELEPON, video)
        return if (bukaChatWa(ctx, digit, null)) "chat" else "gagal"
    }

    fun bukaApp(ctx: Context, paket: String, web: String): Boolean {
        try {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(web)).setPackage(paket).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return true
        } catch (_: Exception) {}
        return try {
            ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(web)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: Exception) { false }
    }

    /** Membuka layar Info Aplikasi; layanan aksesibilitas menekan "Paksa berhenti". true = otomatis. */
    fun tutupApp(ctx: Context, paket: String): Boolean {
        var p = paket
        if (p == "com.whatsapp") {
            try { ctx.packageManager.getPackageInfo("com.whatsapp", 0) } catch (_: Exception) { p = "com.whatsapp.w4b" }
        }
        val otomatis = JarvisAccessibilityService.aktif
        if (otomatis) AutomationBridge.tunggu(AutomationBridge.Aksi.PAKSA_BERHENTI)
        return try {
            ctx.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$p")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            otomatis
        } catch (_: Exception) { AutomationBridge.batal(); false }
    }

    fun minimize(ctx: Context) {
        if (!JarvisAccessibilityService.kembaliKeBeranda()) {
            ctx.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    fun baterai(ctx: Context): Int {
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }
}
