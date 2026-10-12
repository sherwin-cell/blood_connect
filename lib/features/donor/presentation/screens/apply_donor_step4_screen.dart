import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../verification/domain/entities/request_id_verification_data.dart';
import '../../../donor/presentation/widgets/step_indicator.dart';

class ApplyDonorStep4Screen extends StatefulWidget {
  final Map<String, dynamic> personalData;
  final String bloodType;
  final bool isAvailable;
  final DateTime? lastDonationDate;
  final Map<int, bool?> eligibilityAnswers;

  const ApplyDonorStep4Screen({
    super.key,
    required this.personalData,
    required this.bloodType,
    required this.isAvailable,
    this.lastDonationDate,
    required this.eligibilityAnswers,
  });

  @override
  State<ApplyDonorStep4Screen> createState() => _ApplyDonorStep4ScreenState();
}

class _ApplyDonorStep4ScreenState extends State<ApplyDonorStep4Screen> {
  static const Color donorGreen = Color(0xFF2E7D32);

  bool _isSubmitting = false;
  bool _isLoadingStatus = true;

  String? _savedIdSubmissionId;
  String? _frontIdImageUrl;
  String? _backIdImageUrl;
  String? _idType;
  String? _validationStatus;

  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _loadAttachedIdSubmission();
  }

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
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _submitDonorApplication() async {
    if (_isSubmitting) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the certification terms.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestoreService = context.read<FirestoreService>();

      final finalIdData = RequestIdVerificationData(
        idType: _idType ?? 'Government ID',
        validationStatus: _validationStatus ?? 'valid',
      );

      final payload = {
        'userId': user.uid,
        'requestType': 'donor_application',
        ...widget.personalData,
        'bloodType': widget.bloodType,
        'isAvailableForDonation': widget.isAvailable,
        'lastDonationDate': widget.lastDonationDate != null
            ? Timestamp.fromDate(widget.lastDonationDate!)
            : null,
        'eligibilityAnswers': widget.eligibilityAnswers.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'donorStatus': 'pending',
        'frontIdImageUrl': _frontIdImageUrl ?? '',
        'backIdImageUrl': _backIdImageUrl ?? '',
        'appliedForDonorAt': FieldValue.serverTimestamp(),
      };

      await firestoreService.submitRequestWithId(
        collection: 'donors',
        requestPayload: payload,
        idData: finalIdData,
        frontIdImageUrl: _frontIdImageUrl ?? '',
        backIdImageUrl: _backIdImageUrl,
        idVerificationSubmissionId: _savedIdSubmissionId,
      );

      if (!mounted) return;

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/donor-pending', (route) => false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildReviewCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildIdStatusCard() {
    final hasId = _savedIdSubmissionId != null;

    final status = (_validationStatus ?? '').toLowerCase();

    final statusText = status.isEmpty
        ? (hasId ? 'Submitted' : 'Not attached')
        : _validationStatus!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasId ? donorGreen.withOpacity(0.06) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasId ? donorGreen.withOpacity(0.2) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: hasId ? donorGreen.withOpacity(0.1) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.badge_outlined,
              color: hasId ? donorGreen : Colors.grey.shade600,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasId ? 'Attached Government ID' : 'No ID Submission Found',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasId
                      ? '${_idType ?? 'Government ID'} ($statusText)'
                      : 'No saved ID submission is currently attached.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (hasId)
            const Icon(Icons.check_circle, color: donorGreen, size: 20),
        ],
      ),
    );
  }

  Widget _buildScreeningSummary() {
    final answered = widget.eligibilityAnswers.length;

    final yesCount = widget.eligibilityAnswers.values
        .where((answer) => answer == true)
        .length;

    final noCount = widget.eligibilityAnswers.values
        .where((answer) => answer == false)
        .length;

    return _buildReviewCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: donorGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: donorGreen,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Screening (11 Items)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your health screening responses are ready for review.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildScreeningCount(
                  label: 'Answered',
                  value: '$answered/11',
                ),
              ),
              Expanded(
                child: _buildScreeningCount(label: 'Yes', value: '$yesCount'),
              ),
              Expanded(
                child: _buildScreeningCount(label: 'No', value: '$noCount'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningCount({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: donorGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Apply as Blood Donor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: donorGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),
      body: _isLoadingStatus
          ? const Center(child: CircularProgressIndicator(color: donorGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DonorStepIndicator(currentStep: 4),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: donorGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: donorGreen.withOpacity(0.15)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          color: donorGreen,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Review & Submit',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: donorGreen,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Review your information before submitting your donor application.',
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
                  const SizedBox(height: 18),
                  _buildSectionTitle('Personal Information'),
                  const SizedBox(height: 8),
                  _buildReviewCard(
                    child: Column(
                      children: widget.personalData.entries
                          .map(
                            (entry) =>
                                _reviewRow(entry.key, entry.value.toString()),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Blood & Donation Information'),
                  const SizedBox(height: 8),
                  _buildReviewCard(
                    child: Column(
                      children: [
                        _reviewRow('Blood Type', widget.bloodType),
                        _reviewRow(
                          'Available',
                          widget.isAvailable ? 'Yes' : 'No',
                        ),
                        _reviewRow(
                          'Last Donation',
                          widget.lastDonationDate?.toString().split(' ')[0] ??
                              'None',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Health Screening'),
                  const SizedBox(height: 8),
                  _buildScreeningSummary(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Attached Identification'),
                  const SizedBox(height: 8),
                  _buildIdStatusCard(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _agreedToTerms
                            ? donorGreen.withOpacity(0.25)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _agreedToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: donorGreen,
                      title: const Text(
                        'Certification',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'I certify that the personal details and screening answers provided are accurate and complete.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your donor application will be submitted for Philippine Red Cross review. Your donor status will remain pending until the application is reviewed.',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitDonorApplication,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: donorGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.send_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Donor Application',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
    );
  }
}
