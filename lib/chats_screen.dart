import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

enum ChatRole { customer, provider }

class ChatsScreen extends StatefulWidget {
  final ChatRole role;
  const ChatsScreen({super.key, required this.role});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String get _roleLabel => widget.role == ChatRole.customer ? 'Customer' : 'Service Provider';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(
          child: Text('Please sign in to view chats.'),
        ),
      );
    }

    final String filterField = widget.role == ChatRole.customer ? 'customerId' : 'providerId';
    final stream = FirebaseFirestore.instance
        .collection('serviceRequests')
        .where(filterField, isEqualTo: user.uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load chats.'));
          }

          final docs = snapshot.data?.docs.toList() ?? [];
          if (docs.isEmpty) {
            return _EmptyChatsState(roleLabel: _roleLabel);
          }

          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = _extractSortTime(aData);
            final bTime = _extractSortTime(bData);
            return bTime.compareTo(aTime);
          });

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _ChatRequestTile(
                role: widget.role,
                requestDoc: docs[index],
                currentUserId: user.uid,
              );
            },
          );
        },
      ),
    );
  }

  DateTime _extractSortTime(Map<String, dynamic> data) {
    final dynamic ts = data['bookingTimestamp'] ?? data['scheduledDateTime'] ?? data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _EmptyChatsState extends StatelessWidget {
  final String roleLabel;
  const _EmptyChatsState({required this.roleLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Your $roleLabel chats will appear here once a conversation starts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatRequestTile extends StatelessWidget {
  final ChatRole role;
  final DocumentSnapshot requestDoc;
  final String currentUserId;

  const _ChatRequestTile({
    required this.role,
    required this.requestDoc,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final data = requestDoc.data() as Map<String, dynamic>;
    final String requestId = requestDoc.id;
    final String serviceName = (data['serviceName'] ?? 'Service').toString();
    final String otherUserId = role == ChatRole.customer
        ? (data['providerId'] as String? ?? '')
        : (data['customerId'] as String? ?? '');
    final String? customerName = data['customerName'] as String?;
    final String fallbackName = role == ChatRole.customer
        ? 'Service Provider'
        : (customerName != null && customerName.trim().isNotEmpty)
            ? customerName.trim()
            : 'Customer';

    if (otherUserId.isEmpty) {
      return const SizedBox.shrink();
    }

    final userStream = FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots();
    final chatStream = FirebaseFirestore.instance.collection('chats').doc(requestId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final String displayName = _resolveUserName(userData, fallbackName);
        final String? avatarUrl = userData?['profileImageUrl'] as String?;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: chatStream,
          builder: (context, chatSnap) {
            final chatData = chatSnap.data?.data();
            final String? lastMessage = (chatData?['lastMessage'] as String?)?.trim();
            final Timestamp? lastTs = chatData?['lastMessageAt'] as Timestamp?;
            final DateTime? lastTime = lastTs?.toDate();
            final String subtitleText =
                (lastMessage != null && lastMessage.isNotEmpty)
                    ? lastMessage
                    : 'No messages yet';
            final String timeText = _formatMessageTime(lastTime);
            final String lastSenderId = (chatData?['lastSenderId'] as String?) ?? '';
            final String readField = role == ChatRole.customer ? 'lastReadAtCustomer' : 'lastReadAtProvider';
            final Timestamp? lastReadTs = chatData?[readField] as Timestamp?;
            final bool isUnread = lastTs != null &&
                lastSenderId.isNotEmpty &&
                lastSenderId != currentUserId &&
                (lastReadTs == null || lastTs.toDate().isAfter(lastReadTs.toDate()));
            final bool isTyping = _isOtherTyping(chatData);
            final String displaySubtitle = isTyping ? 'Typing...' : subtitleText;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: Colors.deepPurple)
                      : null,
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        serviceName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displaySubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                          fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                          color: isTyping ? Colors.deepPurple : null,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    if (isUnread) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatThreadScreen(
                        role: role,
                        requestId: requestId,
                        serviceName: serviceName,
                        otherUserId: otherUserId,
                        fallbackOtherName: displayName,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _resolveUserName(Map<String, dynamic>? userData, String fallbackName) {
    final String? name = userData?['username'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return fallbackName;
  }

  String _formatMessageTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, time)) {
      return DateFormat.jm().format(time);
    }
    if (now.difference(time).inDays < 7) {
      return DateFormat.E().format(time);
    }
    return DateFormat.MMMd().format(time);
  }

  bool _isOtherTyping(Map<String, dynamic>? chatData) {
    if (chatData == null) return false;
    final String typingField = role == ChatRole.customer ? 'typingProvider' : 'typingCustomer';
    final bool isTyping = chatData[typingField] == true;
    final Timestamp? typingTs = chatData['typingUpdatedAt'] as Timestamp?;
    if (!isTyping || typingTs == null) return false;
    return DateTime.now().difference(typingTs.toDate()).inSeconds <= 8;
  }
}

class ChatThreadScreen extends StatefulWidget {
  final ChatRole role;
  final String requestId;
  final String serviceName;
  final String otherUserId;
  final String fallbackOtherName;

  const ChatThreadScreen({
    super.key,
    required this.role,
    required this.requestId,
    required this.serviceName,
    required this.otherUserId,
    required this.fallbackOtherName,
  });

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_LocalMessage> _localMessages = [];
  bool _sending = false;
  bool _markingRead = false;
  bool _isTyping = false;
  bool _searching = false;
  bool _uploadingImage = false;
  String _searchQuery = '';
  Timestamp? _lastMarkedMessageAt;
  Timer? _typingTimer;
  _ReplyTarget? _replyingTo;

  @override
  void dispose() {
    _typingTimer?.cancel();
    _setTyping(false, force: true);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: Colors.deepPurple,
        ),
        body: const Center(child: Text('Please sign in to continue.')),
      );
    }

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    final chatStream = chatRef.snapshots();
    final messagesStream = chatRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: _searching
            ? _buildSearchField()
            : _ChatHeader(
                otherUserId: widget.otherUserId,
                fallbackName: widget.fallbackOtherName,
                serviceName: widget.serviceName,
              ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: chatStream,
        builder: (context, chatSnap) {
          final chatData = chatSnap.data?.data();
          final String readField = widget.role == ChatRole.customer ? 'lastReadAtCustomer' : 'lastReadAtProvider';
          final Timestamp? lastReadTs = chatData?[readField] as Timestamp?;
          final Map<String, dynamic>? pinned = (chatData?['pinnedMessage'] is Map)
              ? Map<String, dynamic>.from(chatData?['pinnedMessage'])
              : null;
          final String? pinnedMessageId = pinned?['messageId'] as String?;
          final bool otherTyping = _isOtherTyping(chatData);

          return Column(
            children: [
              if (pinned != null)
                _PinnedMessageBanner(
                  pinned: pinned,
                  currentUserId: user.uid,
                  otherName: widget.fallbackOtherName,
                  onUnpin: _unpinMessage,
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Failed to load messages.'));
                    }
                    final allDocs = snapshot.data?.docs ?? [];
                    if (allDocs.isEmpty) {
                      return _EmptyMessagesState(serviceName: widget.serviceName);
                    }

                    final latestData = allDocs.first.data() as Map<String, dynamic>;
                    final Timestamp? latestTs = latestData['createdAt'] as Timestamp?;
                    final String latestSender = (latestData['senderId'] as String?) ?? '';
                    _maybeMarkRead(latestTs, latestSender);

                    final bool searching = _searchQuery.isNotEmpty;
                    final List<QueryDocumentSnapshot> docs = searching
                        ? allDocs
                            .where((d) => _matchesSearch(d.data() as Map<String, dynamic>, _searchQuery))
                            .toList()
                        : allDocs;

                    if (searching && docs.isEmpty) {
                      return const Center(child: Text('No messages found.'));
                    }

                    int dividerAfterIndex = -1;
                    if (!searching && lastReadTs != null) {
                      for (int i = 0; i < allDocs.length; i++) {
                        final data = allDocs[i].data() as Map<String, dynamic>;
                        final String senderId = (data['senderId'] as String?) ?? '';
                        final Timestamp? ts = data['createdAt'] as Timestamp?;
                        if (ts == null) continue;
                        if (senderId != user.uid && ts.toDate().isAfter(lastReadTs.toDate())) {
                          dividerAfterIndex = i;
                        }
                      }
                    }

                    final serverIds = allDocs.map((d) => d.id).toSet();
                    final pending = searching
                        ? <_LocalMessage>[]
                        : _localMessages.where((m) => !serverIds.contains(m.id)).toList()
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    final int pendingCount = pending.length;
                    final bool showDivider = !searching && dividerAfterIndex >= 0 && dividerAfterIndex < allDocs.length - 1;
                    final int dividerInsertIndex = showDivider ? (pendingCount + dividerAfterIndex + 1) : -1;
                    final int totalItems = pendingCount + docs.length + (showDivider ? 1 : 0);

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: totalItems,
                      itemBuilder: (context, index) {
                        if (showDivider && index == dividerInsertIndex) {
                          return const _NewMessagesDivider();
                        }
                        int effectiveIndex = index;
                        if (showDivider && index > dividerInsertIndex) {
                          effectiveIndex -= 1;
                        }

                        if (effectiveIndex < pendingCount) {
                          final local = pending[effectiveIndex];
                          final String statusText = local.status == _LocalMessageStatus.failed
                              ? 'Failed \u2022 Tap to retry'
                              : (local.status == _LocalMessageStatus.sending
                                  ? 'Sending...'
                                  : 'Sent ${DateFormat.jm().format(local.createdAt)}');
                          final _ReplyPreviewData? replyPreview = local.replyTo == null
                              ? null
                              : _ReplyPreviewData.fromReplyMap(
                                  local.replyTo!,
                                  user.uid,
                                  widget.fallbackOtherName,
                                );
                          return _MessageBubble(
                            text: local.text,
                            imageUrl: local.imageUrl,
                            isMe: true,
                            timestamp: local.createdAt,
                            statusText: statusText,
                            isFailed: local.status == _LocalMessageStatus.failed,
                            replyPreview: replyPreview,
                            onTap: local.status == _LocalMessageStatus.failed
                                ? () => _retryLocalMessage(local)
                                : null,
                          );
                        }

                        final int docIndex = effectiveIndex - pendingCount;
                        final message = _ChatMessage.fromDoc(docs[docIndex]);
                        final bool isMe = message.senderId == user.uid;
                        final String? statusText = isMe && message.createdAt != null
                            ? 'Sent ${DateFormat.jm().format(message.createdAt!)}'
                            : null;
                        final _ReplyPreviewData? replyPreview = message.replyTo == null
                            ? null
                            : _ReplyPreviewData.fromReplyMap(
                                message.replyTo!,
                                user.uid,
                                widget.fallbackOtherName,
                              );

                        return _MessageBubble(
                          text: message.text,
                          imageUrl: message.imageUrl,
                          isMe: isMe,
                          timestamp: message.createdAt,
                          statusText: statusText,
                          isDeleted: message.isDeleted,
                          replyPreview: replyPreview,
                          onLongPress: message.isDeleted
                              ? null
                              : () => _showMessageActions(message, isMe, pinnedMessageId),
                        );
                      },
                    );
                  },
                ),
              ),
              if (otherTyping) _TypingIndicator(name: widget.fallbackOtherName),
              if (_replyingTo != null)
                _ReplyPreviewBar(
                  replyingTo: _replyingTo!,
                  onCancel: () => setState(() => _replyingTo = null),
                ),
              _ChatComposer(
                controller: _messageController,
                sending: _sending || _uploadingImage,
                onSend: _sendMessage,
                onAttach: _uploadingImage ? null : _pickAndSendImage,
                onChanged: _handleComposerChanged,
                uploading: _uploadingImage,
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (value) {
        setState(() => _searchQuery = value.trim().toLowerCase());
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search messages...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        border: InputBorder.none,
      ),
    );
  }

  void _handleComposerChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (!hasText) {
      _typingTimer?.cancel();
      _setTyping(false);
      return;
    }
    _setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () => _setTyping(false));
  }

  bool _isOtherTyping(Map<String, dynamic>? chatData) {
    if (chatData == null) return false;
    final String typingField = widget.role == ChatRole.customer ? 'typingProvider' : 'typingCustomer';
    final bool isTyping = chatData[typingField] == true;
    final Timestamp? typingTs = chatData['typingUpdatedAt'] as Timestamp?;
    if (!isTyping || typingTs == null) return false;
    return DateTime.now().difference(typingTs.toDate()).inSeconds <= 8;
  }

  bool _matchesSearch(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final String text = (data['text'] ?? '').toString().toLowerCase();
    final Map<String, dynamic>? reply = data['replyTo'] is Map
        ? Map<String, dynamic>.from(data['replyTo'] as Map)
        : null;
    final String replyText = reply == null ? '' : (reply['text'] ?? '').toString().toLowerCase();
    return text.contains(query) || replyText.contains(query);
  }

  Future<void> _setTyping(bool value, {bool force = false}) async {
    if (!force && _isTyping == value) return;
    _isTyping = value;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String field = widget.role == ChatRole.customer ? 'typingCustomer' : 'typingProvider';
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    try {
      await chatRef.set({
        field: value,
        'typingUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore typing failures
    }
  }

  void _setReplyTarget(_ChatMessage message, bool isMe) {
    final String senderLabel = isMe ? 'You' : widget.fallbackOtherName;
    setState(() {
      _replyingTo = _ReplyTarget(
        messageId: message.id,
        senderId: message.senderId,
        senderLabel: senderLabel,
        text: message.text,
        imageUrl: message.imageUrl,
        type: message.imageUrl != null ? 'image' : 'text',
      );
    });
  }

  Future<void> _showMessageActions(_ChatMessage message, bool isMe, String? pinnedMessageId) async {
    final bool isPinned = pinnedMessageId == message.id;
    final bool hasCopyText = message.text.trim().isNotEmpty || (message.imageUrl != null && message.imageUrl!.isNotEmpty);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _setReplyTarget(message, isMe);
                },
              ),
              if (hasCopyText)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final String toCopy = message.text.trim().isNotEmpty
                        ? message.text.trim()
                        : (message.imageUrl ?? '');
                    Clipboard.setData(ClipboardData(text: toCopy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(isPinned ? 'Unpin' : 'Pin'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (isPinned) {
                    _unpinMessage();
                  } else {
                    _pinMessage(message);
                  }
                },
              ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Delete for everyone', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Delete message?'),
                        content: const Text('This will remove the message for everyone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _deleteMessage(message.id, pinnedMessageId);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pinMessage(_ChatMessage message) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    final Map<String, dynamic> pinData = {
      'messageId': message.id,
      'text': message.text,
      'imageUrl': message.imageUrl,
      'type': message.imageUrl != null ? 'image' : 'text',
      'senderId': message.senderId,
      'pinnedAt': FieldValue.serverTimestamp(),
    };
    try {
      await chatRef.set({'pinnedMessage': pinData}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pin message: $e')),
        );
      }
    }
  }

  Future<void> _unpinMessage() async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    try {
      await chatRef.set({'pinnedMessage': FieldValue.delete()}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unpin message: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId, String? pinnedMessageId) async {
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    final msgRef = chatRef.collection('messages').doc(messageId);
    try {
      await msgRef.update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      if (pinnedMessageId == messageId) {
        await _unpinMessage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_uploadingImage || _sending) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _uploadingImage = true);

      final Uint8List bytes = await file.readAsBytes();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
      final messageRef = chatRef.collection('messages').doc();
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images/${user.uid}/${messageRef.id}.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      final caption = _messageController.text.trim();
      _messageController.clear();
      _setTyping(false, force: true);
      final localMessage = _LocalMessage(
        id: messageRef.id,
        text: caption,
        imageUrl: url,
        type: _LocalMessageType.image,
        createdAt: DateTime.now(),
        status: _LocalMessageStatus.sending,
        replyTo: _replyingTo?.toMap(),
      );
      setState(() {
        _sending = true;
        _localMessages.insert(0, localMessage);
        _replyingTo = null;
      });
      await _sendLocalMessage(localMessage, messageRef);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_sending || _uploadingImage) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    final messageRef = chatRef.collection('messages').doc();
    final localMessage = _LocalMessage(
      id: messageRef.id,
      text: text,
      imageUrl: null,
      type: _LocalMessageType.text,
      createdAt: DateTime.now(),
      status: _LocalMessageStatus.sending,
      replyTo: _replyingTo?.toMap(),
    );
    setState(() {
      _sending = true;
      _localMessages.insert(0, localMessage);
      _replyingTo = null;
    });
    _messageController.clear();
    _setTyping(false, force: true);

    await _sendLocalMessage(localMessage, messageRef);
  }

  Future<void> _sendLocalMessage(_LocalMessage localMessage, DocumentReference messageRef) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
      final String customerId = widget.role == ChatRole.customer ? user.uid : widget.otherUserId;
      final String providerId = widget.role == ChatRole.provider ? user.uid : widget.otherUserId;
      final String readField = widget.role == ChatRole.customer ? 'lastReadAtCustomer' : 'lastReadAtProvider';
      final String lastMessageText = localMessage.type == _LocalMessageType.image &&
              localMessage.text.trim().isEmpty
          ? 'Photo'
          : localMessage.text.trim();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final chatSnap = await tx.get(chatRef);
        final chatData = {
          'requestId': widget.requestId,
          'serviceName': widget.serviceName,
          'customerId': customerId,
          'providerId': providerId,
          'participants': [customerId, providerId],
          'lastMessage': lastMessageText,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': user.uid,
          readField: FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (chatSnap.exists) {
          tx.set(chatRef, chatData, SetOptions(merge: true));
        } else {
          tx.set(
            chatRef,
            {
              ...chatData,
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        tx.set(messageRef, {
          'text': localMessage.text,
          'imageUrl': localMessage.imageUrl,
          'type': localMessage.type == _LocalMessageType.image ? 'image' : 'text',
          'senderId': user.uid,
          'senderRole': widget.role == ChatRole.customer ? 'customer' : 'provider',
          if (localMessage.replyTo != null) 'replyTo': localMessage.replyTo,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      if (mounted) {
        setState(() {
          localMessage.status = _LocalMessageStatus.sent;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          localMessage.status = _LocalMessageStatus.failed;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _retryLocalMessage(_LocalMessage localMessage) async {
    if (_sending) return;
    if (!mounted) return;
    setState(() {
      _sending = true;
      localMessage.status = _LocalMessageStatus.sending;
    });
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
    final messageRef = chatRef.collection('messages').doc(localMessage.id);
    await _sendLocalMessage(localMessage, messageRef);
  }

  void _maybeMarkRead(Timestamp? latestTs, String latestSenderId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (latestTs == null) return;
    if (latestSenderId == user.uid) return;
    if (_lastMarkedMessageAt != null &&
        !latestTs.toDate().isAfter(_lastMarkedMessageAt!.toDate())) {
      return;
    }
    _lastMarkedMessageAt = latestTs;
    _markRead();
  }

  Future<void> _markRead() async {
    if (_markingRead) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _markingRead = true;
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.requestId);
      final chatSnap = await chatRef.get();
      if (!chatSnap.exists) return;
      final field = widget.role == ChatRole.customer ? 'lastReadAtCustomer' : 'lastReadAtProvider';
      await chatRef.set({field: FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {
      // ignore read mark failures
    } finally {
      _markingRead = false;
    }
  }
}

class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
          const SizedBox(width: 8),
          const Text(
            'New messages',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String otherUserId;
  final String fallbackName;
  final String serviceName;

  const _ChatHeader({
    required this.otherUserId,
    required this.fallbackName,
    required this.serviceName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final String name = _resolveName(data, fallbackName);
        final String? avatarUrl = data?['profileImageUrl'] as String?;

        return Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? NetworkImage(avatarUrl)
                  : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    serviceName,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _resolveName(Map<String, dynamic>? data, String fallback) {
    final name = data?['username'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return fallback;
  }
}

class _EmptyMessagesState extends StatelessWidget {
  final String serviceName;
  const _EmptyMessagesState({required this.serviceName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mark_chat_unread_outlined, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            Text(
              'Start a conversation about $serviceName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a message and it will appear here instantly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMe;
  final DateTime? timestamp;
  final String? statusText;
  final bool isFailed;
  final bool isDeleted;
  final _ReplyPreviewData? replyPreview;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.text,
    this.imageUrl,
    required this.isMe,
    required this.timestamp,
    this.statusText,
    this.isFailed = false,
    this.isDeleted = false,
    this.replyPreview,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? Colors.deepPurple : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    final timeColor = isFailed
        ? Colors.redAccent
        : (isMe ? Colors.white70 : Colors.grey[600]);
    final String timeText = statusText ??
        (timestamp == null ? '' : DateFormat.jm().format(timestamp!));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isDeleted)
                Text(
                  'Message deleted',
                  style: TextStyle(color: textColor.withOpacity(0.8), fontStyle: FontStyle.italic),
                )
              else ...[
                if (replyPreview != null) ...[
                  _ReplySnippet(
                    data: replyPreview!,
                    isMe: isMe,
                  ),
                  const SizedBox(height: 6),
                ],
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 220,
                          height: 160,
                          color: Colors.black.withOpacity(0.1),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 220,
                        height: 160,
                        color: Colors.black.withOpacity(0.1),
                        child: const Icon(Icons.broken_image, color: Colors.white70),
                      ),
                    ),
                  ),
                if (text.trim().isNotEmpty) ...[
                  if (imageUrl != null && imageUrl!.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(color: textColor, height: 1.3),
                  ),
                ],
              ],
              if (timeText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(fontSize: 10, color: timeColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _LocalMessageStatus { sending, sent, failed }

enum _LocalMessageType { text, image }

class _LocalMessage {
  final String id;
  final String text;
  final String? imageUrl;
  final _LocalMessageType type;
  final DateTime createdAt;
  final Map<String, dynamic>? replyTo;
  _LocalMessageStatus status;

  _LocalMessage({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.type,
    required this.createdAt,
    required this.status,
    required this.replyTo,
  });
}

class _ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;
  final bool isDeleted;
  final Map<String, dynamic>? replyTo;

  const _ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.imageUrl,
    required this.createdAt,
    required this.isDeleted,
    required this.replyTo,
  });

  factory _ChatMessage.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp? ts = data['createdAt'] as Timestamp?;
    return _ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: ts?.toDate(),
      isDeleted: data['isDeleted'] == true,
      replyTo: data['replyTo'] is Map ? Map<String, dynamic>.from(data['replyTo'] as Map) : null,
    );
  }
}

class _ReplyTarget {
  final String messageId;
  final String senderId;
  final String senderLabel;
  final String text;
  final String? imageUrl;
  final String type;

  const _ReplyTarget({
    required this.messageId,
    required this.senderId,
    required this.senderLabel,
    required this.text,
    required this.imageUrl,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'type': type,
    };
  }
}

class _ReplyPreviewData {
  final String senderLabel;
  final String text;
  final bool isImage;

  const _ReplyPreviewData({
    required this.senderLabel,
    required this.text,
    required this.isImage,
  });

  factory _ReplyPreviewData.fromReplyMap(
    Map<String, dynamic> replyMap,
    String currentUserId,
    String otherName,
  ) {
    final String senderId = (replyMap['senderId'] as String?) ?? '';
    final bool isImage = (replyMap['type'] as String?) == 'image' || (replyMap['imageUrl'] != null);
    final String text = (replyMap['text'] as String?) ?? '';
    final String label = senderId == currentUserId ? 'You' : otherName;
    return _ReplyPreviewData(
      senderLabel: label.isEmpty ? 'User' : label,
      text: text,
      isImage: isImage,
    );
  }
}

class _ReplySnippet extends StatelessWidget {
  final _ReplyPreviewData data;
  final bool isMe;

  const _ReplySnippet({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final Color accent = isMe ? Colors.white70 : Colors.deepPurple;
    final String previewText = data.text.trim().isNotEmpty
        ? data.text.trim()
        : (data.isImage ? 'Photo' : '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.deepPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.senderLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            previewText.isEmpty ? 'Message' : previewText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  final Map<String, dynamic> pinned;
  final String currentUserId;
  final String otherName;
  final VoidCallback onUnpin;

  const _PinnedMessageBanner({
    required this.pinned,
    required this.currentUserId,
    required this.otherName,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final String senderId = (pinned['senderId'] as String?) ?? '';
    final String senderLabel = senderId == currentUserId ? 'You' : otherName;
    final bool isImage = (pinned['type'] as String?) == 'image' || pinned['imageUrl'] != null;
    final String text = (pinned['text'] as String?) ?? '';
    final String preview = text.trim().isNotEmpty ? text.trim() : (isImage ? 'Photo' : 'Message');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 18, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pinned from $senderLabel',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Unpin',
            onPressed: onUnpin,
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final String name;
  const _TypingIndicator({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 4),
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
          ),
          const SizedBox(width: 8),
          Text(
            '${name.isEmpty ? 'User' : name} is typing...',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  final _ReplyTarget replyingTo;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({
    required this.replyingTo,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final String previewText = replyingTo.text.trim().isNotEmpty
        ? replyingTo.text.trim()
        : (replyingTo.type == 'image' ? 'Photo' : 'Message');
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${replyingTo.senderLabel}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool uploading;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onChanged;

  const _ChatComposer({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.uploading,
    this.onAttach,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              onPressed: sending || uploading ? null : onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: sending ? Colors.grey : Colors.deepPurple,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: sending ? null : onSend,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
