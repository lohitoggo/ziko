package com.ziko.ziko

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

class OrderAlertActivity : Activity() {

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var dismissed = false

    private lateinit var orderId: String
    private lateinit var type: String 

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setupLockScreenDisplay()

        orderId = intent.getStringExtra("orderId") ?: ""
        type = intent.getStringExtra("type") ?: "owner"
        val customerName = intent.getStringExtra("customerName") ?: "New Order"
        val amount = intent.getStringExtra("amount") ?: "0"
        val items = intent.getStringExtra("items") ?: ""
        val location = intent.getStringExtra("location") ?: ""
        val appointment = intent.getStringExtra("appointment") ?: ""
        val commission = intent.getStringExtra("commission") ?: ""
        val timeoutSeconds = intent.getIntExtra("timeoutSeconds", 30)

        buildZikoUi(customerName, amount, items, location, appointment, commission)
        
        // Sound and Vibration are now managed globally by NotificationServiceExtension
        // to ensure they work even when the phone is unlocked/foreground.

        handler.postDelayed({ dismissAlert() }, timeoutSeconds * 1000L)
    }

    private fun setupLockScreenDisplay() {
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value.toFloat(), resources.displayMetrics).toInt()

    private fun buildZikoUi(customerName: String, amount: String, items: String, location: String, appointment: String, commission: String) {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
        }

        // 1. HEADER GRADIENT
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(60), dp(20), dp(40))
            background = GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(
                Color.parseColor("#F45D27"), Color.parseColor("#FF8A00")
            ))
        }
        
        val titleTv = TextView(this).apply {
            text = if (appointment.isNotEmpty()) "ZIKO NEW APPOINTMENT" else "ZIKO NEW ORDER"
            setTextColor(Color.WHITE)
            textSize = 22f
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        header.addView(titleTv)
        root.addView(header)

        // 2. DETAILS SECTION
        val details = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(32), dp(24), dp(24))
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f)
            layoutParams = lp
        }

        fun addRow(label: String, value: String, isPrice: Boolean = false, isAccent: Boolean = false) {
            val tv = TextView(this).apply {
                text = if (isPrice) "₹$value" else "$label: $value"
                setTextColor(if (isPrice || isAccent) Color.parseColor("#F45D27") else Color.BLACK)
                textSize = if (isPrice) 32f else 16f
                setPadding(0, dp(8), 0, dp(8))
                if (isPrice || isAccent) setTypeface(null, android.graphics.Typeface.BOLD)
            }
            details.addView(tv)
        }

        addRow("Customer", customerName)
        
        // Show Appointment Date/Time if available (Salon)
        if (appointment.isNotEmpty()) {
            addRow("Appointment", appointment, isAccent = true)
        }

        addRow("Amount", amount, isPrice = true)
        
        // Show Commission if available (Rider)
        if (commission.isNotEmpty()) {
            addRow("Your Earning", "₹$commission", isAccent = true)
        }

        addRow("Items", items)
        if (location.isNotEmpty()) addRow("Location", location)

        root.addView(details)

        // 3. ACTIONS
        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(16), dp(16), dp(16), dp(30))
            gravity = Gravity.CENTER
        }

        actions.addView(zikoButton("ACCEPT", "#2ECC71", 1f) { onAccept() })
        actions.addView(zikoButton("REJECT", "#E74C3C", 1f) { onReject() })

        root.addView(actions)
        setContentView(root)
    }

    private fun zikoButton(label: String, colorHex: String, weight: Float, onClick: () -> Unit): Button {
        val btn = Button(this)
        btn.text = label
        btn.setTextColor(Color.WHITE)
        val shape = GradientDrawable()
        shape.setColor(Color.parseColor(colorHex))
        shape.cornerRadius = dp(12).toFloat()
        btn.background = shape
        val lp = LinearLayout.LayoutParams(0, dp(56), weight)
        lp.setMargins(dp(8), 0, dp(8), 0)
        btn.layoutParams = lp
        btn.setOnClickListener { onClick() }
        return btn
    }

    private fun onAccept() {
        writePendingAction("accept")
        MainActivity.sendActionToFlutter(orderId, type, "accept")
        launchApp()
        dismissAlert()
    }

    private fun onReject() {
        writePendingAction("reject")
        MainActivity.sendActionToFlutter(orderId, type, "reject")
        dismissAlert()
    }

    private fun writePendingAction(action: String) {
        val prefs: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val json = JSONObject()
        json.put("orderId", orderId)
        json.put("type", type)
        json.put("action", action)
        json.put("timestamp", System.currentTimeMillis())
        prefs.edit().putString("flutter.pending_order_action", json.toString()).apply()
    }

    private fun launchApp() {
        val pm = this.packageManager
        val intent = pm.getLaunchIntentForPackage(this.packageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(intent)
        }
    }

    private fun dismissAlert() {
        if (dismissed) return
        dismissed = true
        
        // STOP GLOBAL ALERT SOUND/VIBE
        NotificationServiceExtension.stopNativeAlert()
        finish()
    }

    override fun onDestroy() {
        dismissAlert()
        super.onDestroy()
    }
}
