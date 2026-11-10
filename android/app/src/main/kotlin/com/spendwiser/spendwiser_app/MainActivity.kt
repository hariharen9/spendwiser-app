package com.spendwiser.spendwiser_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var smsPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "spendwiser/sms").setMethodCallHandler { call, result ->
            handleSmsCall(call, result)
        }

        EventChannel(messenger, "spendwiser/sms_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SmsEventBus.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    SmsEventBus.setSink(null)
                }
            },
        )
    }

    private fun handleSmsCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasSmsPermission())
            "requestPermission" -> requestSmsPermission(result)
            "getPending" -> result.success(SmsInboxStore(this).list())
            "count" -> result.success(SmsInboxStore(this).count())
            "addRaw" -> {
                val sender = call.argument<String>("sender") ?: "TEST"
                val body = call.argument<String>("body") ?: ""
                val receivedAt =
                    call.argument<Number>("receivedAt")?.toLong() ?: System.currentTimeMillis()
                val item = SmsInboxStore(this).add(sender, body, receivedAt)
                if (item != null) SmsEventBus.emit(item)
                result.success(item)
            }
            "remove" -> {
                SmsInboxStore(this).remove(call.argument<String>("id"))
                result.success(null)
            }
            "clear" -> {
                SmsInboxStore(this).clear()
                result.success(null)
            }
            "notifyTest" -> {
                val count = SmsInboxStore(this).count()
                result.success(SmsNotifier.notify(this, count, test = true))
            }
            else -> result.notImplemented()
        }
    }

    private fun hasSmsPermission(): Boolean =
        checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        if (smsPermissionResult != null) {
            result.error("permission_busy", "A permission request is already running", null)
            return
        }
        smsPermissionResult = result
        val permissions = mutableListOf(Manifest.permission.RECEIVE_SMS)
        if (Build.VERSION.SDK_INT >= 33) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        requestPermissions(permissions.toTypedArray(), SMS_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != SMS_PERMISSION_REQUEST) return
        val index = permissions.indexOf(Manifest.permission.RECEIVE_SMS)
        val granted =
            index >= 0 && grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        smsPermissionResult?.success(granted)
        smsPermissionResult = null
    }

    companion object {
        private const val SMS_PERMISSION_REQUEST = 7101
    }
}
