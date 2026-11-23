import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/statuses.dart';
import '../../../core/theme/app_theme.dart';
import '../../blood_request/presentation/screens/blood_request_detail_screen.dart';
import '../../donor/data/repositories/donor_repository_impl.dart';

/// An open blood request marked Urgent, as shown in the list.
class UrgentRequest {
  const UrgentRequest({
    required this.id,
    required this.data,
    required this.bloodType,
    required this.hospital,
    required this.units,
    this.neededBy,
    this.createdAt,
  });

  final String id;
  final Map<String, dynamic> data;
  final String bloodType;
  final String hospital;
  final int units;
  final DateTime? neededBy;
  final DateTime? createdAt;

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory UrgentRequest.fromFirestore(String id, Map<String, dynamic> data) {
    final units = data['unitsRequired'] ?? data['unitsNeeded'];
    return UrgentRequest(
      id: id,
      data: data,
      bloodType: (data['bloodType'] ?? '--').toString().trim().toUpperCase(),
      hospital:
          (data['hospitalName'] ??
                  data['hospitalLocation'] ??
                  data['hospital'] ??
                  'Hospital not specified')
              .toString(),
      units: units is num ? units.toInt() : int.tryParse('$units') ?? 1,
      neededBy: _date(
        data['neededByDate'] ?? data['requiredDate'] ?? data['neededBy'],
      ),
      createdAt: _date(data['createdAt']),
    );
  }

  /// Keeps urgent requests donors can still offer to, other than the
  /// user's own, matching [bloodType] ('All' for any) and [search]
  /// (hospital name). Soonest needed-by date first.
  static List<UrgentRequest> filter(
    Iterable<MapEntry<String, Map<String, dynamic>>> docs, {
    String? currentUserId,
    Set<String> ownRequestIds = const {},
    String bloodType = 'All',
    String search = '',
  }) {
    final query = search.trim().toLowerCase();
    final list = <UrgentRequest>[];
    for (final doc in docs) {
      final data = doc.value;
      if (data['urgency'] != RequestUrgency.urgent) continue;
      if (!RequestStatus.isOpenToDonors(data['status']?.toString())) continue;
      final owner = (data['userId'] ?? data['requesterId'])?.toString();
      if (currentUserId != null && owner == currentUserId) continue;
      if (ownRequestIds.contains(doc.key)) continue;

      final request = UrgentRequest.fromFirestore(doc.key, data);
      if (bloodType != 'All' && request.bloodType != bloodType) continue;
      if (query.isNotEmpty && !request.hospital.toLowerCase().contains(query)) {
        continue;
      }
      list.add(request);
    }
    list.sort((a, b) {
      final an = a.neededBy, bn = b.neededBy;
      if (an != null && bn != null && an != bn) return an.compareTo(bn);
      if (an == null && bn != null) return 1;
      if (an != null && bn == null) return -1;
      final ac = a.createdAt, bc = b.createdAt;
      if (ac == null || bc == null) return 0;
      return bc.compareTo(ac);
    });
    return list;
  }
}

/// Open blood requests marked Urgent, for anyone who may be able to help.
///
/// Reads the anonymised `request_summaries` with `urgency == 'Urgent'` (a
/// single-field filter, so no composite index); status, own-request, blood
/// type and search filters run on the device. Offering goes through
/// [BloodRequestDetailScreen], which enforces the donor checks.
class UrgentRequestsScreen extends StatefulWidget {
  const UrgentRequestsScreen({
    super.key,
    this.requests,
    this.currentUserId,
    this.ownRequestIds,
  });

  /// Test hook: summary documents (id → data).
  final Stream<List<MapEntry<String, Map<String, dynamic>>>>? requests;

  /// Test hook: the user's own request ids.
  final Stream<Set<String>>? ownRequestIds;

  /// Test hook: overrides the signed-in user's id.
  final String? currentUserId;

  @override
  State<UrgentRequestsScreen> createState() => _UrgentRequestsScreenState();
}

class _UrgentRequestsScreenState extends State<UrgentRequestsScreen> {
  static const _bloodTypes = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final _searchController = TextEditingController();
  late final Stream<List<MapEntry<String, Map<String, dynamic>>>> _requests;
  String? _uid;
  late final Stream<Set<String>> _ownIds =
      widget.ownRequestIds ??
      (_uid == null
          ? Stream.value(const <String>{})
          : DonorRepositoryImpl().ownRequestIds(_uid!));
  Set<String> _own = const {};
  StreamSubscription<Set<String>>? _ownSub;
  String _bloodType = 'All';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _uid = widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    _requests =
        widget.requests ??
        FirebaseFirestore.instance
            .collection('request_summaries')
            .where('urgency', isEqualTo: RequestUrgency.urgent)
            .snapshots()
            .map((s) => [for (final d in s.docs) MapEntry(d.id, d.data())]);
    _ownSub = _ownIds.listen((ids) {
      if (mounted) setState(() => _own = ids);
    });
  }

  @override
  void dispose() {
    _ownSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _open(UrgentRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BloodRequestDetailScreen(requestId: request.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Urgent Blood Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by hospital...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: const Color(0xFFF3F3F3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _bloodTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final type = _bloodTypes[i];
                      final selected = _bloodType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: selected,
                        selectedColor: AppColors.primaryRed,
                        backgroundColor: const Color(0xFFF3F3F3),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _bloodType = type),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
              stream: _requests,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Urgent requests failed: ${snapshot.error}');
                  return const _Centered(
                    icon: Icons.cloud_off_outlined,
                    text: 'Could not load urgent requests. Please try again.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
                  );
                }
                final requests = UrgentRequest.filter(
                  snapshot.data!,
                  currentUserId: _uid,
                  ownRequestIds: _own,
                  bloodType: _bloodType,
                  search: _search,
                );
                if (requests.isEmpty) {
                  return _Centered(
                    icon: Icons.check_circle_outline,
                    text: _bloodType == 'All' && _search.trim().isEmpty
                        ? 'No urgent blood requests right now.'
                        : 'No urgent blood requests match your filter.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _UrgentCard(
                    request: requests[i],
                    onTap: () => _open(requests[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.request, required this.onTap});

  final UrgentRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neededBy = request.neededBy;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  request.bloodType,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'URGENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.hospital,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.units} ${request.units == 1 ? 'unit' : 'units'} needed'
                      '${neededBy == null ? '' : ' · by ${DateFormat('MMM d, yyyy').format(neededBy)}'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
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

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
