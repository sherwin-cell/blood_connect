import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../donor/data/repositories/donor_repository_impl.dart';
import '../../../donor/presentation/donor_offer_state.dart';
import '../../domain/request_summary.dart';
import '../widgets/request_progress_widgets.dart';

/// Donor-facing view of one open blood request (from a "new matching
/// request" notification, Urgent Requests or the Blood Requester list).
///
/// Shows only the anonymised `request_summaries` entry: no patient name,
/// requester contact or documents. PRC shares contact details after it
/// confirms a donor.
class BloodRequestDetailScreen extends StatefulWidget {
  const BloodRequestDetailScreen({
    super.key,
    required this.requestId,
    this.summary,
    this.offerState,
    this.offer,
  });

  final String requestId;

  /// Test hooks; default to Firestore.
  final Stream<RequestSummary?>? summary;
  final Stream<DonorOfferState>? offerState;
  final Future<void> Function(String requestId)? offer;

  @override
  State<BloodRequestDetailScreen> createState() =>
      _BloodRequestDetailScreenState();
}

class _BloodRequestDetailScreenState extends State<BloodRequestDetailScreen> {
  DonorRepositoryImpl? _repo;
  DonorRepositoryImpl get _repository => _repo ??= DonorRepositoryImpl();

  late final Stream<RequestSummary?> _summary =
      widget.summary ?? _repository.watchSummary(widget.requestId);
  late final Stream<DonorOfferState>? _state =
      widget.offerState ?? _defaultState();

  bool _submitting = false;

  Stream<DonorOfferState>? _defaultState() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null
        ? null
        : DonorOfferState.watch(uid, repository: _repository);
  }

  Future<void> _offer() async {
    if (!await confirmMedicalNotice(context) || !mounted) return;
    setState(() => _submitting = true);
    Object? error;
    try {
      final offer = widget.offer;
      if (offer != null) {
        await offer(widget.requestId);
      } else {
        await _repository.offerToDonate(
          requestId: widget.requestId,
          donorId: FirebaseAuth.instance.currentUser!.uid,
        );
      }
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Offer sent! PRC will review it and contact you.'
              : error.toString().replaceFirst('Exception: ', ''),
        ),
        backgroundColor: error == null ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Blood Request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<RequestSummary?>(
        stream: _summary,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this request.'));
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: requestRed),
            );
          }
          final r = snapshot.data;
          if (r == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This blood request is no longer available.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              RequestCardShell(
                child: Row(
                  children: [
                    BloodTypeBadge(r.bloodType, size: 60),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.hospital,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r.units} ${r.units == 1 ? 'unit' : 'units'}'
                            '${r.component == null ? '' : ' · ${r.component}'}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          if (r.isUrgent) ...[
                            const SizedBox(height: 6),
                            const UrgentBadge(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RequestCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RequestSectionTitle('Request Information'),
                    RequestInfoRows(
                      rows: [
                        (
                          'Blood Type Needed',
                          RequestInfoRows.value(r.bloodType),
                        ),
                        (
                          'Units Needed',
                          RequestInfoRows.value(
                            '${r.units} ${r.units == 1 ? 'unit' : 'units'}',
                          ),
                        ),
                        if (r.component != null)
                          ('Component', RequestInfoRows.value(r.component!)),
                        ('Hospital', RequestInfoRows.value(r.hospital)),
                        (
                          'Date Needed',
                          RequestInfoRows.value(formatRequestDate(r.neededBy)),
                        ),
                        (
                          'Urgency Level',
                          r.isUrgent
                              ? const Align(
                                  alignment: Alignment.centerLeft,
                                  child: UrgentBadge(),
                                )
                              : RequestInfoRows.value('Normal'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: requestSoftRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: requestRed),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'For the patient\'s privacy, PRC shares contact '
                        'details only after it confirms your offer.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<DonorOfferState>(
                stream: _state,
                builder: (context, stateSnap) {
                  final state = stateSnap.data;
                  final reason = state?.reasonFor(r);
                  final offered = state?.hasOffered(r.id) ?? false;
                  final canOffer = state != null && reason == null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reason != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            reason,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: offered
                                  ? Colors.green.shade700
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: canOffer && !_submitting ? _offer : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: requestRed,
                            foregroundColor: Colors.white,
                          ),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  offered
                                      ? Icons.check
                                      : Icons.volunteer_activism,
                                ),
                          label: Text(
                            offered ? 'Offer Sent' : 'Offer to Donate',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
