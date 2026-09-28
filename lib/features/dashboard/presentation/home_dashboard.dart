import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/firestore_service.dart';
import '../../profile/domain/user_profile_model.dart';
import '../../profile/presentation/profile_menu_screen.dart';
import 'views/home_tab_view.dart';
import 'views/activity_tab_view.dart';
import 'views/history_tab_view.dart';
import 'widgets/verification_banner.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      );
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
        final bool isAccountVerified = profile?.faceVerified ?? false;

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
              // Stream raw user document snapshot to safely extract selfieImageUrl from faceVerification map
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, docSnapshot) {
                  final data = docSnapshot.data?.data();
                  final faceVerificationMap =
                      data?['faceVerification'] as Map<String, dynamic>?;
                  final String? selfieUrl =
                      faceVerificationMap?['selfieImageUrl']; //[cite: 4]

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ProfileMenuScreen(),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage:
                            (selfieUrl != null && selfieUrl.isNotEmpty)
                            ? NetworkImage(selfieUrl)
                            : null,
                        child: (selfieUrl == null || selfieUrl.isEmpty)
                            ? const Icon(
                                Icons.account_circle,
                                color: Colors.black38,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeTabView(profile: profile),
                  const ActivityTabView(),
                  const HistoryTabView(),
                ],
              ),

              if (!isAccountVerified)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: VerificationBanner(profile: profile),
                ),
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
                icon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        );
      },
    );
  }
}
