/// Structured Logging Service for GestureApp
/// Provides consistent logging across the app with different log levels
library;

enum LogLevel { debug, info, warning, error }

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal();

  /// Log debug message (lowest priority)
  static void d(String message, [String tag = 'DEBUG']) {
    _log(LogLevel.debug, message, tag);
  }

  /// Log info message
  static void i(String message, [String tag = 'INFO']) {
    _log(LogLevel.info, message, tag);
  }

  /// Log warning message
  static void w(String message, [String tag = 'WARN']) {
    _log(LogLevel.warning, message, tag);
  }

  /// Log error message (highest priority)
  static void e(
    String message, [
    String tag = 'ERROR',
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, message, tag, stackTrace);
  }

  static void _log(
    LogLevel level,
    String message,
    String tag, [
    StackTrace? stackTrace,
  ]) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final logMessage = '[$timestamp] [$levelStr] [$tag] $message';

    // Print to console
    print(logMessage);

    // Log stack trace for errors
    if (stackTrace != null) {
      print('StackTrace:\n$stackTrace');
    }

    // TODO: Send to remote logging service (Firebase Crashlytics, Sentry, etc.)
    // if (level == LogLevel.error) {
    //   _sendToRemote(message, stackTrace);
    // }
  }

  // Future: Send logs to remote service
  // static void _sendToRemote(String message, StackTrace? stackTrace) {
  //   // Implementation for Firebase Crashlytics or Sentry
  // }
}

// Convenience aliases for shorter usage
class Log {
  static void d(String msg, [String tag = 'DEBUG']) =>
      LoggerService.d(msg, tag);
  static void i(String msg, [String tag = 'INFO']) => LoggerService.i(msg, tag);
  static void w(String msg, [String tag = 'WARN']) => LoggerService.w(msg, tag);
  static void e(String msg, [String tag = 'ERROR', StackTrace? st]) =>
      LoggerService.e(msg, tag, st);
}
