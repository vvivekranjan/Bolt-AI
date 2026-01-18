import 'dart:developer' as console;

import 'package:ai_chat_bot/talk_screen.dart';
import 'package:ai_chat_bot/providers/gemini.dart';
// Firebase service import
import 'package:ai_chat_bot/providers/firebase_service.dart';
import 'package:ai_chat_bot/model/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ConsumerStatefulWidget> {
  late final TextEditingController _textFieldController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _textFieldController = TextEditingController();
  }

  @override
  void dispose() {
    super.dispose();
    _textFieldController.dispose();
  }

  void _stopGeneration() {
    setState(() {
      _isLoading = false;
    });
    // Remove the incomplete message
    ref.read(chatMessagesProvider.notifier).removeLastMessage();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Response generation stopped')),
    );
  }

  Future<void> _switchChat(String chatId) async {
    // Update current chat ID
    ref.read(currentChatIdProvider.notifier).setChatId(chatId);

    // Clear current messages
    ref.read(chatMessagesProvider.notifier).clearMessages();

    // Load chat history from Firebase and populate state
    try {
      final history = await ref.read(chatHistoryProvider(chatId).future);
      if (history.isNotEmpty) {
        ref.read(chatMessagesProvider.notifier).addMessages(history);
      }
    } catch (e) {
      console.log('Error loading chat history for $chatId: $e');
      // Keep messages cleared if loading fails
    }

    Navigator.pop(context); // Close drawer
  }

  void _startNewChat() {
    setState(() {
      _isLoading = false;
    });
    // Create new chat ID
    ref.read(currentChatIdProvider.notifier).createNewChat();

    // Clear all messages
    ref.read(chatMessagesProvider.notifier).clearMessages();

    // Clear input
    _textFieldController.clear();

    Navigator.pop(context); // Close drawer
  }

  Future<void> _deleteChat(String chatId) async {
    final firebaseService = ref.read(firebaseChatServiceProvider);

    try {
      await firebaseService.deleteChat(chatId);

      // Refresh the chat list
      ref.invalidate(allChatsProvider);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting chat: $e')));
    }
  }

  Future<void> _sendMessage() async {
    final userInput = _textFieldController.text.trim();

    if (userInput.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    // Add user message to state
    final userMessage = Message.user(userInput);
    ref.read(chatMessagesProvider.notifier).addMessage(userMessage);

    // Add empty assistant message that will be updated with streaming response
    final assistantMessage = Message.assistant('');
    ref.read(chatMessagesProvider.notifier).addMessage(assistantMessage);

    _textFieldController.clear();

    setState(() {
      _isLoading = true;
    });

    // Get Firebase service and current chat ID
    final firebaseService = ref.read(firebaseChatServiceProvider);
    // final currentChatId = ref.read(currentChatIdProvider);
    // final messages = ref.watch(chatMessagesProvider);

    // Save user message to Firebase immediately
    try {
      // Generate response from Gemini
      console.log('Requesting Gemini response for: $userInput');
      final responseText = await ref
          .read(geminiServiceProvider)
          .sendMessage(userInput);
      console.log('Gemini response received and processed');

      // Fire and forget saves - don't await them to prevent UI blocking
      firebaseService.saveMessage(userMessage).catchError((e) {
        console.log('Background save error (user): $e');
      });

      // Create and save assistant message
      final assistantMessageToSave = Message.assistant(responseText);
      firebaseService.saveMessage(assistantMessageToSave).catchError((e) {
        console.log('Background save error (assistant): $e');
      });

      // Invalidate provider locally so if the user switches chats or history reloads it's there
      // But we don't strictly need to wait for Firebase to confirm before letting the user type again.
      ref.invalidate(allChatsProvider);
    } catch (e) {
      console.log('Error saving user message: $e');
      ref.read(chatMessagesProvider.notifier).removeLastMessage();

      // Initialize chat metadata on first message
      try {
        String chatTitle = userInput.length > 50
            ? '${userInput.substring(0, 50)}...'
            : userInput;
        await firebaseService.saveChatMetadata(
          title: chatTitle,
          createdAt: DateTime.now(),
        );
      } catch (e) {
        console.log('Error saving initial chat metadata: $e');
      }

      // Remove the incomplete assistant placeholder on error
      ref.read(chatMessagesProvider.notifier).removeLastMessage();

      // Show error message with specific error type
      if (mounted) {
        String errorMessage = 'Error: ${e.toString()}';

        // Provide more user-friendly error messages
        if (e.toString().contains('timeout')) {
          errorMessage =
              'Request timed out. Please check your connection and try again.';
        } else if (e.toString().contains('No response')) {
          errorMessage = 'No response from API. Please try again.';
        } else if (e.toString().contains('network')) {
          errorMessage =
              'Network error. Please check your internet connection.';
        } else if (e.toString().contains('API key')) {
          errorMessage = 'API key error. Please check your configuration.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      console.log('Error sending message: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      // extendBodyBehindAppBar: true,
      drawer: _buildChatHistoryDrawer(),
      appBar: AppBar(
        title: const Text(
          'Bolt AI',
          style: TextStyle(fontSize: 36, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
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
                      MaterialPageRoute(
                        builder: (context) => const TalkScreen(),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    maxRadius: 22,
                    backgroundColor: Colors.grey.shade900,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.mic, size: 26, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 14, 14, 14),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(color: Color.fromARGB(255, 14, 14, 14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              flex: 1,
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start a conversation with Bolt AI',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      reverse: true,
                      child: Column(
                        children: messages
                            .map((message) => ChatContainer(message: message))
                            .toList(),
                      ),
                    ),
            ),
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: const Color.fromARGB(255, 14, 14, 14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextFormField(
                    controller: _textFieldController,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.newline,
                    autofocus: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade900,
                      focusColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      hintText: "Ask Anything",
                      hintStyle: TextStyle(
                        fontSize: 20,
                        color: Colors.grey.shade700,
                      ),
                      suffixIcon: _isLoading
                          ? IconButton(
                              onPressed: _stopGeneration,
                              icon: const Icon(
                                Icons.stop,
                                size: 36,
                                color: Color(0xFFFF0000),
                              ),
                              tooltip: 'Stop generating',
                              padding: const EdgeInsets.only(right: 8.0),
                            )
                          : IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(
                                Icons.send_rounded,
                                size: 26,
                                color: Color.fromARGB(255, 210, 28, 28),
                              ),
                            ),
                    ),
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                    autocorrect: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryDrawer() {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 20, 20, 20),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 14, 14, 14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chat History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _startNewChat,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'New Chat',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 210, 28, 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref
                .watch(allChatsProvider)
                .when(
                  data: (chats) {
                    if (chats.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No chats yet',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final chatId = chat['id'] as String;
                        final title =
                            chat['title'] as String? ?? 'Untitled Chat';
                        final createdAt = chat['createdAt'] as String?;

                        // Parse and format date
                        DateTime chatDate = DateTime.now();
                        if (createdAt != null) {
                          try {
                            chatDate = DateTime.parse(createdAt);
                          } catch (e) {
                            // Use current date if parsing fails
                          }
                        }

                        final dateString = _formatChatDate(chatDate);

                        return Dismissible(
                          key: Key(chatId),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            _showDeleteConfirmation(chatId, title);
                            return false;
                          },
                          child: ListTile(
                            leading: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            subtitle: Text(
                              dateString,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => _switchChat(chatId),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _showDeleteConfirmation(chatId, title),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _formatChatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final chatDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (chatDate == today) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (chatDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(chatDate).inDays < 7) {
      return '${now.difference(chatDate).inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showDeleteConfirmation(String chatId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteChat(chatId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ChatContainer extends StatefulWidget {
  const ChatContainer({super.key, required this.message});

  final Message message;

  @override
  State<ChatContainer> createState() => _ChatContainerState();
}

class _ChatContainerState extends State<ChatContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotAnimationController;

  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dotAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingResponse =
        !widget.message.isUser && widget.message.message.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: (widget.message.isUser)
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.message.isUser)
            const Icon(Icons.star, color: Colors.white),
          Container(
            alignment: (widget.message.isUser)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              color: (widget.message.isUser)
                  ? Colors.grey.shade900
                  : Colors.transparent,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: isLoadingResponse
                  ? AnimatedBuilder(
                      animation: _dotAnimationController,
                      builder: (context, child) {
                        final progress = _dotAnimationController.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Generating',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 40,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _AnimatedDot(progress: progress, delay: 0.0),
                                  _AnimatedDot(progress: progress, delay: 0.33),
                                  _AnimatedDot(progress: progress, delay: 0.66),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Text(
                      widget.message.message,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      textAlign: TextAlign.left,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final double progress;
  final double delay;

  const _AnimatedDot({required this.progress, required this.delay});

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = ((progress + delay) % 1.0);
    final opacity =
        (sin(normalizedProgress * pi * 2) + 1) / 2; // Pulsing effect

    return Opacity(
      opacity: opacity,
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}
