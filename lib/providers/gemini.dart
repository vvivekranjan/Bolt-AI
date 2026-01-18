import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Provide StateNotifier and StateNotifierProvider
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:ai_chat_bot/model/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

// Key for storing the API key in SharedPreferences
const String _storageKey = 'gemini_api_key';
// Fallback API key if none is stored
final String _fallbackApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

// System prompt that guides Gemini's behavior
const String _systemPrompt =
    '''You are a helpful, friendly, and knowledgeable AI assistant.
Provide clear, concise, and accurate responses.
Maintain a conversational and engaging tone.
If you don't know something, say so honestly.
Be empathetic and understanding in your responses.''';

/// Provider for the SharedPreferences instance
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// Provider that exposes the Gemini API key from storage
final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final storedKey = prefs.getString(_storageKey);
  if (storedKey != null && storedKey.isNotEmpty) {
    return storedKey;
  }
  return _fallbackApiKey;
});

/// Provider to save the API key
final apiKeySetterProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
      return (String newKey) async {
        final prefs = await ref.read(sharedPreferencesProvider.future);
        if (newKey.isEmpty) {
          await prefs.remove(_storageKey);
        } else {
          await prefs.setString(_storageKey, newKey);
        }
        // Refresh the API key provider
        ref.invalidate(geminiApiKeyProvider);
      };
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

/// Service class to handle Gemini API interactions
class GeminiService {
  final Ref _ref;

  GeminiService(this._ref);

  Future<String> sendMessage(String userMessage) async {
    final messagesNotifier = _ref.read(chatMessagesProvider.notifier);

    // Wait for the API key to be loaded
    final apiKey = await _ref.read(geminiApiKeyProvider.future);

    // Validate API key is set
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'API Key not configured. Please add your Gemini API key in Settings.',
      );
    }

    try {
      // Initialize the model
      // Using gemini-2.5-flash as requested
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 2048,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
      );

      final stopwatch = Stopwatch()..start();

      // Generate content
      final response = await model.generateContent([Content.text(userMessage)]);

      stopwatch.stop();
      debugPrint('Gemini response time: ${stopwatch.elapsedMilliseconds} ms');

      final finalResponse = response.text;

      if (finalResponse == null || finalResponse.isEmpty) {
        throw Exception('No response received from Gemini');
      }

      // Update last message in UI state
      messagesNotifier.updateLastMessage(finalResponse);

      return finalResponse;
    } catch (e) {
      debugPrint('Error communicating with Gemini: $e');
      throw Exception('Error communicating with Gemini: ${e.toString()}');
    }
  }
}

/// Provider for the GeminiService
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(ref);
});

// Deprecated: sendChatMessageProvider replaced by GeminiService
// keeping it temporarily if strictly needed by other files, but usually safe to remove
// final sendChatMessageProvider = ... (removed)

// Providers needed for settings_screen.dart compatibility
final apiKeyProvider = geminiApiKeyProvider;
// geminiModelProvider and chatSessionProvider match existing placeholders
final geminiModelProvider = Provider<void>((ref) {});
final chatSessionProvider = Provider<void>((ref) {});

/// Helper to get system prompt for reference
String getSystemPrompt() => _systemPrompt;
