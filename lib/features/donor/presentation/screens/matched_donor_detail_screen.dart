import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../blood_request/domain/request_progress.dart';
import '../../domain/request_match.dart';

const matchRed = AppColors.primaryRed;
const matchGreen = Color(0xFF2E7D32);
const matchGreenTint = Color(0xFFF1F8F2);
const _greenPill = Color(0xFFE3F2E5);
const _bluePill = Color(0xFFE3EEFD);
const _blueText = Color(0xFF1D4ED8);
const _grayPill = Color(0xFFF1F1F1);
const _summaryBlush = Color(0xFFFAEDED);
const _noteBlue = Color(0xFFEFF6FF);

/// Live offers on [requestId]. The requester may read them (firestore.rules);
/// only anonymised fields are ever shown.
Stream<List<MapEntry<String, Map<String, dynamic>>>> matchedDonorOffers(
  String requestId,
) => FirebaseFirestore.instance
    .collection('blood_requests')
    .doc(requestId)
    .collection('offers')
    .snapshots()
    .map((s) => [for (final d in s.docs) MapEntry(d.id, d.data())]);

/// Rounded status pill used by Matched Donors.
class MatchStatusPill extends StatelessWidget {
  const MatchStatusPill(
    this.label, {
    super.key,
    required this.background,
    required this.foreground,
  });

  factory MatchStatusPill.forState(MatchState state, String label) =>
      switch (state) {
        MatchState.matched => MatchStatusPill.green(label),
        MatchState.inProgress => MatchStatusPill(
          label,
          background: _bluePill,
          foreground: _blueText,
        ),
        MatchState.noMatch => MatchStatusPill(
          label,
          background: _grayPill,
          foreground: Colors.black54,
        ),
      };

  factory MatchStatusPill.green(String label) =>
      MatchStatusPill(label, background: _greenPill, foreground: matchGreen);

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: foreground,
      ),
    ),
  );
}

/// One approved blood request and its PRC-confirmed donor(s), read-only.
///
/// The donor is shown only as an anonymised code and blood type: no name,
/// contact, photo, chat or call. PRC-Sorsogon coordinates the donation.
class MatchedDonorDetailScreen extends StatefulWidget {
  const MatchedDonorDetailScreen({
    super.key,
    required this.requestId,
    this.request,
    this.offers,
  });

  final String requestId;

  /// Test hooks; default to Firestore.
  final Stream<Map<String, dynamic>?>? request;
  final Stream<List<MapEntry<String, Map<String, dynamic>>>>? offers;

  @override
  State<MatchedDonorDetailScreen> createState() =>
      _MatchedDonorDetailScreenState();
}

class _MatchedDonorDetailScreenState extends State<MatchedDonorDetailScreen> {
  late final Stream<Map<String, dynamic>?> _request =
      widget.request ??
      FirebaseFirestore.instance
          .collection('blood_requests')
          .doc(widget.requestId)
          .snapshots()
          .map((s) => s.data());

  late final Stream<List<MapEntry<String, Map<String, dynamic>>>> _offers =
      widget.offers ?? matchedDonorOffers(widget.requestId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Matched Donor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _request,
        builder: (context, req) {
          if (req.hasError) {
            return const _Message('Could not load this blood request.');
          }
          if (req.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: matchRed),
            );
          }
          final data = req.data;
          if (data == null) {
            return const _Message('This blood request is no longer available.');
          }
          return StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
            stream: _offers,
            builder: (context, offers) {
              if (offers.hasError) {
                return const _Message('Could not load the matched donor.');
              }
              if (!offers.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: matchRed),
                );
              }
              final match = RequestMatch(
                RequestProgress.fromFirestore(widget.requestId, data),
                offers.data!,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SummaryCard(match),
                  const SizedBox(height: 24),
                  const _SectionTitle('Matched Donor (Anonymized)'),
                  const SizedBox(height: 10),
                  if (match.donors.isEmpty)
                    _NoDonorYet(match)
                  else
                    for (final d in match.donors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DonorCard(d),
                      ),
                  const SizedBox(height: 14),
                  const _SectionTitle('Request Timeline'),
                  const SizedBox(height: 12),
                  _Timeline(match),
                  const SizedBox(height: 24),
                  const _InfoNote(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.match);

  final RequestMatch match;

  @override
  Widget build(BuildContext context) {
    final p = match.request;
    final location = p.location == 'Not specified'
        ? p.hospital
        : '${p.hospital}, ${p.location}';
    final pill = match.isCompleted || match.state == MatchState.matched
        ? MatchStatusPill.green(match.detailLabel)
        : MatchStatusPill.forState(match.state, match.detailLabel);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _summaryBlush,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop, color: matchRed, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.bloodType} • ${p.unitsText}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          pill,
        ],
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  const _DonorCard(this.donor);

  final MatchedDonor donor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, size: 30, color: Colors.grey.shade500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                donor.code,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Blood Type: ${donor.bloodType}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        MatchStatusPill.green('Confirmed'),
      ],
    ),
  );
}

class _NoDonorYet extends StatelessWidget {
  const _NoDonorYet(this.match);

  final RequestMatch match;

  @override
  Widget build(BuildContext context) {
    final inProgress = match.state == MatchState.inProgress;
    final text = match.state == MatchState.matched
        ? '${RequestProgress.prc} has matched your request. Donor details '
              'are being finalised.'
        : inProgress
        ? '${match.pendingOffers} '
              '${match.pendingOffers == 1 ? 'donor has' : 'donors have'} '
              'offered. ${RequestProgress.prc} is screening them.'
        : 'Matching donors were alerted. No donor has offered yet.';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              inProgress ? Icons.hourglass_top_rounded : Icons.person_search,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No donor confirmed yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.match);

  final RequestMatch match;

  @override
  Widget build(BuildContext context) {
    final prc = RequestProgress.prc;
    final matched = match.state == MatchState.matched;
    final completed = match.isCompleted;
    final steps = [
      _Step(
        title: 'Request Approved',
        subtitle: '$prc approved your blood request.',
        done: true,
        at: match.approvedAt,
      ),
      _Step(
        title: 'Donor Matched',
        subtitle: matched
            ? '$prc confirmed a donor for your request.'
            : 'Waiting for $prc to confirm a donor.',
        done: matched,
        at: match.matchedAt,
      ),
      _Step(
        title: 'Donation Completed',
        subtitle: completed
            ? (match.donors.isNotEmpty && match.donors.every((d) => d.donated)
                  ? 'The donation was completed at $prc.'
                  : '$prc marked your request as fulfilled.')
            : '$prc will update this once the donation is done.',
        done: completed,
        at: match.completedAt,
        highlight: completed,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            nextDone: i + 1 < steps.length && steps[i + 1].done,
          ),
      ],
    );
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.subtitle,
    required this.done,
    this.at,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final bool done;
  final DateTime? at;
  final bool highlight;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.nextDone,
  });

  final _Step step;
  final bool isLast;
  final bool nextDone;

  static final _format = DateFormat('MMM d, yyyy • h:mm a');

  @override
  Widget build(BuildContext context) {
    final time = step.done
        ? (step.at == null ? null : _format.format(step.at!))
        : 'Pending';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                step.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: step.done ? Colors.black87 : Colors.black45,
                ),
              ),
            ),
            if (time != null)
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  color: step.done ? Colors.grey.shade600 : Colors.black38,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          step.subtitle,
          style: TextStyle(
            fontSize: 12,
            color: step.done ? Colors.grey.shade700 : Colors.black38,
            height: 1.35,
          ),
        ),
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: step.highlight ? 12 : 0),
                  child: _Dot(done: step.done),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: nextDone ? matchGreen : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: step.highlight
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: matchGreenTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: matchGreen.withValues(alpha: 0.25),
                        ),
                      ),
                      child: content,
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: content,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: done ? matchGreen : Colors.white,
      shape: BoxShape.circle,
      border: done ? null : Border.all(color: Colors.grey.shade400, width: 2),
    ),
    child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
  );
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  static const _lines = [
    'This is a read-only view. You can only see the matched donor assigned '
        'to your blood request.',
    'You cannot chat, contact, or respond to the donor.',
    'All coordination is handled by PRC-Sorsogon.',
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _noteBlue,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: _blueText, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in _lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E3A8A),
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
