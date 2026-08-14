package com.ziko.ziko

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
    }
}
