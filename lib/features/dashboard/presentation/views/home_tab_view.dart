import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../../blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import '../../../blood_request/presentation/screens/donor_request_feed_screen.dart';
import '../../../donor/presentation/screens/apply_donor_welcomescreen.dart';
import '../../../donor/presentation/screens/matched_donors_screen.dart';
import '../../../chat/presentation/screens/prc_chat_room_screen.dart';
import '../../../announcements/presentation/screens/announcements_screen.dart';
import '../../../verification/presentation/id_verification_flow.dart';
import '../widgets/member_card.dart';

class HomeTabView extends StatelessWidget {
  final UserProfile? profile;

  const HomeTabView({super.key, required this.profile});

  /// Gated check for Apply for Blood Request & Donor Application
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

    // 1. Check Face Verification Prerequisite
    final bool isFaceVerified = profile?.faceVerified ?? false;
    if (!isFaceVerified) {
      _showGateDialog(
        context,
        title: 'Face Verification Required',
        message:
            'You must complete Face Verification before you can $actionName.',
        buttonText: 'Complete Face Verification',
        onPressed: () {
          Navigator.pop(context);
        },
      );
      return;
    }

    // 2. Check ID Submission Prerequisite safely with error suppression
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    bool hasSubmittedId = false;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('id_verifications')
          .doc(user.uid)
          .get(GetOptions(source: Source.serverAndCache));

      hasSubmittedId = docSnap.exists && docSnap.data() != null;
    } catch (e) {
      hasSubmittedId = false;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    if (!hasSubmittedId) {
      _showGateDialog(
        context,
        title: 'ID Submission Required',
        message:
            'You must submit a valid government ID before you can $actionName.',
        buttonText: 'Submit Valid ID',
        onPressed: () async {
          Navigator.pop(context);
          await IdVerificationFlow.start(context);
        },
      );
      return;
    }

    // 3. All checks passed! Proceed to destination
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destinationScreen));
  }

  void _showGateDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

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
              _checkVerificationAndNavigate(
                context,
                destinationScreen: const PostBloodRequestWelcomeScreen(),
                actionName: 'Aplly for a blood request',
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
        border: Border.all(color: Colors.black.withOpacity(0.05)),
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

  Widget _buildMatchingCenterGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchingCard(
            title: 'Matched Donors',
            subtitle: 'View donors compatible with your requests.',
            icon: Icons.people_outline,
            onTap: () {
              final userBloodType = profile?.bloodType ?? 'O+';
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MatchedDonorsScreen(requesterBloodType: userBloodType),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMatchingCard(
            title: 'Blood Requester',
            subtitle: 'View blood requests matching your type.',
            icon: Icons.bloodtype_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DonorRequestFeedScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

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
          border: Border.all(color: Colors.black.withOpacity(0.05)),
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

  Widget _buildInfoServicesGrid(BuildContext context) {
    return Row(
      children: [
        _buildInfoServiceItem(
          Icons.chat_bubble_outline,
          'Chat with PRC',
          onTap: () async {
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

            if (!context.mounted) return;
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
          Icons.campaign_outlined,
          'Announcements',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoServiceItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
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
            border: Border.all(color: Colors.black.withOpacity(0.05)),
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
            ],
          ),
        ),
      ),
    );
  }
}
