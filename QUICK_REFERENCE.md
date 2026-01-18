# Quick Reference Guide

## 🎯 Common Tasks

### 1. Access Chat Messages
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final messages = ref.watch(chatMessagesProvider);
  
  return ListView(
    children: messages.map((msg) => MessageTile(message: msg)).toList(),
  );
}
```

### 2. Send Message to Gemini
```dart
Future<void> sendMessage(String userMessage) async {
  // Add user message
  ref.read(chatMessagesProvider.notifier).addMessage(
    Message.user(userMessage),
  );
  
  // Get response
  try {
    final response = await ref.read(
      sendChatMessageProvider(userMessage).future
    );
    
    // Add AI response
    ref.read(chatMessagesProvider.notifier).addMessage(
      Message.assistant(response),
    );
  } catch (e) {
    print('Error: $e');
  }
}
```

### 3. Clear Chat History
```dart
ref.read(chatMessagesProvider.notifier).clearMessages();
```

### 4. Check if API Key is Set
```dart
final apiKeyAsync = ref.watch(apiKeyProvider);

apiKeyAsync.when(
  data: (apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      // Show "Configure API Key" message
    }
  },
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

### 5. Save API Key Programmatically
```dart
Future<void> setApiKey(String newKey) async {
  await ref.read(apiKeySetterProvider)(newKey);
  
  // Refresh model with new key
  ref.invalidate(geminiModelProvider);
  ref.invalidate(chatSessionProvider);
}
```

### 6. Remove Last Message
```dart
ref.read(chatMessagesProvider.notifier).removeLastMessage();
```

### 7. Add Multiple Messages at Once
```dart
List<Message> messagesList = [
  Message.user('Hello'),
  Message.assistant('Hi there!'),
];

ref.read(chatMessagesProvider.notifier).addMessages(messagesList);
```

---

## 📋 State Management Cheat Sheet

### Watching State (Read-only)
```dart
final messages = ref.watch(chatMessagesProvider);
final apiKey = ref.watch(apiKeyProvider);
```

### Reading State (One-time)
```dart
final messages = ref.read(chatMessagesProvider);
```

### Modifying State
```dart
ref.read(chatMessagesProvider.notifier).addMessage(msg);
```

### Invalidating Providers (Refresh)
```dart
ref.invalidate(geminiModelProvider);
ref.invalidate(chatSessionProvider);
ref.invalidate(apiKeyProvider);
```

---

## 🎨 UI Components

### Message Container
```dart
ChatContainer(
  message: Message(
    id: '1',
    message: 'Hello',
    isUser: true,
    createdAt: DateTime.now(),
  ),
)
```

### Error SnackBar
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Error message'),
    backgroundColor: Colors.red,
  ),
);
```

### Loading Indicator
```dart
if (_isLoading)
  CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation(Colors.white),
  )
```

---

## 🔍 Debugging

### Print Provider Values
```dart
ref.listen(chatMessagesProvider, (previous, next) {
  print('Messages changed: $next');
});
```

### Check API Key Status
```dart
final apiKey = await ref.read(apiKeyProvider.future);
print('API Key: ${apiKey != null ? "Set" : "Not Set"}');
```

### Monitor Provider State
```dart
ref.listen(sendChatMessageProvider('test'), (previous, next) {
  print('API Response: $next');
});
```

---

## 🚀 Performance Tips

### 1. Memoize Messages List
```dart
final messages = ref.watch(chatMessagesProvider);
// Only rebuilds when messages change
```

### 2. Use Select for Partial Watching
```dart
// Watch only count instead of entire list
final messageCount = ref.watch(
  chatMessagesProvider.select((msgs) => msgs.length)
);
```

### 3. Invalidate Strategically
```dart
// Only invalidate what changed
ref.invalidate(geminiModelProvider);
// Don't invalidate if only messages changed
```

### 4. Use Future.delayed for Loading
```dart
Future<String> simulateDelay() async {
  await Future.delayed(Duration(seconds: 1));
  return 'Done';
}
```

---

## 🔐 Security Checklist

- [ ] Never hardcode API keys
- [ ] Always store in SharedPreferences/Keychain
- [ ] Validate API key before using
- [ ] Handle API errors gracefully
- [ ] Clear sensitive data on logout
- [ ] Use HTTPS only
- [ ] Don't log API keys

---

## 📦 Dependencies Reference

```yaml
google_generative_ai: ^0.4.0
  # Google's official Gemini AI SDK
  # Models: gemini-pro, gemini-1.5-pro
  
shared_preferences: ^2.2.2
  # Local data persistence
  # Suitable for: settings, keys, cache
  
flutter_riverpod: ^3.0.3
  # State management and dependency injection
  # Reactive, testable, powerful
```

---

## 🧪 Testing Examples

### Test Message Addition
```dart
test('Should add user message', () {
  final container = ProviderContainer();
  
  container.read(chatMessagesProvider.notifier).addMessage(
    Message.user('Test'),
  );
  
  final messages = container.read(chatMessagesProvider);
  expect(messages.length, 1);
  expect(messages[0].isUser, true);
});
```

### Test API Key Retrieval
```dart
test('Should retrieve stored API key', () async {
  final container = ProviderContainer();
  
  // Mock SharedPreferences if needed
  
  final apiKey = await container.read(apiKeyProvider.future);
  expect(apiKey, isNotNull);
});
```

---

## 🎓 Learning Resources

### Riverpod
- [Official Docs](https://riverpod.dev)
- Watch this for state changes
- Read for one-time access
- Listen for side effects

### Google Generative AI
- [API Documentation](https://ai.google.dev)
- [Model Info](https://ai.google.dev/models)
- Text generation, streaming, chat

### Flutter Best Practices
- Use const constructors
- Dispose resources properly
- Prefer immutable state
- Handle errors explicitly

---

## 🔗 Quick Links

- **Settings Screen**: `SettingsScreen()`
- **Chat Screen**: `ChatScreen()`
- **Providers**: `lib/providers/gemini.dart`
- **Message Model**: `lib/model/message.dart`
- **Full Guide**: `GEMINI_INTEGRATION.md`
- **Implementation Details**: `IMPLEMENTATION_SUMMARY.md`

---

## ⚡ Hot Tips

1. **Always validate API key before operations**
   ```dart
   if (apiKey == null) return;
   ```

2. **Use try-catch for API calls**
   ```dart
   try {
     // API call
   } catch (e) {
     // Handle error
   }
   ```

3. **Show loading states**
   ```dart
   setState(() => _isLoading = true);
   // ... do work
   setState(() => _isLoading = false);
   ```

4. **Invalidate after mutations**
   ```dart
   await ref.read(apiKeySetterProvider)(newKey);
   ref.invalidate(geminiModelProvider);
   ```

5. **Message constraints for better UI**
   ```dart
   ConstrainedBox(
     constraints: BoxConstraints(maxWidth: 300),
     child: Text(message),
   )
   ```

---

## 🆘 SOS Quick Fixes

| Problem | Solution |
|---------|----------|
| API key not found | Go to Settings → Save API key |
| Empty messages | Check if API key is set |
| Slow responses | First request is normal |
| Can't send messages | Verify internet connection |
| Messages disappeared | Refresh/reload app |
| Error on API call | Check API key validity |

---

**Happy Coding! 🎉**
