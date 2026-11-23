import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/statuses.dart';
import '../../../blood_request/presentation/screens/request_offers_screen.dart';
import '../../../chat/presentation/screens/match_chat_screen.dart';
import '../../../donor/data/repositories/donor_repository_impl.dart';
import 'activity_helpers.dart';

/// The donor's own offers across all blood requests, with a Withdraw
/// action while PRC has not completed them. Renders nothing when the user
/// has made no offers.
class MyOffersSection extends StatefulWidget {
  const MyOffersSection({
    super.key,
    required this.donorId,
    this.showWhenEmpty = false,
  });

  final String donorId;

  /// Show an empty-state message instead of hiding the section.
  final bool showWhenEmpty;

  @override
  State<MyOffersSection> createState() => _MyOffersSectionState();
}

class _MyOffersSectionState extends State<MyOffersSection> {
  final _repository = DonorRepositoryImpl();
  late Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _offers;

  @override
  void initState() {
    super.initState();
    _offers = _repository.streamMyOffers(widget.donorId);
  }

  @override
  void didUpdateWidget(MyOffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.donorId != widget.donorId) {
      _offers = _repository.streamMyOffers(widget.donorId);
    }
  }

  Future<void> _withdraw(
    QueryDocumentSnapshot<Map<String, dynamic>> offer,
  ) async {
    final confirmed = await confirmActivityAction(
      context,
      title: 'Withdraw this offer?',
      message:
          'PRC will see that you are no longer available for this request.',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed || !mounted) return;

    final requestId =
        offer.data()['requestId'] as String? ??
        offer.reference.parent.parent!.id;

    Object? error;
    try {
      await _repository.withdrawOffer(requestId: requestId, offerId: offer.id);
    } catch (e) {
      error = e;
    }
    if (mounted) {
      showActivityResult(context, error, 'Your offer was withdrawn.');
    }
  }

  void _openChat(QueryDocumentSnapshot<Map<String, dynamic>> offer) {
    final requestId =
        offer.data()['requestId'] as String? ??
        offer.reference.parent.parent!.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchChatScreen(
          chatId: matchChatId(requestId, offer.id),
          title: 'Requester',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _offers,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('My offers failed to load: ${snapshot.error}');
        }
        final offers = snapshot.data ?? const [];
        if (offers.isEmpty) {
          if (!widget.showWhenEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Loading your offers...'
                    : 'You have not offered to donate yet.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'My donation offers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...offers.map(_buildOffer),
          ],
        );
      },
    );
  }

  Widget _buildOffer(QueryDocumentSnapshot<Map<String, dynamic>> offer) {
    final data = offer.data();
    final status = data['status'] as String?;
    final neededBy = formatActivityDate(data['neededByDate']);
    final details = [
      if (data['component'] != null) data['component'].toString(),
      if (data['hospitalName'] != null) data['hospitalName'].toString(),
      if (neededBy != null) 'Needed by $neededBy',
    ].join(' · ');
    final bloodType =
        data['requestBloodType'] ?? data['donorBloodType'] ?? 'blood';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Offer for $bloodType request'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty) Text(details),
            const SizedBox(height: 4),
            OfferStatusChip(status: status),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // PRC confirmed this donor: the backend opened a chat with
            // the requester.
            if (OfferStatus.isConfirmed(status))
              TextButton.icon(
                onPressed: () => _openChat(offer),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chat'),
              ),
            if (OfferStatus.isActive(status))
              TextButton(
                onPressed: () => _withdraw(offer),
                child: const Text('Withdraw'),
              ),
          ],
        ),
      ),
    );
  }
}
