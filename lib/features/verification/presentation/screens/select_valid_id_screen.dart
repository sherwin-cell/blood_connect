import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../provider/request_id_verification_provider.dart';
import 'capture_id_screen.dart';
import 'review_id_screen.dart';

class AcceptedIdItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const AcceptedIdItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class SelectValidIdScreen extends StatefulWidget {
  const SelectValidIdScreen({super.key});

  @override
  State<SelectValidIdScreen> createState() => _SelectValidIdScreenState();
}

class _SelectValidIdScreenState extends State<SelectValidIdScreen> {
  final List<AcceptedIdItem> _acceptedIds = const [
    AcceptedIdItem(
      title: 'Philippine National ID (PhilSys)',
      subtitle: 'Physical card or ePhilID accepted',
      icon: Icons.badge_outlined,
    ),
    AcceptedIdItem(
      title: "Driver's License",
      subtitle: 'LTO-issued photo identification card',
      icon: Icons.time_to_leave_outlined,
    ),
    AcceptedIdItem(
      title: 'UMID',
      subtitle: 'Unified Multi-Purpose ID (SSS/GSIS)',
      icon: Icons.credit_card_outlined,
    ),
    AcceptedIdItem(
      title: 'PRC ID',
      subtitle: 'Professional Regulation Commission ID',
      icon: Icons.workspace_premium_outlined,
    ),
    AcceptedIdItem(
      title: 'Other',
      subtitle: 'Other government-issued photo identification card',
      icon: Icons.account_box_outlined,
    ),
  ];

  String? _selectedIdType;
  File? _frontIdImage;
  File? _backIdImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestIdVerificationProvider>().loadVerificationStatus();
    });
  }

  /// Picks both front and back ID images simultaneously from the gallery
  Future<void> _pickBothImagesFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          _frontIdImage = File(pickedFiles[0].path);
          if (pickedFiles.length > 1) {
            _backIdImage = File(pickedFiles[1].path);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error choosing images: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Opens live camera capture workflow via CaptureIdScreen
  Future<void> _openCameraCapture() async {
    final provider = context.read<RequestIdVerificationProvider>();

    if (_selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid ID type first.')),
      );
      return;
    }

    await provider.selectIdTypeAndSaveProfile(_selectedIdType!);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const CaptureIdScreen(),
        ),
      ),
    );
  }

  /// Bottom sheet selector for choosing between Camera or Gallery
  void _showImageSourceActionSheet() {
    if (_selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid ID type first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFC62828)),
              title: const Text('Take Photos via Camera (Front & Back)'),
              onTap: () {
                Navigator.of(context).pop();
                _openCameraCapture();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFFC62828),
              ),
              title: const Text('Upload Front & Back from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickBothImagesFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Handles action when Continue is pressed after uploading files from gallery
  Future<void> _onContinuePressed(BuildContext context) async {
    final provider = context.read<RequestIdVerificationProvider>();

    if (!provider.isFaceVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Face Verification before submitting an ID.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!provider.canSubmitId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.verificationStatus == 'pending'
                ? 'Your ID verification is currently pending review.'
                : 'Your ID has already been approved.',
          ),
        ),
      );
      return;
    }

    if (_selectedIdType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid ID type.')),
      );
      return;
    }

    if (_frontIdImage == null || _backIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload both the front and back images of your ID, or use the camera option.',
          ),
        ),
      );
      return;
    }

    await provider.selectIdTypeAndSaveProfile(_selectedIdType!);

    // Process gallery images into provider state
    await provider.processIdCard(_frontIdImage!);
    await provider.processBackIdCard(_backIdImage!);

    if (!mounted) return;

    // Route directly to Review Screen when using gallery uploads
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const ReviewIdScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestIdVerificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Submit a Valid ID',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: provider.isLoading && provider.verificationStatus == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!provider.isFaceVerified)
                        _buildStatusBanner(
                          color: Colors.red,
                          text:
                              'Face Verification Required: You must complete face verification before you can submit an ID.',
                        ),
                      if (provider.isFaceVerified &&
                          provider.verificationStatus == 'rejected')
                        _buildStatusBanner(
                          color: Colors.red,
                          text:
                              'Your previous ID submission was rejected. Please resubmit a clear, valid ID.',
                        ),
                      if (provider.isFaceVerified &&
                          provider.verificationStatus == 'pending')
                        _buildStatusBanner(
                          color: Colors.orange,
                          text:
                              'Your ID verification is currently pending review. You cannot submit a new ID at this time.',
                        ),
                      if (provider.isFaceVerified &&
                          provider.isAccountFullyVerified)
                        _buildStatusBanner(
                          color: Colors.green,
                          text: 'Your account is fully verified and approved.',
                        ),
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      _buildSectionTitle(
                        'Government-Issued ID *',
                        'Select the type of ID you will upload.',
                      ),
                      const SizedBox(height: 10),
                      _buildDropdownField(provider),
                      const SizedBox(height: 12),
                      _buildUploadCard(provider),
                      const SizedBox(height: 6),
                      _buildSecurityNote(),
                      const SizedBox(height: 16),
                      _buildAcceptedIdsInfo(),
                      const SizedBox(height: 20),
                      _buildPrivacyBadge(),
                      const SizedBox(height: 24),
                      _buildActionButtons(provider, context),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner({
    required MaterialColor color,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Text(text, style: TextStyle(color: color.shade900, fontSize: 12)),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Color(0xFFC62828),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identity Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'To protect patients and prevent fraudulent requests, please verify your identity.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.black54,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 10,
              backgroundColor: Color(0xFFC62828),
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(RequestIdVerificationProvider provider) {
    final bool isEnabled = provider.isFaceVerified && provider.canSubmitId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedIdType,
          hint: Row(
            children: const [
              Icon(Icons.badge_outlined, color: Colors.grey, size: 20),
              SizedBox(width: 10),
              Text(
                'Select ID Type',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          isExpanded: true,
          items: _acceptedIds.map((item) {
            return DropdownMenuItem<String>(
              value: item.title,
              child: Row(
                children: [
                  Icon(item.icon, color: const Color(0xFFC62828), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: isEnabled
              ? (val) => setState(() => _selectedIdType = val)
              : null,
        ),
      ),
    );
  }

  Widget _buildUploadCard(RequestIdVerificationProvider provider) {
    final bool isEnabled = provider.isFaceVerified && provider.canSubmitId;
    final bool hasBothImages = _frontIdImage != null && _backIdImage != null;

    return InkWell(
      onTap: isEnabled ? _showImageSourceActionSheet : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasBothImages ? Colors.green.shade300 : Colors.red.shade200,
          ),
        ),
        child: hasBothImages
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _frontIdImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _backIdImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Front & Back Attached',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap to change or re-upload photos',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              )
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_file_outlined,
                      color: Color(0xFFC62828),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload Front and Back ID Photos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to capture via camera or select both from gallery',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      children: const [
        Icon(Icons.security_outlined, size: 14, color: Colors.grey),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            'Make sure your name, photo, and ID number are clearly visible.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildAcceptedIdsInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Accepted IDs:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'PhilID/ePhilID, Driver\'s License, UMID, PRC ID, and other government-issued IDs.',
          style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildPrivacyBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your Information is protected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Your identity information will only be used for verification and request processing.',
                  style: TextStyle(color: Colors.black54, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    RequestIdVerificationProvider provider,
    BuildContext context,
  ) {
    final bool canProceed = provider.isFaceVerified && provider.canSubmitId;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: canProceed ? () => _onContinuePressed(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC62828),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          !provider.isFaceVerified
              ? 'Face Verify First'
              : provider.verificationStatus == 'pending'
              ? 'Verification Pending'
              : provider.isAccountFullyVerified
              ? 'Verified'
              : 'Continue',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
