import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/user_profile_model.dart';
import '../../../blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import '../../../donor/presentation/screens/compatible_requests_screen.dart';
import '../../../donor/presentation/screens/apply_donor_welcomescreen.dart';
import '../../../donor/presentation/screens/matched_donors_screen.dart';
import '../../../chat/presentation/screens/prc_chat_room_screen.dart';
import '../../../announcements/presentation/screens/announcements_screen.dart';
import '../../../verification/presentation/id_verification_flow.dart';
import '../widgets/member_card.dart';

class HomeTabView extends StatelessWidget {
  final UserProfile? profile;

  const HomeTabView({super.key, required this.profile});

  // ============================================================
  // VERIFICATION GATE
  // ============================================================

  Future<void> _checkVerificationAndNavigate(
    BuildContext context, {
    required Widget destinationScreen,
    required String actionName,
  }) async {
    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== VERIFICATION CHECK STARTED =============');
    debugPrint('====================================================');
    debugPrint('Action: $actionName');
    debugPrint('Home context mounted: ${context.mounted}');

    final user = FirebaseAuth.instance.currentUser;

    debugPrint('Firebase user exists: ${user != null}');
    debugPrint('Firebase user UID: ${user?.uid}');

    if (user == null) {
      debugPrint('STOP: No authenticated Firebase user.');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to continue.')),
      );

      return;
    }

    // ============================================================
    // 1. FACE VERIFICATION
    // ============================================================

    final bool isFaceVerified = profile?.faceVerified ?? false;

    debugPrint('');
    debugPrint('---------- FACE VERIFICATION CHECK ----------');
    debugPrint('Profile exists: ${profile != null}');
    debugPrint('Profile faceVerified: ${profile?.faceVerified}');
    debugPrint('isFaceVerified: $isFaceVerified');

    if (!isFaceVerified) {
      debugPrint('FACE VERIFICATION FAILED.');
      debugPrint('Showing Identity Verification Required dialog.');

      _showGateDialog(
        context,
        title: 'Identity Verification Required',
        message:
            'You must complete identity verification before you can $actionName.',
        buttonText: 'Complete Identity Verification',
        onPressed: () async {
          debugPrint('');
          debugPrint('========== FACE VERIFICATION BUTTON PRESSED ==========');

          // Keep your existing face verification navigation here.
          //
          // IMPORTANT:
          // Do NOT start ID verification from this callback.
          //
          // Example:
          // await FaceVerificationFlow.start(context);
        },
      );

      return;
    }

    debugPrint('FACE VERIFICATION PASSED.');

    // ============================================================
    // 2. CHECK ID SUBMISSION
    // ============================================================

    debugPrint('');
    debugPrint('---------- ID SUBMISSION CHECK ----------');
    debugPrint('Checking Firestore document:');
    debugPrint('id_verifications/${user.uid}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        debugPrint('Loading dialog CREATED.');

        return const Center(child: CircularProgressIndicator());
      },
    );

    bool hasSubmittedId = false;

    try {
      debugPrint('Reading Firestore ID verification document...');

      final docSnap = await FirebaseFirestore.instance
          .collection('id_verifications')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      debugPrint('Firestore read COMPLETED.');
      debugPrint('Document exists: ${docSnap.exists}');
      debugPrint('Document data: ${docSnap.data()}');

      hasSubmittedId = docSnap.exists && docSnap.data() != null;

      debugPrint('hasSubmittedId: $hasSubmittedId');
    } catch (e, stackTrace) {
      debugPrint('ERROR reading ID verification document.');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      hasSubmittedId = false;
    }

    // ============================================================
    // DISMISS LOADING DIALOG
    // ============================================================

    debugPrint('');
    debugPrint('---------- DISMISSING LOADING DIALOG ----------');

    if (!context.mounted) {
      debugPrint('STOP: Home context is no longer mounted.');

      return;
    }

    Navigator.of(context).pop();

    debugPrint('Loading dialog dismissed.');

    // ============================================================
    // 3. ID DOES NOT EXIST
    // ============================================================

    if (!hasSubmittedId) {
      debugPrint('');
      debugPrint('========== ID SUBMISSION DOES NOT EXIST ==========');

      debugPrint('Showing ID Submission Required dialog.');

      _showGateDialog(
        context,
        title: 'ID Submission Required',
        message:
            'You must submit a valid government ID before you can $actionName.',
        buttonText: 'Submit Valid ID',
        onPressed: () async {
          debugPrint('');
          debugPrint('====================================================');
          debugPrint('========== HOME: ID BUTTON ACTION =================');
          debugPrint('====================================================');

          debugPrint(
            'Home context mounted BEFORE start: '
            '${context.mounted}',
          );

          if (!context.mounted) {
            debugPrint('STOP: Home context is no longer mounted.');

            return;
          }

          try {
            debugPrint('HOME: Calling IdVerificationFlow.start(context)...');

            final result = await IdVerificationFlow.start(context);

            debugPrint('');
            debugPrint('====================================================');
            debugPrint('========== HOME: ID VERIFICATION RETURNED =========');
            debugPrint('====================================================');

            debugPrint('HOME: Result = $result');
            debugPrint('HOME: Result is null = ${result == null}');

            debugPrint(
              'HOME: Context mounted after return = '
              '${context.mounted}',
            );

            if (result != null) {
              debugPrint('HOME: ID verification returned data.');

              debugPrint('ID Type: ${result.idType}');

              debugPrint('Front ID: ${result.frontIdImage}');

              debugPrint('Back ID: ${result.backIdImage}');

              debugPrint(
                'Validation Status: '
                '${result.validationStatus}',
              );

              debugPrint('Submitted At: ${result.submittedAt}');
            } else {
              debugPrint('HOME: ID verification returned NULL.');
            }

            // ==================================================
            // IMPORTANT:
            //
            // Do NOT automatically navigate to the destination.
            //
            // ID submission still requires PRC/admin approval.
            // ==================================================
          } catch (e, stackTrace) {
            debugPrint('');
            debugPrint('====================================================');
            debugPrint('========== HOME: ID VERIFICATION ERROR ============');
            debugPrint('====================================================');

            debugPrint('Error: $e');
            debugPrint('StackTrace: $stackTrace');
          }
        },
      );

      return;
    }

    // ============================================================
    // 4. ALL CHECKS PASSED
    // ============================================================

    debugPrint('');
    debugPrint('====================================================');
    debugPrint('========== ALL VERIFICATION CHECKS PASSED =========');
    debugPrint('====================================================');

    if (!context.mounted) {
      debugPrint('STOP: Home context no longer mounted.');

      return;
    }

    debugPrint('Navigating to destination screen...');

    debugPrint('Destination: $destinationScreen');

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => destinationScreen));

    debugPrint('Destination navigation returned.');
  }

  // ============================================================
  // GATE DIALOG
  // ============================================================

  void _showGateDialog(
    BuildContext homeContext, {
    required String title,
    required String message,
    required String buttonText,
    required Future<void> Function() onPressed,
  }) {
    debugPrint('');
    debugPrint('========== SHOWING GATE DIALOG ==========');

    debugPrint('Title: $title');
    debugPrint('Button: $buttonText');

    showDialog(
      context: homeContext,
      builder: (dialogContext) {
        debugPrint('');
        debugPrint('========== DIALOG BUILDER CREATED ==========');

        debugPrint(
          'Dialog context mounted: '
          '${dialogContext.mounted}',
        );

        debugPrint(
          'Home context mounted: '
          '${homeContext.mounted}',
        );

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
                debugPrint('');
                debugPrint('========== DIALOG CANCEL PRESSED ==========');

                Navigator.of(dialogContext).pop();

                debugPrint('Dialog closed.');
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                debugPrint('');
                debugPrint(
                  '====================================================',
                );
                debugPrint(
                  '========== GATE DIALOG BUTTON PRESSED =============',
                );
                debugPrint(
                  '====================================================',
                );

                debugPrint('Button: $buttonText');

                Navigator.of(dialogContext).pop();

                debugPrint('Gate dialog close command completed.');

                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  debugPrint('');
                  debugPrint(
                    '====================================================',
                  );
                  debugPrint(
                    '========== AFTER DIALOG CLOSED ====================',
                  );
                  debugPrint(
                    '====================================================',
                  );

                  if (!homeContext.mounted) {
                    debugPrint('STOP: Home context is no longer mounted.');

                    return;
                  }

                  try {
                    await onPressed();

                    debugPrint(
                      '========== GATE ACTION COMPLETED ==================',
                    );
                  } catch (e, stackTrace) {
                    debugPrint(
                      '========== GATE ACTION ERROR ======================',
                    );

                    debugPrint('Error: $e');

                    debugPrint('StackTrace: $stackTrace');
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: Text(
                buttonText,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
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

  // ============================================================
  // MATCHING CENTER
  // ============================================================

  Widget _buildMatchingCenterGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchingCard(
            title: 'Matched Donors',
            subtitle: 'View approved donors for your approved blood request.',
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

  Future<void> _openMatchedDonors(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view matched donors.')),
      );

      return;
    }

    debugPrint(
      'MATCHED DONORS: Loading approved requests '
      'for user ${user.uid}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('blood_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'approved')
          .get();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pop();

      debugPrint(
        'MATCHED DONORS: Approved requests found: '
        '${querySnapshot.docs.length}',
      );

      if (querySnapshot.docs.isEmpty) {
        _showMatchingMessage(
          context,
          title: 'No Approved Blood Request',
          message:
              'You need an approved blood request before we can find matched donors.',
        );

        return;
      }

      /*
       * If a user has multiple approved requests, use the
       * most recently created one.
       *
       * The blood type comes from the blood request itself,
       * NOT from the user's profile.
       */
      final sortedDocs = [...querySnapshot.docs];

      sortedDocs.sort((a, b) {
        final aTimestamp = a.data()['createdAt'];

        final bTimestamp = b.data()['createdAt'];

        if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
          return bTimestamp.compareTo(aTimestamp);
        }

        if (aTimestamp is Timestamp) {
          return -1;
        }

        if (bTimestamp is Timestamp) {
          return 1;
        }

        return 0;
      });

      final requestData = sortedDocs.first.data();

      final requestBloodType = (requestData['bloodType'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      final requestId = sortedDocs.first.id;

      debugPrint('MATCHED DONORS: Selected request ID: $requestId');

      debugPrint('MATCHED DONORS: Request blood type: $requestBloodType');

      if (requestBloodType.isEmpty) {
        _showMatchingMessage(
          context,
          title: 'Blood Type Unavailable',
          message: 'Your approved blood request does not contain a blood type.',
        );

        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MatchedDonorsScreen(requesterBloodType: requestBloodType),
        ),
      );
    } catch (e, stackTrace) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      debugPrint('MATCHED DONORS: Error loading approved request.');

      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your approved blood request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // BLOOD REQUESTER
  // ============================================================

  Future<void> _openBloodRequester(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to view blood requests.')),
      );

      return;
    }

    debugPrint(
      'BLOOD REQUESTER: Loading donor application '
      'for user ${user.uid}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final donorSnapshot = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();

      if (!context.mounted) {
        return;
      }

      Navigator.of(context).pop();

      debugPrint(
        'BLOOD REQUESTER: Donor document exists: '
        '${donorSnapshot.exists}',
      );

      if (!donorSnapshot.exists || donorSnapshot.data() == null) {
        _showMatchingMessage(
          context,
          title: 'No Approved Donor Application',
          message:
              'You need an approved donor application before you can view matching blood requests.',
        );

        return;
      }

      final donorData = donorSnapshot.data()!;

      final donorStatus = (donorData['donorStatus'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final isDonor = donorData['isDonor'] == true;

      final isAvailable = donorData['isAvailableForDonation'] == true;

      final donorBloodType = (donorData['bloodType'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      debugPrint('BLOOD REQUESTER: donorStatus=$donorStatus');

      debugPrint('BLOOD REQUESTER: isDonor=$isDonor');

      debugPrint('BLOOD REQUESTER: isAvailable=$isAvailable');

      debugPrint('BLOOD REQUESTER: bloodType=$donorBloodType');

      if (donorStatus != 'approved' || !isDonor) {
        _showMatchingMessage(
          context,
          title: 'Donor Application Not Approved',
          message:
              'Your donor application must be approved by PRC before you can view matching blood requests.',
        );

        return;
      }

      if (!isAvailable) {
        _showMatchingMessage(
          context,
          title: 'Donation Availability Disabled',
          message:
              'Your donor application is approved, but you are currently unavailable for donation.',
        );

        return;
      }

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
          builder: (_) => CompatibleRequestsScreen(
            donorBloodType: donorBloodType,
            donorName: (donorData['fullName'] ?? 'Donor').toString(),
            donorContact:
                (donorData['phoneNumber'] ?? donorData['contactNumber'] ?? '')
                    .toString(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      debugPrint('BLOOD REQUESTER: Error loading donor application.');

      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load your donor application: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          Icons.campaign_outlined,
          'Announcements',
          onTap: () {
            debugPrint('========== ANNOUNCEMENTS PRESSED ==========');

            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
            );
          },
        ),
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
