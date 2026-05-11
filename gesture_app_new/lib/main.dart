import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/providers/theme_provider.dart';
import 'package:gesture_app/core/theme/app_theme.dart';
import 'package:gesture_app/core/routing/app_router.dart';
import 'package:gesture_app/core/services/background_service.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:gesture_app/features/gesture/screens/quick_panel_screen.dart';

import 'package:gesture_app/background_service.dart'; // Import the service

/// Global Entrypoint for Background Service (Must be in main.dart to be found reliably)
@pragma('vm:entry-point')
void backgroundEntrypoint() {
  entrypointMain(); // Call the logic from the service file
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Overlay Listener Immediately (The Fix)
  OverlayService.initialize();

  // Initialize Background Service
  await BackgroundServiceInstance.initializeService();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.backgroundBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: GestureApp()));
}

class GestureApp extends ConsumerWidget {
  const GestureApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'GestureOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuickPanelApp());
}

class QuickPanelApp extends StatelessWidget {
  const QuickPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const QuickPanelScreen(),
    );
  }
}
