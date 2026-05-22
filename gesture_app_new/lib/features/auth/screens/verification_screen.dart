import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VerificationType { mobile, email }

class VerificationScreen extends ConsumerStatefulWidget {
  final VerificationType type;
  final String identifier;

  const VerificationScreen({
    super.key,
    required this.type,
    required this.identifier,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _otpController = TextEditingController();
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Auto-send OTP on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _isResending = true);

    // If identifier is empty (e.g. email from provider), try to fetch from auth state
    String target = widget.identifier;
    if (target.isEmpty) {
      final user = ref.read(authProvider).user;
      if (widget.type == VerificationType.email) {
        target = user?.email ?? '';
      } else {
        target = user?.mobileNumber ?? '';
      }
    }

    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: specific identifier not found')),
      );
      setState(() => _isResending = false);
      return;
    }

    final success = await ref.read(authProvider.notifier).sendOtp(target);

    if (mounted) {
      setState(() => _isResending = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $target'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to send OTP'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    // Get correct identifier
    String target = widget.identifier;
    if (target.isEmpty) {
      final user = ref.read(authProvider).user;
      if (widget.type == VerificationType.email) {
        target = user?.email ?? '';
      } else {
        target = user?.mobileNumber ?? '';
      }
    }

    final success =
        await ref.read(authProvider.notifier).verifyOtp(target, otp);

    if (!mounted) return;

    if (success) {
      if (widget.type == VerificationType.mobile) {
        // Proceed to Email Verification
        final user = ref.read(authProvider).user;
        final email = user?.email ?? '';
        context.go('/verify-email', extra: email);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
        final seenPermissions = prefs.getBool('seen_permissions') ?? false;

        if (!seenOnboarding) {
          context.go('/onboarding');
        } else if (!seenPermissions) {
          context.go('/permissions');
        } else {
          context.go('/dashboard');
        }
      }
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Verification failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final isMobile = widget.type == VerificationType.mobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMobile ? 'VERIFY MOBILE' : 'VERIFY EMAIL'),
        actions: [
          TextButton(
            onPressed: () {
              // Allow skipping if needed? No, user wanted forced.
              // But maybe logout?
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isMobile ? Icons.phone_android : Icons.email_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Enter the code sent to',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              widget.identifier,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: authState.isLoading ? null : _handleVerify,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('VERIFY ${isMobile ? "MOBILE" : "EMAIL"}'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  (authState.isLoading || _isResending) ? null : _sendOtp,
              child: _isResending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
