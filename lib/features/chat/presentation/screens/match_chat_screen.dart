import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Id of the requester-donor chat for one PRC-confirmed offer. The backend
/// (notifications/match_chat.py) creates it when PRC confirms the donor;
/// the app can only open it.
String matchChatId(String requestId, String offerId) =>
    'match_${requestId}_$offerId';

bool isMatchChat(String chatId) => chatId.startsWith('match_');

/// Chat between a requester and a donor PRC confirmed for their request.
class MatchChatScreen extends StatefulWidget {
  const MatchChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.userId,
    this.messages,
    this.send,
  });

  final String chatId;
  final String title;

  /// Test hooks; default to Firebase.
  final String? userId;
  final Stream<List<Map<String, dynamic>>>? messages;
  final Future<void> Function(String text)? send;

  @override
  State<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends State<MatchChatScreen> {
  final _controller = TextEditingController();
  late final String? _uid =
      widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _chat =>
      FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

  late final Stream<List<Map<String, dynamic>>> _messages =
      widget.messages ??
      _chat
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => [for (final d in s.docs) d.data()]);

  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _defaultSend(String text) async {
    await _chat.collection('messages').add({
      'senderId': _uid,
      'message': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _chat.update({
      'lastMessage': text,
      'lastSenderId': _uid,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await (widget.send ?? _defaultSend)(text);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message not sent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryRed,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFDECEC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'PRC confirmed this match. Coordinate the donation here; PRC '
              'staff can see this chat.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'This chat opens once PRC confirms the donor.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final messages = snapshot.data ?? const [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m['senderId'] == _uid;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primaryRed : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${m['message'] ?? ''}',
                          style: TextStyle(
                            color: mine ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primaryRed,
                    child: IconButton(
                      tooltip: 'Send',
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
