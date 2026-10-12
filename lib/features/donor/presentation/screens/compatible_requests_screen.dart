import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/donor_repository_impl.dart';

class CompatibleRequestsScreen extends StatefulWidget {
  final String donorBloodType;
  final String donorName;
  final String donorContact;

  const CompatibleRequestsScreen({
    super.key,
    required this.donorBloodType,
    required this.donorName,
    required this.donorContact,
  });

  @override
  State<CompatibleRequestsScreen> createState() =>
      _CompatibleRequestsScreenState();
}

class _CompatibleRequestsScreenState extends State<CompatibleRequestsScreen> {
  final DonorRepositoryImpl _donorRepository = DonorRepositoryImpl();

  final Set<String> _submittedOffers = {};

  String get _normalizedDonorBloodType {
    return widget.donorBloodType.trim().toUpperCase();
  }

  String _normalizeBloodType(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim().toUpperCase();
  }

  String _getHospital(Map<String, dynamic> data) {
    return (data['hospitalName'] ?? data['hospital'] ?? 'Hospital N/A')
        .toString();
  }

  String _getNeededByDate(Map<String, dynamic> data) {
    final value =
        data['neededByDate'] ?? data['neededBy'] ?? data['requiredDate'];

    if (value == null) {
      return 'Date not specified';
    }

    if (value is Timestamp) {
      final date = value.toDate();

      return '${_monthName(date.month)} '
          '${date.day}, '
          '${date.year}';
    }

    return value.toString();
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final donorBloodType = _normalizedDonorBloodType;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        title: const Text(
          'Blood Requests',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: Column(
        children: [
          // ----------------------------------------------------------
          // MATCHING INFORMATION
          // ----------------------------------------------------------
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blood Requests ($donorBloodType only)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only approved blood requests with the exact same blood type are shown.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------------
          // MEDICAL CLEARANCE NOTICE
          // ----------------------------------------------------------
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Potential matches are based on the same blood type. '
                    'Medical clearance and final confirmation are required by PRC.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------------
          // REQUEST LIST
          // ----------------------------------------------------------
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _donorRepository.getCompatibleRequestsStream(
                donorBloodType,
              ),
              builder: (context, snapshot) {
                // ----------------------------------------------------
                // LOADING
                // ----------------------------------------------------

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ----------------------------------------------------
                // ERROR
                // ----------------------------------------------------

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 52,
                            color: Colors.red.shade200,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load blood requests.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];

                // ----------------------------------------------------
                // FILTER REQUESTS
                // ----------------------------------------------------
                //
                // A request is displayed only when:
                //
                // 1. It is not the current user's own request.
                // 2. Status is APPROVED.
                // 3. Blood type exactly matches the donor.
                //
                // Examples:
                //
                // Donor = A+
                //
                // A+ + approved -> SHOW
                // A+ + pending  -> HIDE
                // A+ + rejected -> HIDE
                // O+ + approved  -> HIDE
                // B+ + approved  -> HIDE
                // AB+ + approved -> HIDE
                // ----------------------------------------------------

                final docs = allDocs.where((doc) {
                  final reqData = doc.data();

                  // ----------------------------------------------
                  // CURRENT USER'S OWN REQUEST
                  // ----------------------------------------------

                  final requesterId =
                      (reqData['userId'] ?? reqData['requesterId'])?.toString();

                  if (requesterId == currentUserId) {
                    return false;
                  }

                  // ----------------------------------------------
                  // REQUEST STATUS
                  // ----------------------------------------------

                  final status = (reqData['status'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  if (status != 'approved') {
                    return false;
                  }

                  // ----------------------------------------------
                  // EXACT BLOOD TYPE MATCH
                  // ----------------------------------------------

                  final requestBloodType = _normalizeBloodType(
                    reqData['bloodType'],
                  );

                  return requestBloodType == donorBloodType;
                }).toList();

                // ----------------------------------------------------
                // SORT REQUESTS
                // ----------------------------------------------------

                docs.sort((a, b) {
                  final aCreatedAt = a.data()['createdAt'];

                  final bCreatedAt = b.data()['createdAt'];

                  if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
                    return bCreatedAt.compareTo(aCreatedAt);
                  }

                  if (aCreatedAt is Timestamp) {
                    return -1;
                  }

                  if (bCreatedAt is Timestamp) {
                    return 1;
                  }

                  return 0;
                });

                // ----------------------------------------------------
                // NO MATCHES
                // ----------------------------------------------------

                if (docs.isEmpty) {
                  return _buildEmptyState(donorBloodType);
                }

                // ----------------------------------------------------
                // MATCHING REQUESTS
                // ----------------------------------------------------

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final reqDoc = docs[index];
                    final reqData = reqDoc.data();

                    final requestId = reqDoc.id;

                    final bloodType = _normalizeBloodType(reqData['bloodType']);

                    final neededByDate = _getNeededByDate(reqData);

                    final hospital = _getHospital(reqData);

                    final hasOffered = _submittedOffers.contains(requestId);

                    return _buildRequestCard(
                      context: context,
                      requestId: requestId,
                      bloodType: bloodType,
                      neededByDate: neededByDate,
                      hospital: hospital,
                      requestData: reqData,
                      hasOffered: hasOffered,
                      currentUserId: currentUserId,
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

  // ================================================================
  // REQUEST CARD
  // ================================================================

  Widget _buildRequestCard({
    required BuildContext context,
    required String requestId,
    required String bloodType,
    required String neededByDate,
    required String hospital,
    required Map<String, dynamic> requestData,
    required bool hasOffered,
    required String? currentUserId,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------
          // REQUEST ID + BLOOD TYPE
          // ----------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop,
                  color: AppColors.primaryRed,
                  size: 21,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Approved Blood Request',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(7),
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

          const SizedBox(height: 12),

          // ----------------------------------------------------------
          // NEEDED BY DATE
          // ----------------------------------------------------------
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  neededByDate,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // ----------------------------------------------------------
          // HOSPITAL
          // ----------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 17,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hospital,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ----------------------------------------------------------
          // VIEW DETAILS
          // ----------------------------------------------------------
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _showRequestDetails(
                  context: context,
                  requestId: requestId,
                  requestData: requestData,
                  hasOffered: hasOffered,
                  currentUserId: currentUserId,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                side: BorderSide(color: Colors.red.shade100),
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'View Details',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primaryRed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // REQUEST DETAILS
  // ================================================================

  void _showRequestDetails({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
    required bool hasOffered,
    required String? currentUserId,
  }) {
    final patientName = requestData['patientName']?.toString() ?? 'Patient';

    final hospital = _getHospital(requestData);

    final bloodType = _normalizeBloodType(requestData['bloodType']);

    final unitsRequired = requestData['unitsRequired'] ?? 1;

    final urgency = requestData['urgency']?.toString() ?? 'Normal';

    final neededByDate = _getNeededByDate(requestData);

    final relationship = requestData['relationship']?.toString() ?? '';

    final notes = requestData['notes']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.water_drop,
                          color: AppColors.primaryRed,
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              requestId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Blood Request',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
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
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _buildDetailRow(Icons.person_outline, 'Patient', patientName),

                  _buildDetailRow(
                    Icons.calendar_today_outlined,
                    'Needed By',
                    neededByDate,
                  ),

                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Hospital',
                    hospital,
                  ),

                  _buildDetailRow(
                    Icons.bloodtype_outlined,
                    'Blood Type',
                    bloodType,
                  ),

                  _buildDetailRow(
                    Icons.water_drop_outlined,
                    'Units Required',
                    '$unitsRequired unit(s)',
                  ),

                  _buildDetailRow(Icons.priority_high, 'Urgency', urgency),

                  if (relationship.isNotEmpty)
                    _buildDetailRow(
                      Icons.people_outline,
                      'Relationship',
                      relationship,
                    ),

                  if (notes.isNotEmpty)
                    _buildDetailRow(Icons.notes_outlined, 'Notes', notes),

                  const SizedBox(height: 16),

                  // ------------------------------------------------
                  // OFFER BUTTON
                  // ------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasOffered || currentUserId == null
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);

                              await _submitOffer(
                                context: context,
                                requestId: requestId,
                                currentUserId: currentUserId,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: Text(
                        hasOffered ? 'Offer Submitted' : 'Offer to Help',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // DETAIL ROW
  // ================================================================

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 9),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _buildEmptyState(String donorBloodType) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype_outlined,
                size: 42,
                color: Colors.red.shade200,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No $donorBloodType blood requests',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'There are currently no approved blood requests that match your $donorBloodType blood type.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // SUBMIT DONATION OFFER
  // ================================================================

  Future<void> _submitOffer({
    required BuildContext context,
    required String requestId,
    required String? currentUserId,
  }) async {
    if (currentUserId == null) {
      return;
    }

    try {
      await _donorRepository.offerToDonate(
        requestId: requestId,
        donorId: currentUserId,
        donorName: widget.donorName,
        donorContact: widget.donorContact,
        donorBloodType: widget.donorBloodType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _submittedOffers.add(requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offer sent successfully! Waiting for PRC/Admin confirmation.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit offer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
