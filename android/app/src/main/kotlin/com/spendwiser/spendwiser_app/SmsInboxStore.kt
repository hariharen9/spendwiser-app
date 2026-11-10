package com.spendwiser.spendwiser_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/// App-private queue of raw bank SMS waiting for review. Nothing here is ever
/// sent to Firestore; entries are removed when approved or dismissed.
class SmsInboxStore(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun add(sender: String, body: String, receivedAt: Long): Map<String, Any?>? {
        val id = digest("$sender|$receivedAt|$body")
        val array = load()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("id") == id) return null
        }
        val item = JSONObject().apply {
            put("id", id)
            put("sender", sender)
            put("body", body)
            put("receivedAt", receivedAt)
        }
        array.put(item)
        while (array.length() > MAX_ITEMS) array.remove(0)
        prefs.edit().putString(KEY, array.toString()).commit()
        return item.toMap()
    }

    @Synchronized
    fun list(): List<Map<String, Any?>> {
        val array = load()
        val result = ArrayList<Map<String, Any?>>(array.length())
        for (i in 0 until array.length()) {
            array.optJSONObject(i)?.let { result.add(it.toMap()) }
        }
        return result
    }

    @Synchronized
    fun remove(id: String?) {
        if (id.isNullOrEmpty()) return
        val array = load()
        val next = JSONArray()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("id") != id) next.put(item)
        }
        prefs.edit().putString(KEY, next.toString()).commit()
    }

    @Synchronized
    fun clear() {
        prefs.edit().remove(KEY).commit()
    }

    @Synchronized
    fun count(): Int = load().length()

    private fun load(): JSONArray = try {
        JSONArray(prefs.getString(KEY, "[]") ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }

    private fun digest(value: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(value.toByteArray())
        return bytes.joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }

    private fun JSONObject.toMap(): Map<String, Any?> = mapOf(
        "id" to optString("id"),
        "sender" to optString("sender"),
        "body" to optString("body"),
        "receivedAt" to optLong("receivedAt"),
    )

    companion object {
        private const val PREFS = "spendwiser_sms"
        private const val KEY = "pending"
        private const val MAX_ITEMS = 200
    }
}
