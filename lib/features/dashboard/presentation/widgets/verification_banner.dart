import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../../verification/presentation/screens/identity_verification_info_screen.dart';

class VerificationBanner extends StatefulWidget {
  final UserProfile? profile;

  const VerificationBanner({super.key, required this.profile});

  @override
  State<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<VerificationBanner> {
  bool _isBannerMinimized = false;

  @override
  Widget build(BuildContext context) {
    final String status = (widget.profile?.verificationStatus ?? '')
        .toLowerCase();
    final bool isPending = status == 'pending' || status == 'under_review';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFF2C2C2C) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: _isBannerMinimized
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPending ? 'Verification Under Review' : 'Verify Account',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isBannerMinimized = true),
                  child: const Text(
                    'Minimize',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPending
                        ? 'Your application is under PRC review. Processing usually takes up to 7 working days.'
                        : 'Get full access to all Blood-Connect services, get verified now!',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                if (!isPending)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const IdentityVerificationInfoScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Verify Now', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'In Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        secondChild: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.shield_outlined,
                  color: isPending ? Colors.amber : Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isPending
                      ? 'Verification pending (Takes up to 7 working days)'
                      : 'Verify Account for full access',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => setState(() => _isBannerMinimized = false),
              child: const Text(
                'Expand',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
