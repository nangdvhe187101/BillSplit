package com.billsplit.mobile

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.billsplit.app/notification"
        private var methodChannel: MethodChannel? = null

        fun onBankNotificationReceived(packageName: String, title: String, text: String) {
            val data = mapOf(
                "package" to packageName,
                "title" to title,
                "text" to text
            )
            methodChannel?.invokeMethod("onBankNotification", data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerGranted" -> {
                    result.success(isNotificationServiceEnabled(context))
                }
                "openNotificationListenerSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationServiceEnabled(context: Context): Boolean {
        val packageName = context.packageName
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
