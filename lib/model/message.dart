class Message {
  final String id;
  final String message;
  final bool isUser;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.message,
    required this.isUser,
    required this.createdAt,
  });

  factory Message.user(String message) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      isUser: true,
      createdAt: DateTime.now(),
    );
  }

  factory Message.assistant(String message) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      isUser: false,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'message': message,
    'isUser': isUser,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      message: map['message'] ?? '',
      isUser: map['isUser'] ?? false,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}