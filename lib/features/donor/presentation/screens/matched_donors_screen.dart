import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../blood_request/domain/request_progress.dart';
import '../../domain/request_match.dart';
import 'matched_donor_detail_screen.dart';

typedef DocList = List<MapEntry<String, Map<String, dynamic>>>;

/// Matching Center > Matched Donors: the signed-in user's approved blood
/// requests and whether PRC has confirmed a donor for each.
///
/// Read-only and anonymised: donors appear only as a `DNR-xxxx` code and
/// blood type. PRC-Sorsogon handles all coordination.
class MatchedDonorsScreen extends StatefulWidget {
  const MatchedDonorsScreen({
    super.key,
    this.userId,
    this.requests,
    this.offersFor,
  });

  /// Test hooks; default to the signed-in user and Firestore.
  final String? userId;
  final Stream<DocList>? requests;
  final Stream<DocList> Function(String requestId)? offersFor;

  @override
  State<MatchedDonorsScreen> createState() => _MatchedDonorsScreenState();
}

class _MatchedDonorsScreenState extends State<MatchedDonorsScreen> {
  late final String? _uid =
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  late final Stream<DocList>? _requests =
      widget.requests ??
      (_uid == null
          ? null
          : FirebaseFirestore.instance
                .collection('blood_requests')
                .where('userId', isEqualTo: _uid)
                .snapshots()
                .map(
                  (s) => [for (final d in s.docs) MapEntry(d.id, d.data())],
                ));

  final Map<String, Stream<DocList>> _offers = {};

  Stream<DocList> _offersFor(String requestId) => _offers.putIfAbsent(
    requestId,
    () => widget.offersFor?.call(requestId) ?? matchedDonorOffers(requestId),
  );

  void _open(String requestId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchedDonorDetailScreen(
          requestId: requestId,
          offers: widget.offersFor?.call(requestId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Matched Donors',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _requests == null
          ? const Center(child: Text('Please sign in to see matched donors.'))
          : StreamBuilder<DocList>(
              stream: _requests,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your blood requests.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: matchRed),
                  );
                }
                final requests = [
                  for (final doc in snapshot.data!)
                    if (RequestMatch.isListed(doc.value['status']?.toString()))
                      RequestProgress.fromFirestore(doc.key, doc.value),
                ]..sort(_newestFirst);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const Text(
                      'My Blood Requests with Matched Donor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'View the confirmed donor for each of your approved '
                      'blood requests.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (requests.isEmpty)
                      const _Empty()
                    else
                      for (final p in requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: StreamBuilder<DocList>(
                            stream: _offersFor(p.id),
                            builder: (context, offers) => _RequestTile(
                              match: RequestMatch(p, offers.data ?? const []),
                              loading: !offers.hasData && !offers.hasError,
                              onTap: () => _open(p.id),
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
    );
  }

  static int _newestFirst(RequestProgress a, RequestProgress b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
    return y.compareTo(x);
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        Icon(Icons.bloodtype_outlined, size: 56, color: Colors.black26),
        SizedBox(height: 10),
        Text(
          'No approved blood requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          'Your requests appear here once PRC-Sorsogon approves them.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      ],
    ),
  );
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.match,
    required this.loading,
    required this.onTap,
  });

  final RequestMatch match;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = match.request;
    final matched = !loading && match.state == MatchState.matched;
    return Material(
      color: matched ? matchGreenTint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: matched
                  ? matchGreen.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDECEC),
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.bloodType} • ${p.unitsText}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: matchRed,
                        ),
                      )
                    else
                      MatchStatusPill.forState(match.state, match.stateLabel),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
