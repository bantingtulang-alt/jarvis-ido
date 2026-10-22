package com.example.jarvis

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "id.pusakabakery.jarvis/otomasi")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "aksesibilitasAktif" -> result.success(JarvisAccessibilityService.aktif)
                    "bukaPengaturanAksesibilitas" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "kirimWa" -> {
                        AutomationBridge.tunggu(AutomationBridge.Aksi.KIRIM)
                        result.success(bukaChatWa(call.argument<String>("nomor") ?: "", call.argument<String>("pesan")))
                    }
                    "teleponWa" -> {
                        val nomor = call.argument<String>("nomor") ?: ""
                        val video = call.argument<Boolean>("video") ?: false
                        // 1) panggilan langsung lewat data kontak WhatsApp; 2) cadangan: buka chat lalu tekan ikon telepon
                        AutomationBridge.tunggu(AutomationBridge.Aksi.KONFIRMASI)
                        if (panggilLangsung(nomor, video)) {
                            result.success(true)
                        } else {
                            AutomationBridge.tunggu(AutomationBridge.Aksi.TELEPON, video)
                            result.success(bukaChatWa(nomor, null))
                        }
                    }
                    "statusHp" -> {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        result.success(mapOf("baterai" to bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)))
                    }
                    "minimize" -> {
                        if (!JarvisAccessibilityService.kembaliKeBeranda()) {
                            startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(true)
                    }
                    "tutupApp" -> {
                        val paket = call.argument<String>("paket") ?: ""
                        // Buka layar Info Aplikasi; layanan aksesibilitas menekan "Paksa berhenti" (jika aktif)
                        val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$paket")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        val otomatis = JarvisAccessibilityService.aktif
                        if (otomatis) AutomationBridge.tunggu(AutomationBridge.Aksi.PAKSA_BERHENTI)
                        try { startActivity(i); result.success(otomatis) } catch (e: Exception) { AutomationBridge.batal(); result.success(false) }
                    }
                    "izinOverlay" -> result.success(Settings.canDrawOverlays(this))
                    "bukaIzinOverlay" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "mulaiBubble" -> {
                        if (!Settings.canDrawOverlays(this)) { result.success(false) } else {
                            val i = Intent(this, BubbleService::class.java)
                            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                            result.success(true)
                        }
                    }
                    "hentikanBubble" -> { stopService(Intent(this, BubbleService::class.java)); result.success(true) }
                    "bubbleAktif" -> result.success(BubbleService.jalan)
                    "ambilPemicu" -> { val v = AutomationBridge.pemicuDengar; AutomationBridge.pemicuDengar = false; result.success(v) }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun bukaChatWa(nomor: String, pesan: String?): Boolean {
        val q = if (pesan.isNullOrEmpty()) "" else "&text=" + Uri.encode(pesan)
        val uri = Uri.parse("https://api.whatsapp.com/send?phone=$nomor$q")
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val i = Intent(Intent.ACTION_VIEW, uri).setPackage(pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (i.resolveActivity(packageManager) != null) { startActivity(i); return true }
        }
        AutomationBridge.batal()
        return false
    }

    /** Memulai panggilan WhatsApp langsung dari baris data kontak (mimetype voip/video call). */
    private fun panggilLangsung(nomor: String, video: Boolean): Boolean {
        val digit = nomor.filter { it.isDigit() }
        if (digit.length < 8) return false
        val mimes = if (video)
            listOf("vnd.android.cursor.item/vnd.com.whatsapp.video.call", "vnd.android.cursor.item/vnd.com.whatsapp.w4b.video.call")
        else
            listOf("vnd.android.cursor.item/vnd.com.whatsapp.voip.call", "vnd.android.cursor.item/vnd.com.whatsapp.w4b.voip.call")
        for (mime in mimes) {
            try {
                contentResolver.query(
                    ContactsContract.Data.CONTENT_URI, arrayOf(ContactsContract.Data._ID),
                    "${ContactsContract.Data.MIMETYPE}=? AND ${ContactsContract.Data.DATA1} LIKE ?",
                    arrayOf(mime, "%${digit.takeLast(10)}@%"), null
                )?.use { c ->
                    if (c.moveToFirst()) {
                        val i = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(Uri.parse("content://com.android.contacts/data/${c.getLong(0)}"), mime)
                            .setPackage(if (mime.contains("w4b")) "com.whatsapp.w4b" else "com.whatsapp")
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(i)
                        return true
                    }
                }
            } catch (_: Exception) {}
        }
        return false
    }
}
