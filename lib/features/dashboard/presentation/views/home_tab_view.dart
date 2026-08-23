import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../../verification/presentation/screens/identity_verification_info_screen.dart';
import '../../../verification/presentation/screens/verification_pending_screen.dart';
import '../../../blood_request/presentation/screens/post_blood_request_screen.dart';
import '../../../donor_application/presentation/screens/apply_donor_screen.dart';
import '../widgets/member_card.dart';

class HomeTabView extends StatelessWidget {
  final UserProfile? profile;

  const HomeTabView({super.key, required this.profile});

  void _handleProtectedFeature(
    BuildContext context,
    VoidCallback onApprovedAction,
  ) {
    final bool isVerified = profile?.isVerified ?? false;
    final String status = (profile?.verificationStatus ?? '').toLowerCase();

    if (isVerified || status == 'approved') {
      onApprovedAction();
    } else if (status == 'pending' || status == 'under_review') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const IdentityVerificationInfoScreen(),
        ),
      );
    }
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
          _buildInfoServicesGrid(),
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
            subtitle: 'Post a blood request.',
            buttonText: 'Post Blood Request',
            icon: Icons.water_drop_outlined,
            iconBgColor: Colors.red.shade50,
            iconColor: Colors.red.shade400,
            buttonColor: Colors.red.shade50,
            buttonTextColor: AppColors.primaryRed,
            onPressed: () {
              _handleProtectedFeature(
                context,
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PostBloodRequestScreen(),
                  ),
                ),
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
              _handleProtectedFeature(
                context,
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ApplyDonorScreen()),
                ),
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
            title: 'Matched Donor',
            subtitle: 'View donors who are compatible with your blood request.',
            icon: Icons.people_outline,
            onTap: () => _handleProtectedFeature(context, () {}),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMatchingCard(
            title: 'Blood Requester',
            subtitle: 'View blood requests that matched your blood type.',
            icon: Icons.bloodtype_outlined,
            onTap: () => _handleProtectedFeature(context, () {}),
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

  Widget _buildInfoServicesGrid() {
    return Row(
      children: [
        _buildInfoServiceItem(Icons.chat_bubble_outline, 'Chat with PRC'),
        const SizedBox(width: 8),
        _buildInfoServiceItem(Icons.menu_book_outlined, 'Help & Guides'),
        const SizedBox(width: 8),
        _buildInfoServiceItem(Icons.campaign_outlined, 'Announcements'),
        const SizedBox(width: 8),
        _buildInfoServiceItem(
          Icons.person_add_alt_1_outlined,
          'Refer a Friend',
        ),
      ],
    );
  }

  Widget _buildInfoServiceItem(IconData icon, String label) {
    return Expanded(
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
