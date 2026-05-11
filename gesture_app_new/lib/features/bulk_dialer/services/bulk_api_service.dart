import 'package:dio/dio.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BulkApiService {
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  BulkApiService() {
    _dio.options.baseUrl = ApiConfig.baseUrl; // e.g. http://10.183.253.98:8000
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 5);
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.headers['Accept'] = 'application/json';

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: ApiConfig.authTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // --- Session Operations ---

  /// Get active sessions
  Future<List<DialerSessionModel>> getSessions() async {
    try {
      print('🌐 BULK API: Fetching sessions...');
      final response = await _dio.get('/api/bulk/sessions');
      print(
        '✅ BULK API: Sessions response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode == 200) {
        // Handle both paginated and flat array responses
        final dynamic responseData = response.data;
        List data;

        if (responseData is Map && responseData.containsKey('data')) {
          // Fix: Handle Map-as-List
          final rawData = responseData['data'];
          if (rawData is List) {
            data = rawData;
          } else if (rawData is Map) {
            data = rawData.values.toList();
          } else {
            return [];
          }
        } else if (responseData is List) {
          // Flat array response
          data = responseData;
        } else {
          print('⚠️ BULK API: Unexpected response format');
          return [];
        }

        return data.map((json) => DialerSessionModel.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      // Retry Logic for Timeout
      if (e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        print('⚠️ BULK API: Timeout in getSessions, retrying once...');
        try {
          final retryResponse = await _dio.get('/api/bulk/sessions');
          if (retryResponse.statusCode == 200) {
            final dynamic responseData = retryResponse.data;
            List data;
            if (responseData is Map && responseData.containsKey('data')) {
              // Fix: Handle Map-as-List
              final rawData = responseData['data'];
              if (rawData is List) {
                data = rawData;
              } else if (rawData is Map) {
                data = rawData.values.toList();
              } else {
                return [];
              }
            } else if (responseData is List) {
              data = responseData;
            } else {
              return [];
            }
            return data
                .map((json) => DialerSessionModel.fromMap(json))
                .toList();
          }
        } catch (retryError) {
          throw _handleError(retryError);
        }
      }
      throw _handleError(e);
    }
  }

  /// Create a new session
  Future<DialerSessionModel> createSession(String name) async {
    try {
      print('🌐 BULK API: Creating session $name...');
      final response = await _dio.post(
        '/api/bulk/sessions',
        data: {'name': name},
      );
      print(
        '✅ BULK API: Create response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode == 201) {
        return DialerSessionModel.fromMap(response.data);
      }
      throw Exception("Failed to create session");
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Delete session (Finish & Clear)
  Future<void> deleteSession(int id) async {
    try {
      await _dio.delete('/api/bulk/sessions/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // --- Number Operations ---

  /// Get numbers for a session
  Future<List<BulkNumberModel>> getNumbers(int sessionId) async {
    try {
      print('🌐 BULK API: Fetching numbers for session $sessionId...');
      final response = await _dio.get('/api/bulk/sessions/$sessionId/numbers');
      print(
        '✅ BULK API: Numbers response: ${response.statusCode} - ${response.data}',
      );
      if (response.statusCode == 200) {
        // Handle both paginated and flat array responses
        final dynamic responseData = response.data;
        List data;

        if (responseData is Map && responseData.containsKey('data')) {
          // Fix: Handle Map-as-List
          final rawData = responseData['data'];
          if (rawData is List) {
            data = rawData;
          } else if (rawData is Map) {
            data = rawData.values.toList();
          } else {
            return [];
          }
        } else if (responseData is List) {
          // Flat array response
          data = responseData;
        } else {
          print('⚠️ BULK API: Unexpected response format for numbers');
          return [];
        }

        return data.map((json) => BulkNumberModel.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      // Retry Logic for Timeout
      if (e is DioException &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)) {
        print('⚠️ BULK API: Timeout in getNumbers, retrying once...');
        try {
          final retryResponse = await _dio.get(
            '/api/bulk/sessions/$sessionId/numbers',
          );
          if (retryResponse.statusCode == 200) {
            final dynamic responseData = retryResponse.data;
            List data;
            if (responseData is Map && responseData.containsKey('data')) {
              // Fix: Handle Map-as-List (PHP array serialization issue)
              final rawData = responseData['data'];
              if (rawData is List) {
                data = rawData;
              } else if (rawData is Map) {
                data = rawData.values.toList();
              } else {
                return []; // Unexpected type
              }
            } else if (responseData is List) {
              data = responseData;
            } else {
              return [];
            }
            return data.map((json) => BulkNumberModel.fromMap(json)).toList();
          }
        } catch (retryError) {
          throw _handleError(retryError);
        }
      }
      throw _handleError(e);
    }
  }

  /// Add numbers (Batch)
  Future<void> addNumbers(int sessionId, List<BulkNumberModel> numbers) async {
    if (numbers.isEmpty) return;

    try {
      // Prepare payload
      final payload = numbers
          .map(
            (n) => {
              'phone_number': n.phoneNumber,
              'name': n.name,
              'notes': n.notes,
            },
          )
          .toList();

      await _dio.post(
        '/api/bulk/numbers',
        data: {'session_id': sessionId, 'numbers': payload},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Update number (status, notes)
  Future<void> updateNumber(BulkNumberModel number) async {
    if (number.id == null) return;
    try {
      await _dio.put(
        '/api/bulk/numbers/${number.id}',
        data: {
          'phone_number': number.phoneNumber,
          'name': number.name,
          'status': number.status.name, // Enum to string
          'notes': number.notes,
          'last_called_at': number.lastCalledAt?.toIso8601String(),
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  // --- Error Handling ---

  /// Handle API errors (User-Friendly)
  String _handleError(dynamic error) {
    String message = 'Something went wrong. Please try again.';

    if (error is DioException) {
      // 1. Handle Response Errors (4xx, 5xx)
      if (error.response != null) {
        final statusCode = error.response!.statusCode;
        final data = error.response!.data;

        // Extract Backend Message if available
        if (data is Map<String, dynamic>) {
          message = data['message'] ?? message;
        }

        // Override with friendly messages for common codes
        switch (statusCode) {
          case 401:
            message = 'Session expired. Please login again.';
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
            message = 'Network error. Please check your connection.';
        }
      }
    } else {
      // Generic Dart Error
      message = error.toString();
      if (message.contains("SocketException") ||
          message.contains("Connection refused")) {
        message = "Unable to connect to server. Check your internet.";
      }
    }

    print('❌ BULK API ERROR: $message (Raw: $error)');
    throw Exception(message); // Throw clean message
  }
}
