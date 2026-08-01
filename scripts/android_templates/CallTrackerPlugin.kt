package com.codeskate.crm

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CallLog
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native call tracker: listens for PHONE_STATE, and after a call ends reads the
 * latest completed call from the CallLog. Mirrors the reference Capacitor
 * plugin (com.codeskate.erp.calltracker.CallTrackerPlugin) but exposed to
 * Flutter via MethodChannel + EventChannel.
 */
class CallTrackerPlugin(private val context: Context) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val PREFS = "codeskate_call_tracker"
        private const val LAST_CALL_ID = "last_processed_call_id"
        private const val CALL_LOG_WRITE_DELAY_MS = 2200L
        private const val CALL_LOG_SKEW_MS = 60000L
    }

    private var receiver: BroadcastReceiver? = null
    private var wasOffhook = false
    private var offhookStartedAtMs = 0L
    private var eventSink: EventChannel.EventSink? = null

    private fun prefs(): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startListening" -> {
                registerReceiver()
                result.success(true)
            }
            "stopListening" -> {
                unregister()
                result.success(true)
            }
            "getLastCall" -> result.success(latestUnprocessedCall(0L))
            "markCallProcessed" -> {
                val id = call.argument<String>("id")
                if (id.isNullOrEmpty()) {
                    result.error("no_id", "A call ID is required", null)
                } else {
                    prefs().edit().putString(LAST_CALL_ID, id).apply()
                    result.success(true)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun registerReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                val state = intent?.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
                if (state == TelephonyManager.EXTRA_STATE_OFFHOOK) {
                    wasOffhook = true
                    offhookStartedAtMs = System.currentTimeMillis()
                } else if (state == TelephonyManager.EXTRA_STATE_IDLE && wasOffhook) {
                    wasOffhook = false
                    val minimumDate = maxOf(0L, offhookStartedAtMs - CALL_LOG_SKEW_MS)
                    Handler(Looper.getMainLooper()).postDelayed({
                        val data = latestUnprocessedCall(minimumDate)
                        if (data != null && data["found"] == true) {
                            eventSink?.success(data)
                        }
                    }, CALL_LOG_WRITE_DELAY_MS)
                }
            }
        }
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(receiver, filter)
        }
    }

    private fun unregister() {
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        receiver = null
        wasOffhook = false
    }

    private fun latestUnprocessedCall(minimumDate: Long): Map<String, Any?> {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf("found" to false)
        }
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.DURATION,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE
        )
        val selection = if (minimumDate > 0) "${CallLog.Calls.DATE} >= ?" else null
        val args = if (minimumDate > 0) arrayOf(minimumDate.toString()) else null
        val cursor = context.contentResolver.query(
            CallLog.Calls.CONTENT_URI, projection, selection, args,
            "${CallLog.Calls.DATE} DESC"
        ) ?: return mapOf("found" to false)

        cursor.use { c ->
            val lastId = prefs().getString(LAST_CALL_ID, null)
            while (c.moveToNext()) {
                val id = c.getString(c.getColumnIndexOrThrow(CallLog.Calls._ID))
                if (id != null && id == lastId) continue
                val duration = c.getInt(c.getColumnIndexOrThrow(CallLog.Calls.DURATION))
                val type = c.getInt(c.getColumnIndexOrThrow(CallLog.Calls.TYPE))
                val number = c.getString(c.getColumnIndexOrThrow(CallLog.Calls.NUMBER))
                val date = c.getLong(c.getColumnIndexOrThrow(CallLog.Calls.DATE))
                if (duration <= 0) {
                    prefs().edit().putString(LAST_CALL_ID, id).apply()
                    continue
                }
                val typeValue = when (type) {
                    CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                    CallLog.Calls.INCOMING_TYPE -> "incoming"
                    else -> "other"
                }
                return mapOf(
                    "found" to true,
                    "id" to id,
                    "number" to number,
                    "duration" to duration,
                    "type" to typeValue,
                    "date" to date
                )
            }
        }
        return mapOf("found" to false)
    }
}
