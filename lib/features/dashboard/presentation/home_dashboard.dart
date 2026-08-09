import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/firestore_service.dart';
import '../../auth/data/auth_service.dart';
import '../../profile/domain/user_profile_model.dart';
import '../../profile/presentation/complete_profile_screen.dart';
import '../../verification/presentation/screens/identity_verification_info_screen.dart';
import '../../verification/presentation/screens/verification_pending_screen.dart';
import 'post_blood_request_screen.dart';
import 'apply_donor_screen.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService =
      AuthService(); // Integrated AuthService instance
  int _selectedIndex = 0;

  Future<void> _signOut() async {
    try {
      // Calls AuthService logout to clear GoogleSignIn + FirebaseAuth sessions
      await _authService.logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  /// Verification Guard Handler
  void _handleProtectedFeature(
    BuildContext context,
    UserProfile? profile,
    VoidCallback onApprovedAction,
  ) {
    final bool isVerified = profile?.isVerified ?? false;
    final String? status = profile?.verificationStatus;

    if (isVerified) {
      onApprovedAction();
    } else if (status == 'pending') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VerificationPendingScreen()),
      );
    } else {
      _showVerificationPromptDialog(context);
    }
  }

  void _showVerificationPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primaryRed),
            SizedBox(width: 8),
            Text('Verification Required', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'You must complete identity verification before you can post blood requests, apply as a donor, or access matching features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IdentityVerificationInfoScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user logged in.')));
    }

    return StreamBuilder<UserProfile?>(
      stream: _firestoreService.getUserProfileStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            ),
          );
        }

        final profile = snapshot.data;

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Blood-Connect',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.black87,
                ),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.account_circle,
                  color: Colors.black38,
                  size: 28,
                ),
                onPressed: () {
                  // Index 3 matches the History/Profile tab where sign out resides
                  setState(() => _selectedIndex = 3);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(profile),
              _buildActivityTab(),
              _buildNotificationTab(),
              _buildHistoryTab(profile),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: AppColors.primaryRed,
            unselectedItemColor: Colors.grey.shade400,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assignment_outlined),
                activeIcon: Icon(Icons.assignment),
                label: 'Activity',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                activeIcon: Icon(Icons.notifications),
                label: 'Notification',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB BUILDERS ---

  Widget _buildHomeTab(UserProfile? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMemberCard(profile),
          const SizedBox(height: 24),
          _buildSectionHeader('Quick Access'),
          const SizedBox(height: 12),
          _buildQuickAccessGrid(profile),
          const SizedBox(height: 24),
          _buildSectionHeader('Matching Center'),
          const SizedBox(height: 12),
          _buildMatchingCenterGrid(profile),
          const SizedBox(height: 24),
          _buildSectionHeader('Information & Services'),
          const SizedBox(height: 12),
          _buildInfoServicesGrid(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActivityTab() => const Center(child: Text('Activity Screen'));
  Widget _buildNotificationTab() =>
      const Center(child: Text('Notifications Screen'));

  Widget _buildHistoryTab(UserProfile? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit Profile'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CompleteProfileScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  // --- DESIGN COMPONENTS ---

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

  /// Top Red Banner
  Widget _buildMemberCard(UserProfile? profile) {
    final name = profile?.fullName ?? 'Ana Santos';
    final bool isVerified = profile?.isVerified ?? false;
    final String memberId = profile?.uid != null
        ? 'BC-${profile!.uid.substring(0, 5).toUpperCase()}'
        : 'BC-00214';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hello,',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.error_outline,
                          color: isVerified
                              ? Colors.lightGreenAccent
                              : Colors.orangeAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'PRC-Verified User' : 'Unverified User',
                          style: TextStyle(
                            color: isVerified ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MEMBER ID',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Available',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Quick Access Cards
  Widget _buildQuickAccessGrid(UserProfile? profile) {
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
                profile,
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
                profile,
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

  /// Matching Center Cards
  Widget _buildMatchingCenterGrid(UserProfile? profile) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchingCard(
            title: 'Matched Donor',
            subtitle: 'View donors who are compatible with your blood request.',
            icon: Icons.people_outline,
            onTap: () {
              _handleProtectedFeature(context, profile, () {
                // Navigate to Matched Donors Screen
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMatchingCard(
            title: 'Blood Requester',
            subtitle: 'View blood requests that matched your blood type.',
            icon: Icons.bloodtype_outlined,
            onTap: () {
              _handleProtectedFeature(context, profile, () {
                // Navigate to Matched Requesters Screen
              });
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

  /// 4-Grid Information & Services Section
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
