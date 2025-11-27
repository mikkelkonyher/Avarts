import 'package:avarts/models/user_profile.dart';

class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<UserProfile> participants;
  final ChatMessage? lastMessage;

  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map((e) => UserProfile.fromJson(e))
              .toList() ??
          [],
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'])
          : null,
    );
  }
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final UserProfile? sender;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.sender,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      sender: json['sender'] != null
          ? UserProfile.fromJson(json['sender'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
    };
  }
}
