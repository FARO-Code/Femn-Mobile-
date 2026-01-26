import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// Internal App Imports
import 'package:femn/hub_screens/chatscreen.dart';
import 'package:femn/hub_screens/story.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/hub_screens/notifications.dart';

// Assuming NewChatScreen is imported or defined in your project structure

class MessagingScreen extends StatefulWidget {
  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // --- Selection & Action State ---
  bool _isSelectionMode = false;
  Set<String> _selectedChatIds = {};

  // --- Actions ---

  Future<void> _togglePinChat(String chatId, bool currentPinned) async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    final pinnedMap = Map<String, dynamic>.from(
      chatDoc.data()?['pinned'] ?? {},
    );

    if (!currentPinned) {
      // Check limit of 3
      int myPinnedCount = 0;
      // We can't easily check global count without query,
      // but for now let's just check the ones we loaded or do a small query.
      // Better: Just check the map in the doc? No, that's this chat.
      // Let's do a query for my pinned chats.
      final myPinnedQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .where('pinned.$currentUserId', isEqualTo: true)
          .get();

      if (myPinnedQuery.docs.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can only pin up to 3 chats.")),
        );
        return;
      }
    }

    pinnedMap[currentUserId] = !currentPinned;
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'pinned': pinnedMap,
      'pinnedAt.$currentUserId': Timestamp.now(),
    });
  }

  Future<void> _toggleArchiveChat(String chatId, bool currentArchived) async {
    // Check if therapy chat (Restriction)
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    if (chatDoc.data()?['type'] == 'therapy') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Therapy chats cannot be archived.")),
      );
      return;
    }

    final archivedMap = Map<String, dynamic>.from(
      chatDoc.data()?['archived'] ?? {},
    );
    archivedMap[currentUserId] = !currentArchived;
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'archived': archivedMap,
    });
  }

  Future<void> _deleteChat(String chatId) async {
    // Check if therapy chat
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    if (chatDoc.data()?['type'] == 'therapy') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Therapy chats cannot be deleted.")),
      );
      return;
    }

    // Soft delete for this user: set deletedAt
    final deletedAtMap = Map<String, dynamic>.from(
      chatDoc.data()?['deletedAt'] ?? {},
    );
    deletedAtMap[currentUserId] = Timestamp.now();

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'deletedAt': deletedAtMap,
    });
  }

  Future<void> _muteChat(String chatId) async {
    // Simple toggle for now, or 8 hours default
    // In real app, show dialog for duration.
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    final mutedMap = Map<String, dynamic>.from(
      chatDoc.data()?['mutedUntil'] ?? {},
    );

    // Toggle: if muted, unmute. If not, mute for 8 hours.
    final currentMute = mutedMap[currentUserId] as Timestamp?;
    final isMuted =
        currentMute != null && currentMute.toDate().isAfter(DateTime.now());

    if (isMuted) {
      mutedMap.remove(currentUserId);
    } else {
      mutedMap[currentUserId] = Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 8)),
      );
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'mutedUntil': mutedMap,
    });
  }

  Future<void> _markReadUnread(String chatId, bool markAsRead) async {
    // This affects the "dot".
    // We already have unreadCount logic.
    // "Mark as Unread" usually just adds a dot locally or sets unreadCount to 1 if 0.
    // "Mark as Read" sets unreadCount to 0.

    // For manual "Mark as Unread", let's use a separate flag 'markedUnread' or just manipulate unreadCount.
    // Manipulating unreadCount is cleaner for existing logic.

    if (markAsRead) {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount.$currentUserId': 0,
      });
    } else {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'unreadCount.$currentUserId': 1, // Artificial unread
      });
    }
  }

  Future<void> _lockChat(String chatId) async {
    final chatDoc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .get();
    final lockedMap = Map<String, dynamic>.from(
      chatDoc.data()?['locked'] ?? {},
    );

    final isLocked = lockedMap[currentUserId] == true;
    lockedMap[currentUserId] = !isLocked;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'locked': lockedMap,
    });
  }

  // --- Bulk Actions ---
  void _performBulkAction(String action) async {
    for (String chatId in _selectedChatIds) {
      switch (action) {
        case 'pin':
          await _togglePinChat(chatId, false);
          break;
        case 'archive':
          await _toggleArchiveChat(chatId, false); // Archive it
          break;
        case 'delete':
          await _deleteChat(chatId);
          break;
        case 'mute':
          await _muteChat(chatId);
          break;
        case 'read':
          await _markReadUnread(chatId, true);
          break;
        case 'unread':
          await _markReadUnread(chatId, false);
          break;
        case 'lock':
          await _lockChat(chatId);
          break;
      }
    }

    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  @override
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Deep background
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),

      body: Column(
        children: [
          // Stories header row (Hide in selection mode? Optional. Let's keep it.)
           _buildStoriesHeader(),
           const SizedBox(height: 12),

          // Subtle divider
           Container(
              height: 1,
              color: AppColors.elevation, // Dark divider
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),

          // Messages list
          Expanded(child: _buildMessagesList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: Icon(Icons.close, color: AppColors.textHigh),
        onPressed: () {
          setState(() {
            _isSelectionMode = false;
            _selectedChatIds.clear();
          });
        },
      ),
      title: Text(
        '${_selectedChatIds.length} Selected',
        style: TextStyle(color: AppColors.textHigh),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.push_pin_outlined, color: AppColors.textHigh),
          onPressed: () => _performBulkAction('pin'),
          tooltip: 'Pin',
        ),
        IconButton(
          icon: Icon(Feather.archive, color: AppColors.textHigh),
          onPressed: () => _performBulkAction('archive'),
        ),
        IconButton(
          icon: Icon(Feather.trash_2, color: AppColors.error),
          onPressed: () => _performBulkAction('delete'),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textHigh),
          onSelected: (value) => _performBulkAction(value),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'lock', child: Text('Lock Chat')),
            PopupMenuItem(value: 'mute', child: Text('Mute/Unmute')),
            PopupMenuItem(value: 'read', child: Text('Mark as Read')),
            PopupMenuItem(value: 'unread', child: Text('Mark as Unread')),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
      return AppBar(
        // ... (existing params)
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // FEMN Logo
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.elevation, // Dark container
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/default_avatar.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Screen Title
          Text(
            'Inbox',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
        ],
      ),
      // AppBar actions
      actions: [
        // Camera Button
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.elevation,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Feather.camera,
              color: AppColors.primaryLavender,
              size: 22,
            ),
            onPressed: () => _showStoryCreationModal(context),
          ),
        ),
        const SizedBox(width: 8),

        // New Chat Button
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.elevation,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Feather.message_circle,
              color: AppColors.primaryLavender,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NewChatScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // User Profile
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get(),
          builder: (context, snapshot) {
            Widget avatar;
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              avatar = Image.asset(
                'assets/default_avatar.png',
                fit: BoxFit.cover,
              );
            } else {
              final user = snapshot.data!;
              final profileImage = user['profileImage'] ?? '';
              avatar = profileImage.isNotEmpty
                  ? Image(
                      image: CachedNetworkImageProvider(profileImage),
                      fit: BoxFit.cover,
                    )
                  : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
            }

            return GestureDetector(
              onTap: () => _showProfileMenu(context),
              child: Container(
                width: 42,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(child: avatar),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _showProfileMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }

  Widget _buildStoriesHeader() {
    return SizedBox(
      height: 100,
      child: FutureBuilder<List<String>>(
        future: _getFollowedUserIds(),
        builder: (context, followedUsersSnapshot) {
          if (!followedUsersSnapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            );
          }

          final followedUserIds = followedUsersSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stories')
                .where('userId', whereIn: followedUserIds)
                .where('expiresAt', isGreaterThan: DateTime.now())
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLavender,
                  ),
                );
              }

              // Group stories by user
              final Map<String, DocumentSnapshot> userStories = {};
              for (var doc in snapshot.data!.docs) {
                final userId = doc['userId'];
                if (!userStories.containsKey(userId)) {
                  userStories[userId] = doc;
                }
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: userStories.length + 1, // +1 for "Add Story" button
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAddStoryButton(context);
                  }

                  final userId = userStories.keys.elementAt(index - 1);
                  final story = userStories[userId]!;
                  final isSeen = List.from(
                    story['viewers'],
                  ).contains(currentUserId);

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return SizedBox.shrink();
                      }

                      final user = userSnapshot.data!;
                      return _buildStoryCircle(
                        user['username'],
                        user['profileImage'],
                        isSeen: isSeen,
                        onTap: () => _viewStory(
                          userId,
                          user['username'],
                          user['profileImage'],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showStoryCreationModal(context),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevation, // Dark circle
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Feather.plus,
                  size: 30,
                  color: AppColors.primaryLavender,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryLavender,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCircle(
    String username,
    String profileImage, {
    bool isSeen = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 64,
              height: 64,
              padding: EdgeInsets.all(2), // Padding for the ring
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Teal for unseen, Disabled for seen
                  color: isSeen
                      ? AppColors.textDisabled
                      : AppColors.secondaryTeal,
                  width: 2,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation, // Background behind image
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots(), // Client side sort/filter for complexity reasons
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryLavender),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No messages yet',
              style: TextStyle(color: AppColors.textMedium),
            ),
          );
        }

        final docs = snapshot.data!.docs;
        List<DocumentSnapshot> filteredDocs = [];
        List<DocumentSnapshot> pinnedDocs = [];

        bool hasArchivedChat = false;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Check Deleted
          final deletedMap = data['deletedAt'] as Map<String, dynamic>?;
          final deletedAtTimestamp = deletedMap?[currentUserId];
          // If deleted, filter out messages before that time??
          // Complex. For now, if 'deletedAt' exists and is AFTER lastMessageTime, don't show chat?
          // Simplification: "Delete" just hides the chat until a new message comes.
          // If deletedAt > lastMessageTime, hide.

          final lastMessageTime = (data['lastMessageTime'] as Timestamp?)
              ?.toDate();
          if (deletedAtTimestamp != null && lastMessageTime != null) {
            final delTime = (deletedAtTimestamp as Timestamp).toDate();
            if (delTime.isAfter(lastMessageTime)) {
              continue; // Skip this chat (it's deleted and no new activity)
            }
          }

          // Check Archived
          final archivedMap = data['archived'] as Map<String, dynamic>?;
          final isArchived = archivedMap?[currentUserId] == true;
          if (isArchived) {
            hasArchivedChat = true;
            continue; // Don't show in main list
          }

          // Check Locked
          final lockedMap = data['locked'] as Map<String, dynamic>?;
          final isLocked = lockedMap?[currentUserId] == true;
          if (isLocked) {
            // If locked, we still show it in list but maybe obfuscated or in "Locked" folder?
            // Requirement said "Locked Chats" folder.
            continue; // Skip for now, assume separate folder viewer not implemented yet or they are hidden.
          }

          // Check Pinned
          final pinnedMap = data['pinned'] as Map<String, dynamic>?;
          final isPinned = pinnedMap?[currentUserId] == true;

          if (isPinned) {
            pinnedDocs.add(doc);
          } else {
            filteredDocs.add(doc);
          }
        }

        // Sort: Recent first. Pinned already separated.
        filteredDocs.sort((a, b) {
          final tA =
              (a.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
          final tB =
              (b.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        pinnedDocs.sort((a, b) {
          // Pinned Date Sort? Or Last Message? Usually Last Message is fine for pinned too.
          final tA =
              (a.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
          final tB =
              (b.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        final displayList = [...pinnedDocs, ...filteredDocs];

        return ListView.builder(
          itemCount: displayList.length + 1 + (hasArchivedChat ? 1 : 0),
          itemBuilder: (context, index) {
            // 0 -> Notifications
            if (index == 0) {
              return _buildNotificationEntryTile();
            }

            int adjustedIndex = index - 1;

            // 1 -> Archived Folder (if exists)
            if (hasArchivedChat) {
              if (adjustedIndex == 0) {
                return ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.elevation,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Feather.archive,
                      color: AppColors.textMedium,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    "Archived Chats",
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    // TODO: Navigate to Archive Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Archive Screen functionality pending."),
                      ),
                    );
                  },
                );
              }
              adjustedIndex--;
            }

            final chat = displayList[adjustedIndex];
            final chatData = chat.data() as Map<String, dynamic>;
            final participants = List.from(chatData['participants']);
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
            );

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return ListTile(
                    title: Text(
                      'Loading...',
                      style: TextStyle(color: AppColors.textDisabled),
                    ),
                  );
                }

                final user = userSnapshot.data!;
                final userData = user.data() as Map<String, dynamic>;

                final unreadCount =
                    chatData.containsKey('unreadCount') &&
                        chatData['unreadCount'] != null
                    ? chatData['unreadCount'][currentUserId] ?? 0
                    : 0;

                final pinnedMap = chatData['pinned'] as Map<String, dynamic>?;
                final isPinned = pinnedMap?[currentUserId] == true;

                final mutedMap =
                    chatData['mutedUntil'] as Map<String, dynamic>?;
                final muteTs = mutedMap?[currentUserId] as Timestamp?;
                final isMuted =
                    muteTs != null && muteTs.toDate().isAfter(DateTime.now());

                return _buildMessageTile(
                  chat.id,
                  userData['username'] ?? 'User',
                  userData['profileImage'] ?? '',
                  chatData['lastMessage'] ?? '',
                  (chatData['lastMessageTime'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  unreadCount,
                  otherUserId,
                  chatType: chatData['type'],
                  otherUserAccountType: userData['accountType'],
                  isPinned: isPinned,
                  isMuted: isMuted,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationEntryTile() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: unreadCount > 0
                    ? Border.all(
                        color: AppColors.primaryLavender.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Notification Icon as Profile Pic
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.elevation,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Feather.bell,
                      color: AppColors.primaryLavender,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Notifications Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHigh,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'You have $unreadCount interactions',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryLavender,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Indicator for unread
                  if (unreadCount > 0)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accentMustard,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageTile(
    String chatId,
    String username,
    String profileImage,
    String lastMessage,
    DateTime timestamp,
    int unreadCount,
    String otherUserId, {
    String? chatType,
    String? otherUserAccountType,
    bool isPinned = false,
    bool isMuted = false,
  }) {
    final bool isTherapyChat = chatType == 'therapy';
    final bool isTherapist = otherUserAccountType == 'therapist';
    final bool isSelected = _selectedChatIds.contains(chatId);

    String displayName = username;
    if (isTherapyChat) {
      if (isTherapist) {
        displayName = "Therapist | $username";
      } else {
        displayName = "Client | $username";
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            _selectedChatIds.add(chatId);
          });
        },
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedChatIds.remove(chatId);
                if (_selectedChatIds.isEmpty) _isSelectionMode = false;
              } else {
                _selectedChatIds.add(chatId);
              }
            });
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                otherUserId: otherUserId,
                otherUserName: displayName,
                otherUserProfileImage: profileImage,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryLavender.withOpacity(0.2)
                : AppColors.surface, // Surface color for message tile
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Selection Checkbox
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppColors.primaryLavender
                        : AppColors.textDisabled,
                  ),
                ),

              // Profile image with optional Pulse Badge
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.elevation,
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                  ),
                  if (isTherapyChat)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLavender, // Purple
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLavender.withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Name and last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh, // White Name
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPinned)
                          Icon(
                            Icons.push_pin,
                            size: 14,
                            color: AppColors.textMedium,
                          ),
                        if (isMuted) SizedBox(width: 4),
                        if (isMuted)
                          Icon(
                            Feather.volume_x,
                            size: 14,
                            color: AppColors.textMedium,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium, // Gray message preview
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Timestamp and unread count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeago.format(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  if (unreadCount > 0) const SizedBox(height: 6),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors
                            .accentMustard, // Mustard for notification badge
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors
                              .backgroundDeep, // Dark text on light badge
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _getFollowedUserIds() async {
    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (currentUserDoc.exists) {
        final followingList = List<String>.from(
          currentUserDoc['following'] ?? [],
        );
        followingList.add(currentUserId);
        return followingList;
      }
      return [currentUserId];
    } catch (e) {
      print('Error fetching followed users: $e');
      return [currentUserId];
    }
  }

  void _showStoryCreationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StoryCreationModal(),
      isScrollControlled: true,
      backgroundColor: AppColors.surface, // Ensure modal matches theme
    );
  }

  void _viewStory(String userId, String username, String profileImage) async {
    try {
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .orderBy('timestamp', descending: false)
          .get();

      if (storiesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No stories available for this user.')),
        );
        return;
      }

      final List<DocumentSnapshot> userStoriesList = storiesSnapshot.docs;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryViewerScreen(
            userId: userId,
            stories: userStoriesList,
            username: username,
            profileImage: profileImage,
          ),
        ),
      );
    } catch (e) {
      print('Error viewing story: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading story.')));
    }
  }
}
