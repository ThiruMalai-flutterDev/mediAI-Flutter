class ChatSession {
  final String id;
  final String title;
  final String lastMessagePreview;
  final DateTime lastUpdated;
  final bool medicalMode;
  final bool mediAiMode;

  ChatSession({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
    required this.lastUpdated,
    required this.medicalMode,
    required this.mediAiMode,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      title: json['title'] ?? 'New Chat Session',
      lastMessagePreview: json['last_message_preview'] ?? 'No messages yet.',
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? '') ?? DateTime.now(),
      medicalMode: json['medical_mode'] ?? true,
      mediAiMode: json['medi_ai_mode'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'last_message_preview': lastMessagePreview,
      'last_updated': lastUpdated.toIso8601String(),
      'medical_mode': medicalMode,
      'medi_ai_mode': mediAiMode,
    };
  }

  // Helper method to get formatted date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastUpdated.day}/${lastUpdated.month}/${lastUpdated.year}';
    }
  }

  // Helper method to get AI mode display text
  String get aiModeText {
    return mediAiMode ? 'MediAI' : 'General AI';
  }
}
