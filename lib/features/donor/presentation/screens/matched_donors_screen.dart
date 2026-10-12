import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/donor_repository_impl.dart';
import '../../../chat/presentation/screens/prc_chat_room_screen.dart';

class MatchedDonorsScreen extends StatelessWidget {
  final String requesterBloodType;
  final DonorRepositoryImpl _donorRepository = DonorRepositoryImpl();

  MatchedDonorsScreen({super.key, required this.requesterBloodType});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final normalizedRequesterBloodType = requesterBloodType
        .trim()
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Matched Donors',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Requested blood type information
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.red.shade50,
                  child: Text(
                    normalizedRequesterBloodType.isEmpty
                        ? 'N/A'
                        : normalizedRequesterBloodType,
                    style: TextStyle(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Approved Blood Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Showing approved and available donors with the exact same blood type.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _donorRepository.getCompatibleDonorsStream(
                normalizedRequesterBloodType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading donors: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                if (normalizedRequesterBloodType.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.bloodtype_outlined,
                    message:
                        'No blood type is available for your approved blood request.',
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                /*
                 * A donor is eligible for this Matching Center list only when:
                 *
                 * 1. donorStatus == approved
                 * 2. isDonor == true
                 * 3. isAvailableForDonation == true
                 * 4. bloodType exactly matches the request blood type
                 * 5. donor is not the current user
                 *
                 * Blood type matching is exact.
                 */
                final docs = allDocs.where((doc) {
                  final data = doc.data();

                  final donorId = (data['userId'] ?? data['uid'] ?? doc.id)
                      .toString();

                  final donorStatus = (data['donorStatus'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  final isDonor = data['isDonor'] == true;

                  final isAvailable = data['isAvailableForDonation'] == true;

                  final donorBloodType = (data['bloodType'] ?? '')
                      .toString()
                      .trim()
                      .toUpperCase();

                  final isCurrentUser =
                      currentUserId != null && donorId == currentUserId;

                  final hasApprovedStatus = donorStatus == 'approved';

                  final exactBloodTypeMatch =
                      donorBloodType == normalizedRequesterBloodType;

                  return !isCurrentUser &&
                      hasApprovedStatus &&
                      isDonor &&
                      isAvailable &&
                      exactBloodTypeMatch;
                }).toList();

                if (docs.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.people_outline,
                    message:
                        'No approved and available donors with blood type '
                        '$normalizedRequesterBloodType are available right now.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final donorUserId =
                        (data['userId'] ?? data['uid'] ?? doc.id).toString();

                    final donorName =
                        (data['fullName'] ?? data['name'] ?? 'Anonymous Donor')
                            .toString();

                    final donorBloodType = (data['bloodType'] ?? 'N/A')
                        .toString()
                        .trim()
                        .toUpperCase();

                    final chapter = (data['chapter'] ?? 'PRC Chapter')
                        .toString();

                    return _buildDonorCard(
                      context: context,
                      currentUserId: currentUserId,
                      donorUserId: donorUserId,
                      donorName: donorName,
                      donorBloodType: donorBloodType,
                      chapter: chapter,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorCard({
    required BuildContext context,
    required String? currentUserId,
    required String donorUserId,
    required String donorName,
    required String donorBloodType,
    required String chapter,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.red.shade50,
            child: Text(
              donorBloodType,
              style: TextStyle(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Blood Type: $donorBloodType',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chapter: $chapter',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: currentUserId == null
                ? null
                : () => _startChat(
                    context: context,
                    currentUserId: currentUserId,
                    donorUserId: donorUserId,
                    donorName: donorName,
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryRed,
              side: BorderSide(color: AppColors.primaryRed.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Connect', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat({
    required BuildContext context,
    required String currentUserId,
    required String donorUserId,
    required String donorName,
  }) async {
    if (currentUserId == donorUserId) {
      return;
    }

    final ids = [currentUserId, donorUserId]..sort();
    final chatId = ids.join('_');

    try {
      final chatDocRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId);

      await chatDocRef.set({
        'chatId': chatId,
        'participants': [currentUserId, donorUserId],
        'participantNames': {donorUserId: donorName},
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PrcChatRoomScreen(chatId: chatId, otherUserName: donorName),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
