/// LOGGING EXAMPLES - How to use LoggerService in GestureApp
/// 
/// Before: print("🔄 Starting gesture sync...");
/// After:  Log.i("Starting gesture sync", "GestureProvider");
///
/// Replace print() calls with structured logging:

// EXAMPLE 1: Debug Info
// Before: debugPrint("📥 Loading gestures from database...");
// After:  Log.d("Loading gestures from database", "GestureProvider");

// EXAMPLE 2: API Calls
// Before: print('🌐 REQUEST: POST https://servermine.com/api/gestures');
// After:  Log.i("POST /api/gestures", "ApiService");

// EXAMPLE 3: Errors
// Before: print("❌ Error: Failed to save gesture: $e");
// After:  Log.e("Failed to save gesture", "GestureProvider", stackTrace);

// EXAMPLE 4: Info Messages
// Before: print('✅ Gesture saved successfully');
// After:  Log.i("Gesture saved successfully", "GestureProvider");

// EXAMPLE 5: Warnings
// Before: print('⚠️ No network connection');
// After:  Log.w("No network connection", "NetworkService");

/*
IMPLEMENTATION GUIDE:
====================

1. Import the logger in any file:
   import 'package:gesture_app/core/services/logger_service.dart';

2. Use the Log convenience class:
   
   // Debug
   Log.d("User logged in", "AuthService");
   
   // Info
   Log.i("Gesture sync started", "GestureProvider");
   
   // Warning
   Log.w("Connection timeout, retrying", "ApiService");
   
   // Error (with optional stack trace)
   try {
     await saveGesture();
   } catch (e, st) {
     Log.e("Failed to save gesture: $e", "GestureProvider", st);
   }

OUTPUT FORMAT:
==============
[2026-04-20T15:30:45.123456] [DEBUG] [GestureProvider] User logged in
[2026-04-20T15:30:46.234567] [INFO] [ApiService] POST /api/gestures
[2026-04-20T15:30:47.345678] [WARN] [NetworkService] Connection timeout
[2026-04-20T15:30:48.456789] [ERROR] [GestureProvider] Failed to save gesture

FUTURE ENHANCEMENTS:
===================
1. Add Firebase Crashlytics integration for error reporting
2. Add Sentry integration for error tracking
3. Add log rotation to prevent memory bloat
4. Add file persistence for offline debugging
5. Add log filtering by tag or level
*/
