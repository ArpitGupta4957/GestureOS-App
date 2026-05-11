/// API Configuration for the Gesture App
class ApiConfig {
  // Base URL for the Laravel backend
  //
  // IMPORTANT: Update this based on your setup:
  //
  // For Android Emulator:
  //   static const String baseUrl = 'http://10.0.2.2:8000';
  //
  // For Physical Device (RECOMMENDED):
  //   1. Find your computer's IP address:
  //      Windows: Run 'ipconfig' and look for IPv4 Address
  //      Mac/Linux: Run 'ifconfig' and look for inet
  //   2. Replace 'YOUR_COMPUTER_IP' below with that IP
  //   3. Make sure your phone and computer are on the same WiFi network

  static const String baseUrl = 'https://servermine.com'; // Host LAN IP Updated

  // API endpoints
  static const String register = '/api/register';
  static const String login = '/api/login';
  static const String gesturesSync = '/api/gestures/sync';
  static const String gestures = '/api/gestures';
  static const String sendOtp = '/api/auth/send-otp';
  static const String verifyOtp = '/api/auth/verify-otp';
  static const String resetPassword = '/api/auth/reset-password';
  static const String changePassword = '/api/user/change-password';
  static const String setPin = '/api/user/set-pin';
  static const String deleteAccountRequest = '/api/user/delete-request';

  // Subscription endpoints (Issue #12 fix: Centralized constants)
  static const String subscriptionPlans = '/api/subscription/plans';
  static const String subscriptionStatus = '/api/subscription/status';
  static const String subscriptionCheckFeature =
      '/api/subscription/check-feature';
  static const String subscriptionActivateFree =
      '/api/subscription/activate-free';
  static const String subscriptionCreateOrder = '/api/subscription/create';
  static const String razorpayVerify = '/api/razorpay/verify';
  static const String appleIapVerify = '/api/apple-iap/verify';
  static const String trialsRecord = '/api/trials/record';

  // Timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Default values (Issue #11 fix: Centralized defaults)\n  static const int defaultFreePlanDays = 30; // Use backend value when available, fallback to this

  // Storage keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
}
