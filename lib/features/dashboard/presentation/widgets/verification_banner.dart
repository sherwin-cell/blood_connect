import 'package:flutter/material.dart';

import '../../../profile/domain/user_profile_model.dart';
import '../../../verification/domain/entities/account_verification_stage.dart';
import '../../../verification/presentation/identity_verification_flow.dart';
import '../../../verification/presentation/screens/identity_verification_info_screen.dart';
import '../../../verification/presentation/widgets/verification_stage_builder.dart';

/// Dashboard banner for users who are not verified yet.
///
/// "Not Verified" (no ID on file): Verify Now opens the intro screen, which
/// runs the ID upload and then the selfie. "Face Not Verified" (ID on file):
/// Verify Now goes straight to the selfie guide.
class VerificationBanner extends StatefulWidget {
  final UserProfile? profile;

  /// Test hook; see [VerificationStageBuilder.idSubmitted].
  final Stream<bool>? idSubmitted;

  const VerificationBanner({
    super.key,
    required this.profile,
    this.idSubmitted,
  });

  @override
  State<VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<VerificationBanner> {
  bool _isBannerMinimized = false;

  Future<void> _verifyNow(AccountVerificationStage stage) async {
    if (stage.needsIdUpload) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IdentityVerificationInfoScreen(),
        ),
      );
    } else {
      await IdentityVerificationFlow.startFaceVerification(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile?.faceVerified == true) {
      return const SizedBox.shrink();
    }

    return VerificationStageBuilder(
      profile: widget.profile,
      idSubmitted: widget.idSubmitted,
      builder: (context, stage) {
        if (stage == AccountVerificationStage.verified) {
          return const SizedBox.shrink();
        }
        final message = stage.bannerMessage(
          lastCheckFailed: widget.profile?.faceVerificationFailed ?? false,
        );
        return _buildBanner(stage, message);
      },
    );
  }

  Widget _buildBanner(AccountVerificationStage stage, String message) {
    final icon = stage.needsIdUpload
        ? Icons.badge_outlined
        : Icons.face_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                Row(
                  children: [
                    Icon(icon, color: Colors.orangeAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      stage.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
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
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _verifyNow(stage),
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
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  stage.label,
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
