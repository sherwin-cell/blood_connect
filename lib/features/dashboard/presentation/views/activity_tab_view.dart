import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/statuses.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/streams.dart';
import '../../../../core/widgets/pill_switcher.dart';
import '../../../blood_request/domain/request_progress.dart';
import '../../../blood_request/presentation/screens/my_request_details_screen.dart';
import '../../../blood_request/presentation/widgets/request_progress_widgets.dart';
import '../../../donor/presentation/screens/apply_donor_welcomescreen.dart';
import '../../../requests/presentation/request_rejection_screen.dart';
import '../../../verification/presentation/verification_gate.dart';
import '../widgets/my_offers_section.dart';

enum ActivitySection { bloodRequest, donation }

/// Activity tab: the user's current blood requests (with live PRC progress)
/// and, under Donation, their donor offers and donor application.
///
/// Fulfilled, cancelled and expired requests are in the History tab.
class ActivityTabView extends StatefulWidget {
  const ActivityTabView({super.key});

  @override
  State<ActivityTabView> createState() => _ActivityTabViewState();
}

class _ActivityTabViewState extends State<ActivityTabView> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  // Re-listenable: switching sub-tabs rebuilds the list and re-subscribes.
  late final Stream<List<MapEntry<String, Map<String, dynamic>>>>? _requests =
      _uid == null
      ? null
      : relistenable(
          () => FirebaseFirestore.instance
              .collection('blood_requests')
              .where('userId', isEqualTo: _uid)
              .snapshots()
              .map((s) => [for (final d in s.docs) MapEntry(d.id, d.data())]),
        );

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in to view activity.'));
    }
    return ActivityView(
      userId: uid,
      requests: _requests!,
      donationTab: (_) => _DonationActivity(userId: uid),
    );
  }
}

/// The Activity layout, fed by a stream so it can be tested without
/// Firebase.
class ActivityView extends StatefulWidget {
  const ActivityView({
    super.key,
    required this.userId,
    required this.requests,
    required this.donationTab,
    this.initialSection = ActivitySection.bloodRequest,
    this.openDetails,
  });

  final String userId;

  /// The user's blood requests (id → data), any status.
  final Stream<List<MapEntry<String, Map<String, dynamic>>>> requests;
  final WidgetBuilder donationTab;
  final ActivitySection initialSection;

  /// Test hook; defaults to pushing [MyRequestDetailsScreen].
  final void Function(BuildContext context, String requestId)? openDetails;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  late ActivitySection _section = widget.initialSection;

  void _open(String requestId) {
    final open = widget.openDetails;
    if (open != null) return open(context, requestId);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MyRequestDetailsScreen(requestId: requestId, userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Room for the floating verification banner.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        PillSwitcher<ActivitySection>(
          options: const [
            (ActivitySection.bloodRequest, 'Blood Request'),
            (ActivitySection.donation, 'Donation'),
          ],
          selected: _section,
          onChanged: (s) => setState(() => _section = s),
        ),
        const SizedBox(height: 16),
        if (_section == ActivitySection.bloodRequest) ...[
          const _SectionHeader(),
          const SizedBox(height: 16),
          StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
            stream: widget.requests,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Activity requests failed: ${snapshot.error}');
                return const _Note(
                  icon: Icons.cloud_off_outlined,
                  text:
                      'Could not load your blood requests. Please try '
                      'again later.',
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: requestRed),
                  ),
                );
              }
              final requests =
                  [
                    for (final doc in snapshot.data!)
                      if (RequestProgress.showInActivity(
                        doc.value['status']?.toString(),
                      ))
                        RequestProgress.fromFirestore(doc.key, doc.value),
                  ]..sort((a, b) {
                    final at = a.createdAt, bt = b.createdAt;
                    if (at == null) return 1;
                    if (bt == null) return -1;
                    return bt.compareTo(at);
                  });
              if (requests.isEmpty) {
                return const _Note(
                  icon: Icons.bloodtype_outlined,
                  title: 'No active blood requests',
                  text:
                      'Use Apply for Blood Request on the Home tab when '
                      'you need blood. Past requests are in History.',
                );
              }
              return Column(
                children: [
                  for (final p in requests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ActivityRequestCard(
                        progress: p,
                        onViewDetails: () => _open(p.id),
                      ),
                    ),
                  const _Note(
                    icon: Icons.history,
                    text:
                        'Fulfilled, cancelled and expired requests move to '
                        'the History tab.',
                  ),
                ],
              );
            },
          ),
        ] else
          widget.donationTab(context),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: requestSoftRed,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.water_drop, color: requestRed),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blood Request',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text(
                'Track your blood requests and follow updates from '
                'PRC-Sorsogon.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One request in the Activity tab: header, information, status callout,
/// progress timeline and a link to Request Details.
class ActivityRequestCard extends StatelessWidget {
  const ActivityRequestCard({
    super.key,
    required this.progress,
    required this.onViewDetails,
  });

  final RequestProgress progress;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return RequestCardShell(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BloodTypeBadge(p.bloodType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.reference,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Blood Request',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RequestStatusChip(p),
                  ],
                ),
                const Divider(height: 28),
                const RequestSectionTitle('Request Information'),
                RequestInfoRows(rows: RequestInfoRows.basic(p)),
                const SizedBox(height: 12),
                RequestStatusCallout(p),
                const SizedBox(height: 16),
                const RequestSectionTitle('Request Progress'),
                RequestProgressTimeline(steps: p.steps),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            onTap: onViewDetails,
            title: const Text(
              'View Request Details',
              style: TextStyle(fontWeight: FontWeight.w600, color: requestRed),
            ),
            trailing: const Icon(Icons.chevron_right, color: requestRed),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.title});

  final IconData icon;
  final String? title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: requestSoftRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: requestRed),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  text,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Donation sub-tab: donor offers and donor application (unchanged behaviour)
// ---------------------------------------------------------------------------

class _DonationActivity extends StatefulWidget {
  const _DonationActivity({required this.userId});

  final String userId;

  @override
  State<_DonationActivity> createState() => _DonationActivityState();
}

class _DonationActivityState extends State<_DonationActivity> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _application =
      FirebaseFirestore.instance
          .collection('donors')
          .doc(widget.userId)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MyOffersSection(donorId: widget.userId, showWhenEmpty: true),
        const SizedBox(height: 24),
        const Text(
          'Donor application',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _application,
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
                        DonorStatus.pending)
                    .toLowerCase();
            return _DonorApplicationTile(
              userId: widget.userId,
              status: status,
              rejectionReason:
                  data['rejectionReason'] as String? ??
                  data['adminNotes'] as String?,
              // PRC decides whether a rejected applicant may apply again.
              canResubmit: data['reapplicationAllowed'] == true,
            );
          },
        ),
      ],
    );
  }
}

class _DonorApplicationTile extends StatelessWidget {
  const _DonorApplicationTile({
    required this.userId,
    required this.status,
    required this.rejectionReason,
    required this.canResubmit,
  });

  final String userId;
  final String status;
  final String? rejectionReason;
  final bool canResubmit;

  Color get _statusColor => switch (status) {
    DonorStatus.approved => Colors.green,
    DonorStatus.rejected => AppColors.primaryRed,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: const Text('Donor application'),
        subtitle: Text(
          status == DonorStatus.rejected && (rejectionReason ?? '').isNotEmpty
              ? 'Rejected — tap to view reason'
              : 'Status: $status',
        ),
        trailing: Text(
          status,
          style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
        ),
        onTap: status == DonorStatus.rejected
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RequestRejectionScreen(
                      title: 'Donor application',
                      reason:
                          rejectionReason ??
                          'No specific notes provided by the administrator.',
                      // Same identity check as Home, before the form. The
                      // new application replaces donors/{uid} and the old
                      // one moves to application_history, as before.
                      onResubmit: () {
                        VerificationGate.open(
                          context,
                          userId: userId,
                          destination: const ApplyDonorWelcomeScreen(),
                          actionName: 'apply as a blood donor',
                        );
                      },
                      canResubmit: canResubmit,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}
