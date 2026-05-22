import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/models/gesture_model.dart';
import 'package:gesture_app/features/auth/screens/login_screen.dart';
import 'package:gesture_app/features/auth/screens/register_screen.dart';
import 'package:gesture_app/features/auth/screens/verification_screen.dart';
import 'package:gesture_app/features/auth/screens/forgot_password_screen.dart';
import 'package:gesture_app/features/auth/screens/reset_password_screen.dart';
import 'package:gesture_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:gesture_app/features/gesture/screens/draw_gesture_screen.dart';
import 'package:gesture_app/features/settings/screens/settings_screen.dart';
import 'package:gesture_app/features/onboarding/screens/permission_onboarding_screen.dart';
import 'package:gesture_app/features/auth/screens/splash_screen.dart';
import 'package:gesture_app/features/subscription/screens/subscription_screen.dart';
import 'package:gesture_app/features/gesture/screens/auto_assign_shortcuts_screen.dart';
import 'package:gesture_app/features/onboarding/screens/onboarding_screen.dart';
import 'package:gesture_app/features/auth/screens/pin_setup_screen.dart';
import 'package:gesture_app/features/auth/screens/pin_unlock_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoggedIn = authState.isAuthenticated;
      final path = state.uri.path;
      final isLoggingIn = path == '/login';
      final isRegistering = path == '/register';
      final isSplashing = path == '/splash';
      final isOnboarding = path == '/onboarding';
      final isForgotPw = path == '/forgot-password';
      final isResetPw = path == '/reset-password';

      // If we are on the splash screen, we don't redirect immediately.
      // The splash screen itself will handle navigation after its logic.
      if (isSplashing) {
        return null;
      }

      // Allow onboarding without authentication
      if (isOnboarding) {
        return null;
      }

      // Allow forgot password & reset password flows without authentication
      if (isForgotPw || isResetPw) {
        return null;
      }

      if (isLoggedIn) {
        // If logged in and trying to go to login or register, go to dashboard
        if (isLoggingIn || isRegistering || isForgotPw || isResetPw) {
          return '/dashboard';
        }
      } else {
        // If not logged in and trying to access protected routes, go to login
        if (!isLoggingIn && !isRegistering && !isForgotPw && !isResetPw) {
          return '/login';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/verify-mobile',
        name: 'verify-mobile',
        builder: (context, state) {
          final mobile = state.extra as String;
          return VerificationScreen(
            type: VerificationType.mobile,
            identifier: mobile,
          );
        },
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final email = state.extra as String;
          return VerificationScreen(
            type: VerificationType.email,
            identifier: email,
          );
        },
      ),
      GoRoute(
        path: '/permissions',
        name: 'permissions',
        builder: (context, state) => const PermissionOnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/draw-gesture',
        name: 'draw-gesture',
        builder: (context, state) {
          final extra = state.extra;
          // Support both editing (GestureModel) and new action-first (Map)
          if (extra is GestureModel) {
            return DrawGestureScreen(gestureToEdit: extra);
          } else if (extra is Map<String, dynamic>) {
            return DrawGestureScreen(
              preSelectedActionType: extra['actionType'] as String?,
              preSelectedActionValue: extra['actionValue'] as String?,
              preSelectedActionName: extra['actionName'] as String?,
              preSelectedContactId: extra['contactId'] as String?,
              preSelectedLocalPhotoPath: extra['localPhotoPath'] as String?,
            );
          }
          return const DrawGestureScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/subscription',
        name: 'subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/auto-assign',
        name: 'auto-assign',
        builder: (context, state) => const AutoAssignShortcutsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/pin-setup',
        name: 'pin-setup',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/pin-unlock',
        name: 'pin-unlock',
        builder: (context, state) => const PinUnlockScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final identifier = state.extra as String? ?? '';
          return ResetPasswordScreen(identifier: identifier);
        },
      ),
    ],
  );
});

/// A [Listenable] that notifies when a [Stream] emits a value.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
