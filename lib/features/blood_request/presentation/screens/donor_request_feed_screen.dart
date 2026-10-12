import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../donor/data/repositories/donor_repository_impl.dart';

class DonorRequestFeedScreen extends StatefulWidget {
  const DonorRequestFeedScreen({super.key});

  @override
  State<DonorRequestFeedScreen> createState() => _DonorRequestFeedScreenState();
}

class _DonorRequestFeedScreenState extends State<DonorRequestFeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DonorRepositoryImpl _donorRepository = DonorRepositoryImpl();

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _currentUserId;

    if (currentUserId == null) {
      return _buildErrorScaffold(
        context,
        'You must be logged in to view matching blood requests.',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Blood Requester',
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('donors').doc(currentUserId).snapshots(),
        builder: (context, donorSnapshot) {
          if (donorSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (donorSnapshot.hasError) {
            return _buildMessage(
              icon: Icons.error_outline,
              message: 'Error loading your donor information.',
            );
          }

          final donorDoc = donorSnapshot.data;

          if (donorDoc == null || !donorDoc.exists) {
            return _buildMessage(
              icon: Icons.person_outline,
              message: 'You do not have a donor application yet.',
              subtitle:
                  'Apply as a donor first before viewing matching blood requests.',
            );
          }

          final donorData = donorDoc.data();

          if (donorData == null) {
            return _buildMessage(
              icon: Icons.person_outline,
              message: 'Your donor information could not be loaded.',
            );
          }

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

          final donorName =
              (donorData['fullName'] ?? donorData['name'] ?? 'Anonymous Donor')
                  .toString();

          final donorContact =
              (donorData['contactNumber'] ??
                      donorData['phoneNumber'] ??
                      donorData['contact'] ??
                      '')
                  .toString();

          // A donor must be approved before they can participate
          // in the matching center.
          if (donorStatus != 'approved' || !isDonor) {
            return _buildMessage(
              icon: Icons.pending_actions_outlined,
              message: 'Your donor application is not approved yet.',
              subtitle:
                  'Only approved donors can view matching blood requests.',
            );
          }

          if (!isAvailable) {
            return _buildMessage(
              icon: Icons.event_busy_outlined,
              message: 'You are currently unavailable for donation.',
              subtitle:
                  'Update your donor availability to view matching requests.',
            );
          }

          if (donorBloodType.isEmpty) {
            return _buildMessage(
              icon: Icons.bloodtype_outlined,
              message: 'Your donor blood type is missing.',
              subtitle:
                  'Your donor profile needs a valid blood type before matching can be performed.',
            );
          }

          return _buildMatchingRequests(
            currentUserId: currentUserId,
            donorBloodType: donorBloodType,
            donorName: donorName,
            donorContact: donorContact,
          );
        },
      ),
    );
  }

  Widget _buildMatchingRequests({
    required String currentUserId,
    required String donorBloodType,
    required String donorName,
    required String donorContact,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _donorRepository.getCompatibleRequestsStream(donorBloodType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildMessage(
            icon: Icons.error_outline,
            message: 'Error loading matching blood requests.',
            subtitle: '${snapshot.error}',
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        final docs = allDocs.where((doc) {
          final data = doc.data();

          final requestStatus = (data['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          final requestUserId =
              (data['userId'] ?? data['requesterId'] ?? data['creatorId'] ?? '')
                  .toString();

          final requestBloodType = (data['bloodType'] ?? '')
              .toString()
              .trim()
              .toUpperCase();

          // Matching requirements:
          //
          // 1. Request must be approved.
          // 2. Request must belong to another user.
          // 3. Blood type must exactly match the donor's
          //    blood type.
          return requestStatus == 'approved' &&
              requestUserId != currentUserId &&
              requestBloodType == donorBloodType;
        }).toList();

        // Sort newest requests first locally so this screen
        // does not require a Firestore composite index.
        docs.sort((a, b) {
          final aTimestamp = _timestampValue(a.data()['createdAt']);

          final bTimestamp = _timestampValue(b.data()['createdAt']);

          return bTimestamp.compareTo(aTimestamp);
        });

        if (docs.isEmpty) {
          return _buildNoMatches(donorBloodType);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMatchingHeader(donorBloodType, docs.length),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];

                  return _buildRequestCard(
                    context: context,
                    requestId: doc.id,
                    data: doc.data(),
                    donorId: currentUserId,
                    donorName: donorName,
                    donorContact: donorContact,
                    donorBloodType: donorBloodType,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMatchingHeader(String donorBloodType, int requestCount) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bloodtype_outlined,
              color: AppColors.primaryRed,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Matching Blood Requests',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Showing approved requests for blood type $donorBloodType.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            '$requestCount',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> data,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) {
    final patientName = (data['patientName'] ?? 'Unknown Patient').toString();

    final bloodType = (data['bloodType'] ?? 'N/A').toString();

    final hospital = (data['hospitalLocation'] ?? 'Unknown Hospital')
        .toString();

    final units = (data['unitsRequired'] ?? '1').toString();

    final urgency = (data['urgency'] ?? 'Normal').toString();

    final contactPerson = (data['contactPerson'] ?? '').toString();

    final contactNumber = (data['contactNumber'] ?? '').toString();

    final notes = (data['notes'] ?? '').toString();

    final relationship =
        (data['relationship'] ?? data['patientRelationship'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  patientName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  bloodType,
                  style: TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          if (relationship.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Relationship: $relationship',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hospital,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(Icons.opacity, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Units Needed: $units',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                'Urgency: $urgency',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: $notes',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          if (contactPerson.isNotEmpty || contactNumber.isNotEmpty)
            Text(
              'Contact: ${contactPerson.isNotEmpty ? contactPerson : 'Not provided'}'
              '${contactNumber.isNotEmpty ? ' ($contactNumber)' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _submitOffer(
                  context: context,
                  requestId: requestId,
                  donorId: donorId,
                  donorName: donorName,
                  donorContact: donorContact,
                  donorBloodType: donorBloodType,
                );
              },
              icon: const Icon(Icons.volunteer_activism_outlined, size: 18),
              label: const Text(
                'Offer to Help',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                foregroundColor: Colors.green.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOffer({
    required BuildContext context,
    required String requestId,
    required String donorId,
    required String donorName,
    required String donorContact,
    required String donorBloodType,
  }) async {
    try {
      await _donorRepository.offerToDonate(
        requestId: requestId,
        donorId: donorId,
        donorName: donorName,
        donorContact: donorContact,
        donorBloodType: donorBloodType,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your offer to help has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNoMatches(String donorBloodType) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 60,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            const Text(
              'No matching blood requests found.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'There are currently no approved blood requests '
              'from other users for blood type $donorBloodType.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
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
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Blood Requester',
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
      body: _buildMessage(icon: Icons.lock_outline, message: message),
    );
  }

  int _timestampValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    return 0;
  }
}
