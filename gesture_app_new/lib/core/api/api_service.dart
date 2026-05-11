import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Service for handling HTTP requests to the Laravel backend
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _authToken;

  ApiService(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add interceptors for logging and error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token to requests if available
          // PRIORITY 1: Check in-memory token
          String? token = _authToken;

          // PRIORITY 2: Check secure storage (Robustness Fix)
          if (token == null) {
            token = await _storage.read(key: ApiConfig.authTokenKey);
            if (token != null) {
              _authToken = token; // Sync back to memory
            }
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (kDebugMode) {
            // Force logging
            print(
              '🌐 REQUEST: ${options.method} ${options.uri}',
            ); // Log FULL URI
            // Mask headers and data to prevent sensitive leak
            print('🔑 Headers: [REDACTED]');
            print('📤 Data: [REDACTED]');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          // ALWAYS LOG for debugging sync issue
          print(
            '✅ RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
          );
          print('📥 Data: ${response.data}');
          return handler.next(response);
        },
        onError: (error, handler) async {
          // ALWAYS LOG for debugging sync issue
          print(
            '❌ ERROR: ${error.response?.statusCode} ${error.requestOptions.path}',
          );
          print('💥 Message: ${error.message}');
          print('📛 Data: ${error.response?.data}');

          // Handle 401 Unauthenticated - Clear invalid token and require re-login
          if (error.response?.statusCode == 401) {
            print('🔴 401 Unauthenticated - Clearing stored token');
            _authToken = null;
            await _storage.delete(key: 'auth_token');
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Set authentication token for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Expose Dio for other services (Razorpay)
  Dio get dio => _dio;

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Register new user
  Future<ApiResponse> register({
    required String name,
    String? email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'name': name,
          'email': email,
          'mobile_number': mobileNumber,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );

      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Login user
  Future<ApiResponse> login({
    required String identifier,
    String? password,
    String? pin,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'identifier': identifier,
          if (password != null) 'password': password,
          if (pin != null) 'pin': pin,
        },
      );

      if (response.data is! Map<String, dynamic>) {
        return ApiResponse(
          success: false,
          message:
              'Server returned invalid format: ${response.data.runtimeType}',
        );
      }

      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    } catch (e) {
      return ApiResponse(success: false, message: 'Unexpected error: $e');
    }
  }

  /// Send OTP
  Future<ApiResponse> sendOtp(String identifier) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendOtp,
        data: {'identifier': identifier},
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Verify OTP
  Future<ApiResponse> verifyOtp(String identifier, String otp) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtp,
        data: {'identifier': identifier, 'otp': otp},
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Change Password
  Future<ApiResponse> changePassword(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        },
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Set or update user PIN
  Future<ApiResponse> setPin(String pin, String password) async {
    try {
      final response = await _dio.post(
        ApiConfig.setPin,
        data: {'pin': pin, 'password': password},
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Reset Password (Forgot Password)
  Future<ApiResponse> resetPassword(
    String identifier,
    String otp,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.resetPassword,
        data: {
          'identifier': identifier,
          'otp': otp,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Sync gestures to server
  Future<ApiResponse> syncGestures(List<Map<String, dynamic>> gestures) async {
    try {
      final response = await _dio.post(
        ApiConfig.gesturesSync,
        data: {'gestures': gestures},
      );

      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Delete a gesture
  Future<ApiResponse> deleteGesture(int id) async {
    try {
      final response = await _dio.delete('${ApiConfig.gestures}/$id');
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Update a gesture
  Future<ApiResponse> updateGesture(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('${ApiConfig.gestures}/$id', data: data);
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Get all gestures for authenticated user
  Future<ApiResponse> getGestures() async {
    try {
      final response = await _dio.get(ApiConfig.gestures);
      return ApiResponse.fromJson(response.data);
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  /// Handle API errors (User-Friendly)
  ApiResponse _handleError(DioException error) {
    String message = 'Something went wrong. Please try again.';
    Map<String, dynamic>? errors;

    // 1. Handle Response Errors (4xx, 5xx)
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      if (kDebugMode) {
        print('🛑 API ERROR ($statusCode): ${error.requestOptions.path}');
        print('🛑 DATA: $data');
      }

      // Extract Backend Message if available
      if (data is Map<String, dynamic>) {
        message = data['message'] ?? message;
        errors = data['errors']; // Validation errors
      }

      // Override with friendly messages for common codes
      switch (statusCode) {
        case 401:
          // Do not override message here to allow backend "Invalid credentials" to show
          break;
        case 403:
          message = 'You do not have permission to perform this action.';
          break;
        case 404:
          message = 'Resource not found.';
          break;
        case 500:
        case 502:
        case 503:
          message = 'Server is having trouble. Please try again later.';
          break;
      }
    }
    // 2. Handle Connection Errors (Network)
    else {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Connection timed out. Please check your internet.';
          break;
        case DioExceptionType.connectionError:
          message = 'No internet connection.';
          break;
        case DioExceptionType.cancel:
          message = 'Request cancelled.';
          break;
        default:
          message = 'Unexpected network error. Please check your connection.';
          if (kDebugMode) {
            print('🛑 UNKNOWN DIO ERROR: ${error.message}');
          }
      }

      // Reduce severity for logs in console
      if (kDebugMode &&
          !message.contains('Connection timed out') &&
          !message.contains('No internet')) {
        print('⚠️ API Issue: $message');
      }
    }

    return ApiResponse(
      success: false,
      message: message, // User-friendly message
      errors: errors,
    );
  }
}

/// API Response model
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
      errors: json['errors'],
    );
  }

  /// Get error messages as a list
  List<String> get errorMessages {
    if (errors == null) return [];

    List<String> messages = [];
    errors!.forEach((key, value) {
      if (value is List) {
        messages.addAll(value.cast<String>());
      } else {
        messages.add(value.toString());
      }
    });

    return messages;
  }

  /// Get first error message
  String? get firstError {
    final messages = errorMessages;
    return messages.isNotEmpty ? messages.first : null;
  }
}
