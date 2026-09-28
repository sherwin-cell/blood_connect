import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PrcChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;

  const PrcChatRoomScreen({
    super.key,
    required this.chatId,
    this.otherUserName = 'PRC Support',
  });

  @override
  State<PrcChatRoomScreen> createState() => _PrcChatRoomScreenState();
}

class _PrcChatRoomScreenState extends State<PrcChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  bool _isInitialized = false;

  // List of predicted quick-action questions
  final List<String> _predictedQuestions = [
    'How do I renew my PRC license?',
    'How to register on LERIS?',
    'What are the exam requirements?',
    'How to replace a lost PRC ID?',
  ];

  @override
  void initState() {
    super.initState();
    _checkAndSendInitialGreeting();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// Automatically sends the initial greeting message if the chat is completely new/empty
  Future<void> _checkAndSendInitialGreeting() async {
    if (currentUser == null || _isInitialized) return;

    try {
      final messagesRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages');

      final snapshot = await messagesRef.limit(1).get();

      if (snapshot.docs.isEmpty && !_isInitialized) {
        _isInitialized = true;
        final userName = currentUser!.displayName ?? 'User';
        final welcomeMessage = 'Hi $userName, what can we help you today?';

        // 1. Add welcome message from support admin
        await messagesRef.add({
          'senderId': 'prc_support_admin',
          'message': welcomeMessage,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Update chat metadata preview document
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
            .set({
              'chatId': widget.chatId,
              'lastMessage': 'Admin: $welcomeMessage',
              'lastMessageTime': FieldValue.serverTimestamp(),
              'userId': currentUser!.uid,
              'userName': userName,
              'isPrcSupport': true,
              'participants': [currentUser!.uid, 'prc_support_admin'],
              'participantNames': {
                currentUser!.uid: userName,
                'prc_support_admin': 'PRC Support',
              },
            }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error sending initial chat greeting: $e');
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    if (presetText == null) {
      _messageController.clear();
    }

    try {
      // 1. Add user message to subcollection 'messages'
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
            'senderId': currentUser!.uid,
            'message': text,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 2. Update the chat document preview for admin lists
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .set({
            'chatId': widget.chatId,
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'userId': currentUser!.uid,
            'userName': currentUser!.displayName ?? 'Anonymous User',
            'isPrcSupport': true,
            'participants': [currentUser!.uid, 'prc_support_admin'],
            'participantNames': {
              currentUser!.uid: currentUser!.displayName ?? 'User',
              'prc_support_admin': 'PRC Support',
            },
          }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
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
          // Message List Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryRed,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading chat: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true, // Show newest messages at the bottom
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final senderId = data['senderId'] ?? '';
                    final message = data['message'] ?? '';
                    final isMe = senderId == currentUser?.uid;
                    final bool isBotOrAdmin =
                        senderId == 'prc_support_admin' ||
                        senderId == 'prc_bot_support';

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primaryRed
                              : (isBotOrAdmin
                                    ? Colors.grey.shade200
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                            bottomLeft: !isMe
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick-Action Predicted Questions Bar (Shows above text input)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _predictedQuestions.map((question) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(question),
                      backgroundColor: Colors.red.shade50,
                      labelStyle: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      onPressed: () => _sendMessage(question),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message or follow-up...',
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
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primaryRed,
                  child: IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
