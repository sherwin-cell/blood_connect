import 'package:flutter/material.dart';

/// Pure visual splash screen used during auth/profile stream resolution.
/// Contains no timers or internal navigation logic.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype, size: 80, color: Colors.red),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.red),
          ],
        ),
      ),
    );
  }
}
