import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/statuses.dart';
import '../../../../core/utils/streams.dart';
import '../../../../core/widgets/pill_switcher.dart';
import '../../../history/domain/history_entries.dart';

const _softRed = Color(0xFFFDECEC);
const _red = Color(0xFFC62828);
const _pillGray = Color(0xFFF1F1F1);

/// Donation records plus the totals shown above them.
typedef DonationHistory = ({
  List<DonationHistoryEntry> entries,
  DonationSummary summary,
});

/// History tab of the dashboard: the signed-in user's past blood requests
/// and donations, read live from Firestore.
///
/// Queries need no composite index: requests filter on `userId` only and
/// offers on `donorId` only (single-field collection-group override in
/// firestore.indexes.json); both are sorted on the device.
class HistoryTabView extends StatefulWidget {
  const HistoryTabView({super.key});

  @override
  State<HistoryTabView> createState() => _HistoryTabViewState();
}

class _HistoryTabViewState extends State<HistoryTabView> {
  String? _uid;
  Stream<List<RequestHistoryEntry>>? _requests;
  Stream<DonationHistory>? _donations;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _uid = uid;
    final db = FirebaseFirestore.instance;

    _requests = relistenable(
      () => db
          .collection('blood_requests')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map(
            (s) => RequestHistoryEntry.fromDocs(
              s.docs.map((d) => MapEntry(d.id, d.data())),
            ),
          ),
    );

    offers() => db
        .collectionGroup('offers')
        .where('donorId', isEqualTo: uid)
        .snapshots();
    donor() => db.collection('donors').doc(uid).snapshots();

    _donations = combineLatest2(offers, donor, (offerSnap, donorSnap) {
      final donorData = donorSnap.data();
      final entries = DonationHistoryEntry.combine(
        uid: uid,
        offers: offerSnap.docs.map((d) => MapEntry(d.id, d.data())),
        donor: donorData,
      );
      return (
        entries: entries,
        summary: DonationSummary.from(entries, donor: donorData),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Center(child: Text('Please sign in to view your history.'));
    }
    return HistoryView(requests: _requests!, donations: _donations!);
  }
}

enum HistorySection { requests, donations }

/// The History layout, fed by streams so it can be tested without Firebase.
class HistoryView extends StatefulWidget {
  const HistoryView({
    super.key,
    required this.requests,
    required this.donations,
    this.initialSection = HistorySection.requests,
    this.today,
  });

  final Stream<List<RequestHistoryEntry>> requests;
  final Stream<DonationHistory> donations;
  final HistorySection initialSection;

  /// Overrides "today" for the eligibility summary (tests).
  final DateTime? today;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late HistorySection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Extra bottom space so the floating verification banner never
      // covers the footer.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const Text(
          'History',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'View your previous blood requests and donation records.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        PillSwitcher<HistorySection>(
          options: const [
            (HistorySection.requests, 'Blood Request'),
            (HistorySection.donations, 'Donation'),
          ],
          selected: _section,
          onChanged: (s) => setState(() => _section = s),
        ),
        const SizedBox(height: 20),
        if (_section == HistorySection.requests)
          _RequestHistory(stream: widget.requests)
        else
          _DonationHistory(stream: widget.donations, today: widget.today),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Blood request history
// ---------------------------------------------------------------------------

class _RequestHistory extends StatelessWidget {
  const _RequestHistory({required this.stream});

  final Stream<List<RequestHistoryEntry>> stream;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Blood Request History'),
        StreamBuilder<List<RequestHistoryEntry>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Request history failed: ${snapshot.error}');
              return const _Message(
                'Could not load your blood request history. '
                'Please try again later.',
              );
            }
            if (!snapshot.hasData) return const _Loading();
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return const _EmptyState(
                icon: Icons.bloodtype_outlined,
                title: 'No past blood requests',
                message:
                    'Fulfilled, cancelled and expired requests will appear '
                    'here.',
              );
            }
            return Column(
              children: [
                for (final entry in entries)
                  _HistoryCard(
                    icon: Icons.water_drop_outlined,
                    reference: entry.reference,
                    summary: entry.summary,
                    place: entry.hospital,
                    date: entry.date,
                    badge: _requestBadge(entry.status),
                    onTap: () => _showRequestDetails(context, entry),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _FooterNote(
          'This section shows your past and completed blood requests.',
        ),
      ],
    );
  }
}

_Badge _requestBadge(String status) {
  switch (status) {
    case RequestStatus.fulfilled:
      return const _Badge('Fulfilled', _BadgeTone.green);
    case RequestStatus.expired:
      return const _Badge('Expired', _BadgeTone.amber);
    case RequestStatus.rejected:
      return const _Badge('Rejected', _BadgeTone.red);
    default:
      return const _Badge('Cancelled', _BadgeTone.red);
  }
}

void _showRequestDetails(BuildContext context, RequestHistoryEntry e) {
  _showDetails(
    context,
    title: 'Blood Request Details',
    reference: e.reference,
    badge: _requestBadge(e.status),
    rows: [
      ('Blood type', e.bloodType),
      ('Units', unitsLabel(e.units)),
      if (e.component != null) ('Component', e.component!),
      ('Hospital', e.hospital),
      if (e.patientName != null) ('Patient', e.patientName!),
      ('Requested on', _formatDate(e.createdAt)),
      if (e.neededBy != null) ('Needed by', _formatDate(e.neededBy)),
      if (e.closedAt != null)
        ('${RequestStatus.label(e.status)} on', _formatDate(e.closedAt)),
      if (e.reason != null) ('Reason', e.reason!),
    ],
  );
}

// ---------------------------------------------------------------------------
// Donation history
// ---------------------------------------------------------------------------

class _DonationHistory extends StatelessWidget {
  const _DonationHistory({required this.stream, this.today});

  final Stream<DonationHistory> stream;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DonationHistory>(
      stream: stream,
      builder: (context, snapshot) {
        final Widget list;
        Widget? summary;
        if (snapshot.hasError) {
          debugPrint('Donation history failed: ${snapshot.error}');
          list = const _Message(
            'Could not load your donation history. Please try again later.',
          );
        } else if (!snapshot.hasData) {
          list = const _Loading();
        } else {
          final data = snapshot.data!;
          summary = DonationSummaryBar(summary: data.summary, today: today);
          list = data.entries.isEmpty
              ? const _EmptyState(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'No donations yet',
                  message:
                      'Completed donations recorded by PRC will appear here.',
                )
              : Column(
                  children: [
                    for (final entry in data.entries)
                      _HistoryCard(
                        icon: Icons.water_drop,
                        iconFilled: true,
                        reference: entry.reference,
                        summary: entry.summary,
                        place: entry.facility,
                        date: entry.date,
                        badge: _donationBadge(entry.status),
                        onTap: () => _showDonationDetails(context, entry),
                      ),
                  ],
                );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary != null) ...[summary, const SizedBox(height: 20)],
            const _SectionTitle('Donation History'),
            list,
            const SizedBox(height: 12),
            const _FooterNote(
              'This section shows your past and completed blood donations.',
            ),
          ],
        );
      },
    );
  }
}

_Badge _donationBadge(String status) {
  switch (status) {
    case OfferStatus.donated:
      return const _Badge('Completed', _BadgeTone.green, check: true);
    case OfferStatus.rejected:
      return const _Badge('Declined', _BadgeTone.red);
    default:
      return const _Badge('Withdrawn', _BadgeTone.neutral);
  }
}

void _showDonationDetails(BuildContext context, DonationHistoryEntry e) {
  _showDetails(
    context,
    title: 'Donation Details',
    reference: e.reference,
    badge: _donationBadge(e.status),
    rows: [
      ('Blood type', e.bloodType),
      ('Donation type', '${e.donationType} (${unitsLabel(e.units)})'),
      ('Facility', e.facility),
      ('Date', _formatDate(e.date)),
      if (e.source == DonationSource.donorActivation)
        ('Recorded as', 'First donation (donor activation)'),
      if (e.requestId != null) ('Request ID', e.requestId!),
      if (e.notes != null) ('Notes', e.notes!),
    ],
  );
}

/// Total completed donations and the next eligible donation date.
class DonationSummaryBar extends StatelessWidget {
  const DonationSummaryBar({super.key, required this.summary, this.today});

  final DonationSummary summary;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final eligible = summary.isEligible(today: today);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Total Completed Donations',
                value: '${summary.completedCount}',
                valueColor: _red,
              ),
            ),
            const VerticalDivider(width: 24, color: Color(0xFFEDEDED)),
            Expanded(
              child: _Stat(
                label: 'Next Eligible Donation Date',
                value: eligible
                    ? 'Eligible to donate now'
                    : _formatDate(summary.nextEligible),
                valueColor: eligible ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

String _formatDate(DateTime? date) =>
    date == null ? 'Not recorded' : DateFormat('MMM d, yyyy').format(date);

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.icon,
    required this.reference,
    required this.summary,
    required this.place,
    required this.date,
    required this.badge,
    required this.onTap,
    this.iconFilled = false,
  });

  final IconData icon;
  final bool iconFilled;
  final String reference;
  final String summary;
  final String place;
  final DateTime? date;
  final _Badge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconFilled ? _red : _softRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconFilled ? Colors.white : _red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reference,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                badge,
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _BadgeTone { green, red, amber, neutral }

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.tone, {this.check = false});

  final String label;
  final _BadgeTone tone;
  final bool check;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _BadgeTone.green => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      _BadgeTone.red => (_softRed, _red),
      _BadgeTone.amber => (const Color(0xFFFFF4E0), const Color(0xFFB26A00)),
      _BadgeTone.neutral => (_pillGray, Colors.black54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (check) ...[
            Icon(Icons.check, size: 13, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softRed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: _red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black26),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator(color: _red)),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(color: Colors.black54)),
  );
}

void _showDetails(
  BuildContext context, {
  required String title,
  required String reference,
  required _Badge badge,
  required List<(String, String)> rows,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reference,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                badge,
              ],
            ),
            const Divider(height: 28),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _red,
                  side: const BorderSide(color: _red),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
