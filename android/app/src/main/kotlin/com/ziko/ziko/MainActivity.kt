package com.ziko.ziko

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    companion object {
        private var flutterEngineInstance: FlutterEngine? = null
        
        fun sendActionToFlutter(orderId: String, type: String, action: String) {
            val engine = flutterEngineInstance ?: return
            val data = mapOf(
                "orderId" to orderId,
                "type" to type,
                "action" to action
            )
            MethodChannel(engine.dartExecutor.binaryMessenger, "com.ziko/order_actions")
                .invokeMethod("onOrderAction", data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineInstance = flutterEngine

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ziko/upi_intent")
            .setMethodCallHandler { call, result ->
                if (call.method == "launchUpiIntent") {
                    val upiUrl = call.argument<String>("url")
                    try {
                        val uri = Uri.parse(upiUrl)
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        val chooser = Intent.createChooser(intent, "Pay using UPI app")
                        this.startActivity(chooser)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
