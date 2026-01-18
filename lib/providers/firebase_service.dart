import 'dart:developer' as console;

import 'package:ai_chat_bot/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ai_chat_bot/model/message.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Initialize Firebase
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Service for managing chat history in Firestore
class FirebaseChatService {
  final FirebaseFirestore _firestore;
  late String Function() _getChatId; // Callback to get current chat ID from provider
  static const String _chatsCollection = 'chats';
  static const String _messagesSubCollection = 'messages';

  FirebaseChatService(this._firestore) {
    // Default implementation - will be overridden by provider
    _getChatId = () => DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Set the chat ID getter function
  void setChatIdGetter(String Function() getChatId) {
    _getChatId = getChatId;
  }

  /// Get current chat ID
  String _getCurrentChatId() => _getChatId();

  /// Save a single message to Firestore
  Future<void> saveMessage(Message message) async {
    try {
      await _firestore
          .collection(_chatsCollection)
          .doc(_getCurrentChatId())
          .collection(_messagesSubCollection)
          .add({
        'message': message.message,
        'isUser': message.isUser,
        'createdAt': message.createdAt.toIso8601String(),
        'id': message.id,
      });
    } catch (e) {
      console.log('Error saving message: $e');
    }
  }

  /// Load chat history from Firestore
  Future<List<Message>> loadChatHistory(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesSubCollection)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Message(
          message: data['message'] as String,
          isUser: data['isUser'] as bool,
          createdAt: DateTime.parse(data['createdAt'] as String),
          id: data['id'] as String,
        );
      }).toList();
    } catch (e) {
      console.log('Error loading chat history: $e');
      return [];
    }
  }

  /// Get all chats
  Future<List<Map<String, dynamic>>> getAllChats() async {
    try {
      final snapshot = await _firestore
          .collection(_chatsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'createdAt': data['createdAt'] as String? ?? DateTime.now().toIso8601String(),
          ...data,
        };
      }).toList();
    } catch (e) {
      console.log('Error getting all chats: $e');
      return [];
    }
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      final messagesSnapshot = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesSubCollection)
          .get();

      for (final doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the chat document
      await _firestore.collection(_chatsCollection).doc(chatId).delete();
    } catch (e) {
      console.log('Error deleting chat: $e');
    }
  }

  /// Save chat metadata
  Future<void> saveChatMetadata(
      {String? title, DateTime? createdAt}) async {
    try {
      final data = {
        'title': title ?? 'Chat ${DateTime.now()}',
        'createdAt': createdAt?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await _firestore
          .collection(_chatsCollection)
          .doc(_getCurrentChatId())
          .set(data, SetOptions(merge: true));
    } catch (e) {
      console.log('Error saving chat metadata: $e');
    }
  }
}

/// Provider for Firebase Chat Service (singleton)
final firebaseChatServiceProvider =
    Provider<FirebaseChatService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final currentChatId = ref.watch(currentChatIdProvider);
  final service = FirebaseChatService(firestore);
  
  // Set the chat ID getter to pull from the provider
  service.setChatIdGetter(() => currentChatId);
  
  return service;
});

/// Provider for loading chat history
final chatHistoryProvider = FutureProvider.family<List<Message>, String>(
  (ref, chatId) async {
    final chatService = ref.watch(firebaseChatServiceProvider);
    return chatService.loadChatHistory(chatId);
  },
);

/// Provider for all chats list
final allChatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final chatService = ref.watch(firebaseChatServiceProvider);
  return chatService.getAllChats();
});

/// State notifier for managing current chat ID
class CurrentChatIdNotifier extends StateNotifier<String> {
  CurrentChatIdNotifier() : super(DateTime.now().millisecondsSinceEpoch.toString());

  void setChatId(String chatId) {
    state = chatId;
  }

  void createNewChat() {
    state = DateTime.now().millisecondsSinceEpoch.toString();
  }

  String getCurrentId() => state;
}

/// Provider for current chat ID state
final currentChatIdProvider = StateNotifierProvider<CurrentChatIdNotifier, String>((ref) {
  return CurrentChatIdNotifier();
});

/// Refresh all chats provider
final refreshAllChatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final chatService = ref.watch(firebaseChatServiceProvider);
  return chatService.getAllChats();
});
