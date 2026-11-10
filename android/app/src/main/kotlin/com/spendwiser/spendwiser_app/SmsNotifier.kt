package com.spendwiser.spendwiser_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object SmsNotifier {
    private const val CHANNEL_ID = "sms_capture"
    private const val NOTIFICATION_ID = 7100

    fun notify(context: Context, count: Int) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "SMS review",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Bank messages waiting for review"
                },
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        launch.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        launch.putExtra("open_sms_review", true)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_sms)
            .setContentTitle("Spendwiser")
            .setContentText(
                if (count == 1) "1 bank message to review"
                else "$count bank messages to review",
            )
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
        manager.notify(NOTIFICATION_ID, builder.build())
    }
}
