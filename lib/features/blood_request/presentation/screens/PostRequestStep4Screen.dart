import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../verification/domain/entities/request_id_verification_data.dart';
import '../widgets/step_indicator.dart';

class PostRequestStep4Screen extends StatefulWidget {
  final String patientName;
  final int patientAge;
  final String patientBirthday;
  final String patientSex;
  final String contactNumber;
  final String relativeName;
  final String relationship;

  final String bloodType;
  final int unitsRequired;
  final String component;
  final String hemoglobin;

  final String urgency;
  final DateTime neededByDate;
  final String notes;

  final String hospitalName;
  final String attendingPhysician;
  final String clinicalDiagnosis;
  final String requestingPhysician;

  final String brfFileName;
  final String brfFileUrl;
  final String otherInfo;

  const PostRequestStep4Screen({
    super.key,
    required this.patientName,
    required this.patientAge,
    required this.patientBirthday,
    required this.patientSex,
    required this.contactNumber,
    required this.relativeName,
    required this.relationship,
    required this.bloodType,
    required this.unitsRequired,
    required this.component,
    required this.hemoglobin,
    required this.urgency,
    required this.neededByDate,
    required this.notes,
    required this.hospitalName,
    required this.attendingPhysician,
    required this.clinicalDiagnosis,
    required this.requestingPhysician,
    required this.brfFileName,
    required this.brfFileUrl,
    required this.otherInfo,
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

  // ============================================================
  // LOAD SAVED ID
  // ============================================================

  Future<void> _loadAttachedIdSubmission() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return;
      }

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
        setState(() {
          _isLoadingStatus = false;
        });
      }
    }
  }

  // ============================================================
  // CHECK ACTIVE REQUEST
  // ============================================================

  Future<bool> _hasActiveBloodRequest(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('blood_requests')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        final status = data['status']?.toString().toLowerCase();

        if (status == 'active' || status == 'pending') {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking active requests: $e');
    }

    return false;
  }

  // ============================================================
  // SUBMIT REQUEST
  // ============================================================

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

    if (widget.brfFileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'BRF PDF is missing. Please go back and upload the BRF again.',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // ----------------------------------------------------------
      // CHECK ACTIVE REQUEST
      // ----------------------------------------------------------

      final hasActive = await _hasActiveBloodRequest(user.uid);

      if (hasActive) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an active blood request. '
              'Please complete or cancel your current request '
              'before creating a new one.',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // FIRESTORE SERVICE
      // ----------------------------------------------------------

      final firestoreService = context.read<FirestoreService>();

      final idData = RequestIdVerificationData(
        idType: _idType ?? 'Government ID',
        validationStatus: _validationStatus ?? 'valid',
      );

      // ----------------------------------------------------------
      // SUBMIT BLOOD REQUEST
      // ----------------------------------------------------------

      await firestoreService.submitRequestWithId(
        collection: 'blood_requests',

        requestPayload: {
          'userId': user.uid,
          'requesterId': user.uid,
          'requestType': 'blood_request',

          // Patient information
          'patientName': widget.patientName,
          'patientAge': widget.patientAge,
          'patientBirthday': widget.patientBirthday,
          'patientSex': widget.patientSex,
          'contactNumber': widget.contactNumber,
          'relativeName': widget.relativeName,
          'relationship': widget.relationship,

          // Blood details
          'bloodType': widget.bloodType,
          'unitsRequired': widget.unitsRequired,
          'unitsNeeded': widget.unitsRequired,
          'component': widget.component,
          'hemoglobin': widget.hemoglobin,

          // Request details
          'urgency': widget.urgency,
          'neededByDate': Timestamp.fromDate(widget.neededByDate),
          'requiredDate': Timestamp.fromDate(widget.neededByDate),
          'notes': widget.notes,

          // Hospital / medical information
          'hospitalName': widget.hospitalName,
          'attendingPhysician': widget.attendingPhysician,
          'clinicalDiagnosis': widget.clinicalDiagnosis,
          'requestingPhysician': widget.requestingPhysician,

          // BRF
          'brfFileName': widget.brfFileName,
          'brfFileUrl': widget.brfFileUrl,

          // Optional information
          'otherInfo': widget.otherInfo,

          // Request status
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        },

        // Attached ID information
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Post Blood Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                  // ==================================================
                  // STEP INDICATOR
                  // ==================================================
                  const StepIndicator(currentStep: 4),

                  const SizedBox(height: 18),

                  // ==================================================
                  // HEADER
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade100),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,

                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.shade100),
                          ),

                          child: const Icon(
                            Icons.fact_check_outlined,
                            color: AppColors.primaryRed,
                            size: 27,
                          ),
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
                                  fontSize: 15,
                                ),
                              ),

                              SizedBox(height: 4),

                              Text(
                                'Review your request details before sending it to Philippine Red Cross for review.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // PATIENT INFORMATION
                  // ==================================================
                  _buildSectionCard(
                    title: 'Patient Information',
                    icon: Icons.person_outline,
                    children: [
                      _buildInfoRow('Patient Name', widget.patientName),

                      _buildInfoRow('Age', '${widget.patientAge}'),

                      _buildInfoRow('Birthday', widget.patientBirthday),

                      _buildInfoRow('Sex', widget.patientSex),

                      _buildInfoRow('Contact Number', widget.contactNumber),

                      _buildInfoRow(
                        'Relative / Contact Person',
                        '${widget.relativeName} (${widget.relationship})',
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // BLOOD REQUEST DETAILS
                  // ==================================================
                  _buildSectionCard(
                    title: 'Blood Request Details',
                    icon: Icons.bloodtype_outlined,
                    children: [
                      _buildInfoRow('Blood Type Needed', widget.bloodType),

                      _buildInfoRow(
                        'Units Required',
                        '${widget.unitsRequired}',
                      ),

                      _buildInfoRow('Blood Component', widget.component),

                      _buildInfoRow(
                        'Hemoglobin / Hematocrit',
                        widget.hemoglobin.isEmpty ? 'N/A' : widget.hemoglobin,
                      ),

                      _buildInfoRow('Urgency', widget.urgency),

                      _buildInfoRow(
                        'Blood Needed By',
                        _formatDate(widget.neededByDate),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // HOSPITAL & MEDICAL INFORMATION
                  // ==================================================
                  _buildSectionCard(
                    title: 'Hospital & Medical Information',
                    icon: Icons.local_hospital_outlined,
                    children: [
                      _buildInfoRow('Hospital', widget.hospitalName),

                      _buildInfoRow(
                        'Attending Physician',
                        widget.attendingPhysician,
                      ),

                      _buildInfoRow(
                        'Clinical Diagnosis',
                        widget.clinicalDiagnosis,
                      ),

                      _buildInfoRow(
                        'Requesting Physician',
                        widget.requestingPhysician,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // BRF DOCUMENT
                  // ==================================================
                  _buildSectionCard(
                    title: 'Blood Request Form',
                    icon: Icons.picture_as_pdf_outlined,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),

                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),

                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,

                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),

                              child: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.green,
                                size: 24,
                              ),
                            ),

                            const SizedBox(width: 11),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  const Text(
                                    'BRF PDF Attached',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    widget.brfFileName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 22,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'The BRF date and other information are contained in the uploaded PDF and will be reviewed by PRC admin.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),

                      if (widget.otherInfo.isNotEmpty) ...[
                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),

                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),

                          child: Text(
                            'Other Info: ${widget.otherInfo}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // ATTACHED ID
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: Colors.blue,
                          size: 25,
                        ),

                        const SizedBox(width: 11),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Text(
                                'Identification Document Attached',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                _idType != null
                                    ? '$_idType has been attached to this request.'
                                    : 'Your submitted ID has been attached to this request.',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'The blood request and attached documents will be reviewed by PRC admin.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.check_circle,
                          color: Colors.blue,
                          size: 21,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // SUBMISSION NOTICE
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),

                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber.shade800,
                          size: 20,
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            'After submission, your blood request will be marked as pending and sent to Philippine Red Cross for review. Please make sure all information is correct before submitting.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 10.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // BUTTONS
                  // ==================================================
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),

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
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Submit Request',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    SizedBox(width: 6),

                                    Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,

                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),

                child: Icon(icon, color: AppColors.primaryRed, size: 19),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Divider(height: 1, color: Colors.grey.shade200),

          const SizedBox(height: 8),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 125,

            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
