import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;

  void _onDigitPressed(String digit) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) {
            _verifyAndSavePin();
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      } else if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (_isConfirming && _confirmPin.isEmpty) {
        // Go back to step 1
        _isConfirming = false;
        _pin = '';
      }
    });
  }

  Future<void> _verifyAndSavePin() async {
    if (_pin == _confirmPin) {
      // Show password confirmation dialog
      final passwordController = TextEditingController();
      final formKey = GlobalKey<FormState>();

      bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isSubmitting = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF2C2C2C),
                title: const Text(
                  'Confirm Password',
                  style: TextStyle(color: Colors.white),
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Please enter your password to set your PIN.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Enter password' : null,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('CANCEL'),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              setDialogState(() => isSubmitting = true);

                              final success = await ref
                                  .read(authProvider.notifier)
                                  .setPin(_pin, passwordController.text);

                              if (!success) {
                                // Show error in dialog
                                final errorMsg =
                                    ref.read(authProvider).error ??
                                    'Password verification failed';
                                setDialogState(() => isSubmitting = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(errorMsg),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                                return; // Stay in dialog, don't pop
                              }

                              if (context.mounted) {
                                Navigator.pop(context, success);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('VERIFY & SET'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App PIN saved and synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(); // Returns to Settings
      } else if (mounted) {
        // Reset confirmation state if cancelled or failed (null or false)
        setState(() {
          _isConfirming = false;
          _pin = '';
          _confirmPin = '';
        });
      }
    } else {
      // Mismatch
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PINs do not match. Try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        _isConfirming = false;
        _pin = '';
        _confirmPin = '';
      });
    }
  }

  Future<void> _removePin() async {
    final pinService = ref.read(pinServiceProvider);
    await pinService.removePin();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('App PIN removed.'),
          backgroundColor: Colors.grey,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using a simple 4 dots indicator
    final currentInput = _isConfirming ? _confirmPin : _pin;
    final message = _isConfirming ? 'Confirm your PIN' : 'Enter a 4-digit PIN';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Set Login PIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // If we already have a PIN, offer a way to remove it
          FutureBuilder<bool>(
            future: ref.read(pinServiceProvider).hasPin(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return TextButton(
                  onPressed: _removePin,
                  child: const Text(
                    'REMOVE PIN',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(message, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 48),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < currentInput.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: isFilled ? theme.colorScheme.primary : Colors.grey,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
            // Numpad
            _buildNumpad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildKey('1'), _buildKey('2'), _buildKey('3')],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildKey('4'), _buildKey('5'), _buildKey('6')],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_buildKey('7'), _buildKey('8'), _buildKey('9')],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 80, height: 80), // Empty space
              _buildKey('0'),
              _buildBackspaceKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _onDigitPressed(label),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return InkWell(
      onTap: _onBackspacePressed,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: const Icon(Icons.backspace_outlined, size: 32),
      ),
    );
  }
}
