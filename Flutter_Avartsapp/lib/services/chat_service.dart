import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:avarts/models/chat_models.dart';
import 'package:avarts/models/user_profile.dart';
import 'package:avarts/services/auth_service.dart';

class ChatService {
  SupabaseClient get client => Supabase.instance.client;
  String? get currentUserId => AuthService().currentUser?.id;

  /// Get a stream of conversations for the current user
  Stream<List<Conversation>> getConversations() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .asyncMap((data) async {
          final conversations = <Conversation>[];
          for (final item in data) {
            final conversationId = item['id'] as String;

            // Fetch participants
            final participantsResponse = await client
                .from('conversation_participants')
                .select('user_id, profiles(*)')
                .eq('conversation_id', conversationId);

            final participants = (participantsResponse as List)
                .map((p) => UserProfile.fromJson(p['profiles']))
                .toList();

            // Fetch last message (optional optimization: store last_message in conversations table)
            final lastMessageResponse = await client
                .from('messages')
                .select()
                .eq('conversation_id', conversationId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            ChatMessage? lastMessage;
            if (lastMessageResponse != null) {
              lastMessage = ChatMessage.fromJson(lastMessageResponse);
            }

            conversations.add(
              Conversation(
                id: conversationId,
                createdAt: DateTime.parse(item['created_at']),
                updatedAt: DateTime.parse(item['updated_at']),
                participants: participants,
                lastMessage: lastMessage,
              ),
            );
          }
          return conversations;
        });
  }

  /// Fetch a chunk of messages for a specific conversation
  Future<List<ChatMessage>> fetchMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    // Start building the query
    var query = client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);

    // Apply 'before' filter if provided
    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    // Apply order and limit
    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => ChatMessage.fromJson(json))
        .toList();
  }

  /// Subscribe to new messages for a specific conversation
  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1) // We only care about receiving the latest message to append
        .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
  }

  /// Send a message in a conversation
  Future<void> sendMessage(String conversationId, String content) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
    });

    // Update conversation updated_at
    await client
        .from('conversations')
        .update({'updated_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  /// Create or get an existing conversation with a user
  Future<String> createConversation(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not logged in');

    // Check if conversation already exists
    // This is a bit complex in SQL, so we'll do a simplified check or just create a new one if not found easily.
    // Ideally, we'd have a function or a more complex query to find a conversation with exactly these 2 participants.
    // For now, let's try to find a conversation where both are participants.

    final response = await client.rpc(
      'find_conversation_with_user',
      params: {'other_user_id': otherUserId},
    );

    if (response != null) {
      return response as String;
    }

    // Create new conversation using RPC
    final conversationId = await client.rpc(
      'create_new_conversation',
      params: {'other_user_id': otherUserId},
    );

    return conversationId as String;
  }
}
