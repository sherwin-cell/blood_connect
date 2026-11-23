import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../blood_request/domain/request_summary.dart';
import '../../../blood_request/presentation/screens/blood_request_detail_screen.dart';
import '../../../blood_request/presentation/widgets/request_progress_widgets.dart';
import '../../data/repositories/donor_repository_impl.dart';
import '../donor_offer_state.dart';

const _green = Color(0xFF2E7D32);
const _softGreen = Color(0xFFE8F5E9);
const _blue = Color(0xFF1565C0);
const _softBlue = Color(0xFFE3F2FD);

const allBloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Sort orders for the view-only list.
enum RequestSort {
  nearestDate('Nearest Date'),
  newest('Newest First'),
  urgentFirst('Urgent First');

  const RequestSort(this.label);
  final String label;
}

/// Splits open requests into ones the donor can respond to (exactly their
/// blood type, as firestore.rules require) and read-only ones. The user's
/// own requests are left out of both.
class BloodRequestLists {
  BloodRequestLists._(this.matched, this.viewOnly);

  final List<RequestSummary> matched;
  final List<RequestSummary> viewOnly;

  factory BloodRequestLists.from(
    List<RequestSummary> all, {
    required String donorBloodType,
    Set<String> ownRequestIds = const {},
    String? bloodTypeFilter,
    RequestSort sort = RequestSort.nearestDate,
    bool urgentOnly = false,
  }) {
    final type = donorBloodType.trim().toUpperCase();
    final open = [
      for (final r in all)
        if (r.isOpen && !ownRequestIds.contains(r.id)) r,
    ];
    final matched = [
      for (final r in open)
        if (r.bloodType == type) r,
    ]..sort((a, b) => compare(RequestSort.nearestDate, a, b));
    final viewOnly = [
      for (final r in open)
        if (r.bloodType != type &&
            (bloodTypeFilter == null || r.bloodType == bloodTypeFilter) &&
            (!urgentOnly || r.isUrgent))
          r,
    ]..sort((a, b) => compare(sort, a, b));
    return BloodRequestLists._(matched, viewOnly);
  }

  static final _far = DateTime(9999);
  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  static int compare(RequestSort sort, RequestSummary a, RequestSummary b) {
    int newest() => (b.createdAt ?? _epoch).compareTo(a.createdAt ?? _epoch);
    int nearest() {
      final c = (a.neededBy ?? _far).compareTo(b.neededBy ?? _far);
      return c != 0 ? c : newest();
    }

    switch (sort) {
      case RequestSort.nearestDate:
        return nearest();
      case RequestSort.newest:
        return newest();
      case RequestSort.urgentFirst:
        if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
        return nearest();
    }
  }
}

/// Matching Center > Blood Requester: approved requests from the anonymised
/// `request_summaries`.
///
/// Requests with the donor's blood type are listed under "Matched Blood
/// Requests" and open [BloodRequestDetailScreen], where the donor offers via
/// [DonorRepositoryImpl.offerToDonate]. Other blood types are shown
/// read-only with a lock: firestore.rules reject offers on them.
class CompatibleRequestsScreen extends StatefulWidget {
  const CompatibleRequestsScreen({
    super.key,
    required this.donorBloodType,
    this.requests,
    this.offerState,
    this.offer,
  });

  final String donorBloodType;

  /// Test hooks; default to Firestore.
  final Stream<List<RequestSummary>>? requests;
  final Stream<DonorOfferState>? offerState;
  final Future<void> Function(String requestId)? offer;

  /// Matched requests shown before "View more".
  static const collapsedCount = 2;

  @override
  State<CompatibleRequestsScreen> createState() =>
      _CompatibleRequestsScreenState();
}

class _CompatibleRequestsScreenState extends State<CompatibleRequestsScreen> {
  DonorRepositoryImpl? _repo;
  DonorRepositoryImpl get _repository => _repo ??= DonorRepositoryImpl();

  late final String _bloodType = widget.donorBloodType.trim().toUpperCase();
  late final Stream<List<RequestSummary>> _requests =
      widget.requests ?? _repository.openSummaries();
  late final Stream<DonorOfferState>? _state =
      widget.offerState ?? _defaultState();

  bool _expanded = false;
  String? _typeFilter;
  RequestSort _sort = RequestSort.nearestDate;
  bool _urgentOnly = false;

  Stream<DonorOfferState>? _defaultState() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? null
        : DonorOfferState.watch(uid, repository: _repository);
  }

  void _open(RequestSummary request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloodRequestDetailScreen(
          requestId: request.id,
          summary: widget.requests == null ? null : Stream.value(request),
          offerState: widget.offerState,
          offer: widget.offer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blood Requests',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Browse and respond to approved blood requests from '
              'PRC-Sorsogon.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DonorOfferState>(
        stream: _state,
        builder: (context, stateSnap) {
          final state = stateSnap.data;
          return StreamBuilder<List<RequestSummary>>(
            stream: _requests,
            builder: (context, snapshot) {
              final children = <Widget>[
                const _HelpBanner(),
                if (state?.blockingReason != null) ...[
                  const SizedBox(height: 10),
                  _Notice(state!.blockingReason!),
                ],
                const SizedBox(height: 16),
              ];

              if (snapshot.hasError) {
                debugPrint('Blood requests failed: ${snapshot.error}');
                children.add(
                  const _Notice(
                    'Could not load blood requests. Please try again later.',
                  ),
                );
              } else if (!snapshot.hasData) {
                children.add(
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(color: requestRed),
                    ),
                  ),
                );
              } else {
                final lists = BloodRequestLists.from(
                  snapshot.data!,
                  donorBloodType: _bloodType,
                  ownRequestIds: state?.ownRequestIds ?? const {},
                  bloodTypeFilter: _typeFilter,
                  sort: _sort,
                  urgentOnly: _urgentOnly,
                );
                children.addAll([
                  _matchedCard(lists.matched, state),
                  const SizedBox(height: 20),
                  const Text(
                    'Other Blood Requests',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _filters(),
                  const SizedBox(height: 10),
                  if (lists.viewOnly.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No other blood requests match these filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    for (final r in lists.viewOnly) _ViewOnlyRow(r),
                  const SizedBox(height: 8),
                  const _ViewOnlyInfo(),
                ]);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: children,
              );
            },
          );
        },
      ),
    );
  }

  Widget _matchedCard(List<RequestSummary> matched, DonorOfferState? state) {
    const limit = CompatibleRequestsScreen.collapsedCount;
    final hidden = matched.length - limit;
    final shown = _expanded || hidden <= 0 ? matched : matched.take(limit);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: _green),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Matched Blood Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _green,
                      ),
                    ),
                    Text(
                      'Requests that match your blood type.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (matched.isEmpty)
            Text(
              'No $_bloodType blood requests right now. We will notify you '
              'when one is posted.',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            for (final r in shown)
              _MatchedRow(
                request: r,
                offered: state?.hasOffered(r.id) ?? false,
                onTap: () => _open(r),
              ),
          if (hidden > 0)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(foregroundColor: _green),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Show less' : 'View more ($hidden)'),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    final types = [
      for (final t in allBloodTypes)
        if (t != _bloodType) t,
    ];
    return Row(
      children: [
        Expanded(
          child: _DropdownBox(
            child: DropdownButton<String?>(
              key: const Key('blood-type-filter'),
              value: _typeFilter,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(child: Text('All Blood Types')),
                for (final t in types)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _typeFilter = v),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DropdownBox(
            child: DropdownButton<RequestSort>(
              key: const Key('sort-filter'),
              value: _sort,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in RequestSort.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _sort = v ?? _sort),
            ),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          key: const Key('more-filters'),
          tooltip: 'Filter options',
          icon: Icon(
            Icons.tune,
            color: _urgentOnly ? requestRed : Colors.black54,
          ),
          onSelected: (_) => setState(() => _urgentOnly = !_urgentOnly),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'urgent',
              checked: _urgentOnly,
              child: const Text('Urgent only'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpBanner extends StatelessWidget {
  const _HelpBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: requestSoftRed,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.favorite, color: requestRed),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help Save Lives!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: requestRed,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Below are blood requests that need donors. You may respond '
                'to a request if you are willing to donate.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MatchedRow extends StatelessWidget {
  const _MatchedRow({
    required this.request,
    required this.offered,
    required this.onTap,
  });

  final RequestSummary request;
  final bool offered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const _Drop(color: requestRed, background: requestSoftRed),
              const SizedBox(width: 12),
              Expanded(child: _RowText(request)),
              if (offered)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _softGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: _green),
                      SizedBox(width: 4),
                      Text(
                        'Offer Sent',
                        style: TextStyle(
                          fontSize: 11,
                          color: _green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ViewOnlyRow extends StatelessWidget {
  const _ViewOnlyRow(this.request);

  final RequestSummary request;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        _Drop(color: Colors.grey.shade600, background: Colors.grey.shade200),
        const SizedBox(width: 12),
        Expanded(child: _RowText(request)),
        Icon(
          Icons.lock_outline,
          color: Colors.grey.shade500,
          semanticLabel: 'View only',
        ),
      ],
    ),
  );
}

class _RowText extends StatelessWidget {
  const _RowText(this.request);

  final RequestSummary request;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              request.reference,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (request.isUrgent) ...[
            const SizedBox(width: 6),
            const UrgentBadge(),
          ],
        ],
      ),
      const SizedBox(height: 2),
      Text(
        request.typeAndUnits,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class _Drop extends StatelessWidget {
  const _Drop({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(Icons.water_drop, color: color, size: 22),
  );
}

class _DropdownBox extends StatelessWidget {
  const _DropdownBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.black12),
    ),
    child: DropdownButtonHideUnderline(child: child),
  );
}

class _ViewOnlyInfo extends StatelessWidget {
  const _ViewOnlyInfo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _softBlue,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: _blue),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View-Only Requests',
                style: TextStyle(fontWeight: FontWeight.bold, color: _blue),
              ),
              SizedBox(height: 4),
              Text(
                'Requests marked with a lock need a different blood type. '
                'Following PRC matching rules, you can only respond to '
                'requests that match your blood type.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: Color(0xFFB26A00), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
