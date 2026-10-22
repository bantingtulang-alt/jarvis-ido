package com.example.jarvis

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Otomasi tanpa sentuh:
 * - WhatsApp: tekan Kirim, ikon telepon/video, dan dialog konfirmasi panggilan.
 * - Layar Info Aplikasi: tekan "Paksa berhenti" (untuk perintah "tutup <aplikasi>").
 * Hanya bereaksi saat Jarvis meminta (maks. 15 detik) dan tidak pernah membaca atau menyimpan isi layar.
 */
class JarvisAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var aktif = false
        @Volatile var instance: JarvisAccessibilityService? = null
        fun kembaliKeBeranda(): Boolean = instance?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
    }

    private val handler = Handler(Looper.getMainLooper())
    private var sedangMencoba = false

    override fun onServiceConnected() { super.onServiceConnected(); aktif = true; instance = this }
    override fun onUnbind(intent: android.content.Intent?): Boolean { aktif = false; instance = null; return super.onUnbind(intent) }
    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val pkg = event?.packageName?.toString() ?: return
        val aksi = AutomationBridge.aktifMenunggu() ?: return
        val wa = pkg == "com.whatsapp" || pkg == "com.whatsapp.w4b"
        when (aksi) {
            AutomationBridge.Aksi.PAKSA_BERHENTI -> if (pkg == packageName) return
            else -> if (!wa) return
        }
        if (sedangMencoba) return
        sedangMencoba = true
        handler.postDelayed({ coba(aksi, 0) }, if (aksi == AutomationBridge.Aksi.PAKSA_BERHENTI) 500 else 700)
    }

    private fun coba(aksi: AutomationBridge.Aksi, ke: Int) {
        val root = rootInActiveWindow
        val ok = if (root == null) false else when (aksi) {
            AutomationBridge.Aksi.KIRIM -> klikKirim(root)
            AutomationBridge.Aksi.TELEPON -> klikTelepon(root, AutomationBridge.video)
            AutomationBridge.Aksi.KONFIRMASI -> konfirmasi(root)
            AutomationBridge.Aksi.PAKSA_BERHENTI -> paksaBerhenti(root)
        }
        if (ok) {
            AutomationBridge.batal()
            when (aksi) {
                AutomationBridge.Aksi.TELEPON -> { AutomationBridge.tunggu(AutomationBridge.Aksi.KONFIRMASI) }
                AutomationBridge.Aksi.PAKSA_BERHENTI -> handler.postDelayed({ konfirmasiBerhenti() }, 600)
                else -> {}
            }
            sedangMencoba = false
        } else if (ke < 5 && AutomationBridge.aktifMenunggu() != null) {
            handler.postDelayed({ coba(aksi, ke + 1) }, 500)
        } else {
            sedangMencoba = false
        }
    }

    private fun klik(n: AccessibilityNodeInfo?): Boolean {
        var x = n
        while (x != null) { if (x.isClickable && x.isEnabled) return x.performAction(AccessibilityNodeInfo.ACTION_CLICK); x = x.parent }
        return false
    }

    private fun klikKirim(root: AccessibilityNodeInfo): Boolean {
        for (id in listOf("com.whatsapp:id/send", "com.whatsapp.w4b:id/send")) {
            if (root.findAccessibilityNodeInfosByViewId(id).any { klik(it) }) return true
        }
        for (t in listOf("Kirim", "Send")) {
            if (root.findAccessibilityNodeInfosByText(t).any { it.contentDescription?.toString().equals(t, true) && klik(it) }) return true
        }
        return false
    }

    private fun klikTelepon(root: AccessibilityNodeInfo, video: Boolean): Boolean {
        val ids = if (video) listOf("video_call", "menu_item_video_call") else listOf("voice_call", "menu_item_call")
        for (pkg in listOf("com.whatsapp", "com.whatsapp.w4b")) for (i in ids) {
            if (root.findAccessibilityNodeInfosByViewId("$pkg:id/$i").any { klik(it) }) return true
        }
        val kata = if (video) listOf("Panggilan video", "Video call") else listOf("Panggilan suara", "Voice call")
        for (t in kata) if (root.findAccessibilityNodeInfosByText(t).any { klik(it) }) return true
        return false
    }

    /** Dialog "Mulai panggilan suara ke X?" -> tombol Panggil. Cocok persis agar tidak salah tekan. */
    private fun konfirmasi(root: AccessibilityNodeInfo): Boolean {
        for (t in listOf("Panggil", "Call", "Telepon")) {
            val n = root.findAccessibilityNodeInfosByText(t).firstOrNull { it.isClickable && it.text?.toString().equals(t, true) }
            if (n != null) return n.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        return false
    }

    private fun paksaBerhenti(root: AccessibilityNodeInfo): Boolean {
        for (t in listOf("Paksa berhenti", "Paksa henti", "Force stop", "Paksa tutup")) {
            val n = root.findAccessibilityNodeInfosByText(t).firstOrNull { klik(it) }
            if (n != null) return true
        }
        return false
    }

    private fun konfirmasiBerhenti() {
        val root = rootInActiveWindow
        if (root != null) {
            for (t in listOf("OK", "Ya", "Paksa berhenti", "Force stop")) {
                val n = root.findAccessibilityNodeInfosByText(t).firstOrNull { it.isClickable && it.text?.toString().equals(t, true) }
                if (n != null) { n.performAction(AccessibilityNodeInfo.ACTION_CLICK); break }
            }
        }
        handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 700)
    }
}
