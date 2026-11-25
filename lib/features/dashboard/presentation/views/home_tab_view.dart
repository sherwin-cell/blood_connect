import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../../blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import '../../../donor/presentation/screens/compatible_requests_screen.dart';
import '../../../donor/presentation/screens/apply_donor_welcomescreen.dart';
import '../../../donor/presentation/screens/matched_donors_screen.dart';
import '../../../chat/presentation/screens/prc_chat_room_screen.dart';
import '../../../announcements/presentation/screens/announcements_screen.dart';
import '../../../help/presentation/help_guides_screen.dart';
import '../../../referral/presentation/refer_friend_screen.dart';
import '../../../verification/presentation/verification_gate.dart';
import '../widgets/member_card.dart';
import '../../../../core/constants/statuses.dart';

class HomeTabView extends StatelessWidget {
  final UserProfile? profile;

  const HomeTabView({super.key, required this.profile});

  // ============================================================
  // VERIFICATION GATE
  // ============================================================

  /// Same check as "Submit a New Request" and "Resubmit application":
  /// see [VerificationGate].
  Future<void> _checkVerificationAndNavigate(
    BuildContext context, {
    required Widget destinationScreen,
    required String actionName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue.')),
      );
      return;
    }
    await VerificationGate.open(
      context,
      userId: user.uid,
      destination: destinationScreen,
      actionName: actionName,
      profile: profile,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: 18.0,
        right: 18.0,
        top: 8.0,
        bottom: 100.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MemberCard(profile: profile),

          const SizedBox(height: 24),

          _buildSectionHeader('Quick Access'),

          const SizedBox(height: 12),

          _buildQuickAccessGrid(context),

          const SizedBox(height: 24),

          _buildSectionHeader('Matching Center'),

          const SizedBox(height: 12),

          _buildMatchingCenterGrid(context),

          const SizedBox(height: 24),

          _buildSectionHeader('Information & Services'),

          const SizedBox(height: 12),

          _buildInfoServicesGrid(context),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // ============================================================
  // QUICK ACCESS
  // ============================================================

  Widget _buildQuickAccessGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            title: 'Need Blood?',
            subtitle: 'Apply for a blood request.',
            buttonText: 'Apply for Blood Request',
            icon: Icons.water_drop_outlined,
            iconBgColor: Colors.red.shade50,
            iconColor: Colors.red.shade400,
            buttonColor: Colors.red.shade50,
            buttonTextColor: AppColors.primaryRed,
            onPressed: () {
              debugPrint('========== APPLY BLOOD REQUEST PRESSED ==========');

              _checkVerificationAndNavigate(
                context,
                destinationScreen: const PostBloodRequestWelcomeScreen(),
                actionName: 'apply for a blood request',
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            title: 'Wants to donate?',
            subtitle: 'Become a donor.',
            buttonText: 'Apply as Blood Donor',
            icon: Icons.volunteer_activism_outlined,
            iconBgColor: Colors.orange.shade50,
            iconColor: Colors.orange.shade400,
            buttonColor: Colors.green.shade50,
            buttonTextColor: Colors.green.shade700,
            onPressed: () {
              debugPrint('========== APPLY DONOR PRESSED ==========');

              _checkVerificationAndNavigate(
                context,
                destinationScreen: const ApplyDonorWelcomeScreen(),
                actionName: 'apply as a blood donor',
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTION CARD
  // ============================================================

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color buttonColor,
    required Color buttonTextColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  color: buttonTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MATCHING CENTER
  // ============================================================

  Widget _buildMatchingCenterGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchingCard(
            title: 'Matched Donors',
            subtitle: 'Donors PRC confirmed for your blood request.',
            icon: Icons.people_outline,
            onTap: () {
              debugPrint('========== MATCHED DONORS PRESSED ==========');

              _openMatchedDonors(context);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMatchingCard(
            title: 'Blood Requester',
            subtitle: 'View approved blood requests matching your donor type.',
            icon: Icons.bloodtype_outlined,
            onTap: () {
              debugPrint('========== BLOOD REQUESTER PRESSED ==========');

              _openBloodRequester(context);
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MATCHED DONORS
  // ============================================================

  /// Donors PRC confirmed for the user's in-progress requests. The screen
  /// explains what to do when there is no request yet.
  Future<void> _openMatchedDonors(BuildContext context) async {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view matched donors.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MatchedDonorsScreen()),
    );
  }

  // ============================================================
  // BLOOD REQUESTER
  // ============================================================

  /// Open requests matching the donor's blood type. Only approved,
  /// available donors past their next eligible date may open it.
  Future<void> _openBloodRequester(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view blood requests.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final donorData =
          (await FirebaseFirestore.instance
                  .collection('donors')
                  .doc(user.uid)
                  .get())
              .data();
      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (donorData == null) {
        _showMatchingMessage(
          context,
          title: 'No Approved Donor Application',
          message:
              'You need an approved donor application before you can view '
              'matching blood requests.',
        );
        return;
      }

      // Same rule the offer uses: approved, available, past the next
      // eligible donation date set by PRC.
      final blockingReason = DonorEligibility.blockingReason(donorData);
      if (blockingReason != null) {
        _showMatchingMessage(
          context,
          title: 'Not Able to Donate Yet',
          message: blockingReason,
        );
        return;
      }

      final donorBloodType = (donorData['bloodType'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      if (donorBloodType.isEmpty) {
        _showMatchingMessage(
          context,
          title: 'Blood Type Unavailable',
          message:
              'Your approved donor application does not contain a blood type.',
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CompatibleRequestsScreen(donorBloodType: donorBloodType),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load your donor application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // MATCHING MESSAGE
  // ============================================================

  void _showMatchingMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message, style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'OK',
                style: TextStyle(color: AppColors.primaryRed),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MATCHING CARD
  // ============================================================

  Widget _buildMatchingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryRed, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFORMATION & SERVICES
  // ============================================================

  Widget _buildInfoServicesGrid(BuildContext context) {
    return Row(
      children: [
        _buildInfoServiceItem(
          Icons.chat_bubble_outline,
          'Chat with PRC',
          onTap: () async {
            debugPrint('========== CHAT WITH PRC PRESSED ==========');

            final user = FirebaseAuth.instance.currentUser;

            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please log in to chat with PRC support.'),
                ),
              );

              return;
            }

            final prcChatId = '${user.uid}_prc_support';

            await FirebaseFirestore.instance
                .collection('chats')
                .doc(prcChatId)
                .set({
                  'chatId': prcChatId,
                  'participants': [user.uid, 'prc_support_admin'],
                  'participantNames': {
                    user.uid: user.displayName ?? 'User',
                    'prc_support_admin': 'PRC Support',
                  },
                  'lastMessageTime': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

            if (!context.mounted) {
              return;
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PrcChatRoomScreen(
                  chatId: prcChatId,
                  otherUserName: 'PRC Support',
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        _buildInfoServiceItem(
          Icons.groups_outlined,
          'Refer a Friend',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ReferFriendScreen())),
        ),
        const SizedBox(width: 8),
        _buildInfoServiceItem(
          Icons.menu_book_outlined,
          'Help & Guides',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HelpGuidesScreen())),
        ),
        // Hidden until announcements are finished (see FeatureFlags).
        if (FeatureFlags.announcements) ...[
          const SizedBox(width: 8),
          _buildInfoServiceItem(
            Icons.campaign_outlined,
            'Announcements',
            underDevelopment: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // INFORMATION SERVICE ITEM
  // ============================================================

  Widget _buildInfoServiceItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool underDevelopment = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryRed, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (underDevelopment) ...[
                const SizedBox(height: 4),
                const UnderDevelopmentBadge(compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
