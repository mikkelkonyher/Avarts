import 'dart:async';
import 'package:flutter/material.dart';
import 'package:avarts/models/chat_models.dart';
import 'package:avarts/models/user_profile.dart';
import 'package:avarts/services/auth_service.dart';
import 'package:avarts/services/chat_service.dart';
import 'package:avarts/services/user_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.targetUser});

  final UserProfile targetUser;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final String _currentUserId = AuthService().currentUser?.id ?? '';
  final ScrollController _scrollController = ScrollController();

  UserProfile? _currentUserProfile;
  String? _conversationId;
  final List<ChatMessage> _messages = [];
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _messagesPerPage = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Fetch current user profile first
      final currentUserProfile = await _userService.getCurrentUserProfile();

      final conversationId = await _chatService.createConversation(
        widget.targetUser.id,
      );

      if (!mounted) return;

      setState(() {
        _currentUserProfile = currentUserProfile;
        _conversationId = conversationId;
      });

      // Fetch initial messages
      await _loadMessages();

      // Subscribe to new messages
      _subscribeToNewMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing chat: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    try {
      final messages = await _chatService.fetchMessages(
        _conversationId!,
        limit: _messagesPerPage,
      );

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _hasMoreMessages = messages.length >= _messagesPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Log error or show snackbar if needed
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_conversationId == null ||
        _isLoadingMore ||
        !_hasMoreMessages ||
        _messages.isEmpty) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final lastMessageTime = _messages.last.createdAt;
      final messages = await _chatService.fetchMessages(
        _conversationId!,
        limit: _messagesPerPage,
        before: lastMessageTime,
      );

      if (mounted) {
        setState(() {
          _messages.addAll(messages);
          _hasMoreMessages = messages.length >= _messagesPerPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Log error
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _subscribeToNewMessages() {
    if (_conversationId == null) return;

    _messagesSubscription = _chatService
        .subscribeToMessages(_conversationId!)
        .listen((newMessages) {
          if (newMessages.isEmpty) return;

          // Since we limit(1) in subscription, we usually get 1 message.
          // Check if we already have it to avoid duplicates (though Stream usually gives new ones)
          for (final message in newMessages) {
            final exists = _messages.any((m) => m.id == message.id);
            if (!exists) {
              setState(() {
                _messages.insert(0, message);
              });
            }
          }
        });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _messageController.clear();
    try {
      await _chatService.sendMessage(_conversationId!, text);
      // The subscription will handle adding the message to the UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Chat with ${widget.targetUser.displayName}')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet.\nSay hi to ${widget.targetUser.displayName}!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    reverse: true,
                    itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator at the top (visually)
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final message = _messages[index];
                      final isMe = message.senderId == _currentUserId;

                      final bubbleColor = isMe
                          ? colors.primary
                          : colors.surfaceContainerHighest;

                      final textColor = isMe
                          ? colors.onPrimary
                          : colors.onSurface;

                      final userProfile = isMe
                          ? _currentUserProfile
                          : widget.targetUser;
                      final displayName = userProfile?.displayName ?? 'Unknown';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  // Name label
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isMe ? 0 : 4,
                                      right: isMe ? 4 : 0,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      displayName,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onSurface.withValues(
                                              alpha: 0.6,
                                            ),
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bubbleColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      message.content,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: textColor),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: isMe ? 0 : 8,
                                      right: isMe ? 8 : 0,
                                    ),
                                    child: Text(
                                      _formatDateTime(
                                        message.createdAt.toLocal(),
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onSurface.withValues(
                                              alpha: 0.5,
                                            ),
                                            fontSize: 9,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Send a message…',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    final timeString =
        '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';

    if (messageDate == today) {
      return timeString;
    } else {
      return '${time.month}/${time.day} $timeString';
    }
  }
}
