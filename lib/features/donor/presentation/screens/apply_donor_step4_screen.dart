import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../verification/domain/entities/request_id_verification_data.dart';
import '../../../verification/domain/repositories/i_verification_repository.dart';
import '../../../verification/presentation/id_verification_flow.dart';
import '../../../verification/presentation/widgets/request_id_summary_card.dart';

class ApplyDonorStep4Screen extends StatefulWidget {
  final String bloodType;
  final bool isAvailable;
  final DateTime? lastDonationDate;
  final bool isEligible;
  final Map<String, dynamic> eligibilityAnswers;

  const ApplyDonorStep4Screen({
    super.key,
    required this.bloodType,
    required this.isAvailable,
    this.lastDonationDate,
    required this.isEligible,
    required this.eligibilityAnswers,
  });

  @override
  State<ApplyDonorStep4Screen> createState() => _ApplyDonorStep4ScreenState();
}

class _ApplyDonorStep4ScreenState extends State<ApplyDonorStep4Screen> {
  bool _isSubmitting = false;
  bool _isLoadingStatus = true;
  String? _userVerificationStatus;
  String? _rejectionReason;
  RequestIdVerificationData? _idVerification;
  String? _savedIdSubmissionId;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIdSubmission();
  }

  Future<void> _loadSavedIdSubmission() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestoreService = context.read<FirestoreService>();

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final userData = userDoc.data();
      String? profileStatus = userData?['idVerificationStatus'] as String?;

      final savedId = await firestoreService.getLatestSavedIdSubmissionForUser(
        user.uid,
      );

      if (!mounted) return;

      setState(() {
        _savedIdSubmissionId = savedId?['submissionId'] as String?;
        _userVerificationStatus =
            profileStatus ?? (savedId?['status'] as String?);
        _rejectionReason = savedId?['rejectionReason'] as String?;
      });
    } catch (e) {
      debugPrint('Error loading saved ID submission: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  Future<void> _captureValidId() async {
    if (_userVerificationStatus == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your ID verification is currently pending admin review.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await IdVerificationFlow.start(context);
    if (!mounted) return;
    if (result != null && result.isComplete) {
      setState(() => _idVerification = result);
    }
  }

  Future<void> _submitDonorApplication() async {
    if (_isSubmitting) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the declaration before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found. Please log in.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bool isApproved = RequestIdVerificationData.isApprovedStatus(
        _userVerificationStatus,
      );
      final bool hasSavedReusableId =
          _savedIdSubmissionId != null && isApproved;
      final bool needsIdCapture = !hasSavedReusableId;

      final repository = context.read<IVerificationRepository>();
      final firestoreService = context.read<FirestoreService>();

      String? frontUrl;
      String? backUrl;
      String? idType = 'Government ID';
      String? submissionId = _savedIdSubmissionId;
      RequestIdVerificationData? finalIdData = _idVerification;

      if (needsIdCapture && _idVerification != null) {
        final uploaded = await repository.uploadRequestIdImages(
          frontIdPath: _idVerification!.frontIdImage!,
          backIdPath: _idVerification!.backIdImage,
        );
        frontUrl = uploaded.frontUrl;
        backUrl = uploaded.backUrl;
        idType = _idVerification!.idType;

        submissionId = await repository.saveOrUpdateIdSubmission(
          userId: user.uid,
          data: _idVerification!,
        );
      } else if (!needsIdCapture && submissionId != null) {
        final existingIdDoc = await FirebaseFirestore.instance
            .collection('id_verifications')
            .doc(submissionId)
            .get();

        if (existingIdDoc.exists) {
          final data = existingIdDoc.data()!;
          frontUrl = data['frontIdImageUrl'] as String?;
          backUrl = data['backIdImageUrl'] as String?;
          idType = data['idType'] as String? ?? 'Government ID';

          finalIdData = RequestIdVerificationData(
            idType: idType,
            validationStatus: data['validationStatus'] ?? 'valid',
          );
        }
      }

      // Fetch user profile info to populate the donor document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final fullName = userData['fullName'] ?? 'Anonymous Donor';
      final chapter = userData['chapter'] ?? 'PRC Chapter';
      final email = user.email ?? '';

      // Submit donor application including root-level image and ID type fields for admin visibility
      await firestoreService.submitRequestWithId(
        collection: 'donors',
        requestPayload: {
          'userId': user.uid,
          'requesterId': user.uid,
          'requestType': 'donor_application',
          'fullName': fullName,
          'email': email,
          'chapter': chapter,
          'isDonor': false,
          'donorStatus': 'pending',
          'bloodType': widget.bloodType,
          'isAvailableForDonation': widget.isAvailable,
          'lastDonationDate': widget.lastDonationDate != null
              ? Timestamp.fromDate(widget.lastDonationDate!)
              : null,
          'isEligible': widget.isEligible,
          'eligibilityAnswers': widget.eligibilityAnswers,
          'frontIdImageUrl': frontUrl ?? '',
          'backIdImageUrl': backUrl ?? '',
          'idType': idType,
          'appliedForDonorAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'stepCompleted': 4,
        },
        idData: finalIdData ?? const RequestIdVerificationData(),
        frontIdImageUrl: frontUrl ?? '',
        backIdImageUrl: backUrl ?? '',
        idVerificationSubmissionId: submissionId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donor application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/donor-pending', (route) => false);
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'No previous donation recorded';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _yesNo(dynamic value) {
    if (value == true) return 'Yes';
    if (value == false) return 'No';
    return 'Not answered';
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isApproved = RequestIdVerificationData.isApprovedStatus(
      _userVerificationStatus,
    );
    final bool isPending = _userVerificationStatus == 'pending';
    final bool isRejected = _userVerificationStatus == 'rejected';
    final bool canBypassId = isApproved && _savedIdSubmissionId != null;
    final answers = widget.eligibilityAnswers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Step 4: Review & Submit',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: Colors.green.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your application is ready for submission. Please review your details and confirm your identity verification below.',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'DONOR INFORMATION',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 14,
                    ),
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _reviewRow('Blood Type', widget.bloodType),
                        _reviewRow(
                          'Emergency Availability',
                          widget.isAvailable ? 'Yes' : 'No',
                        ),
                        _reviewRow(
                          'Last Donation',
                          _formatDate(widget.lastDonationDate),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'ELIGIBILITY SCREENING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 14,
                    ),
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _reviewRow(
                          'Currently Healthy',
                          _yesNo(answers['feelsHealthy']),
                        ),
                        _reviewRow(
                          'Recent Illness',
                          _yesNo(answers['hasRecentIllness']),
                        ),
                        _reviewRow(
                          'Recent Medication',
                          _yesNo(answers['hasRecentMedication']),
                        ),
                        _reviewRow(
                          'Recent Tattoo/Piercing',
                          _yesNo(answers['hasRecentTattooOrPiercing']),
                        ),
                        _reviewRow(
                          'Recently Donated',
                          _yesNo(answers['hasDonatedRecently']),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'IDENTITY VERIFICATION',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontSize: 14,
                    ),
                  ),
                  const Divider(height: 20),

                  if (canBypassId) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '✓ Identity already verified',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your approved identity verification will be used for this donor application.',
                                  style: TextStyle(
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
                  ] else if (isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.hourglass_empty,
                            color: Colors.orange,
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your ID verification is currently pending admin review.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isRejected) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _rejectionReason != null &&
                                      _rejectionReason!.trim().isNotEmpty
                                  ? 'Previous ID submission rejected: $_rejectionReason'
                                  : 'Your previous ID verification was rejected. Please resubmit your ID.',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _captureValidId,
                        icon: const Icon(
                          Icons.badge_outlined,
                          color: Color(0xFF2E7D32),
                        ),
                        label: const Text(
                          'Resubmit Government ID',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'To complete your donor application, please verify your identity with a valid government ID.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    if (_idVerification != null)
                      RequestIdSummaryCard(
                        data: _idVerification!,
                        onRecapture: _captureValidId,
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _captureValidId,
                          icon: const Icon(
                            Icons.badge_outlined,
                            color: Color(0xFF2E7D32),
                          ),
                          label: const Text(
                            'Capture Government ID for Verification',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),

                  CheckboxListTile(
                    value: _agreedToTerms,
                    onChanged: _isSubmitting
                        ? null
                        : (val) =>
                              setState(() => _agreedToTerms = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I certify that the information I provided is accurate and complete.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
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
                              (_isSubmitting ||
                                  isPending ||
                                  (!canBypassId && _idVerification == null))
                              ? null
                              : _submitDonorApplication,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
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
                                  'Submit Donor Application',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
