# Updated main.dart with Settings Navigation

If you want to add a Settings button to navigate to the Settings screen, update your `main.dart` or integrate the Settings screen into your existing navigation.

## Option 1: Add Settings Button to Chat Screen AppBar

In `lib/chat_screen.dart`, add the following import:

```dart
import 'package:ai_chat_bot/settings_screen.dart';
```

Then update the AppBar actions list:

```dart
actions: [
  // Settings Button
  Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          child: CircleAvatar(
            maxRadius: 22,
            backgroundColor: Colors.grey.shade900,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.settings,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  // Existing Mic Button
  Padding(
    padding: const EdgeInsets.only(right: 16.0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TalkScreen()),
            );
          },
          child: CircleAvatar(
            maxRadius: 22,
            backgroundColor: Colors.grey.shade900,
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.mic,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
],
```

---

## Option 2: Add Settings to Navigation Drawer

Create a drawer in your Chat Screen:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final messages = ref.watch(chatMessagesProvider);
  final apiKeyAsync = ref.watch(apiKeyProvider);

  return Scaffold(
    drawer: Drawer(
      child: Container(
        color: const Color.fromARGB(255, 14, 14, 14),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 210, 28, 28),
              ),
              child: const Text(
                'vox AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text(
                'Settings',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.white),
              title: const Text(
                'Clear Chat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                ref.read(chatMessagesProvider.notifier).clearMessages();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat cleared'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info, color: Colors.white),
              title: const Text(
                'About',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'vox AI',
                  applicationVersion: '1.0.0',
                  children: [
                    const Text('An AI Chat Bot powered by Google Gemini'),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
    // ... rest of scaffold
  );
}
```

---

## Option 3: Add Settings to OnBoarding/Home Screen

If you have an `OnBoarding` or home screen, add a settings button there:

```dart
class OnBoarding extends StatelessWidget {
  const OnBoarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat Bot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      // ... rest of onboarding
    );
  }
}
```

---

## Option 4: Add Settings Route to Navigation

For a more advanced setup, add Settings route to your main.dart:

```dart
import 'package:ai_chat_bot/chat_screen.dart';
import 'package:ai_chat_bot/settings_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'vox AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routes: {
        '/': (context) => const ChatScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      home: const ChatScreen(),
    );
  }
}

// Then navigate using named routes:
Navigator.pushNamed(context, '/settings');
```

---

## Quick Integration Checklist

- [ ] Import SettingsScreen in your file
- [ ] Add settings navigation (choose one option above)
- [ ] Test navigation works
- [ ] Verify settings screen loads
- [ ] Test API key save functionality
- [ ] Test API key clear functionality
- [ ] Verify chat works after saving API key

---

## Common Navigation Patterns

### After Saving API Key
```dart
// Return to Chat Screen automatically
if (mounted) {
  Navigator.pop(context); // Close settings
}
```

### Check API Key Before Enabling Chat
```dart
final apiKeyAsync = ref.watch(apiKeyProvider);

apiKeyAsync.when(
  data: (apiKey) {
    if (apiKey == null || apiKey.isEmpty) {
      // Show settings button
    }
  },
  loading: () => const CircularProgressIndicator(),
  error: (err, stack) => Text('Error: $err'),
);
```

### Navigate to Settings from Chat
```dart
FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  },
  child: const Icon(Icons.settings),
)
```

---

## Testing Navigation

```dart
// In widget test
testWidgets('Navigate to settings', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  
  expect(find.byType(SettingsScreen), findsOneWidget);
});
```

---

**Choose the option that best fits your app architecture!**
