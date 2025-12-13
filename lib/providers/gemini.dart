import 'dart:async';
import 'dart:developer' as console;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_chat_bot/model/message.dart';
import 'package:ai_chat_bot/providers/firebase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Gemini API key is loaded from environment (.env) as `GEMINI_API_KEY`.
// Do not commit your real key; put it in a local `.env` file.

// System prompt that guides Gemini's behavior
const String _systemPrompt = '''You are a helpful, friendly, and knowledgeable AI assistant.
Provide clear, concise, and accurate responses.
Maintain a conversational and engaging tone.
If you don't know something, say so honestly.
Be empathetic and understanding in your responses.''';

/// Provider for Gemini model instance (cached, not recreated each time)
final geminiModelProvider = Provider<GenerativeModel>((ref) {
  final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw Exception('GEMINI_API_KEY is not set. Add it to a local .env file.');
  }

  return GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: apiKey,
  );
});

/// State notifier for managing chat messages
class ChatMessagesNotifier extends StateNotifier<List<Message>> {
  ChatMessagesNotifier() : super([]);

  void addMessage(Message message) {
    state = [...state, message];
  }

  void addMessages(List<Message> messages) {
    state = [...state, ...messages];
  }

  void clearMessages() {
    state = [];
  }

  void removeLastMessage() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void updateLastMessage(String newText) {
    if (state.isNotEmpty) {
      final lastMessage = state.last;
      final updatedMessage = Message(
        message: newText,
        isUser: lastMessage.isUser,
        id: lastMessage.id,
        createdAt: lastMessage.createdAt,
      );
      state = [...state.sublist(0, state.length - 1), updatedMessage];
    }
  }
}

/// Provider for chat messages state management
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<Message>>((ref) {
  return ChatMessagesNotifier();
});

/// State notifier for managing chat session
class ChatSessionNotifier extends StateNotifier<ChatSession?> {
  final GenerativeModel model;
  
  ChatSessionNotifier(this.model) : super(null) {
    _initializeSession();
  }
  
  void _initializeSession() {
    state = model.startChat(
      history: [
        Content.text(_systemPrompt),
      ],
    );
  }
  
  /// Reset session while preserving context
  void resetSession() {
    _initializeSession();
  }
}

/// Provider for persistent chat session with conversation history
final chatSessionProvider = StateNotifierProvider<ChatSessionNotifier, ChatSession?>((ref) {
  final model = ref.watch(geminiModelProvider);
  return ChatSessionNotifier(model);
});

/// Provider for sending message with streaming support and Firebase persistence
final sendChatMessageProvider =
    FutureProvider.family<String, String>((ref, userMessage) async {
  final session = ref.watch(chatSessionProvider);
  final messagesNotifier = ref.watch(chatMessagesProvider.notifier);
  final firebaseService = ref.watch(firebaseChatServiceProvider);
  final currentChatId = ref.watch(currentChatIdProvider);
  final messages = ref.watch(chatMessagesProvider);

  // Validate session exists
  if (session == null) {
    throw Exception('Chat session not initialized');
  }

  try {
    // Use streaming for better UX - responses appear incrementally
    final fullResponse = StringBuffer();
    bool hasReceivedContent = false;
    
    // Send message with timeout protection (30 seconds)
    try {
      await for (final chunk in session.sendMessageStream(
        Content.text(userMessage),
      ).timeout(const Duration(seconds: 30))) {
        try {
          final chunkText = chunk.text;
          
          // Only process non-empty text chunks
          if (chunkText != null && chunkText.isNotEmpty) {
            hasReceivedContent = true;
            fullResponse.write(chunkText);
            
            // Update message in real-time as chunks arrive
            messagesNotifier.updateLastMessage(fullResponse.toString());
          }
        } catch (e) {
          // Log chunk processing errors but continue
          console.log('Error processing chunk: $e');
          continue;
        }
      }
    } on TimeoutException {
      throw TimeoutException('API request timed out after 30 seconds');
    }

    // Validate we received actual content
    if (!hasReceivedContent) {
      throw Exception('No response content received from API');
    }

    final responseText = fullResponse.toString().trim();
    final finalResponse = responseText.isEmpty ? 'No response received' : responseText;

    // Ensure the last message is fully updated with the final response
    messagesNotifier.updateLastMessage(finalResponse);

    // Get the placeholder assistant message ID that was added to UI
    final assistantMessageId = messages.isNotEmpty ? messages.last.id : DateTime.now().millisecondsSinceEpoch.toString();
    
    // Create assistant message with proper ID for consistency
    final assistantMsg = Message(
      id: assistantMessageId,
      message: finalResponse,
      isUser: false,
      createdAt: DateTime.now(),
    );
    
    // Save assistant response to Firebase
    await firebaseService.saveMessage(assistantMsg);

    // Update chat metadata with latest timestamp
    await firebaseService.saveChatMetadata();

    return finalResponse;
  } on TimeoutException catch (e) {
    throw Exception('Request timeout: ${e.message}');
  } catch (e) {
    throw Exception('Error communicating with Gemini: ${e.toString()}');
  }
});

/// Helper to get system prompt for reference
String getSystemPrompt() => _systemPrompt;
