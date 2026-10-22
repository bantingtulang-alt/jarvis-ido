package com.example.jarvis

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Memanggil /api/chat dari latar belakang memakai token dan alamat server yang disimpan aplikasi Flutter. */
object ServerKlien {
    fun chat(ctx: Context, riwayat: List<Pair<String, String>>): JSONObject {
        val fp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = fp.getString("flutter.token", null) ?: throw Exception("Belum masuk. Buka aplikasi Jarvis dan masuk dulu.")
        val server = (fp.getString("flutter.server", null) ?: "https://jarvis.pusakabakery.com").trimEnd('/')
        val pesan = JSONArray()
        riwayat.takeLast(8).forEach { pesan.put(JSONObject().put("sender", it.first).put("text", it.second)) }
        val body = JSONObject().put("klien", "android").put("messages", pesan).toString().toByteArray()
        var url = URL("$server/api/chat")
        for (i in 0..3) {
            val c = url.openConnection() as HttpURLConnection
            try {
                c.instanceFollowRedirects = false
                c.requestMethod = "POST"
                c.doOutput = true
                c.connectTimeout = 15000
                c.readTimeout = 90000
                c.setRequestProperty("Content-Type", "application/json")
                c.setRequestProperty("Authorization", "Bearer $token")
                c.outputStream.use { it.write(body) }
                val kode = c.responseCode
                if (kode in listOf(301, 302, 307, 308)) {
                    val lok = c.getHeaderField("Location") ?: throw Exception("Server mengalihkan tanpa tujuan.")
                    val baru = URL(url, lok)
                    if (baru.host.removePrefix("www.") != url.host.removePrefix("www.")) throw Exception("Server mengalihkan ke alamat lain.")
                    url = baru
                    continue
                }
                if (kode == 401) throw Exception("Sesi habis. Buka aplikasi Jarvis dan masuk lagi.")
                val teks = (if (kode in 200..299) c.inputStream else c.errorStream)?.bufferedReader()?.readText() ?: ""
                val j = try { JSONObject(teks) } catch (_: Exception) { JSONObject() }
                if (kode != 200) throw Exception(j.optString("error").ifEmpty { "Server menjawab kode $kode" })
                return j
            } finally {
                c.disconnect()
            }
        }
        throw Exception("Server mengalihkan terlalu banyak kali.")
    }
}
