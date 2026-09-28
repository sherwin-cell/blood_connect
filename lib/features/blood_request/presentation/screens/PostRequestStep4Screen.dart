import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../verification/domain/entities/request_id_verification_data.dart';

class PostRequestStep4Screen extends StatefulWidget {
  final String patientName;
  final int patientAge;
  final String relationship;
  final String bloodType;
  final int unitsRequired;
  final String component;
  final String urgency;
  final DateTime neededByDate;
  final String notes;
  final String hospitalName;
  final String hospitalAddress;
  final String city;
  final String contactPerson;
  final String contactNumber;

  const PostRequestStep4Screen({
    super.key,
    required this.patientName,
    required this.patientAge,
    required this.relationship,
    required this.bloodType,
    required this.unitsRequired,
    required this.component,
    required this.urgency,
    required this.neededByDate,
    required this.notes,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.city,
    required this.contactPerson,
    required this.contactNumber,
  });

  @override
  State<PostRequestStep4Screen> createState() => _PostRequestStep4ScreenState();
}

class _PostRequestStep4ScreenState extends State<PostRequestStep4Screen> {
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  String? _savedIdSubmissionId;
  String? _frontIdImageUrl;
  String? _backIdImageUrl;
  String? _idType;
  String? _validationStatus;

  @override
  void initState() {
    super.initState();
    _loadAttachedIdSubmission();
  }

  /// Automatically fetch the user's latest submitted ID evidence to attach to this request
  Future<void> _loadAttachedIdSubmission() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestoreService = context.read<FirestoreService>();
      final savedId = await firestoreService.getLatestSavedIdSubmissionForUser(
        user.uid,
      );

      if (!mounted) return;

      if (savedId != null) {
        setState(() {
          _savedIdSubmissionId = savedId['submissionId'] as String?;
          _frontIdImageUrl = savedId['frontIdImageUrl'] as String?;
          _backIdImageUrl = savedId['backIdImageUrl'] as String?;
          _idType = savedId['idType'] as String?;
          _validationStatus = savedId['validationStatus'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading attached ID submission: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  Future<bool> _hasActiveBloodRequest(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('blood_requests')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase();
        if (status == 'active' || status == 'pending') {
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error checking active requests: $e");
    }
    return false;
  }

  Future<void> _submitRequest() async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in.')),
      );
      return;
    }

    if (_savedIdSubmissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No submitted ID found. Please complete ID submission first.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final hasActive = await _hasActiveBloodRequest(user.uid);
      if (hasActive) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an active blood request. Please complete or cancel your current request before creating a new one.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final firestoreService = context.read<FirestoreService>();

      // Construct ID verification payload entity using the already submitted data
      final idData = RequestIdVerificationData(
        idType: _idType ?? 'Government ID',
        validationStatus: _validationStatus ?? 'valid',
      );

      // Submit request attached with the user's existing submitted ID info for PRC Admin Review
      await firestoreService.submitRequestWithId(
        collection: 'blood_requests',
        requestPayload: {
          'userId': user.uid,
          'requesterId': user.uid,
          'requestType': 'blood_request',
          'patientName': widget.patientName,
          'patientAge': widget.patientAge,
          'relationship': widget.relationship,
          'bloodType': widget.bloodType,
          'unitsRequired': widget.unitsRequired,
          'unitsNeeded': widget.unitsRequired,
          'component': widget.component,
          'urgency': widget.urgency,
          'neededByDate': Timestamp.fromDate(widget.neededByDate),
          'requiredDate': Timestamp.fromDate(widget.neededByDate),
          'notes': widget.notes,
          'hospitalLocation':
              '${widget.hospitalName}, ${widget.hospitalAddress}, ${widget.city}',
          'hospital': widget.hospitalName,
          'contactPerson': widget.contactPerson,
          'contactNumber': widget.contactNumber,
          'status': 'pending', // Sent directly to PRC Admin review queue
          'createdAt': FieldValue.serverTimestamp(),
        },
        idData: idData,
        frontIdImageUrl: _frontIdImageUrl ?? '',
        backIdImageUrl: _backIdImageUrl,
        idVerificationSubmissionId: _savedIdSubmissionId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Blood request posted successfully and sent for PRC admin review.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        '${widget.neededByDate.month}/${widget.neededByDate.day}/${widget.neededByDate.year}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Post Blood Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        '1\nPatient Info',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Expanded(
                        child: Divider(thickness: 2, indent: 8, endIndent: 8),
                      ),
                      Text(
                        '2\nBlood Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Expanded(
                        child: Divider(thickness: 2, indent: 8, endIndent: 8),
                      ),
                      Text(
                        '3\nHospital Info',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      Expanded(
                        child: Divider(thickness: 2, indent: 8, endIndent: 8),
                      ),
                      Text(
                        '4\nReview & Submit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Info header card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: AppColors.primaryRed,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Review & Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Please review your information. Your submitted ID will be attached automatically for PRC admin review.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Request Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Summary Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request Summary Details',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryRed,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 20),
                        Text(
                          'Patient Information: ${widget.patientName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Age / Relationship: ${widget.patientAge} yrs, ${widget.relationship}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Blood Type Needed: ${widget.bloodType}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Units Needed: ${widget.unitsRequired}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Components: ${widget.component}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Needed By: $formattedDate',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Urgency: ${widget.urgency}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (widget.notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Notes: ${widget.notes}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Hospital Name: ${widget.hospitalName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Address: ${widget.hospitalAddress}, ${widget.city}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (widget.contactPerson.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Contact Person: ${widget.contactPerson}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (widget.contactNumber.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Contact Number: ${widget.contactNumber}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Attached ID status indicator badge
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '✓ Submitted ID Attached',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _idType != null
                                    ? 'Using your submitted $_idType record for admin review.'
                                    : 'Your submitted ID will be attached to this request.',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed:
                              (_isSubmitting || _savedIdSubmissionId == null)
                              ? null
                              : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit Request',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
