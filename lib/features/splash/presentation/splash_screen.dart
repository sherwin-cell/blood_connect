import 'package:flutter/material.dart';

/// Static loading UI shown by AuthGate only while the auth stream is
/// still resolving (ConnectionState.waiting). This widget must NEVER
/// navigate on its own — AuthGate is the single source of truth for
/// top-level routing and will swap this out automatically once the
/// auth state is known.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFD32F2F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_rounded, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Blood-Connect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
