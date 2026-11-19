import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/request_id_verification_data.dart';
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

  final ImagePicker _picker = ImagePicker();
  String? _selectedIdType;
  File? _frontIdImage;
  File? _backIdImage;
  bool _preparing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestIdVerificationProvider>().loadVerificationStatus();
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickBothImagesFromGallery() async {
    if (!context.read<RequestIdVerificationProvider>().canSubmitId) return;
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 85);
      if (!mounted) return;
      if (pickedFiles.isEmpty) return;
      if (pickedFiles.length != 2) {
        _message('Please select exactly two photos: front first, then back.');
        return;
      }
      setState(() {
        _frontIdImage = File(pickedFiles[0].path);
        _backIdImage = File(pickedFiles[1].path);
      });
    } catch (error) {
      if (!mounted) return;
      _message('Unable to select ID images: $error');
    }
  }

  Future<void> _openCameraCapture() async {
    final provider = context.read<RequestIdVerificationProvider>();
    if (!provider.canSubmitId || _preparing) return;
    if (_selectedIdType == null) {
      _message('Please select a valid ID type first.');
      return;
    }

    setState(() => _preparing = true);
    try {
      await provider.selectIdTypeAndSaveProfile(_selectedIdType!);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final result = await navigator.push<RequestIdVerificationData>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const CaptureIdScreen(),
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) navigator.pop<RequestIdVerificationData>(result);
    } catch (error) {
      if (!mounted) return;
      _message('Unable to open ID camera: $error');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _showImageSourceActionSheet() {
    if (!context.read<RequestIdVerificationProvider>().canSubmitId ||
        _preparing) {
      return;
    }
    if (_selectedIdType == null) {
      _message('Please select a valid ID type first.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFC62828)),
              title: const Text('Take Photos via Camera (Front & Back)'),
              onTap: () {
                Navigator.of(sheetContext).pop();
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
                Navigator.of(sheetContext).pop();
                _pickBothImagesFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onContinuePressed() async {
    final provider = context.read<RequestIdVerificationProvider>();
    if (_preparing) return;
    if (!provider.isFaceVerified) {
      _message('Please complete face verification before submitting an ID.');
      return;
    }
    if (!provider.canSubmitId) {
      _message(
        provider.hasSubmittedId
            ? 'Your ID has already been submitted.'
            : 'ID submission is unavailable. Please try again.',
      );
      return;
    }
    if (_selectedIdType == null) {
      _message('Please select a valid ID type.');
      return;
    }
    if (_frontIdImage == null || _backIdImage == null) {
      _message('Please attach both front and back ID images.');
      return;
    }

    setState(() => _preparing = true);
    try {
      await provider.selectIdTypeAndSaveProfile(_selectedIdType!);
      await provider.processIdCard(_frontIdImage!);
      await provider.processBackIdCard(_backIdImage!);
      if (!mounted) return;
      if (provider.errorMessage != null) {
        _message(provider.errorMessage!);
        return;
      }
      final navigator = Navigator.of(context);
      final result = await navigator.push<RequestIdVerificationData>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const ReviewIdScreen(),
          ),
        ),
      );
      if (!mounted) return;
      if (result != null) navigator.pop<RequestIdVerificationData>(result);
    } catch (error) {
      if (!mounted) return;
      _message('Unable to review ID images: $error');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestIdVerificationProvider>();
    final submitted = provider.hasSubmittedId;
    final canEdit = provider.canSubmitId && !_preparing;
    final busy = provider.isLoading || _preparing;

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
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: busy && provider.verificationStatus == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.errorMessage != null)
                      _statusBanner(provider.errorMessage!, Colors.red),
                    if (submitted)
                      _statusBanner(
                        'ID Already Submitted. Your saved ID can be reused for future donor applications and blood requests. No new upload is needed.',
                        Colors.green,
                      )
                    else if (!provider.isFaceVerified)
                      _statusBanner(
                        'Face Verification Required: Complete face verification before submitting an ID.',
                        Colors.red,
                      ),
                    if (!submitted) ...[
                      _headerCard(),
                      const SizedBox(height: 20),
                      const Text(
                        'Government-Issued ID *',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select the type of ID you will upload.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 10),
                      _dropdown(canEdit),
                      const SizedBox(height: 12),
                      _uploadCard(canEdit),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(
                            Icons.security_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Make sure your name, photo and ID number are clearly visible.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Accepted IDs:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PhilID/ePhilID, Driver\'s License, UMID, PRC ID, and other government-issued photo IDs.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                      const SizedBox(height: 20),
                      _privacyNote(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: canEdit && !busy
                              ? _onContinuePressed
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            busy
                                ? 'Please wait...'
                                : !provider.isFaceVerified
                                ? 'Face Verify First'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ] else
                      const Text(
                        'Your ID submission is saved. Return to the donor or blood request form to continue.',
                        style: TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statusBanner(String text, MaterialColor color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        border: Border.all(color: color.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color.shade900)),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.badge_outlined, color: Color(0xFFC62828), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One-Time ID Submission',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Submit your government-issued ID once. A saved submission does not mean the ID has been authenticated or approved.',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedIdType,
          isExpanded: true,
          hint: const Text('Select ID Type'),
          items: _acceptedIds
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.title,
                  child: Row(
                    children: [
                      Icon(item.icon, color: const Color(0xFFC62828), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (value) => setState(() => _selectedIdType = value)
              : null,
        ),
      ),
    );
  }

  Widget _uploadCard(bool enabled) {
    final hasBoth = _frontIdImage != null && _backIdImage != null;
    return InkWell(
      onTap: enabled ? _showImageSourceActionSheet : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasBoth ? Colors.green.shade300 : Colors.red.shade200,
          ),
        ),
        child: hasBoth
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _frontIdImage!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _backIdImage!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Front & Back Attached',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              )
            : const Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    color: Color(0xFFC62828),
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Upload Front and Back ID Photos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to capture with camera or choose from gallery',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _privacyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your ID images are sensitive personal information. They should be accessible only to authorized users for the intended purpose.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
