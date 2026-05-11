import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:gesture_app/core/api/api_service.dart';
import 'package:gesture_app/core/services/pin_service.dart';
import 'dart:convert';

/// User model
class User {
  final int id;
  final String name;
  final String? email;
  final String? mobileNumber;
  final String role;

  User({
    required this.id,
    required this.name,
    this.email,
    this.mobileNumber,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      mobileNumber: json['mobile_number'] ?? '',
      role: json['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile_number': mobileNumber,
      'role': role,
    };
  }
}

/// Authentication state
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool isAppLocked;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.isAppLocked = false,
  });

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isAppLocked,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isAppLocked: isAppLocked ?? this.isAppLocked,
    );
  }
}

/// Authentication provider
class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;
  final PinService _pinService;

  AuthNotifier(this._apiService, this._storage, this._pinService)
    : super(AuthState()) {
    _loadSavedAuth();
  }

  /// Load saved authentication from secure storage
  Future<void> _loadSavedAuth() async {
    try {
      final token = await _storage.read(key: ApiConfig.authTokenKey);
      final userJson = await _storage.read(key: ApiConfig.userDataKey);

      if (token != null && userJson != null) {
        final user = User.fromJson(json.decode(userJson));
        _apiService.setAuthToken(token);

        state = state.copyWith(user: user, token: token);
      }
    } catch (e) {
      print('Error loading saved auth: $e');
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    String? email,
    String? mobileNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _apiService.register(
        name: name,
        email: email,
        mobileNumber: mobileNumber,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (response.success && response.data != null) {
        final user = User.fromJson(response.data!['user']);
        final token = response.data!['token'];

        await _saveAuth(user, token);
        _apiService.setAuthToken(token);

        state = state.copyWith(user: user, token: token, isLoading: false);

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed: $e',
      );
      return false;
    }
  }

  /// Login user
  Future<bool> login({
    required String identifier,
    String? password,
    String? pin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _apiService.login(
        identifier: identifier,
        password: password,
        pin: pin,
      );

      if (response.success && response.data != null) {
        final user = User.fromJson(response.data!['user']);
        final token = response.data!['token'];

        await _saveAuth(user, token);
        _apiService.setAuthToken(token);

        // If login was via PIN, we also sync local PIN service
        if (pin != null) {
          await _pinService.setPin(pin);
        }

        state = state.copyWith(user: user, token: token, isLoading: false);

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Login failed: $e');
      return false;
    }
  }

  /// Send OTP
  Future<bool> sendOtp(String identifier) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.sendOtp(identifier);
      if (response.success) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to send OTP: $e');
      return false;
    }
  }

  /// Verify OTP and Login
  Future<bool> verifyOtp(String identifier, String otp) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.verifyOtp(identifier, otp);
      if (response.success && response.data != null) {
        final user = User.fromJson(response.data!['user']);
        final token = response.data!['token'];

        await _saveAuth(user, token);
        _apiService.setAuthToken(token);

        state = state.copyWith(user: user, token: token, isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed: $e',
      );
      return false;
    }
  }

  /// Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.changePassword(
        currentPassword,
        newPassword,
        newPasswordConfirmation,
      );
      if (response.success) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to change password: $e',
      );
      return false;
    }
  }

  /// Set or update user PIN (Server Sync)
  Future<bool> setPin(String pin, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.setPin(pin, password);
      if (response.success) {
        // Also update local App Lock PIN for consistency
        await _pinService.setPin(pin);
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to set PIN: $e');
      return false;
    }
  }

  /// Reset Password (Forgot Password)
  Future<bool> resetPassword({
    required String identifier,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.resetPassword(
        identifier,
        otp,
        password,
        passwordConfirmation,
      );
      if (response.success) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.firstError ?? response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to reset password: $e',
      );
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _clearAuth();
    _apiService.clearAuthToken();
    state = AuthState();
  }

  /// Save authentication to secure storage
  Future<void> _saveAuth(User user, String token) async {
    await _storage.write(key: ApiConfig.authTokenKey, value: token);
    await _storage.write(
      key: ApiConfig.userDataKey,
      value: json.encode(user.toJson()),
    );
  }

  /// Clear authentication from secure storage
  Future<void> _clearAuth() async {
    await _storage.delete(key: ApiConfig.authTokenKey);
    await _storage.delete(key: ApiConfig.userDataKey);
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Providers
final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(secureStorageProvider)),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(secureStorageProvider)),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(secureStorageProvider),
    ref.watch(pinServiceProvider),
  );
});
