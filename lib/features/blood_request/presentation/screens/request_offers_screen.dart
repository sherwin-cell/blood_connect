import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/statuses.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/blood_request_repository.dart';

/// Shows the requester the donor offers on one of their blood requests.
///
/// PRC confirms or declines offers from the admin app; this screen is
/// read-only. A donor's contact number is shown only after PRC confirms
/// the match.
class RequestOffersScreen extends StatelessWidget {
  final String requestId;
  final String title;

  RequestOffersScreen({
    super.key,
    required this.requestId,
    required this.title,
    BloodRequestRepository? repository,
  }) : _repository = repository ?? BloodRequestRepository();

  final BloodRequestRepository _repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _repository.streamOffers(requestId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load offers: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoBanner(),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const _EmptyOffers()
              else
                ...docs.map((doc) => _OfferCard(data: doc.data())),
            ],
          );
        },
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'PRC reviews each offer and confirms the donor match. '
              'Contact details appear once a donor is confirmed.',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Text(
            'No donation offers received yet.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final donorName = (data['donorName'] ?? 'Anonymous Donor').toString();
    final donorBloodType = (data['donorBloodType'] ?? 'N/A').toString();
    final donorContact = (data['donorContact'] ?? '').toString();
    final status = (data['status'] ?? OfferStatus.pending).toString();
    final confirmed = OfferStatus.isConfirmed(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  donorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  donorBloodType,
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OfferStatusChip(status: status),
          if (confirmed && donorContact.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  donorContact,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Colored label for an offer status. Shared by the requester and donor views.
class OfferStatusChip extends StatelessWidget {
  const OfferStatusChip({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status?.trim().toLowerCase()) {
      OfferStatus.approved || OfferStatus.legacyAccepted => Colors.green,
      OfferStatus.donated => Colors.teal,
      OfferStatus.rejected || OfferStatus.withdrawn => Colors.grey,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        OfferStatus.label(status),
        style: TextStyle(
          color: color.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
