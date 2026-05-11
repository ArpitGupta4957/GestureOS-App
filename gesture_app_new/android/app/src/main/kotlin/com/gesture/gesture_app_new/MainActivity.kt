package com.gesture.gesture_app_new

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.app.AppOpsManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.razorpay.Checkout
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import org.json.JSONObject

class MainActivity: FlutterFragmentActivity(), PaymentResultWithDataListener {
    private val OVERLAY_CHANNEL = "overlay_channel"
    private val ACTION_CHANNEL = "action_channel"
    private val APPS_CHANNEL = "apps_channel"
    private val RAZORPAY_CHANNEL = "razorpay_channel"
    
    private var isTorchOn = false 
    private var razorpayResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Preload Razorpay
        Checkout.preload(applicationContext)
        
        // --- TORCH CALLBACK ---
        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager.registerTorchCallback(object : CameraManager.TorchCallback() {
            override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                super.onTorchModeChanged(cameraId, enabled)
                isTorchOn = enabled
            }
        }, null)
        
        // Cache Engine
        io.flutter.embedding.engine.FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)

        // --- OVERLAY CHANNEL ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startOverlay") {
                 if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                        result.error("PERMISSION_NEEDED", "Notification permission requested", null)
                        return@setMethodCallHandler
                    }
                }
                val intent = Intent(this, OverlayService::class.java)
                ContextCompat.startForegroundService(this, intent)
                result.success(true)
            } else if (call.method == "showNote") {
                val args = call.arguments as Map<String, String>
                val text = args["text"] ?: ""
                val status = args["status"] ?: ""
                
                val intent = Intent(this, OverlayService::class.java)
                intent.putExtra("ACTION", "SHOW_NOTE")
                intent.putExtra("TEXT", text)
                intent.putExtra("STATUS", status)
                ContextCompat.startForegroundService(this, intent)
                result.success(true)
            } else if (call.method == "stopOverlay") {
                 stopService(Intent(this, OverlayService::class.java))
                 result.success(true)
            } else if (call.method == "syncShortcuts") {
                val shortcuts = call.arguments as List<String>
                OverlayService.updateShortcuts(shortcuts)
                result.success(true)
            } else if (call.method == "refreshBackgroundGestures") {
                OverlayService.refreshBackgroundGestures()
                result.success(true)
            } else if (call.method == "isOverlayActive") {
                result.success(OverlayService.instance != null)
            } else if (call.method == "updateOverlaySettings") {
                val args = call.arguments as? Map<String, Any>
                if (args != null) {
                    OverlayService.updateSettings(args)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Arguments null", null)
                }
            } else if (call.method == "checkUsageStats") {
                val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                result.success(mode == AppOpsManager.MODE_ALLOWED)
            } else if (call.method == "updateInputText") {
                val text = call.arguments as String
                OverlayService.updateInputText(text)
                result.success(true)
            } else if (call.method == "collapseOverlay") {
                OverlayService.collapseToOverlay()
                result.success(true)
            } else if (call.method == "hideGestureView") {
                OverlayService.hideGestureView()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        // --- ACTION EXECUTOR CHANNEL ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTION_CHANNEL).setMethodCallHandler { call, result ->
             if (call.method == "executeAction") {
                val type = call.argument<String>("type")
                val value = call.argument<String>("value")
                try {
                    when (type) {
                        "camera" -> {
                            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        }
                        "app" -> {
                            if (value != null) {
                                val intent = packageManager.getLaunchIntentForPackage(value)
                                if (intent != null) {
                                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(intent)
                                }
                            }
                        }
                        "call" -> {
                            if (value != null) {
                                val intent = Intent(Intent.ACTION_CALL)
                                intent.data = Uri.parse("tel:$value")
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                                    startActivity(intent)
                                } else {
                                    val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$value"))
                                    dialIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    startActivity(dialIntent)
                                }
                            }
                        }
                        "wifi" -> startActivity(Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        "bluetooth" -> startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        "flashlight" -> {
                             val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                             for (id in cm.cameraIdList) {
                                 if (cm.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true) {
                                     cm.setTorchMode(id, !isTorchOn)
                                     break
                                 }
                             }
                        }
                        "volume" -> {
                            // value expected: "0" to "100", "silent", "vibrate", "normal"
                            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            when (value) {
                                "silent" -> audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                                "vibrate" -> audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                                "normal" -> audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
                                else -> {
                                    try {
                                        // Default to music stream volume
                                        val volPercent = value?.toIntOrNull() ?: 50
                                        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                                        val targetVol = (volPercent / 100.0 * maxVol).toInt()
                                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI)
                                    } catch (e: Exception) {
                                        startActivity(Intent(Settings.ACTION_SOUND_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                    }
                                }
                            }
                        }
                        "nfc" -> startActivity(Intent(Settings.ACTION_NFC_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        "aeroplane" -> startActivity(Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("EXECUTION_FAILED", e.message, null)
                }
             } else {
                 result.notImplemented()
             }
        }

        // --- APPS CHANNEL ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL).setMethodCallHandler { call, result ->
             if (call.method == "getInstalledApps") {
                 Thread {
                     val pm = packageManager
                     val apps = pm.getInstalledApplications(0)
                        .filter { pm.getLaunchIntentForPackage(it.packageName) != null }
                        .map {
                            mapOf("name" to pm.getApplicationLabel(it).toString(), "package" to it.packageName, "icon" to (getAppIconBytes(it.packageName) ?: ByteArray(0)))
                        }.sortedBy { it["name"] as String }
                     runOnUiThread { result.success(apps) }
                 }.start()
             }
        }
        
        // --- RAZORPAY CHANNEL ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RAZORPAY_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "open") {
                val options = call.arguments as Map<String, Any>
                startPayment(options, result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startPayment(optionsMap: Map<String, Any>, result: MethodChannel.Result) {
        razorpayResult = result
        val checkout = Checkout()
        checkout.setKeyID(optionsMap["key"] as String)
        try {
            val options = JSONObject(optionsMap)
            checkout.open(this, options)
        } catch(e: Exception) {
             result.error("INIT_FAILED", e.message, null)
             razorpayResult = null
        }
    }

    override fun onPaymentSuccess(razorpayPaymentID: String, paymentData: PaymentData) {
        val response = mapOf(
            "status" to "success",
            "paymentId" to razorpayPaymentID,
            "orderId" to paymentData.orderId,
            "signature" to paymentData.signature
        )
        razorpayResult?.success(response)
        razorpayResult = null
    }

    override fun onPaymentError(code: Int, response: String, paymentData: PaymentData?) {
        razorpayResult?.error("PAYMENT_FAILED", response, code.toString())
        razorpayResult = null
    }

    override fun onDestroy() {
        super.onDestroy()
        // Remove Main Engine from cache so OverlayService falls back to Background Engine
        io.flutter.embedding.engine.FlutterEngineCache.getInstance().remove("my_engine_id")
        Log.d("MainActivity", "🧹 Main Engine removed from cache")
    }

    private fun getAppIconBytes(packageName: String): ByteArray? {
        try {
            val drawable = packageManager.getApplicationIcon(packageName)
            val bitmap = if (drawable is android.graphics.drawable.BitmapDrawable) {
                drawable.bitmap
            } else {
                val bmp = android.graphics.Bitmap.createBitmap(drawable.intrinsicWidth, drawable.intrinsicHeight, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(bmp)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bmp
            }
            val stream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 75, stream)
            return stream.toByteArray()
        } catch (e: Exception) {
            return null
        }
    }
}
