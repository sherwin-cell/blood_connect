import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../blood_request/presentation/screens/post_blood_request_welcome_screen.dart';
import '../../../donor/presentation/screens/apply_donor_welcomescreen.dart';
import '../../../requests/presentation/request_rejection_screen.dart';

class ActivityTabView extends StatelessWidget {
  const ActivityTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view activity.'));
    }

    final firestore = context.read<FirestoreService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Blood requests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.getUserBloodRequests(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Could not load requests: ${snapshot.error}');
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'You have not submitted a blood request yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                return _RequestActivityTile(
                  title: 'Blood request for ${data['bloodType'] ?? '—'}',
                  status: (data['status'] as String? ?? 'pending')
                      .toLowerCase(),
                  rejectionReason:
                      data['rejectionReason'] as String? ??
                      data['adminNotes'] as String?,
                  onResubmit: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PostBloodRequestWelcomeScreen(),
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Donor application',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.getUserDonorApplication(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final doc = snapshot.data;
            if (doc == null || !doc.exists) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'You have not applied as a donor yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            final data = doc.data() ?? {};
            final status =
                (data['donorStatus'] as String? ??
                        data['status'] as String? ??
                        'pending')
                    .toLowerCase();
            return _RequestActivityTile(
              title: 'Donor application',
              status: status,
              rejectionReason:
                  data['rejectionReason'] as String? ??
                  data['adminNotes'] as String?,
              onResubmit: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ApplyDonorWelcomeScreen(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _RequestActivityTile extends StatelessWidget {
  final String title;
  final String status;
  final String? rejectionReason;
  final VoidCallback onResubmit;

  const _RequestActivityTile({
    required this.title,
    required this.status,
    required this.rejectionReason,
    required this.onResubmit,
  });

  Color get _statusColor {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return AppColors.primaryRed;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          status == 'rejected' && (rejectionReason ?? '').isNotEmpty
              ? 'Rejected — tap to view reason'
              : 'Status: $status',
        ),
        trailing: Text(
          status,
          style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
        ),
        onTap: status == 'rejected'
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestRejectionScreen(
                      title: title,
                      reason:
                          rejectionReason ??
                          'No specific notes provided by the administrator.',
                      onResubmit: onResubmit,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}
