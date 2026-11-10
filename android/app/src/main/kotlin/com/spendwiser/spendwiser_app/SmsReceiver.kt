package com.spendwiser.spendwiser_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = try {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } catch (_: Exception) {
            null
        } ?: return
        if (messages.isEmpty()) return

        val sender = messages.firstNotNullOfOrNull { it.originatingAddress } ?: "Unknown"
        val body = messages.joinToString("") { it.messageBody ?: "" }.trim()
        if (body.isEmpty()) return
        if (!SmsFilter.isCandidate(sender, body)) return

        val receivedAt = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()
        val store = SmsInboxStore(context)
        val item = store.add(sender, body, receivedAt) ?: return
        SmsEventBus.emit(item)
        SmsNotifier.notify(context, store.count())
    }
}
