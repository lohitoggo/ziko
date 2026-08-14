package com.ziko.ziko

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONObject

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val orderId = intent.getStringExtra("orderId") ?: ""
        val type = intent.getStringExtra("type") ?: "owner"
        val requestCode = intent.getIntExtra("notificationId", 999)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(requestCode)

        // STOP NATIVE ALERT SOUND/VIBE
        NotificationServiceExtension.stopNativeAlert()

        if (action == null || orderId.isEmpty()) return

        when (action) {
            "ACTION_ACCEPT" -> {
                writeAction(context, orderId, type, "accept")
                MainActivity.sendActionToFlutter(orderId, type, "accept")
                launchApp(context)
            }
            "ACTION_REJECT" -> {
                writeAction(context, orderId, type, "reject")
                MainActivity.sendActionToFlutter(orderId, type, "reject")
            }
            "ACTION_VIEW" -> {
                writeAction(context, orderId, type, "view")
                MainActivity.sendActionToFlutter(orderId, type, "view")
                launchApp(context)
            }
        }
    }

    private fun writeAction(context: Context, orderId: String, type: String, action: String) {
        val prefs: SharedPreferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = JSONObject()
        json.put("orderId", orderId)
        json.put("type", type)
        json.put("action", action)
        json.put("timestamp", System.currentTimeMillis())
        
        prefs.edit().putString("flutter.pending_order_action", json.toString()).apply()
    }

    private fun launchApp(context: Context) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launchIntent != null) {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            context.startActivity(launchIntent)
        }
    }
}
