package com.example.jarvis

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import java.util.Locale

/**
 * Jarvis di latar belakang:
 * - mendengar terus kata panggil "Jarvis" (jika mode dengar aktif), menjalankan perintah, dan menjawab dengan suara;
 * - tombol Arc Reactor melayang: ketuk untuk bicara langsung tanpa membuka aplikasi.
 * Pengaturan disimpan di SharedPreferences "jarvis_native" (bubble, dengar).
 */
@SuppressLint("NewApi")
class JarvisService : Service() {
    companion object {
        @Volatile var jalan = false
        @Volatile var instance: JarvisService? = null
        fun segarkan() { val s = instance ?: return; s.handler.post { s.sinkron() } }
        private const val ID_NOTIF = 7
    }

    private class Pilihan(val kandidat: List<KontakWa>, val perintah: Perintah)

    val handler = Handler(Looper.getMainLooper())
    private val np by lazy { getSharedPreferences("jarvis_native", MODE_PRIVATE) }
    private val fp by lazy { getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE) }

    private var wm: WindowManager? = null
    private var tombol: View? = null
    private var warnaInti = Color.parseColor("#F59E0B")

    private var sr: SpeechRecognizer? = null
    private var mendengar = false
    private var dengarTerus = false
    private var sekali = false        // jalankan pendengar sekali walau dengarTerus mati (ketuk tombol / menunggu jawaban)
    private var langsung = false      // ucapan berikutnya = perintah tanpa kata "Jarvis"
    private var galatBeruntun = 0
    private var tundaSampai = 0L      // jeda mendengar setelah memulai panggilan agar tidak mengganggu mikrofon WhatsApp

    private var tts: TextToSpeech? = null
    private var ttsSiap = false
    private var sedangBicara = false

    private var menungguPesan: KontakWa? = null
    private var menungguPilihan: Pilihan? = null
    private val riwayat = ArrayList<Pair<String, String>>()

    override fun onBind(intent: Intent?): IBinder? = null

    // ---------------------------------------------------------------- siklus hidup

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            np.edit().putBoolean("bubble", false).putBoolean("dengar", false).apply()
            stopSelf()
            return START_NOT_STICKY
        }
        instance = this
        jalan = true
        if (!mulaiForeground()) { stopSelf(); return START_NOT_STICKY }
        siapkanTts()
        sinkron()
        return START_STICKY
    }

    private fun punyaMic() = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun buatNotif(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("jarvis_latar", "Jarvis", NotificationManager.IMPORTANCE_LOW))
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "jarvis_latar") else Notification.Builder(this)
        val stop = PendingIntent.getService(this, 1, Intent(this, JarvisService::class.java).setAction("STOP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val buka = PendingIntent.getActivity(this, 2, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val teks = if (np.getBoolean("dengar", false)) "Mendengar kata \"Jarvis\"" else "Tombol melayang aktif"
        @Suppress("DEPRECATION")
        val notif = b.setContentTitle("Jarvis").setContentText(teks).setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(buka).addAction(0, "Hentikan", stop).setOngoing(true).build()
        return notif
    }

    /** Mencoba tipe mikrofon dulu; jika ditolak sistem, turun ke tipe biasa. false = gagal total (galat dicatat). */
    private fun mulaiForeground(): Boolean {
        val n = buatNotif()
        val mic = punyaMic()
        val percobaan = ArrayList<Int>()
        if (Build.VERSION.SDK_INT >= 34) {
            if (mic) percobaan.add(ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            percobaan.add(ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else if (Build.VERSION.SDK_INT >= 30) {
            if (mic) percobaan.add(ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            percobaan.add(0)
        } else percobaan.add(0)
        var terakhir: Exception? = null
        for (tipe in percobaan) {
            try {
                if (tipe == 0) startForeground(ID_NOTIF, n) else startForeground(ID_NOTIF, n, tipe)
                np.edit().remove("galat").apply()
                return true
            } catch (e: Exception) { terakhir = e }
        }
        np.edit().putString("galat", "${terakhir?.javaClass?.simpleName}: ${terakhir?.message}").apply()
        return false
    }

    fun sinkron() {
        val bubble = np.getBoolean("bubble", false) && Settings.canDrawOverlays(this)
        if (bubble) tampilTombol() else hapusTombol()
        dengarTerus = np.getBoolean("dengar", false)
        if (dengarTerus) {
            if (!AutomationBridge.appTampil) mulaiDengar() else if (!sekali) berhentiDengar()
        } else if (!sekali) berhentiDengar()
        if (!bubble && !dengarTerus) stopSelf()
    }

    override fun onDestroy() {
        jalan = false
        instance = null
        handler.removeCallbacksAndMessages(null)
        berhentiDengar()
        hapusTombol()
        try { tts?.stop(); tts?.shutdown() } catch (_: Exception) {}
        tts = null
        super.onDestroy()
    }

    // ---------------------------------------------------------------- suara keluar (TTS)

    private fun siapkanTts() {
        if (tts != null) return
        tts = TextToSpeech(this) { st ->
            if (st == TextToSpeech.SUCCESS) {
                tts?.language = Locale("id", "ID")
                tts?.setPitch(0.9f)
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) { handler.post { selesaiBicara() } }
                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) { handler.post { selesaiBicara() } }
                })
                ttsSiap = true
            }
        }
    }

    private fun ucap(teks: String) {
        riwayat.add("jarvis" to teks)
        berhentiDengar()
        warna("#35D0FF")
        val t = teks.take(3500)
        if (!ttsSiap) { handler.postDelayed({ selesaiBicara() }, 300); return }
        sedangBicara = true
        val r = tts?.speak(t, TextToSpeech.QUEUE_FLUSH, null, "u${System.nanoTime()}")
        if (r != TextToSpeech.SUCCESS) selesaiBicara()
    }

    private fun selesaiBicara() {
        sedangBicara = false
        warna("#F59E0B")
        if (dengarTerus || sekali) mulaiDengar()
    }

    // ---------------------------------------------------------------- suara masuk (SpeechRecognizer)

    private val intentDengar by lazy {
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
        }
    }

    private val pendengar = object : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onPartialResults(partialResults: Bundle?) {}
        override fun onEvent(eventType: Int, params: Bundle?) {}

        override fun onResults(results: Bundle?) {
            mendengar = false
            warna("#F59E0B")
            val teks = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
            if (teks.isBlank()) { ulangi(250); return }
            galatBeruntun = 0
            terima(teks)
        }

        override fun onError(error: Int) {
            mendengar = false
            warna("#F59E0B")
            when (error) {
                SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                    galatBeruntun = 0
                    if (langsung && !dengarTerus) { langsung = false; sekali = false; return } // menunggu jawaban tapi diam
                    ulangi(250)
                }
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                    sekali = false
                    np.edit().putString("galat", "Izin mikrofon belum diberikan").apply()
                    ucap("Izin mikrofon belum diberikan. Buka aplikasi Jarvis untuk mengaktifkannya.")
                }
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                    try { sr?.destroy() } catch (_: Exception) {}
                    sr = null
                    ulangi(1000)
                }
                else -> {
                    galatBeruntun++
                    ulangi(minOf(400L * galatBeruntun, 5000L))
                }
            }
        }
    }

    private fun ulangi(ms: Long) {
        handler.postDelayed({ if ((dengarTerus || sekali) && !sedangBicara) mulaiDengar() }, ms)
    }

    private fun mulaiDengar(paksa: Boolean = false) {
        if (mendengar || sedangBicara) return
        if (!paksa && AutomationBridge.appTampil) return // layar Jarvis terbuka: mikrofon dipakai aplikasi
        val sisaTunda = tundaSampai - SystemClock.elapsedRealtime()
        if (!paksa && sisaTunda > 0) { handler.postDelayed({ mulaiDengar() }, sisaTunda); return }
        if (!punyaMic()) { np.edit().putString("galat", "Izin mikrofon belum diberikan").apply(); return }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) { np.edit().putString("galat", "Layanan pengenal suara Google tidak tersedia").apply(); return }
        try {
            if (sr == null) sr = SpeechRecognizer.createSpeechRecognizer(this).also { it.setRecognitionListener(pendengar) }
            mendengar = true
            warna("#5DFFB0")
            sr?.startListening(intentDengar)
        } catch (e: Exception) {
            mendengar = false
            np.edit().putString("galat", "Pendengar: ${e.message}").apply()
            try { sr?.destroy() } catch (_: Exception) {}
            sr = null
            ulangi(2000)
        }
    }

    private fun berhentiDengar() {
        mendengar = false
        try { sr?.cancel(); sr?.destroy() } catch (_: Exception) {}
        sr = null
    }

    // ---------------------------------------------------------------- memproses ucapan

    private fun terima(mentah: String) {
        val teks = Parser.normalisasi(mentah)

        menungguPilihan?.let { p ->
            menungguPilihan = null; sekali = false
            val q = Aksi.norm(teks)
            val urut = listOf("satu pertama" to 0, "dua kedua" to 1, "tiga ketiga" to 2)
            val dipilih = p.kandidat.firstOrNull { k -> val n = Aksi.norm(k.nama); n.isNotEmpty() && (q.contains(n) || n.split(" ").all { q.contains(it) }) }
                ?: urut.firstOrNull { (kata, _) -> kata.split(" ").any { q.split(" ").contains(it) } }?.let { p.kandidat.getOrNull(it.second) }
            if (dipilih == null) ucap("Tidak ada yang cocok, dibatalkan.") else eksekusi(p.perintah, dipilih)
            return
        }
        menungguPesan?.let { k ->
            menungguPesan = null; sekali = false; langsung = false
            if (Regex("""^(batal|tidak|jangan)\b""").containsMatchIn(teks)) ucap("Baik, dibatalkan.")
            else { riwayat.add("user" to teks); eksekusi(Perintah(Niat.KIRIM, nama = k.nama, pesan = mentah.trim()), k) }
            return
        }

        if (!langsung && !teks.contains("jarvis")) { ulangi(150); return } // bukan untuk Jarvis
        langsung = false; sekali = false
        val c = Parser.urai(teks)

        if (fp.getBoolean("flutter.siaga", false)) {
            if (c.niat == Niat.BANGUN) { fp.edit().putBoolean("flutter.siaga", false).apply(); ucap("Jarvis aktif kembali. Siap menerima perintah.") }
            else ulangi(150)
            return
        }
        riwayat.add("user" to Parser.tanpaPanggil(teks))
        jalankan(c)
    }

    private fun jalankan(c: Perintah) {
        when (c.niat) {
            Niat.SIAGA -> { fp.edit().putBoolean("flutter.siaga", true).apply(); ucap("Jarvis siaga. Katakan Jarvis mulai untuk mengaktifkan kembali.") }
            Niat.BANGUN -> ucap("Jarvis sudah aktif.")
            Niat.SAPA -> { langsung = true; sekali = true; ucap("Halo, saya Jarvis. Ada yang bisa saya bantu?") }
            Niat.WAKTU -> ucap(Parser.kalimatWaktu(c.asli))
            Niat.STATUS -> ucap("Baterai HP ada di ${Aksi.baterai(this)} persen.")
            Niat.BUKA -> {
                val a = Parser.cariApp(c.nama) ?: return kePeladen(c.asli)
                ucap("Membuka ${a.label}.")
                Aksi.bukaApp(this, a.paket, a.web)
            }
            Niat.MINIMIZE -> { ucap("Baik."); Aksi.minimize(this) }
            Niat.TUTUP -> {
                val a = Parser.cariApp(c.nama) ?: return kePeladen(c.asli)
                val oto = Aksi.tutupApp(this, a.paket)
                ucap(if (oto) "Menutup ${a.label}." else "Layanan aksesibilitas belum aktif, jadi saya hanya bisa membuka layar info ${a.label}. Aktifkan Jarvis Otomasi di pengaturan aksesibilitas.")
            }
            Niat.TELEPON, Niat.VIDEO, Niat.KIRIM, Niat.MULAI_WA -> denganKontak(c)
            Niat.SERVER -> kePeladen(c.asli)
        }
    }

    private fun bg(f: () -> Unit) {
        Thread {
            try { f() } catch (e: Exception) { handler.post { ucap("Terjadi kesalahan. ${e.message ?: ""}".trim()) } }
        }.start()
    }

    private fun denganKontak(c: Perintah) {
        if (checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            ucap("Izin kontak belum diberikan. Buka aplikasi Jarvis untuk mengaktifkannya."); return
        }
        bg {
            val k = Aksi.cariKontak(this, c.nama)
            handler.post {
                when {
                    k.isEmpty() -> ucap("Kontak ${c.nama} tidak ditemukan di WhatsApp. Sebutkan nama persis seperti di kontak.")
                    k.size > 1 -> {
                        menungguPilihan = Pilihan(k, c); sekali = true
                        ucap("Ada beberapa kontak: ${k.joinToString(", ") { it.nama }}. Sebutkan yang mana.")
                    }
                    else -> eksekusi(c, k[0])
                }
            }
        }
    }

    private fun eksekusi(c: Perintah, k: KontakWa) {
        when (c.niat) {
            Niat.TELEPON, Niat.VIDEO -> {
                val video = c.niat == Niat.VIDEO
                ucap(if (video) "Video call ke ${k.nama} lewat WhatsApp." else "Menelepon ${k.nama} lewat WhatsApp.")
                tundaSampai = SystemClock.elapsedRealtime() + 30_000
                bg { val jalur = Aksi.panggilWa(this, k.nomor, video); np.edit().putString("jalurTerakhir", jalur).apply() }
            }
            Niat.KIRIM -> {
                ucap("Baik, mengirim pesan ke ${k.nama}: ${c.pesan}")
                Aksi.kirimWa(this, k.nomor, c.pesan)
            }
            Niat.MULAI_WA -> { menungguPesan = k; sekali = true; ucap("Apa pesannya?") }
            else -> {}
        }
    }

    // ---------------------------------------------------------------- pertanyaan ke server (AI, pencarian web, berita)

    private fun kePeladen(teks: String) {
        val kirim = ArrayList(riwayat.takeLast(8))
        bg {
            val j = ServerKlien.chat(this, kirim)
            handler.post { tanggapi(j) }
        }
    }

    private fun tanggapi(j: org.json.JSONObject) {
        var balas = j.optString("reply").ifBlank { "Baik, sudah saya proses." }
        j.optJSONObject("app")?.let { Aksi.bukaApp(this, it.optString("paket"), it.optString("web")) }
        val telp = j.optJSONObject("telp")
        if (telp != null) {
            val nama = telp.optString("nama"); val nomor = telp.optString("nomor")
            if (nomor.isNotEmpty()) {
                tundaSampai = SystemClock.elapsedRealtime() + 30_000
                bg { Aksi.panggilWa(this, nomor, false) }
            } else if (nama.isNotEmpty()) {
                jalankan(Perintah(Niat.TELEPON, nama = nama, asli = nama)); return
            }
        }
        if (j.has("file") && !j.isNull("file")) balas += " Dokumennya sudah dibuat. Buka aplikasi Jarvis untuk mengunduhnya."
        if ((j.has("email") && !j.isNull("email")) || (j.has("wa") && !j.isNull("wa"))) balas += " Buka aplikasi Jarvis untuk mengonfirmasi pengirimannya."
        ucap(balas)
    }

    // ---------------------------------------------------------------- tombol Arc Reactor melayang

    private fun warna(hex: String) { warnaInti = Color.parseColor(hex); tombol?.invalidate() }
    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun tampilTombol() {
        if (tombol != null) return
        try {
            wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val ukuran = dp(56)
            val v = object : View(this) {
                private val p = Paint(Paint.ANTI_ALIAS_FLAG)
                override fun onDraw(c: Canvas) {
                    val cx = width / 2f; val cy = height / 2f; val r = width / 2f
                    p.style = Paint.Style.FILL; p.color = Color.parseColor("#E6061018"); c.drawCircle(cx, cy, r - 2, p)
                    p.style = Paint.Style.STROKE; p.strokeWidth = dp(2).toFloat(); p.color = Color.parseColor("#00E5FF"); c.drawCircle(cx, cy, r - dp(3), p)
                    p.strokeWidth = dp(1).toFloat(); p.color = Color.parseColor("#6600E5FF"); c.drawCircle(cx, cy, r * 0.62f, p)
                    p.style = Paint.Style.FILL; p.color = warnaInti; c.drawCircle(cx, cy, r * 0.28f, p)
                }
            }
            @Suppress("DEPRECATION")
            val tipe = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE
            val lp = WindowManager.LayoutParams(ukuran, ukuran, tipe, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT).apply {
                gravity = Gravity.TOP or Gravity.START; x = dp(8); y = dp(200)
            }
            var awalX = 0; var awalY = 0; var sentuhX = 0f; var sentuhY = 0f; var geser = false
            v.setOnTouchListener { _, e ->
                when (e.action) {
                    MotionEvent.ACTION_DOWN -> { awalX = lp.x; awalY = lp.y; sentuhX = e.rawX; sentuhY = e.rawY; geser = false; true }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = e.rawX - sentuhX; val dy = e.rawY - sentuhY
                        if (geser || dx * dx + dy * dy > dp(8) * dp(8)) { geser = true; lp.x = awalX + dx.toInt(); lp.y = awalY + dy.toInt(); try { wm?.updateViewLayout(v, lp) } catch (_: Exception) {} }
                        true
                    }
                    MotionEvent.ACTION_UP -> { if (!geser) ketukTombol(); true }
                    else -> false
                }
            }
            wm?.addView(v, lp)
            tombol = v
        } catch (e: Exception) {
            tombol = null
            np.edit().putString("galat", "Tombol melayang: ${e.javaClass.simpleName} ${e.message}").apply()
        }
    }

    private fun hapusTombol() {
        tombol?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        tombol = null
    }

    /** Ketuk: Jarvis menjawab "Ya?" lalu langsung mendengar perintah (tanpa membuka aplikasi). */
    private fun ketukTombol() {
        if (!punyaMic()) {
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP))
            return
        }
        if (fp.getBoolean("flutter.siaga", false)) { fp.edit().putBoolean("flutter.siaga", false).apply() }
        langsung = true; sekali = true
        ucap("Ya?")
    }
}
