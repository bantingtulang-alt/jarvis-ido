package com.example.jarvis

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager

/** Tombol Arc Reactor melayang di atas aplikasi lain. Seret untuk memindahkan, ketuk untuk memanggil Jarvis (langsung mendengar). */
class BubbleService : Service() {
    companion object { @Volatile var jalan = false }

    private var wm: WindowManager? = null
    private var tombol: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!jalan) {
            jalan = true
            mulaiForeground()
            tampilkan()
        }
        return START_STICKY
    }

    private fun mulaiForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(NotificationChannel("jarvis_bubble", "Tombol Jarvis", NotificationManager.IMPORTANCE_MIN))
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "jarvis_bubble") else Notification.Builder(this)
        val n = b.setContentTitle("Jarvis").setContentText("Tombol melayang aktif").setSmallIcon(android.R.drawable.ic_btn_speak_now).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(7, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE) else startForeground(7, n)
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private fun tampilkan() {
        wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val ukuran = dp(56)
        val v = object : View(this) {
            private val p = Paint(Paint.ANTI_ALIAS_FLAG)
            override fun onDraw(c: Canvas) {
                val cx = width / 2f; val cy = height / 2f; val r = width / 2f
                p.style = Paint.Style.FILL; p.color = Color.parseColor("#E6061018"); c.drawCircle(cx, cy, r - 2, p)
                p.style = Paint.Style.STROKE; p.strokeWidth = dp(2).toFloat(); p.color = Color.parseColor("#00E5FF"); c.drawCircle(cx, cy, r - dp(3), p)
                p.strokeWidth = dp(1).toFloat(); p.color = Color.parseColor("#6600E5FF"); c.drawCircle(cx, cy, r * 0.62f, p)
                p.style = Paint.Style.FILL; p.color = Color.parseColor("#F59E0B"); c.drawCircle(cx, cy, r * 0.28f, p)
            }
        }
        val tipe = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE
        val lp = WindowManager.LayoutParams(ukuran, ukuran, tipe, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, PixelFormat.TRANSLUCENT).apply {
            gravity = Gravity.TOP or Gravity.START; x = dp(8); y = dp(200)
        }
        var awalX = 0; var awalY = 0; var sentuhX = 0f; var sentuhY = 0f; var geser = false
        v.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> { awalX = lp.x; awalY = lp.y; sentuhX = e.rawX; sentuhY = e.rawY; geser = false; true }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - sentuhX; val dy = e.rawY - sentuhY
                    if (geser || dx * dx + dy * dy > dp(8) * dp(8)) { geser = true; lp.x = awalX + dx.toInt(); lp.y = awalY + dy.toInt(); wm?.updateViewLayout(v, lp) }
                    true
                }
                MotionEvent.ACTION_UP -> { if (!geser) panggil(); true }
                else -> false
            }
        }
        tombol = v
        wm?.addView(v, lp)
    }

    private fun panggil() {
        AutomationBridge.pemicuDengar = true
        val i = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        startActivity(i)
    }

    override fun onDestroy() {
        jalan = false
        tombol?.let { try { wm?.removeView(it) } catch (_: Exception) {} }
        tombol = null
        super.onDestroy()
    }
}
