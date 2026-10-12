import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_theme.dart';
import './PostRequestStep4Screen.dart';
import '../widgets/step_indicator.dart';

class PostRequestStep3Screen extends StatefulWidget {
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

  const PostRequestStep3Screen({
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
  });

  @override
  State<PostRequestStep3Screen> createState() => _PostRequestStep3ScreenState();
}

class _PostRequestStep3ScreenState extends State<PostRequestStep3Screen> {
  final _formKey = GlobalKey<FormState>();

  final _hospitalController = TextEditingController();
  final _attendingPhysicianController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _requestingPhysicianController = TextEditingController();
  final _otherInfoController = TextEditingController();

  String? _brfFileName;
  String? _brfFileUrl;

  bool _isUploadingPdf = false;

  @override
  void dispose() {
    _hospitalController.dispose();
    _attendingPhysicianController.dispose();
    _diagnosisController.dispose();
    _requestingPhysicianController.dispose();
    _otherInfoController.dispose();

    super.dispose();
  }

  // ============================================================
  // BRF PDF UPLOAD
  // ============================================================

  Future<void> _pickBrfPdf() async {
    if (_isUploadingPdf) return;

    try {
      debugPrint('========================================');
      debugPrint('BRF PDF: Starting file picker');
      debugPrint('========================================');

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.isEmpty) {
        debugPrint('BRF PDF: User cancelled file picker.');
        return;
      }

      final PlatformFile platformFile = result.first;
      final String fileName = platformFile.name;

      debugPrint('BRF PDF: File selected');
      debugPrint('BRF PDF: Name = $fileName');
      debugPrint('BRF PDF: Path = ${platformFile.path}');

      if (!fileName.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a PDF file.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final String? filePath = platformFile.path;

      if (filePath == null || filePath.isEmpty) {
        debugPrint('BRF PDF: File path is null or empty.');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access the selected PDF file.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final File file = File(filePath);
      final bool fileExists = await file.exists();

      debugPrint('BRF PDF: File exists = $fileExists');

      if (!fileExists) {
        throw Exception('The selected PDF file could not be found.');
      }

      if (mounted) {
        setState(() {
          _isUploadingPdf = true;
          _brfFileName = null;
          _brfFileUrl = null;
        });
      }

      final Uint8List fileBytes = await file.readAsBytes();

      debugPrint('========================================');
      debugPrint('BRF PDF: File successfully read');
      debugPrint('BRF PDF: File name = $fileName');
      debugPrint('BRF PDF: File size = ${fileBytes.length} bytes');
      debugPrint('========================================');

      if (fileBytes.isEmpty) {
        throw Exception('The selected PDF file is empty.');
      }

      // ==========================================================
      // CLOUDINARY
      // ==========================================================

      const String cloudName = 'dlk8chosr';
      const String uploadPreset = 'blood_request_preset';

      final Uri uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/raw/upload',
      );

      debugPrint('========================================');
      debugPrint('BRF PDF: Starting Cloudinary upload');
      debugPrint('Cloud name: $cloudName');
      debugPrint('Upload preset: $uploadPreset');
      debugPrint('Upload endpoint: $uri');
      debugPrint('File name: $fileName');
      debugPrint('File bytes: ${fileBytes.length}');
      debugPrint('========================================');

      final http.MultipartRequest request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = uploadPreset;

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      debugPrint('BRF PDF: Sending request to Cloudinary...');

      final http.StreamedResponse response = await request.send();

      final String responseData = await response.stream.bytesToString();

      debugPrint('========================================');
      debugPrint('BRF PDF: Cloudinary response');
      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response: $responseData');
      debugPrint('========================================');

      Map<String, dynamic> jsonResult;

      try {
        final dynamic decoded = json.decode(responseData);

        if (decoded is! Map<String, dynamic>) {
          throw Exception('Unexpected Cloudinary response format.');
        }

        jsonResult = decoded;
      } catch (e) {
        throw Exception(
          'Cloudinary returned an invalid response: $responseData',
        );
      }

      // ==========================================================
      // SUCCESS
      // ==========================================================

      if (response.statusCode == 200) {
        final String? secureUrl = jsonResult['secure_url']?.toString();

        debugPrint('BRF PDF: Upload successful.');
        debugPrint('BRF PDF: secure_url = $secureUrl');

        if (secureUrl == null || secureUrl.isEmpty) {
          throw Exception(
            'Cloudinary upload succeeded but no secure_url '
            'was returned.',
          );
        }

        if (!mounted) return;

        setState(() {
          _brfFileName = fileName;
          _brfFileUrl = secureUrl;
          _isUploadingPdf = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('BRF PDF uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        return;
      }

      // ==========================================================
      // CLOUDINARY ERROR
      // ==========================================================

      String errorMessage = 'Cloudinary upload failed.';

      final dynamic error = jsonResult['error'];

      if (error is Map && error['message'] != null) {
        errorMessage = error['message'].toString();
      }

      debugPrint('BRF PDF: Cloudinary ERROR');
      debugPrint('BRF PDF: $errorMessage');

      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('BRF PDF UPLOAD ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');

      if (!mounted) return;

      setState(() {
        _isUploadingPdf = false;
        _brfFileName = null;
        _brfFileUrl = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading BRF PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // NEXT STEP
  // ============================================================

  void _nextStep() {
    if (_isUploadingPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for the BRF PDF upload to finish.'),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_brfFileName == null ||
        _brfFileName!.isEmpty ||
        _brfFileUrl == null ||
        _brfFileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the BRF PDF before continuing.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    debugPrint('========================================');
    debugPrint('BRF PDF: Moving to Step 4');
    debugPrint('BRF File Name: $_brfFileName');
    debugPrint('BRF File URL: $_brfFileUrl');
    debugPrint('========================================');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostRequestStep4Screen(
          patientName: widget.patientName,
          patientAge: widget.patientAge,
          patientBirthday: widget.patientBirthday,
          patientSex: widget.patientSex,
          contactNumber: widget.contactNumber,
          relativeName: widget.relativeName,
          relationship: widget.relationship,
          bloodType: widget.bloodType,
          unitsRequired: widget.unitsRequired,
          component: widget.component,
          hemoglobin: widget.hemoglobin,
          urgency: widget.urgency,
          neededByDate: widget.neededByDate,
          notes: widget.notes,
          hospitalName: _hospitalController.text.trim(),
          attendingPhysician: _attendingPhysicianController.text.trim(),
          clinicalDiagnosis: _diagnosisController.text.trim(),
          requestingPhysician: _requestingPhysicianController.text.trim(),
          brfFileName: _brfFileName!,
          brfFileUrl: _brfFileUrl!,
          otherInfo: _otherInfoController.text.trim(),
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Apply for Blood Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: () {}),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // STEP INDICATOR
              // ==================================================
              const StepIndicator(currentStep: 3),

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
                        Icons.local_hospital_rounded,
                        color: AppColors.primaryRed,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: const [
                          Text(
                            'Hospital & Medical Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryRed,
                              fontSize: 15,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Provide the hospital information and '
                            'upload the Blood Request Form (BRF).',
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
              // FACILITY & PHYSICIAN INFORMATION
              // ==================================================
              const Text(
                'Facility & Physician Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),

                child: Column(
                  children: [
                    TextFormField(
                      controller: _hospitalController,
                      decoration: _inputDecoration(
                        'Hospital Admitted (Name & Location)',
                        Icons.local_hospital_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter hospital name';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _attendingPhysicianController,
                      decoration: _inputDecoration(
                        'Attending Physician',
                        Icons.medical_services_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter attending physician';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _diagnosisController,
                      decoration: _inputDecoration(
                        'Clinical Diagnosis',
                        Icons.sick_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter clinical diagnosis';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _requestingPhysicianController,
                      decoration: _inputDecoration(
                        'Requesting Physician & License Number',
                        Icons.badge_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter requesting physician & license';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // BRF DOCUMENT
              // ==================================================
              const Text(
                'Blood Request Form (BRF)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'Upload Medical Certificate / Request Slip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ==================================================
                    // UPLOAD AREA
                    // ==================================================
                    GestureDetector(
                      onTap: _isUploadingPdf ? null : _pickBrfPdf,

                      child: CustomPaint(
                        painter: _DashedBorderPainter(
                          color: _brfFileName != null
                              ? Colors.green
                              : Colors.grey.shade400,
                          radius: 10,
                        ),

                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 22,
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              if (_isUploadingPdf)
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primaryRed,
                                  ),
                                )
                              else
                                Icon(
                                  _brfFileName != null
                                      ? Icons.check_circle_outline
                                      : Icons.file_upload_outlined,
                                  size: 34,
                                  color: _brfFileName != null
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),

                              const SizedBox(height: 8),

                              Text(
                                _isUploadingPdf
                                    ? 'Uploading BRF...'
                                    : _brfFileName == null
                                    ? 'Tap to upload file'
                                    : 'BRF uploaded successfully',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _brfFileName != null
                                      ? Colors.green
                                      : Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                _brfFileName == null
                                    ? 'PDF document'
                                    : _brfFileName!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // OTHER INFORMATION
                    // ==================================================
                    TextFormField(
                      controller: _otherInfoController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'Other Info (Optional)',
                        Icons.info_outline,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // INFORMATION BOX
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),

                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
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
                        'Please upload a valid Blood Request Form '
                        '(BRF) PDF. The date and other information '
                        'contained in the uploaded form will be '
                        'used for PRC admin verification.',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // NAVIGATION
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUploadingPdf
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
                      onPressed: _isUploadingPdf ? null : _nextStep,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),

                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Text(
                            'Next: Review & Submit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(width: 4),

                          Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,

      labelStyle: const TextStyle(fontSize: 12, color: Colors.grey),

      prefixIcon: Icon(icon, color: AppColors.primaryRed, size: 20),

      filled: true,
      fillColor: Colors.white,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
      ),

      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: Colors.red),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

// ============================================================
// DASHED BORDER
// ============================================================

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );

    const double dashWidth = 6;
    const double dashSpace = 4;

    final Path path = Path();

    path.addRRect(rrect);
    final ui.PathMetric metric = path.computeMetrics().first;

    double distance = 0;

    while (distance < metric.length) {
      final double end = distance + dashWidth;

      final Path extract = metric.extractPath(
        distance,
        end > metric.length ? metric.length : end,
      );

      canvas.drawPath(extract, paint);

      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
