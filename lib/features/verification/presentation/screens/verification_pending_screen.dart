import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/verification_provider.dart';

class VerificationPendingScreen extends StatefulWidget {
  const VerificationPendingScreen({super.key});

  @override
  State<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  StreamSubscription<VerificationStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialStatus();
      _listenToVerificationStatus();
    });
  }

  void _checkInitialStatus() {
    if (!mounted) return;
    final provider = context.read<VerificationProvider>();
    _handleStatusChange(provider.status);
  }

  void _listenToVerificationStatus() {
    final provider = context.read<VerificationProvider>();
    _statusSubscription = provider.statusStream.listen((status) {
      if (!mounted) return;
      _handleStatusChange(status);
    });
  }

  void _handleStatusChange(VerificationStatus status) {
    if (status == VerificationStatus.approved) {
      _goToDashboard();
    } else if (status == VerificationStatus.rejected) {
      _showRejectedDialog();
    }
  }

  void _goToDashboard() {
    if (!mounted) return;
    // Return to AuthGate root — it will route to Dashboard via ProfileGate.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verification Failed'),
        content: const Text(
          'Your identity verification could not be approved. '
          'Please ensure your ID photo and selfie are clear and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _goToDashboard();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFF1E1E2C,
        ), // Dark sleek background matching reference
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // --- Success / Pending Checkmark Badge Icon ---
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00C853), // Vibrant success green
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    // Sparkle decorative placements matching your layout style
                    const Positioned(
                      top: 10,
                      right: 15,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.greenAccent,
                        size: 22,
                      ),
                    ),
                    const Positioned(
                      bottom: 15,
                      left: 10,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.greenAccent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // --- Titles ---
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your application\nsubmitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),

                // --- Description ---
                const Text(
                  "Your application is currently under review and may take 2-4 hours. You'll be notified once it's accepted",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                const Spacer(),

                // --- Primary Action Button ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _goToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF7C69EE,
                      ), // Soft purple/indigo accent button
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Go to Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
