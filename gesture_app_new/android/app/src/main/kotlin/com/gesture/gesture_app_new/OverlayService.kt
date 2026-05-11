package com.gesture.gesture_app_new

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.Toast
import androidx.core.app.NotificationCompat
import android.text.InputType
import android.view.KeyEvent
import android.view.inputmethod.EditorInfo
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.android.FlutterView
import io.flutter.plugins.GeneratedPluginRegistrant
import android.provider.MediaStore
import android.provider.Settings
import android.net.Uri
import android.Manifest
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraCharacteristics
import io.flutter.embedding.android.FlutterTextureView
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import kotlin.math.abs

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

class OverlayService : Service(), SensorEventListener {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var gestureView: GestureView? = null
    private var params: WindowManager.LayoutParams? = null
    private var isCanvasMode = false

    // --- SHAKE DETECTION ---
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var lastShakeTime: Long = 0
    private val SHAKE_THRESHOLD_GRAVITY = 2.7F
    private val SHAKE_SLOP_TIME_MS = 500

    // --- BACKGROUND FLUTTER ENGINE (persists when app killed) ---
    private var backgroundEngine: FlutterEngine? = null
    private var backgroundChannel: MethodChannel? = null

    // --- SETTINGS ---
    private var bubbleSizePx = 100 // Default, will be overwritten
    private var bubbleOpacity = 1.0f
    private var autoHideEnabled = false
    private var doubleTapAction = "QUICK_PANEL"
    private var longPressAction = "OPEN_APP"
    private var shakeEnabled = true
    
    private val autoHideHandler = Handler(Looper.getMainLooper())
    private val autoHideRunnable = Runnable {
        if (overlayView != null && !isCanvasMode) {
             overlayView?.animate()?.alpha(0.0f)?.setDuration(500)?.start()
        }
    }

    // --- STATE ---
    companion object {
        var shortcutLabels: List<String> = emptyList()
        var instance: OverlayService? = null

        fun updateShortcuts(labels: List<String>) {
            shortcutLabels = labels.take(4) // Max 4
            Log.d("OVERLAY_DEBUG", "Shortcuts Updated: $shortcutLabels")
            // Notify active service instance to refresh the Flutter Engine
            instance?.notifyQuickPanelRefresh()
        }
        
        fun refreshBackgroundGestures() {
             instance?.triggerBackgroundRefresh()
        }
        
        fun updateSettings(settings: Map<String, Any>) {
            instance?.applySettings(settings)
        }

        fun updateInputText(text: String) {
            instance?.updateInput(text)
        }

        fun collapseToOverlay() {
            instance?.let {
                Handler(Looper.getMainLooper()).post {
                    it.showOverlay() // Close expanded and go back to bubble
                }
            }
        }

        fun hideGestureView() {
            instance?.hideGestureViewInstance()
        }
    }
    
    fun hideGestureViewInstance() {
         Handler(Looper.getMainLooper()).post {
             if (drawContainer != null) {
                 drawContainer?.visibility = View.GONE
                 Log.d("OVERLAY_DEBUG", "🎨 Gesture View Hidden")
             }
         }
    }
    
    fun updateInput(text: String) {
        Handler(Looper.getMainLooper()).post {
             if (inputField != null) {
                 inputField?.setText(text)
                 inputField?.setSelection(text.length)
             }
        }
    }
    
    fun triggerBackgroundRefresh() {
        if (backgroundChannel != null) {
             backgroundChannel!!.invokeMethod("refreshTemplates", null)
             Log.d("OVERLAY_DEBUG", "🔄 Triggered Background Refresh")
        }
    }

    fun applySettings(settings: Map<String, Any>) {
        val size = (settings["bubbleSize"] as? Number)?.toInt() ?: 35
        val opacity = (settings["opacity"] as? Number)?.toFloat() ?: 1.0f
        val autoHide = (settings["autoHide"] as? Boolean) ?: false
        val shake = (settings["shakeEnabled"] as? Boolean) ?: true // Default true
        doubleTapAction = settings["doubleTapAction"] as? String ?: "QUICK_PANEL"
        longPressAction = settings["longPressAction"] as? String ?: "OPEN_APP"
        
        bubbleSizePx = dpToPx(size)
        bubbleOpacity = opacity
        autoHideEnabled = autoHide
        shakeEnabled = shake
        
        Log.d("OVERLAY_DEBUG", "Settings Applied: Size=$size, Opacity=$opacity, AutoHide=$autoHide, Shake=$shake")
        
        // Refresh Bubble if active
        if (overlayView != null && !isCanvasMode) {
            // Update Opacity
            overlayView?.alpha = bubbleOpacity
            
            // Update Size
            params?.width = bubbleSizePx
            params?.height = bubbleSizePx
            windowManager?.updateViewLayout(overlayView, params)
            
            // Reset AutoHide
            resetAutoHideTimer()
        }
    }
    
    private fun resetAutoHideTimer() {
        autoHideHandler.removeCallbacks(autoHideRunnable)
        if (overlayView != null && bubbleOpacity > 0) {
             overlayView?.alpha = bubbleOpacity // Ensure visible
        }
        
        if (autoHideEnabled && !isCanvasMode) {
            autoHideHandler.postDelayed(autoHideRunnable, 5000) // 5s idle
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }
    
    // Shortcuts View
    private var shortcutsView: View? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        Log.e("OVERLAY_DEBUG", "OverlayService CREATED")
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        // Initialize Shake Sensor
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        
        accelerometer?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            Log.d("OVERLAY_DEBUG", "✅ Shake Detector Registered")
        }
        
        // Initialize Background Flutter Engine for gesture recognition
        initBackgroundEngine()
    }
    
    /**
     * Initialize a headless Flutter engine for background gesture recognition.
     * This engine runs independently and persists even when the main app is killed.
     */
    private fun initBackgroundEngine() {
        if (backgroundEngine != null) {
            Log.d("OVERLAY_DEBUG", "⚠️ Background engine already initialized")
            return
        }
        
        try {
            Log.d("OVERLAY_DEBUG", "🚀 Initializing Background Flutter Engine...")
            
            // Create a new Flutter engine
            backgroundEngine = FlutterEngine(this)
            
            // Configure to run the background entrypoint
            // Use the full library URI to locate the backgroundMain function
            val entrypoint = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "package:gesture_app/main.dart",  // Main Library
                "backgroundEntrypoint"  // New Function name
            )
            
            // Execute the Dart entrypoint
            backgroundEngine!!.dartExecutor.executeDartEntrypoint(entrypoint)
            
            // Register Plugins for background engine
            GeneratedPluginRegistrant.registerWith(backgroundEngine!!)
            
            // Create method channel for communication
            backgroundChannel = MethodChannel(
                backgroundEngine!!.dartExecutor.binaryMessenger,
                "overlay_channel"
            )

            // Listen for Background Ready Signal and updateInputText
            backgroundChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "backgroundReady" -> {
                        Log.e("OVERLAY_DEBUG", "🚀🚀 BACKGROUND ENGINE SIGNALED READY 🚀🚀")
                        result.success(true)
                    }
                    "updateInputText" -> {
                        val text = call.arguments as? String ?: ""
                        Log.d("OVERLAY_DEBUG", "📝 Background updateInputText: $text")
                        updateInput(text)
                        result.success(true)
                    }
                    "hideGestureView" -> {
                        hideGestureViewInstance()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
            
            // Setup Action Channel for background execution
            setupActionChannel(backgroundEngine!!)
            
            Log.d("OVERLAY_DEBUG", "✅ Background Flutter Engine initialized (Wait for Ready Signal)")
        } catch (e: Exception) {
            Log.e("OVERLAY_DEBUG", "❌ Failed to init background engine: $e")
            backgroundEngine = null
            backgroundChannel = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        sensorManager?.unregisterListener(this) // Unregister Sensor
        
        if (overlayView != null) windowManager?.removeView(overlayView)
        if (gestureView != null) windowManager?.removeView(gestureView)
        // ... rest of cleanup
        if (shortcutsView != null) windowManager?.removeView(shortcutsView)
        
        // Clean up Quick Panel Engine
        if (flutterOverlayView != null) {
            windowManager?.removeView(flutterOverlayView)
            flutterOverlayView?.detachFromFlutterEngine()
        }
        quickPanelEngine?.destroy()
        
        // Clean up Background Engine
        backgroundChannel = null
        backgroundEngine?.destroy()
        backgroundEngine = null
        Log.d("OVERLAY_DEBUG", "🧹 Background Engine cleaned up")
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]

            val gX = x / SensorManager.GRAVITY_EARTH
            val gY = y / SensorManager.GRAVITY_EARTH
            val gZ = z / SensorManager.GRAVITY_EARTH

            // gForce will be close to 1 when there is no movement.
            val gForce = sqrt((gX * gX + gY * gY + gZ * gZ).toDouble()).toFloat()

            if (gForce > SHAKE_THRESHOLD_GRAVITY) {
                // 🔴 FIX: Check Setting First!
                if (!shakeEnabled) return

                val now = System.currentTimeMillis()
                // Ignore shake events too close to each other (500ms)
                if (lastShakeTime + SHAKE_SLOP_TIME_MS > now) {
                    return
                }

                // SHAKE DETECTED!
                lastShakeTime = now
                Log.d("OVERLAY_DEBUG", "📳 SHAKE DETECTED! Force: $gForce")
                
                // Trigger Action: Show Expanded Overlay (Canvas)
                // Need to run on Main Thread
                Handler(Looper.getMainLooper()).post {
                    if (!isCanvasMode && shortcutsView == null) {
                        showExpandedOverlay()
                        // Optional: Vibration Feedback
                         val v = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                             v.vibrate(android.os.VibrationEffect.createOneShot(100, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                         } else {
                             v.vibrate(100)
                         }
                    }
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Not implemented
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.e("OVERLAY_DEBUG", "OverlayService STARTED")
        startMyForeground()
        
        // Ensure we start with the bubble
        Handler(Looper.getMainLooper()).post {
             val action = intent?.getStringExtra("ACTION")
             if (action == "SHOW_NOTE") {
                 val text = intent?.getStringExtra("TEXT") ?: ""
                 val status = intent?.getStringExtra("STATUS") ?: ""
                 showNoteBubble(text, status)
             } else {
                 showOverlay()
             }
        }
        
        return START_STICKY
    }

    // ==========================================
    // MODE 1: THE BUBBLE (Small, Draggable)
    // ==========================================
    private fun showOverlay() {
         isCanvasMode = false
         
         // Cleanup other views
         gestureView?.cancelFallbackTimer()
         removeViewSafe(gestureView)
         gestureView = null
         removeViewSafe(shortcutsView)
         shortcutsView = null
         removeViewSafe(closeButton)
         closeButton = null
         removeViewSafe(expandedContainer) // Cleanup Panel
         expandedContainer = null

         // Remove existing Bubble if exists
         removeViewSafe(overlayView)

        // --- CYBERPUNK UI: CONCENTRIC CIRCLES ---
        val outerSize = if (bubbleSizePx > 0) bubbleSizePx else dpToPx(35)
        val innerSize = (outerSize * 0.35).toInt()
        
        val rootLayout = FrameLayout(this)
        val outerBackground = GradientDrawable()
        outerBackground.shape = GradientDrawable.OVAL
        outerBackground.setColor(Color.parseColor("#121212")) // Dark Theme
        outerBackground.setStroke(dpToPx(1), Color.parseColor("#333333"))
        rootLayout.background = outerBackground
        rootLayout.elevation = 15f
        rootLayout.alpha = bubbleOpacity // Apply Opacity
        
        val innerCircle = View(this)
        val innerBackground = GradientDrawable()
        innerBackground.shape = GradientDrawable.OVAL
        innerBackground.setColor(Color.parseColor("#00FF41")) // Neo Green
        innerCircle.background = innerBackground
        
        val innerParams = FrameLayout.LayoutParams(innerSize, innerSize)
        innerParams.gravity = Gravity.CENTER
        rootLayout.addView(innerCircle, innerParams)

        this.overlayView = rootLayout

        params = WindowManager.LayoutParams(
            outerSize,
            outerSize,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )

        params?.gravity = Gravity.TOP or Gravity.START
        // Restore last known position if possible, else default
        params?.x = lastBubbleX
        params?.y = lastBubbleY
        
        // Start AutoHide Timer
        resetAutoHideTimer()

        // --- DRAG + CLICK + DOUBLE TAP LOGIC ---
        rootLayout.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isClick = false
            private var lastClickTime: Long = 0
            
            // Fix for Double Tap Glitch
            private val handler = Handler(Looper.getMainLooper())
            private var pendingRunnable: Runnable? = null
            
            // Long Press Logic
            private var isLongPress = false
            private val longPressRunnable = Runnable {
                isLongPress = true
                isClick = false
                
                // HAPTIC FEEDBACK
                val v = getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(android.os.VibrationEffect.createOneShot(50, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    v.vibrate(50)
                }

                // ACTION
                when (longPressAction) {
                    "OPEN_APP" -> {
                        openMainActivity()
                        rootLayout.alpha = 1.0f 
                    }
                    "QUICK_PANEL" -> {
                        showQuickPanel()
                        rootLayout.alpha = 1.0f 
                    }
                    "NONE" -> {
                         // Do nothing, just visual feedback
                         rootLayout.alpha = bubbleOpacity
                    }
                    else -> rootLayout.alpha = bubbleOpacity
                }
            }

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params!!.x
                        initialY = params!!.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isClick = true 
                        isLongPress = false
                        rootLayout.alpha = bubbleOpacity // Reset Alpha
                        
                        resetAutoHideTimer() // Reset Timer

                        // Start Long Press Timer
                        handler.postDelayed(longPressRunnable, 600) // 600ms hold
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        // Cancel Long Press if released currently
                        handler.removeCallbacks(longPressRunnable)
                        
                        rootLayout.alpha = bubbleOpacity
                        
                        // Only process click if NOT a long press and NOT a drag
                        if (isClick && !isLongPress) {
                            val currentTime = System.currentTimeMillis()
                            if (currentTime - lastClickTime < 300) {
                                // DOUBLE TAP
                                pendingRunnable?.let { handler.removeCallbacks(it) }
                                
                                if (doubleTapAction == "QUICK_PANEL") {
                                    showQuickPanel()
                                } else if (doubleTapAction == "CANVAS") {
                                    showExpandedOverlay()
                                }
                            } else {
                                // SINGLE TAP (Wait for potential double tap)
                                lastClickTime = currentTime
                                
                                pendingRunnable = Runnable {
                                    if (!isCanvasMode && shortcutsView == null) {
                                         showExpandedOverlay()
                                    }
                                }
                                handler.postDelayed(pendingRunnable!!, 250)
                            }
                        }
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        
                        // If moved significantly, cancel click AND long press
                        if (abs(dx) > 10 || abs(dy) > 10) {
                            isClick = false
                            handler.removeCallbacks(longPressRunnable)
                        }

                        params!!.x = initialX + dx
                        params!!.y = initialY + dy
                        
                        // Save Position
                        lastBubbleX = params!!.x
                        lastBubbleY = params!!.y
                        
                        windowManager?.updateViewLayout(overlayView, params)
                        return true
                    }
                }
                return false
            }
        })

        addViewSafe(this.overlayView, params)
    }

    // Persist position
    private var lastBubbleX = 50
    private var lastBubbleY = 300

    // ==========================================
    // MODE 2: EXPANDED OVERLAY (Unified: Text Top / Draw Bottom)
    // ==========================================
    private var expandedContainer: LinearLayout? = null
    private var inputField: EditText? = null
    private var drawContainer: FrameLayout? = null

    private fun showExpandedOverlay() {
        isCanvasMode = true
        
        // Remove Bubble
        removeViewSafe(overlayView)
        overlayView = null
        
        // Create Main Container (Full Screen)
        val container = LinearLayout(this)
        container.orientation = LinearLayout.VERTICAL
        container.setBackgroundColor(Color.parseColor("#EE000000")) // 93% Black
        container.setOnClickListener { 
             // Catch clicks to prevent passing through
             showOverlay() // Corrected from closeExpandedOverlay
        }
        
        // --- 1. TEXT INPUT AREA (Top) ---
        val inputContainer = FrameLayout(this)
        inputContainer.setPadding(dpToPx(20), dpToPx(50), dpToPx(20), dpToPx(20))
        inputContainer.setBackgroundColor(Color.parseColor("#222222")) // Dark Gray Header
        
        inputField = EditText(this)
        inputField?.hint = "Type shortcut..."
        inputField?.setHintTextColor(Color.GRAY)
        inputField?.setTextColor(Color.WHITE)
        inputField?.textSize = 18f
        inputField?.background = null // Remove underline
        inputField?.inputType = InputType.TYPE_CLASS_TEXT
        inputField?.imeOptions = EditorInfo.IME_ACTION_GO
        
        inputField?.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_GO || actionId == EditorInfo.IME_ACTION_DONE) {
                val text = inputField?.text.toString()
                if (text.isNotEmpty()) {
                    sendTextTriggerToFlutter(text) // Corrected from processGesture
                    showOverlay()
                }
                true
            } else {
                false
            }
        }
        
        inputContainer.addView(inputField)
        container.addView(inputContainer, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))
        
        // --- 2. DRAW AREA (Bottom) ---
        val drawLayout = FrameLayout(this)
        drawContainer = drawLayout
        
        val drawParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            0, 
            1f // Fill remaining space
        )
        drawParams.setMargins(dpToPx(20), dpToPx(20), dpToPx(20), dpToPx(20))
        
        gestureView = GestureView(this)
        gestureView!!.setBackgroundColor(Color.TRANSPARENT) // Or subtle border
        
        // Visual Hint for Draw Area
        val border = GradientDrawable()
        border.setColor(Color.parseColor("#0500FF41")) // Extremely subtle green tint
        border.setStroke(dpToPx(2), Color.parseColor("#00FF41")) // Thicker Neon Green Border
        border.cornerRadius = dpToPx(16).toFloat()
        drawLayout.background = border
        
        drawLayout.addView(gestureView)
        
        // Hint Text inside Draw Area
        val hintText = TextView(this)
        hintText.text = "Draw Gesture Here"
        hintText.setTextColor(Color.parseColor("#55FFFFFF"))
        hintText.gravity = Gravity.CENTER
        drawLayout.addView(hintText, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ))
        
        container.addView(drawLayout, drawParams)
        
        this.expandedContainer = container
        
        // --- WINDOW PARAMS ---
        // We need focus for EditText, but logic to handle "Outside Touch" is harder with FOCUSABLE.
        // For now, we enable focus (USER request: Text Input available)
        val windowParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, 
            PixelFormat.TRANSLUCENT
        )
        windowParams.dimAmount = 0.8f
        // windowParams.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE // Optional: Auto-keyboard

        addViewSafe(expandedContainer, windowParams)
        
        // --- ADD CLOSE BUTTON ---
        addCloseButton()
    }
    
    // Custom Gesture View with Debounce and Point Tracking
    private inner class GestureView(context: Context) : View(context) {
        private val path = Path()
        private val paint = Paint().apply {
            color = Color.parseColor("#00FF41") // Neon Green
            style = Paint.Style.STROKE
            strokeWidth = 12f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            isAntiAlias = true
        }
        
        // Persistent Handler for Debouncing
        private val mainHandler = Handler(Looper.getMainLooper())
        private var fallbackRunnable: Runnable? = null
        
        fun cancelFallbackTimer() {
            fallbackRunnable?.let {
                mainHandler.removeCallbacks(it)
                fallbackRunnable = null
                Log.d("OVERLAY_DEBUG", "🚫 Fallback timer cancelled")
            }
        }
        
        // Track points for Flutter (Separator: {-1.0, -1.0})
        private val points = ArrayList<Map<String, Float>>()
        
        private var startTime: Long = 0
        private val STROKE_TIMEOUT = 1500L // Increased to 1.5s for Multi-Stroke Handwriting
        
        private val closeRunnable = Runnable {
            Log.d("OVERLAY_DEBUG", "⏰ Timeout reached, processing gesture...")
            if (points.isNotEmpty()) {
                val pointsToSend = ArrayList(points)
                sendGestureToFlutter(pointsToSend)
                
                // Clear drawing state
                path.reset()
                points.clear()
                invalidate()
                
                // DON'T close overlay immediately - wait for OCR to show result
                // Flutter will call collapseOverlay() if a match is successful.
                // If no match is found, we want the drawpad to stay open so the user can try again.
            } else {
                Log.d("OVERLAY_DEBUG", "⏰ Timeout reached but points empty.")
            }
        }

        override fun onDraw(canvas: Canvas) {
            canvas.drawPath(path, paint)
        }
        
        fun clear() {
            mainHandler.removeCallbacks(closeRunnable)
            path.reset()
            points.clear()
            invalidate()
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            val x = event.x
            val y = event.y
            
            // RESET TIMER ON ANY TOUCH
            mainHandler.removeCallbacks(closeRunnable)
            Log.v("OVERLAY_DEBUG", "Timer Cancelled (Touch Event)")

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    Log.d("OVERLAY_DEBUG", "👇 Touch Down: $x, $y")
                    if (points.isNotEmpty()) {
                        // Continuing gesture (New Stroke)
                        path.moveTo(x, y)
                        points.add(mapOf("x" to -1f, "y" to -1f)) // Logical Separator
                    } else {
                        // New Gesture
                        path.moveTo(x, y)
                        points.clear() // Should be empty anyway
                    }
                    
                    points.add(mapOf("x" to x, "y" to y))
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    path.lineTo(x, y)
                    points.add(mapOf("x" to x, "y" to y))
                    invalidate()
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    Log.d("OVERLAY_DEBUG", "☝️ Touch Up, starting timer ($STROKE_TIMEOUT ms)")
                    // Start Timer to Close/Send
                    mainHandler.postDelayed(closeRunnable, STROKE_TIMEOUT)
                    return true
                }
            }
            return false
        }
    }
    
    private fun sendGestureToFlutter(points: List<Map<String, Float>>) {
         try {
            Log.d("OVERLAY_DEBUG", "📤 Attempting to send ${points.size} points to Flutter...")
            
            // Try main app engine first (works when app is running)
            val engine = FlutterEngineCache.getInstance().get("my_engine_id")
            if (engine != null) {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "overlay_channel")
                channel.invokeMethod("onGestureDrawn", points)
                Log.d("OVERLAY_DEBUG", "✅ Sent ${points.size} points via Main Engine")
                return
            }
            
            // Fallback to background engine (persists when app killed)
            if (backgroundChannel != null) {
                backgroundChannel!!.invokeMethod("onGestureDrawn", points)
                Log.d("OVERLAY_DEBUG", "✅ Sent ${points.size} points via Background Engine (fallback)")
                return
            }
            
            Log.e("OVERLAY_DEBUG", "❌ No Flutter Engine available! Attempting restart...")
            
            // 🔴 AUTO-RESTART ENGINE
            Handler(Looper.getMainLooper()).post {
                 initBackgroundEngine()
            }
        } catch (e: Exception) {
            Log.e("OVERLAY_DEBUG", "❌ Error sending gesture: $e")
        }
    }


    private fun addCloseButton() {
        val container = LinearLayout(this)
        container.orientation = LinearLayout.HORIZONTAL
        container.gravity = Gravity.CENTER
        
        // --- 1. CLEAR BUTTON (Reload) ---
        val clearBtn = TextView(this)
        clearBtn.text = "🔄" // Reload Icon
        clearBtn.textSize = 24f
        clearBtn.setTextColor(Color.WHITE)
        clearBtn.gravity = Gravity.CENTER
        
        val clearBg = GradientDrawable()
        clearBg.shape = GradientDrawable.OVAL
        clearBg.setColor(Color.parseColor("#44000000")) 
        clearBg.setStroke(2, Color.YELLOW)
        clearBtn.background = clearBg
        
        clearBtn.setOnClickListener {
             // Clear Canvas
             (gestureView as? GestureView)?.clear()
        }
        
        val clearParams = LinearLayout.LayoutParams(dpToPx(50), dpToPx(50))
        clearParams.setMargins(0, 0, dpToPx(20), 0) // Margin Right
        container.addView(clearBtn, clearParams)
        
        // --- 2. CLOSE BUTTON ---
        val closeBtn = TextView(this)
        closeBtn.text = "✖"
        closeBtn.textSize = 24f
        closeBtn.setTextColor(Color.WHITE)
        closeBtn.gravity = Gravity.CENTER
        
        val closeBg = GradientDrawable()
        closeBg.shape = GradientDrawable.OVAL
        closeBg.setColor(Color.parseColor("#44000000")) 
        closeBg.setStroke(2, Color.RED)
        closeBtn.background = closeBg
        
        closeBtn.setOnClickListener {
            showOverlay() // Back to Bubble
        }
        
        val closeParams = LinearLayout.LayoutParams(dpToPx(50), dpToPx(50))
        container.addView(closeBtn, closeParams)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        params.y = dpToPx(50) 
        
        this.closeButton = container
        addViewSafe(closeButton, params)
    }
    
    // Track close button
    private var closeButton: View? = null

    // ==========================================
    // MODE 5: NOTE BUBBLE (Text Display)
    // ==========================================
    private var noteInput: EditText? = null
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var wasCallActive = false 

    private fun showNoteBubble(text: String, status: String = "") {
        // Clear existing
        removeViewSafe(overlayView)
        overlayView = null
        removeViewSafe(gestureView)
        gestureView = null
        removeViewSafe(shortcutsView)
        shortcutsView = null
        removeViewSafe(closeButton)
        closeButton = null
        removeViewSafe(expandedContainer)
        expandedContainer = null

        val card = LinearLayout(this)
        card.orientation = LinearLayout.VERTICAL
        card.setPadding(35, 35, 35, 35)
        
        val bg = GradientDrawable()
        bg.setColor(Color.parseColor("#EE121212")) // Semi-transparent Dark
        bg.cornerRadius = dpToPx(16).toFloat()
        bg.setStroke(dpToPx(2), Color.parseColor("#00FF41")) // Neon Green Border
        card.background = bg
        
        // 1. STATUS HEADER (System Info)
        if (status.isNotEmpty()) {
            val statusView = TextView(this)
            statusView.text = status.uppercase()
            statusView.textSize = 12f
            statusView.setTypeface(null, android.graphics.Typeface.BOLD)
            statusView.setTextColor(Color.parseColor("#00FF41")) // Neo Green
            statusView.gravity = Gravity.CENTER_HORIZONTAL
            statusView.setPadding(0, 0, 0, 10)
            card.addView(statusView)
        }
        
        // 2. STATIC HEADER
        val header = TextView(this)
        header.text = "NOTES"
        header.textSize = 10f
        header.setTextColor(Color.LTGRAY)
        header.gravity = Gravity.CENTER_HORIZONTAL
        card.addView(header)
        
        // 3. EDITABLE NOTE INPUT (User Data)
        val input = EditText(this)
        input.setText(text) // ONLY the note content
        input.hint = "Tap to add notes..."
        input.setTextColor(Color.WHITE)
        input.setHintTextColor(Color.GRAY)
        input.textSize = 16f
        input.gravity = Gravity.TOP or Gravity.START
        input.background = null // Remove underline
        input.minLines = 4 
        input.maxLines = 6
        input.isVerticalScrollBarEnabled = true
        input.inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        
        // FOCUS LOGIC
        input.setOnClickListener { enableInputFocus() }
        input.setOnFocusChangeListener { _, hasFocus -> if (hasFocus) enableInputFocus() }

        card.addView(input)
        this.noteInput = input
        
        // Save & Close Button
        val btnSave = Button(this)
        btnSave.text = "SAVE & CLOSE"
        btnSave.textSize = 12f
        btnSave.setTextColor(Color.BLACK)
        btnSave.setTypeface(null, android.graphics.Typeface.BOLD)

        val btnBg = GradientDrawable()
        btnBg.setColor(Color.parseColor("#00FF41")) // Neon Green Button
        btnBg.cornerRadius = dpToPx(20).toFloat()
        btnSave.background = btnBg

        val btnParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        btnParams.setMargins(0, dpToPx(10), 0, 0)
        
        btnSave.setOnClickListener {
             saveNoteAndClose()
        }
        card.addView(btnSave, btnParams)

        this.shortcutsView = card 

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = 100
        params.y = 300 
        
        // Make draggable
        card.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()
                        params.x = initialX + dx
                        params.y = initialY + dy
                        windowManager?.updateViewLayout(card, params)
                        return true
                    }
                }
                return false
            }
        })

        addViewSafe(card, params)
        
        // Start Call Monitoring
        startCallMonitoring()
    }


    private fun enableInputFocus() {
        if (shortcutsView == null) return
        try {
            val params = shortcutsView!!.layoutParams as WindowManager.LayoutParams
            params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()
            windowManager?.updateViewLayout(shortcutsView, params)
            
            // Force Show Keyboard
            // val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager
            // imm.showSoftInput(noteInput, android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT)
        } catch (e: Exception) { Log.e("OVERLAY_DEBUG", "Focus Error: $e") }
    }
    
    private fun saveNoteAndClose() {
        val text = noteInput?.text?.toString() ?: ""
        // Send to Flutter
        sendNoteSavedToFlutter(text)
        // Clean up listeners
        stopCallMonitoring()
        // Close
        showOverlay()
    }

    private fun sendNoteSavedToFlutter(text: String) {
        try {
            Handler(Looper.getMainLooper()).post {
                 val engine = FlutterEngineCache.getInstance().get("my_engine_id")
                 if (engine != null) {
                    val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "overlay_channel")
                    channel.invokeMethod("onNoteSaved", text)
                    Log.d("OVERLAY_DEBUG", "Note Saved sent to Flutter: $text")
                 }
            }
        } catch (e: Exception) {
            Log.e("OVERLAY_DEBUG", "Error sending note: $e")
        }
    }

    private fun startCallMonitoring() {
        if (telephonyManager == null) {
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        }
        
        if (phoneStateListener == null) {
            phoneStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    super.onCallStateChanged(state, phoneNumber)
                    Log.d("OVERLAY_DEBUG", "📞 Call State Changed: $state")
                    
                    if (state == TelephonyManager.CALL_STATE_OFFHOOK) {
                        wasCallActive = true
                        Log.d("OVERLAY_DEBUG", "📞 Call Active (OFFHOOK). Auto-Save Armed.")
                    } else if (state == TelephonyManager.CALL_STATE_IDLE) {
                        if (wasCallActive) {
                            Log.d("OVERLAY_DEBUG", "✅ Call Ended (IDLE) -> Triggering Auto-Save")
                             Handler(Looper.getMainLooper()).post {
                                 saveNoteAndClose()
                            }
                        } else {
                            Log.d("OVERLAY_DEBUG", "⚠️ Initial IDLE state ignored (Call hasn't started yet)")
                        }
                    }
                }
            }
        }
        
        // Reset state
        wasCallActive = false
        
        try {
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
        } catch (e: SecurityException) {
            Log.e("OVERLAY_DEBUG", "Permission Missing for Phone State: $e")
        }
    }

    private fun stopCallMonitoring() {
        try {
             telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        } catch (e: Exception) {}
    }

    // ==========================================
    // MODE 3: SHORTCUTS PANEL
    // ==========================================
    private fun showShortcuts() {
        // Clear all
        removeViewSafe(overlayView)
        overlayView = null
        removeViewSafe(gestureView)
        gestureView = null
        removeViewSafe(closeButton)
        closeButton = null

        val panel = android.widget.LinearLayout(this)
        panel.orientation = android.widget.LinearLayout.VERTICAL
        panel.setPadding(30, 30, 30, 30)
        
        val bg = GradientDrawable()
        bg.setColor(Color.parseColor("#EE1E1E1E"))
        bg.cornerRadius = dpToPx(16).toFloat()
        bg.setStroke(2, Color.parseColor("#00FF41"))
        panel.background = bg
        
        // Title
        val title = android.widget.TextView(this)
        title.text = "SHORTCUTS"
        title.setTextColor(Color.GRAY)
        title.textSize = 12f
        title.gravity = Gravity.CENTER
        panel.addView(title)
        
        // Buttons
        if (shortcutLabels.isEmpty()) {
            val empty = android.widget.TextView(this)
            empty.text = "No shortcuts set"
            empty.setTextColor(Color.WHITE)
            empty.setPadding(0, 20, 0, 20)
            panel.addView(empty)
        } else {
            shortcutLabels.forEachIndexed { index, name ->
                val btn = android.widget.Button(this)
                btn.text = name
                btn.setTextColor(Color.WHITE)
                btn.setBackgroundColor(Color.TRANSPARENT)
                btn.setOnClickListener {
                    sendShortcutClick(index)
                    showOverlay() 
                }
                panel.addView(btn)
            }
        }
        
        // Close Panel Button
        val closePanel = android.widget.Button(this)
        closePanel.text = "CLOSE"
        closePanel.setTextColor(Color.RED)
        closePanel.setBackgroundColor(Color.TRANSPARENT)
        closePanel.setOnClickListener { showOverlay() }
        panel.addView(closePanel)

        this.shortcutsView = panel
        
        val panelParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, // Adaptive width
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        panelParams.gravity = Gravity.TOP or Gravity.START
        panelParams.x = lastBubbleX
        panelParams.y = lastBubbleY
        
        // --- DRAG LOGIC FOR SHORTCUTS ---
        panel.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                 when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = panelParams.x
                        initialY = panelParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()

                        panelParams.x = initialX + dx
                        panelParams.y = initialY + dy
                        
                        // Update Persisted Position? Maybe user wants bubble to move here too?
                        // For now let's just move the panel.
                        // lastBubbleX = panelParams.x
                        // lastBubbleY = panelParams.y

                        windowManager?.updateViewLayout(shortcutsView, panelParams)
                        return true
                    }
                }
                return false
            }
        })
        
        addViewSafe(panel, panelParams)
    }




    
    // ==========================================
    // MODE 4: QUICK ACTION PANEL (FLUTTER UI)
    // ==========================================
    private var quickPanelEngine: FlutterEngine? = null
    private var flutterOverlayView: FlutterView? = null

    private fun initQuickPanelEngine() {
        if (quickPanelEngine == null) {
            quickPanelEngine = FlutterEngine(this)
            // Start executing the "overlayMain" entry point
            quickPanelEngine!!.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "overlayMain"
                )
            )
            Log.e("OVERLAY_DEBUG", "⚡ Quick Panel Engine Started")
            
            // Setup Channel
            MethodChannel(quickPanelEngine!!.dartExecutor.binaryMessenger, "overlay_channel").setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeQuickPanel" -> {
                        closeQuickPanel()
                        result.success(true)
                    }
                    "getRecentCalls" -> {
                        val calls = fetchFrequentContacts()
                        result.success(calls)
                    }
                    "getTopApps" -> {
                        val apps = fetchTopApps()
                        result.success(apps)
                    }
                    "checkUsagePermission" -> {
                         val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
                         val mode = appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                         result.success(mode == android.app.AppOpsManager.MODE_ALLOWED)
                    }
                    "updateOverlaySettings" -> {
                        val args = call.arguments as? Map<String, Any>
                        if (args != null) {
                            OverlayService.updateSettings(args)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Arguments null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            // Setup Action Channel
            MethodChannel(quickPanelEngine!!.dartExecutor.binaryMessenger, "action_channel").setMethodCallHandler { call, result ->
                handleAction(call, result)
            }
        }
    }

    // Notify Quick Panel to reload data (called from static updateShortcuts)
    fun notifyQuickPanelRefresh() {
        if (quickPanelEngine != null) {
            Handler(Looper.getMainLooper()).post {
                 MethodChannel(quickPanelEngine!!.dartExecutor.binaryMessenger, "overlay_channel")
                    .invokeMethod("refreshData", null)
            }
        }
    }

    private fun fetchFrequentContacts(): List<Map<String, Any>> {
        val contacts = ArrayList<Map<String, Any>>()
        
        Log.d("OVERLAY_DEBUG", "🔍 fetchFrequentContacts started")

        val hasPermission = androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CONTACTS) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (!hasPermission) {
            Log.e("OVERLAY_DEBUG", "❌ Contacts permission denied")
            contacts.add(mapOf("name" to "Permission Denied", "number" to "Enable Contacts in Settings", "timesContacted" to 0))
            return contacts
        }
        
        try {
            // First: Get starred (favorite) contacts
            val starredCursor = contentResolver.query(
                android.provider.ContactsContract.Contacts.CONTENT_URI,
                arrayOf(
                    android.provider.ContactsContract.Contacts._ID,
                    android.provider.ContactsContract.Contacts.DISPLAY_NAME,
                    android.provider.ContactsContract.Contacts.STARRED,
                    android.provider.ContactsContract.Contacts.HAS_PHONE_NUMBER
                ),
                "${android.provider.ContactsContract.Contacts.STARRED} = 1 AND ${android.provider.ContactsContract.Contacts.HAS_PHONE_NUMBER} = 1",
                null,
                null
            )

            val seenNumbers = HashSet<String>()

            starredCursor?.use { cursor ->
                val idIdx = cursor.getColumnIndex(android.provider.ContactsContract.Contacts._ID)
                val nameIdx = cursor.getColumnIndex(android.provider.ContactsContract.Contacts.DISPLAY_NAME)

                while (cursor.moveToNext() && contacts.size < 8) {
                    val contactId = cursor.getString(idIdx) ?: continue
                    val name = cursor.getString(nameIdx) ?: "Unknown"
                    
                    // Get the phone number for this contact
                    val phoneCursor = contentResolver.query(
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER),
                        "${android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                        arrayOf(contactId),
                        null
                    )

                    phoneCursor?.use { pc ->
                        if (pc.moveToFirst()) {
                            val number = pc.getString(0)?.replace("\\s".toRegex(), "") ?: ""
                            if (number.isNotEmpty() && !seenNumbers.contains(number)) {
                                seenNumbers.add(number)
                                contacts.add(mapOf(
                                    "name" to name,
                                    "number" to number,
                                    "timesContacted" to 999 // starred contacts get highest priority
                                ))
                            }
                        }
                    }
                }
            }

            // Then: Fill remaining slots with contacts that have phone numbers (most recently updated)
            if (contacts.size < 8) {
                val recentCursor = contentResolver.query(
                    android.provider.ContactsContract.Contacts.CONTENT_URI,
                    arrayOf(
                        android.provider.ContactsContract.Contacts._ID,
                        android.provider.ContactsContract.Contacts.DISPLAY_NAME,
                        android.provider.ContactsContract.Contacts.HAS_PHONE_NUMBER
                    ),
                    "${android.provider.ContactsContract.Contacts.HAS_PHONE_NUMBER} = 1 AND ${android.provider.ContactsContract.Contacts.STARRED} = 0",
                    null,
                    "${android.provider.ContactsContract.Contacts.LAST_TIME_CONTACTED} DESC"
                )

                recentCursor?.use { cursor ->
                    val idIdx = cursor.getColumnIndex(android.provider.ContactsContract.Contacts._ID)
                    val nameIdx = cursor.getColumnIndex(android.provider.ContactsContract.Contacts.DISPLAY_NAME)

                    while (cursor.moveToNext() && contacts.size < 8) {
                        val contactId = cursor.getString(idIdx) ?: continue
                        val name = cursor.getString(nameIdx) ?: "Unknown"

                        val phoneCursor = contentResolver.query(
                            android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            arrayOf(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER),
                            "${android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                            arrayOf(contactId),
                            null
                        )

                        phoneCursor?.use { pc ->
                            if (pc.moveToFirst()) {
                                val number = pc.getString(0)?.replace("\\s".toRegex(), "") ?: ""
                                if (number.isNotEmpty() && !seenNumbers.contains(number)) {
                                    seenNumbers.add(number)
                                    contacts.add(mapOf(
                                        "name" to name,
                                        "number" to number,
                                        "timesContacted" to 0
                                    ))
                                }
                            }
                        }
                    }
                }
            }

            Log.d("OVERLAY_DEBUG", "✅ Fetched ${contacts.size} frequent contacts")
        } catch (e: Exception) {
            Log.e("OVERLAY_DEBUG", "❌ CRASH: ${e.message}")
            contacts.add(mapOf("name" to "Error", "number" to (e.message ?: "Unknown"), "timesContacted" to 0))
        }
        return contacts
    }

    private fun fetchTopApps(): List<Map<String, Any>> {
        val apps = ArrayList<Map<String, Any>>()
        
        // Re-check permission explicitly
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        val mode = appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        
        if (mode != android.app.AppOpsManager.MODE_ALLOWED) {
             Log.e("OVERLAY_DEBUG", "❌ Usage Stats Permission Denied (Re-checked)")
             apps.add(mapOf("packageName" to "PERMISSION_ERROR", "appName" to "Grant Access", "usageTime" to 0L))
             return apps
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
        val time = System.currentTimeMillis()
        
        val stats = usageStatsManager.queryUsageStats(
            android.app.usage.UsageStatsManager.INTERVAL_WEEKLY,
            time - 1000 * 60 * 60 * 24 * 7,
            time
        )
        
        if (stats != null) {
            val sorted = stats.sortedByDescending { it.totalTimeInForeground }.take(10)
            val pm = packageManager
            for (usage in sorted) {
                try {
                    val info = pm.getApplicationInfo(usage.packageName, 0)
                    val label = pm.getApplicationLabel(info).toString()
                    val iconBytes = getAppIconBytes(usage.packageName)

                    apps.add(mapOf(
                        "packageName" to usage.packageName,
                        "appName" to label,
                        "usageTime" to usage.totalTimeInForeground,
                        "icon" to (iconBytes ?: ByteArray(0))
                    ))
                } catch (e: Exception) {}
            }
        }
        return apps
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
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 75, stream) // 75 quality for speed
            return stream.toByteArray()
        } catch (e: Exception) {
            return null
        }
    }

    private fun showQuickPanel() {
        initQuickPanelEngine() // Ensure started
        
        // 🔥 FORCE ENGINE TO RESUME RENDRING
        quickPanelEngine?.lifecycleChannel?.appIsResumed()

        // 🔄 Force Data Refresh (In case permissions changed)
        notifyQuickPanelRefresh()

        // Remove Bubble
        removeViewSafe(overlayView)
        overlayView = null

        // Remove others
        removeViewSafe(gestureView)
        removeViewSafe(expandedContainer)

        // Create Flutter View
        // Use FlutterView with Texture mode for transparency
        flutterOverlayView = FlutterView(this, FlutterTextureView(this))
        flutterOverlayView!!.attachToFlutterEngine(quickPanelEngine!!)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL, // Allow focus for back handling?
            PixelFormat.TRANSLUCENT
        )
        // params.flags = params.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv() // Focusable

        addViewSafe(flutterOverlayView, params)
    }

    // Call this if Flutter requests close
    private fun closeQuickPanel() {
         removeViewSafe(flutterOverlayView)
         flutterOverlayView?.detachFromFlutterEngine()
         flutterOverlayView = null
         showOverlay() // Back to bubble
    }
    private fun sendTextTriggerToFlutter(text: String) {
         try {
            val engine = FlutterEngineCache.getInstance().get("my_engine_id")
            if (engine != null) {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "overlay_channel")
                channel.invokeMethod("onTextTrigger", text)
                Log.e("OVERLAY_DEBUG", "🚀 Text Trigger sent: $text")
                return
            }
            
            if (backgroundChannel != null) {
                 backgroundChannel!!.invokeMethod("onTextTrigger", text)
                 Log.e("OVERLAY_DEBUG", "🚀 Text Trigger sent via Background: $text")
            } else {
                 Log.e("OVERLAY_DEBUG", "❌ No Engine available for Text Trigger!")
            }
        } catch (e: Exception) {}
    }

    private fun sendShortcutClick(index: Int) {
         try {
            val engine = FlutterEngineCache.getInstance().get("my_engine_id")
            if (engine != null) {
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "overlay_channel")
                channel.invokeMethod("onShortcutClicked", index)
                Log.e("OVERLAY_DEBUG", "🚀 Shortcut $index sent")
                return
            }
            
             if (backgroundChannel != null) {
                 backgroundChannel!!.invokeMethod("onShortcutClicked", index)
                 Log.e("OVERLAY_DEBUG", "🚀 Shortcut $index sent via Background")
            }
        } catch (e: Exception) {}
    }

    private fun startMyForeground() {
        val channelId = "overlay_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Gesture Overlay",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Gesture Overlay Active")
            .setContentText("Tap overlay to draw")
            .setSmallIcon(android.R.drawable.btn_star_big_on)
            .build()
            
        startForeground(999, notification)
    }

    private fun dpToPx(dp: Int): Int {
        val density = resources.displayMetrics.density
        return (dp * density).toInt()
    }
    
    private fun addViewSafe(view: View?, params: WindowManager.LayoutParams?) {
        if (view != null && params != null) {
            try { windowManager?.addView(view, params) } catch (e: Exception) {}
        }
    }
    
    private fun removeViewSafe(view: View?) {
        if (view != null) {
            try { windowManager?.removeView(view) } catch (e: Exception) {}
        }
    }

    private var isFlashlightOn = false

    private fun handleAction(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
         if (call.method == "executeAction") {
             val args = call.arguments as? Map<String, String>
             val type = args?.get("type")
             val value = args?.get("value")
             Log.d("OVERLAY_DEBUG", "🎬 handleAction: type=$type, value=$value")
             
             when(type) {
                 "flashlight" -> {
                      try {
                          val camManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                          val cameraId = camManager.cameraIdList[0]
                          isFlashlightOn = !isFlashlightOn
                          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                               camManager.setTorchMode(cameraId, isFlashlightOn)
                          }
                          result.success(true) 
                      } catch (e: Exception) { result.error("ERR", e.message, null) }
                 }
                 "wifi" -> {
                      startActivity(Intent(android.provider.Settings.ACTION_WIFI_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                      result.success(true)
                 }
                 "bluetooth" -> {
                      startActivity(Intent(android.provider.Settings.ACTION_BLUETOOTH_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                      result.success(true)
                 }
                 "settings" -> {
                      if (value == "usage") {
                          startActivity(Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                          result.success(true)
                      }
                 }
                 "call" -> {
                      if (androidx.core.content.ContextCompat.checkSelfPermission(this, android.Manifest.permission.CALL_PHONE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                           val intent = Intent(Intent.ACTION_CALL)
                           intent.data = android.net.Uri.parse("tel:$value")
                           intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                           startActivity(intent)
                           result.success(true)
                      } else {
                           val intent = Intent(Intent.ACTION_DIAL)
                           intent.data = android.net.Uri.parse("tel:$value")
                           intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                           startActivity(intent)
                           result.success(true)
                      }
                 }
                 "app" -> {
                      try {
                          val launchIntent = packageManager.getLaunchIntentForPackage(value ?: "")
                          if (launchIntent != null) {
                              launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                              startActivity(launchIntent)
                              result.success(true)
                          } else {
                              result.error("NOT_FOUND", "App not found", null)
                          }
                      } catch(e: Exception) { result.error("ERR", e.message, null) }
                 }
                 else -> result.notImplemented()
             }
         } else {
             result.notImplemented()
         }
    }

    private fun openMainActivity() {
         try {
             val intent = packageManager.getLaunchIntentForPackage(packageName)
             if (intent != null) {
                 intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                 startActivity(intent)
                 Log.d("OVERLAY_DEBUG", "🚀 Opening Main Activity from Bubble")
             }
         } catch (e: Exception) {
             Log.e("OVERLAY_DEBUG", "Error opening app: ${e.message}")
         }
    }

    private fun setupActionChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "action_channel").setMethodCallHandler { call, result ->
             handleAction(call, result)
        }
    }
}


