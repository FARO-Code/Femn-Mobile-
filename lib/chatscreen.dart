import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;


// --- UPDATED CHAT SCREEN WITH READ RECEIPTS ---
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserProfileImage;

  const ChatScreen({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserProfileImage,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String currentUserId;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    // Prevent concurrent calls
    if (_isMarkingRead) return;
    _isMarkingRead = true;

    try {
      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      final unreadQuery = await chatDocRef
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .where('read', isEqualTo: false)
          .get();

      if (unreadQuery.docs.isEmpty) {
        _isMarkingRead = false;
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }

      // Reset unread count for current user in chat doc; merge so doc can be created/merged safely
      batch.set(chatDocRef, {
        'unreadCount': {currentUserId: 0}
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    final messagesRef = chatRef.collection('messages');

    final messageData = {
      'senderId': currentUserId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    try {
      await messagesRef.add(messageData);

      await chatRef.set({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        // increment unread for the other user
        'unreadCount': {widget.otherUserId: FieldValue.increment(1)},
      }, SetOptions(merge: true));

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending message: $e");
      // Optionally show snack or handle error UI
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageBubble(String text, DateTime timestamp, bool isMe,
      {bool isRead = false, bool isLastMessage = false}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.secondary : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeago.format(timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe && isLastMessage) const SizedBox(width: 6),
                if (isMe && isLastMessage)
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead ? Colors.blue : Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatMessagesStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUserProfileImage.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserProfileImage)
                  : const AssetImage('assets/femnlogo.png') as ImageProvider,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final map = snapshot.data!.data() as Map<String, dynamic>?;
                        final bool isOnline = (map?['isOnline'] ?? false) as bool;
                        return Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(fontSize: 12, color: isOnline ? Colors.green : Colors.grey),
                        );
                      } else {
                        return const Text(
                          'Offline',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatMessagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                // Check for unread messages from the other user and mark them as read (once per frame)
                int unreadFromOther = 0;
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) continue;
                  if (data['senderId'] == widget.otherUserId && (data['read'] ?? true) == false) {
                    unreadFromOther++;
                  }
                }
                if (unreadFromOther > 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markMessagesAsRead();
                  });
                }

                // scroll to bottom after frame
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final text = data['text'] as String? ?? '';
                    final ts = data['timestamp'];
                    final timestamp = ts is Timestamp ? ts.toDate() : DateTime.now();
                    final senderId = data['senderId'] as String? ?? '';
                    final isMe = senderId == currentUserId;
                    final isRead = data['read'] as bool? ?? false;
                    final isLastMessage = index == docs.length - 1;

                    return _buildMessageBubble(
                      text,
                      timestamp,
                      isMe,
                      isRead: isRead,
                      isLastMessage: isMe && isLastMessage,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}

// New Chat Screen
class NewChatScreen extends StatefulWidget {
  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _searchResults = [];

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: query + 'z')
        .get();
    setState(() {
      _searchResults = result.docs
          .where((doc) => doc['uid'] != FirebaseAuth.instance.currentUser!.uid)
          .toList();
    });
  }

 void _startChat(String otherUserId, String otherUserName,
     String otherUserProfileImage) async {
   final currentUserId = FirebaseAuth.instance.currentUser!.uid;
   // Check if chat already exists
   final existingChat = await FirebaseFirestore.instance
       .collection('chats')
       .where('participants', arrayContains: currentUserId)
       .get();
   // Find existing chat with the other user
   QueryDocumentSnapshot<Map<String, dynamic>>? existingChatDoc;
   for (var doc in existingChat.docs) {
     if (List.from(doc['participants']).contains(otherUserId)) {
       existingChatDoc = doc;
       break;
     }
   }
   String chatId;
   if (existingChatDoc != null) {
     chatId = existingChatDoc.id;
   } else {
    final newChat = await FirebaseFirestore.instance.collection('chats').add({
      'participants': [currentUserId, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(), // Use server timestamp
      'createdAt': FieldValue.serverTimestamp(),
      // Initialize unread counts for both participants
      'unreadCount': {
         currentUserId: 0, // Current user starts with 0 unread in this new chat
         otherUserId: 0,   // Other user also starts with 0
       }
    });
    chatId = newChat.id;
   }
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserProfileImage: otherUserProfileImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New Message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                var user = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['profileImage'].isNotEmpty
                        ? CachedNetworkImageProvider(user['profileImage'])
                        : AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  title: Text(user['username']),
                  subtitle: Text(user['fullName']),
                  onTap: () => _startChat(
                    user['uid'],
                    user['username'],
                    user['profileImage'],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
