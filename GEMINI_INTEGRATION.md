# Gemini AI Integration & State Management Guide

## Overview
This guide explains the Gemini AI integration with custom API key support and state management using Riverpod for your AI Chat Bot application.

## What's Been Added

### 1. **Dependencies** (`pubspec.yaml`)
- `google_generative_ai: ^0.4.0` - Official Google Generative AI SDK
- `shared_preferences: ^2.2.2` - For persistent API key storage

### 2. **Gemini Provider** (`lib/providers/gemini.dart`)

#### Key Providers:

**API Key Management:**
- `apiKeyProvider` - Retrieves stored API key from SharedPreferences
- `apiKeySetterProvider` - Saves API key to local storage

**Gemini Model:**
- `geminiModelProvider` - Creates and provides GenerativeModel instance

**Chat State:**
- `chatMessagesProvider` - Manages chat messages list using StateNotifier
  - `addMessage()` - Add single message
  - `addMessages()` - Add multiple messages
  - `clearMessages()` - Clear all messages
  - `removeLastMessage()` - Remove last message

**AI Communication:**
- `sendMessageProvider` - Single-turn message (stateless)
- `chatSessionProvider` - Manages multi-turn conversation session
- `sendChatMessageProvider` - Send message with conversation history

### 3. **Enhanced Message Model** (`lib/model/message.dart`)

```dart
Message.user(String message)      // Create user message
Message.assistant(String message) // Create AI response
Message.fromMap(Map)              // Deserialize
message.toMap()                   // Serialize
```

### 4. **Updated Chat Screen** (`lib/chat_screen.dart`)

**Features:**
- Real-time message display from state
- Loading indicator during API calls
- Error handling and user feedback
- API key validation check
- Empty state messaging
- Message constraints for better UI

**Workflow:**
1. User types message and sends
2. User message added to state immediately
3. Loading indicator shown
4. Gemini API called for response
5. AI response added to state
6. Messages displayed in conversation view

### 5. **Settings Screen** (`lib/settings_screen.dart`)

**Features:**
- Secure API key input with visibility toggle
- Save/Clear API key functionality
- Persistent storage integration
- Clear instructions for getting API key
- Visual feedback for actions

## Usage Guide

### Step 1: Get Your Gemini API Key

1. Visit [Google AI Studio](https://aistudio.google.com)
2. Click "Get API Key"
3. Create or select a project
4. Copy your API key

### Step 2: Configure API Key in App

1. Open the Settings screen in your app
2. Paste your API key in the input field
3. Click "Save API Key"
4. The app will save it securely

### Step 3: Use Chat Screen

1. Go to Chat screen
2. Type your message
3. Press send button
4. Wait for Gemini's response
5. Continue the conversation

## Code Examples

### Sending a Message
```dart
final response = await ref.read(
  sendChatMessageProvider('Hello, how are you?').future
);
```

### Accessing Chat Messages
```dart
final messages = ref.watch(chatMessagesProvider);
// Returns List<Message>
```

### Adding Message to State
```dart
final userMessage = Message.user('User input');
ref.read(chatMessagesProvider.notifier).addMessage(userMessage);
```

### Checking API Key
```dart
final apiKey = await ref.watch(apiKeyProvider.future);
if (apiKey == null || apiKey.isEmpty) {
  // Show settings screen or warning
}
```

## Integration with Navigation

To add the Settings screen to your navigation:

```dart
// In your app
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const SettingsScreen()),
);
```

You can add a settings button in the AppBar or a drawer menu.

## State Management Flow

```
User Input
    ↓
Add User Message to State
    ↓
Call Gemini API (via Provider)
    ↓
Add AI Response to State
    ↓
Update UI (Riverpod watches state)
```

## Error Handling

The app handles several error scenarios:

1. **No API Key** - Shows warning to configure settings
2. **API Errors** - Shows SnackBar with error message
3. **Network Issues** - Caught and displayed to user
4. **Empty Messages** - Validates input before sending

## API Key Security

- API key is stored in device storage using SharedPreferences
- Consider using platform-specific secure storage for production:
  - Android: Encrypted SharedPreferences
  - iOS: Keychain

## Next Steps (Optional Enhancements)

1. Add message persistence (save to SQLite/Hive)
2. Implement multi-turn conversation history
3. Add message editing/deletion
4. Implement conversation bookmarking
5. Add text-to-speech for AI responses
6. Add speech-to-text for user input
7. Implement conversation clearing with confirmation
8. Add typing indicators
9. Stream responses for real-time display
10. Add analytics for conversation tracking

## Troubleshooting

**Issue:** "API Key not configured" message
- **Solution:** Go to Settings and add your Gemini API key

**Issue:** Messages not appearing
- **Solution:** Ensure API key is valid and you have internet connection

**Issue:** Slow responses
- **Solution:** This is expected for the first request; Gemini API may have latency

**Issue:** Invalid API key error
- **Solution:** Get a new key from Google AI Studio and update in Settings

## Running the App

```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

Enjoy chatting with Gemini AI! 🚀
