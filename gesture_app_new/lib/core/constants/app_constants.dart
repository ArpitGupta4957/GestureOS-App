/// Application Constants
/// Centralized configuration values used throughout the app
library;

/// ============================================================================
/// GESTURE RECOGNITION CONSTANTS
/// ============================================================================

/// Default gesture recognition delay in milliseconds
const int defaultRecognitionDelay = 600;

/// Minimum gesture points required to recognize
const int minGesturePoints = 5;

/// Maximum gesture distance before considering it a new stroke
const double gestureDistanceThreshold = 50.0;

/// Gesture similarity threshold (0.0 - 1.0)
const double gestureSimilarityThreshold = 0.75;

/// ============================================================================
/// API CONSTANTS
/// ============================================================================

/// API request timeout in seconds
const int apiConnectTimeout = 30;
const int apiReceiveTimeout = 30;
const int apiSendTimeout = 30;

/// API error codes
const int apiErrorUnauthorized = 401;
const int apiErrorForbidden = 403;
const int apiErrorNotFound = 404;
const int apiErrorServerError = 500;

/// ============================================================================
/// UI CONSTANTS
/// ============================================================================

/// Theme colors (Neon Green cyberpunk theme)
const int neonGreenHex = 0xFF00FF41;
const int darkBackgroundHex = 0xFF0A0E27;
const int surfaceHex = 0xFF141B2D;

/// Standard padding/margins
const double paddingXSmall = 4.0;
const double paddingSmall = 8.0;
const double paddingMedium = 16.0;
const double paddingLarge = 24.0;
const double paddingXLarge = 32.0;

/// Border radius
const double borderRadiusSmall = 4.0;
const double borderRadiusMedium = 8.0;
const double borderRadiusLarge = 12.0;

/// Overlay UI dimensions
const double overlayWidth = 360.0;
const double overlayCornerRadius = 12.0;

/// ============================================================================
/// ANIMATION CONSTANTS
/// ============================================================================

/// Standard animation durations (milliseconds)
const int animationShort = 150;
const int animationMedium = 300;
const int animationLong = 500;

/// ============================================================================
/// DATABASE CONSTANTS
/// ============================================================================

/// Database name and version
const String databaseName = 'gesture_app_offline_v5.db';
const int databaseVersion = 5;

/// SQLite table names
const String tableGestures = 'gestures';
const String tableBulkSessions = 'bulk_sessions';
const String tableBulkNumbers = 'bulk_numbers';

/// ============================================================================
/// TRIAL & SUBSCRIPTION CONSTANTS
/// ============================================================================

/// Trial period duration in days
const int trialDurationDays = 7;

/// Maximum free trial usages per feature
const int maxTrialUsagesExcelImport = 5;
const int maxTrialUsagesOcr = 10;
const int maxTrialUsagesBulkDialer = 3;

/// ============================================================================
/// PHONE NUMBER FORMAT CONSTANTS
/// ============================================================================

/// Phone number formats
const String indianPhoneFormat = '+91XXXXXXXXXX';
const int minPhoneNumberLength = 3;
const int indianPhoneNumberLength = 10;

/// ============================================================================
/// CONTACT & APP CONSTANTS
/// ============================================================================

/// Maximum contacts to load at once
const int maxContactsPerPage = 50;

/// Maximum apps to display in app picker
const int maxAppsToDisplay = 100;

/// ============================================================================
/// FILE & STORAGE CONSTANTS
/// ============================================================================

/// Maximum file size for uploads (in MB)
const int maxFileUploadSizeMB = 10;

/// Supported image formats
const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'gif'];

/// ============================================================================
/// PERMISSION & SECURITY CONSTANTS
/// ============================================================================

/// App lock timeout in seconds (0 = disabled)
const int appLockTimeoutSeconds = 300; // 5 minutes

/// Session timeout in minutes
const int sessionTimeoutMinutes = 60;

/// ============================================================================
/// LOGGING CONSTANTS
/// ============================================================================

/// Log tags for organized logging
const String logTagApi = "ApiService";
const String logTagAuth = "AuthService";
const String logTagGesture = "GestureProvider";
const String logTagDatabase = "DatabaseHelper";
const String logTagOverlay = "OverlayService";
const String logTagBulkDialer = "BulkDialer";
const String logTagNetwork = "NetworkService";
