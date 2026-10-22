package com.example.jarvis

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

@SuppressLint("NewApi")
class MainActivity : FlutterActivity() {
    private var menungguIzin: MethodChannel.Result? = null

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
                    "izinInti" -> mintaIzin(result)
                    "cariKontakWa" -> {
                        val nama = call.argument<String>("nama") ?: ""
                        Thread {
                            try {
                                val hasil = Aksi.cariKontak(this, nama).map { mapOf("nama" to it.nama, "nomor" to it.nomor, "paket" to it.paket) }
                                runOnUiThread { result.success(hasil) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("kontak", e.message, null) }
                            }
                        }.start()
                    }
                    "kirimWa" -> result.success(Aksi.kirimWa(this, call.argument<String>("nomor") ?: "", call.argument<String>("pesan") ?: ""))
                    "teleponWa" -> {
                        val nomor = call.argument<String>("nomor") ?: ""
                        val video = call.argument<Boolean>("video") ?: false
                        Thread {
                            val jalur = try { Aksi.panggilWa(this, nomor, video) } catch (e: Exception) { "gagal" }
                            runOnUiThread { result.success(jalur) }
                        }.start()
                    }
                    "statusHp" -> result.success(mapOf("baterai" to Aksi.baterai(this)))
                    "minimize" -> { Aksi.minimize(this); result.success(true) }
                    "tutupApp" -> result.success(Aksi.tutupApp(this, call.argument<String>("paket") ?: ""))
                    "izinOverlay" -> result.success(Settings.canDrawOverlays(this))
                    "bukaIzinOverlay" -> {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "aturLatar" -> {
                        val bubble = call.argument<Boolean>("bubble") ?: false
                        val dengar = call.argument<Boolean>("dengar") ?: false
                        getSharedPreferences("jarvis_native", Context.MODE_PRIVATE).edit().putBoolean("bubble", bubble).putBoolean("dengar", dengar).remove("galat").apply()
                        if (!bubble && !dengar) {
                            stopService(Intent(this, JarvisService::class.java))
                            result.success("ok")
                        } else {
                            try {
                                val i = Intent(this, JarvisService::class.java)
                                if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                                result.success("ok")
                            } catch (e: Exception) {
                                result.success("${e.javaClass.simpleName}: ${e.message}")
                            }
                        }
                    }
                    "statusLatar" -> {
                        val p = getSharedPreferences("jarvis_native", Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "bubble" to p.getBoolean("bubble", false),
                            "dengar" to p.getBoolean("dengar", false),
                            "jalan" to JarvisService.jalan,
                            "galat" to (p.getString("galat", "") ?: ""),
                            "jalur" to (p.getString("jalurTerakhir", "") ?: "")
                        ))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Meminta mikrofon, kontak, dan notifikasi sekaligus. Mengembalikan true jika mikrofon dan kontak diberikan. */
    private fun mintaIzin(result: MethodChannel.Result) {
        val perlu = ArrayList<String>()
        perlu.add(Manifest.permission.RECORD_AUDIO)
        perlu.add(Manifest.permission.READ_CONTACTS)
        if (Build.VERSION.SDK_INT >= 33) perlu.add(Manifest.permission.POST_NOTIFICATIONS)
        val belum = perlu.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (belum.isEmpty()) { result.success(true); return }
        menungguIzin?.success(false)
        menungguIzin = result
        requestPermissions(belum.toTypedArray(), 77)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 77) {
            val ok = checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED &&
                checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
            menungguIzin?.success(ok)
            menungguIzin = null
        }
    }

    override fun onResume() {
        super.onResume()
        AutomationBridge.appTampil = true
        JarvisService.segarkan()
    }

    override fun onPause() {
        AutomationBridge.appTampil = false
        JarvisService.segarkan()
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
