import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/statuses.dart';
import '../../../blood_request/domain/request_progress.dart';
import '../../../blood_request/presentation/widgets/request_progress_widgets.dart';
import '../../../chat/presentation/screens/match_chat_screen.dart';

/// Matching Center > Matched Donors: the donors PRC confirmed for the
/// user's in-progress blood requests.
///
/// There is no donor directory: donors offer on a request, PRC confirms
/// one (Item 5), and only then does the requester see the donor's name and
/// contact and get a chat (created by the backend). Offers still waiting
/// for PRC are shown as a count only.
class MatchedDonorsScreen extends StatefulWidget {
  const MatchedDonorsScreen({
    super.key,
    this.userId,
    this.requests,
    this.offersFor,
    this.openChat,
  });

  /// Test hooks; default to the signed-in user and Firestore.
  final String? userId;
  final Stream<List<MapEntry<String, Map<String, dynamic>>>>? requests;
  final Stream<List<MapEntry<String, Map<String, dynamic>>>> Function(
    String requestId,
  )?
  offersFor;
  final void Function(BuildContext context, String chatId, String title)?
  openChat;

  @override
  State<MatchedDonorsScreen> createState() => _MatchedDonorsScreenState();
}

class _MatchedDonorsScreenState extends State<MatchedDonorsScreen> {
  late final String? _uid =
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  late final Stream<List<MapEntry<String, Map<String, dynamic>>>>? _requests =
      widget.requests ??
      (_uid == null
          ? null
          : FirebaseFirestore.instance
                .collection('blood_requests')
                .where('userId', isEqualTo: _uid)
                .snapshots()
                .map(
                  (s) => [for (final d in s.docs) MapEntry(d.id, d.data())],
                ));

  final Map<String, Stream<List<MapEntry<String, Map<String, dynamic>>>>>
  _offers = {};

  Stream<List<MapEntry<String, Map<String, dynamic>>>> _offersFor(
    String requestId,
  ) => _offers.putIfAbsent(
    requestId,
    () =>
        widget.offersFor?.call(requestId) ??
        FirebaseFirestore.instance
            .collection('blood_requests')
            .doc(requestId)
            .collection('offers')
            .snapshots()
            .map((s) => [for (final d in s.docs) MapEntry(d.id, d.data())]),
  );

  void _chat(String chatId, String title) {
    final open = widget.openChat;
    if (open != null) return open(context, chatId, title);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchChatScreen(chatId: chatId, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          'Matched Donors',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _requests == null
          ? const Center(child: Text('Please sign in to see matched donors.'))
          : StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
              stream: _requests,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your blood requests.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: requestRed),
                  );
                }
                final requests = [
                  for (final doc in snapshot.data!)
                    if (RequestStatus.isInProgress(
                      doc.value['status']?.toString(),
                    ))
                      RequestProgress.fromFirestore(doc.key, doc.value),
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    const _Explainer(),
                    const SizedBox(height: 16),
                    if (requests.isEmpty)
                      const _Empty()
                    else
                      for (final p in requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _RequestMatches(
                            progress: p,
                            offers: p.hasOffersStage ? _offersFor(p.id) : null,
                            onChat: _chat,
                          ),
                        ),
                  ],
                );
              },
            ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: requestSoftRed,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, color: requestRed),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Donors with your blood type are alerted when PRC approves your '
            'request. PRC screens each donor who offers; once PRC confirms '
            'one, their contact details and a chat appear here.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(Icons.people_outline, size: 56, color: Colors.black26),
        SizedBox(height: 10),
        Text(
          'No active blood request',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          'Matched donors appear here for requests PRC is working on.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      ],
    ),
  );
}

class _RequestMatches extends StatelessWidget {
  const _RequestMatches({
    required this.progress,
    required this.offers,
    required this.onChat,
  });

  final RequestProgress progress;
  final Stream<List<MapEntry<String, Map<String, dynamic>>>>? offers;
  final void Function(String chatId, String title) onChat;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final notified = p.data['matchingDonorsNotified'];
    return RequestCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BloodTypeBadge(p.bloodType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.reference,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      p.hospital,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              RequestStatusChip(p),
            ],
          ),
          const Divider(height: 24),
          if (offers == null)
            const Text(
              'PRC is still reviewing this request. Donors are alerted once '
              'it is approved.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else ...[
            if (notified is num && notified > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${notified.toInt()} matching '
                  '${notified == 1 ? 'donor was' : 'donors were'} alerted.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
            StreamBuilder<List<MapEntry<String, Map<String, dynamic>>>>(
              stream: offers,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Could not load donor offers.');
                }
                final all = snapshot.data ?? const [];
                final confirmed = [
                  for (final o in all)
                    if (OfferStatus.isConfirmed(o.value['status']?.toString()))
                      o,
                ];
                final waiting = all
                    .where((o) => o.value['status'] == OfferStatus.pending)
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (confirmed.isEmpty)
                      Text(
                        snapshot.hasData
                            ? 'No donor confirmed by PRC yet.'
                            : 'Loading donors...',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    else
                      for (final o in confirmed)
                        _ConfirmedDonor(
                          requestId: p.id,
                          offerId: o.key,
                          offer: o.value,
                          onChat: onChat,
                        ),
                    if (waiting > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$waiting ${waiting == 1 ? 'offer' : 'offers'} '
                          'waiting for PRC review.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmedDonor extends StatelessWidget {
  const _ConfirmedDonor({
    required this.requestId,
    required this.offerId,
    required this.offer,
    required this.onChat,
  });

  final String requestId;
  final String offerId;
  final Map<String, dynamic> offer;
  final void Function(String chatId, String title) onChat;

  @override
  Widget build(BuildContext context) {
    final name = (offer['donorName'] ?? 'Donor').toString();
    final contact = (offer['donorContact'] ?? '').toString().trim();
    final hasContact = contact.isNotEmpty && contact != 'N/A';
    final donated = offer['status'] == OfferStatus.donated;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                donated ? 'Donated' : 'Confirmed by PRC',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Blood type ${offer['donorBloodType'] ?? '—'}'
            '${hasContact ? ' · $contact' : ''}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (hasContact)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: contact)),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call'),
                ),
              if (hasContact) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => onChat(matchChatId(requestId, offerId), name),
                style: FilledButton.styleFrom(backgroundColor: requestRed),
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
