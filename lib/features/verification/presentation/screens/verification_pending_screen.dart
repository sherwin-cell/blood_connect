import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../dashboard/presentation/home_dashboard.dart';
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
    // Schedule check after the frame builds to prevent navigating during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialStatus();
      _listenToVerificationStatus();
    });
  }

  /// Check current status in case it was resolved before listener initialized
  void _checkInitialStatus() {
    if (!mounted) return;
    final provider = context.read<VerificationProvider>();
    _handleStatusChange(provider.status);
  }

  /// Listen for real-time verification updates from Firestore via Provider
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

    // Clear navigation stack and return to the main home dashboard
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeDashboard()),
      (route) => false,
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Prevents default back button
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verification Under Review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your identity verification details have been submitted and are currently being reviewed. This usually takes up to 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _goToDashboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
