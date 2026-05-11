import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TestOverlayScreen extends StatelessWidget {
  const TestOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Overlay Test Console")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_circle, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              onPressed: () async {
                print("🔴 FLUTTER: BUTTON PRESSED");
                const channel = MethodChannel('overlay_channel'); // Using 'overlay_channel' as per MainActivity
                try {
                  await channel.invokeMethod('startOverlay');
                  print("🚀 FLUTTER: COMMAND SENT TO ANDROID");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Command Sent! Check Logs/Screen")),
                    );
                  }
                } catch (e) {
                  print("❌ FLUTTER ERROR: $e");
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error: $e")),
                    );
                  }
                }
              },
              child: const Text("LAUNCH RED STAR ⭐", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
