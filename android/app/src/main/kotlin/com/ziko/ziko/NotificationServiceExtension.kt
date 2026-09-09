package com.ziko.ziko

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import androidx.core.app.NotificationCompat
import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class NotificationServiceExtension : INotificationServiceExtension {

    companion object {
        private var mediaPlayer: android.media.MediaPlayer? = null
        private var vibrator: android.os.Vibrator? = null

        fun stopNativeAlert() {
            try {
                val mp = mediaPlayer
                if (mp != null) {
                    if (mp.isPlaying) {
                        mp.stop()
                    }
                    mp.release()
                }
                mediaPlayer = null
                
                vibrator?.cancel()
                vibrator = null
            } catch (e: Exception) {
                Log.e("Ziko", "Error stopping alert", e)
            }
        }
    }

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val payload = notification.additionalData
        val appContext = event.context

        if (payload != null && payload.has("action") && payload.getString("action") == "incoming_order_call") {
            try {
                val orderId = payload.optString("orderId", "")
                val customerName = payload.optString("customerName", "New Order")
                val amount = payload.optString("amount", "")
                val items = payload.optString("items", "")
                val type = payload.optString("type", "owner")
                val appointment = payload.optString("appointment", "")
                val location = payload.optString("location", "")
                val commission = payload.optString("commission", "")
                val timeoutSeconds = payload.optInt("timeoutSeconds", 30)

                // 1. FORCE START SOUND & VIBRATION (Consistent even if phone is unlocked)
                startCustomAlert(appContext)

                // 2. SHOW ACTIONABLE NOTIFICATION (Synchronized with detailed content)
                showOrderAlert(
                    appContext, orderId, customerName, amount, items, type,
                    appointment, location, commission, timeoutSeconds
                )

                Log.d("OneSignal", "SUCCESS: Branded alert with custom sound dispatched.")
            } catch (e: Exception) {
                Log.e("OneSignal", "FAILED: Native alert error", e)
            }
        }
    }

    private fun startCustomAlert(context: Context) {
        try {
            stopNativeAlert()
            
            val mp = android.media.MediaPlayer()
            val afd = context.assets.openFd("flutter_assets/assets/audio/ringtone.mp3")
            mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mp.setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            mp.isLooping = true
            mp.prepare()
            mp.start()
            mediaPlayer = mp

            val vib = context.getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
            vibrator = vib
            val pattern = longArrayOf(0, 1000, 500, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib.vibrate(android.os.VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e("Ziko", "Custom alert sound failed: " + e.message)
        }
    }

    private fun showOrderAlert(
        context: Context,
        orderId: String,
        customerName: String,
        amount: String,
        items: String,
        type: String,
        appointment: String,
        location: String,
        commission: String,
        timeoutSeconds: Int
    ) {
        val requestCode = orderId.hashCode()

        // Formatting Title and Content for the heads-up notification (unlocked screen)
        val isAppointment = appointment.isNotEmpty() && type != "rider"
        val title = when {
            type == "rider" -> "🛵 নতুন ডেলিভারি রিকোয়েস্ট: ₹$commission"
            isAppointment -> "💇 নতুন সেলুন অ্যাপয়েন্টমেন্ট: ₹$amount"
            else -> "🛍️ নতুন অর্ডার প্রাপ্তি: ₹$amount"
        }
        
        var bodyText = if (type == "rider") "লোকেশন: $location | $items" else "$customerName • $items"
        if (isAppointment) {
            bodyText = "বুকিং সময়: $appointment | $bodyText"
        }

        val acceptIntent = Intent(context, NotificationActionReceiver::class.java)
        acceptIntent.setAction("ACTION_ACCEPT")
        acceptIntent.putExtra("orderId", orderId)
        acceptIntent.putExtra("type", type)
        acceptIntent.putExtra("notificationId", requestCode)
        val acceptPending = PendingIntent.getBroadcast(context, requestCode + 1, acceptIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val rejectIntent = Intent(context, NotificationActionReceiver::class.java)
        rejectIntent.setAction("ACTION_REJECT")
        rejectIntent.putExtra("orderId", orderId)
        rejectIntent.putExtra("type", type)
        rejectIntent.putExtra("notificationId", requestCode)
        val rejectPending = PendingIntent.getBroadcast(context, requestCode + 2, rejectIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val fullScreenIntent = Intent(context, OrderAlertActivity::class.java)
        fullScreenIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        fullScreenIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        fullScreenIntent.putExtra("orderId", orderId)
        fullScreenIntent.putExtra("customerName", customerName)
        fullScreenIntent.putExtra("amount", amount)
        fullScreenIntent.putExtra("items", items)
        fullScreenIntent.putExtra("type", type)
        fullScreenIntent.putExtra("appointment", appointment)
        fullScreenIntent.putExtra("location", location)
        fullScreenIntent.putExtra("commission", commission)
        fullScreenIntent.putExtra("timeoutSeconds", timeoutSeconds)
        
        val fullScreenPending = PendingIntent.getActivity(context, requestCode, fullScreenIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val channelId = "ziko_urgent_foreground_v4"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (nm.getNotificationChannel(channelId) == null) {
                val channel = NotificationChannel(channelId, "Order Alerts", NotificationManager.IMPORTANCE_HIGH)
                channel.enableVibration(true)
                channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                channel.setSound(null, null)
                nm.createNotificationChannel(channel)
            }
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(bodyText)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(fullScreenPending, true)
            .setOngoing(true) 
            .setAutoCancel(true)
            .setColor(android.graphics.Color.parseColor("#F45D27"))
            .addAction(0, "ACCEPT", acceptPending)
            .addAction(0, "REJECT", rejectPending)

        nm.notify(requestCode, builder.build())
    }
}
