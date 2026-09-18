import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../donor/data/repositories/donor_repository_impl.dart';

class BloodRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const BloodRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.requestData,
  });

  @override
  State<BloodRequestDetailScreen> createState() =>
      _BloodRequestDetailScreenState();
}

class _BloodRequestDetailScreenState extends State<BloodRequestDetailScreen> {
  final DonorRepositoryImpl _donorRepository = DonorRepositoryImpl();
  bool _isApplying = false;

  void _showEligibilityModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Medical Eligibility Notice', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'Please note that offering to donate does not guarantee medical eligibility. '
          'You will undergo a standard medical screening at the designated blood donation center '
          'before the actual donation procedure can proceed.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              _confirmAndSubmitOffer();
            },
            child: const Text(
              'I Understand & Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndSubmitOffer() async {
    setState(() => _isApplying = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Fetch donor profile to verify approved status and grab credentials
      final donorDoc = await FirebaseFirestore.instance
          .collection('donors')
          .doc(user.uid)
          .get();

      if (!donorDoc.exists || donorDoc.data()?['donorStatus'] != 'approved') {
        throw Exception(
          'You must be an approved donor by the PRC to make an offer.',
        );
      }

      final donorData = donorDoc.data()!;
      final donorName =
          donorData['fullName'] ?? donorData['name'] ?? 'Unknown Donor';
      final donorContact = donorData['contact'] ?? donorData['phone'] ?? 'N/A';
      final donorBloodType = donorData['bloodType'] ?? 'O+';

      // Submit offer into nested subcollection using repository (includes duplicate check)
      await _donorRepository.offerToDonate(
        requestId: widget.requestId,
        donorId: user.uid,
        donorName: donorName,
        donorContact: donorContact,
        donorBloodType: donorBloodType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offer sent successfully! Waiting for PRC/Admin confirmation.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.requestData;
    final bloodType = data['bloodType'] ?? 'O+';
    final hospital =
        data['hospitalLocation'] ?? data['hospital'] ?? 'Unknown Hospital';
    final units = data['unitsRequired'] ?? 1;
    final contact = data['contactNumber'] ?? 'N/A';
    final notes = data['notes'] ?? 'No additional notes provided.';
    final status = data['status'] ?? 'active';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Blood Request Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Required Blood Type',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bloodType,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.local_hospital_rounded,
                    'Hospital / Location',
                    hospital,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    Icons.water_drop_rounded,
                    'Units Required',
                    '$units Unit(s)',
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    Icons.phone_rounded,
                    'Contact Number',
                    contact,
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    Icons.note_rounded,
                    'Additional Notes',
                    notes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _showEligibilityModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isApplying
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Offer to Help',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryRed, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
