package com.spendwiser.spendwiser_app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/// Bridges the manifest receiver to the live Flutter EventChannel when the
/// engine is running. When the app is dead the queue is read on next launch.
object SmsEventBus {
    @Volatile
    private var sink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setSink(value: EventChannel.EventSink?) {
        sink = value
    }

    fun emit(item: Map<String, Any?>) {
        mainHandler.post { sink?.success(item) }
    }
}
