
import 'package:firebase_database/firebase_database.dart';

class ChatMessage {
  final String id;
  final String sender;
  final String text;
  final String? content;
  final String timestamp;

  final String? q; // For AI logs
  final String? a; // For AI logs

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.content,
    this.q,
    this.a,
  });

  factory ChatMessage.fromMap(String key, Map<dynamic, dynamic> data) {
    // Check if it's an AI log (has 'q' and 'a') or a regular chat (has 'content')
    final isAiLog = data.containsKey('q') && data.containsKey('a');
    
    final timeValue = data['time'] as int?;
    String timestamp = '';
    
    if (timeValue != null) {
      final int millis = timeValue < 10000000000 ? timeValue * 1000 : timeValue;
      timestamp = DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
    }

    if (isAiLog) {
      return ChatMessage(
        id: key,
        sender: 'ai',
        text: data['a']?.toString() ?? '',
        q: data['q']?.toString() ?? '',
        a: data['a']?.toString() ?? '',
        timestamp: timestamp,
      );
    }

    return ChatMessage(
      id: key,
      sender: data['sender']?.toString() ?? 'unknown',
      text: data['content']?.toString() ?? '',
      content: data['content']?.toString(),
      timestamp: timestamp,
    );
  }
}

class ChatService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Future<DataSnapshot> fetchAiLog(String deviceId) {
    return _db.ref('$deviceId/ai_log').get();
  }

  /// Get a stream of AI chat messages for a specific device
  Stream<List<ChatMessage>> getAiChatStream(String deviceId) {
    final ref = _db.ref('$deviceId/ai_log');
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final Map<dynamic, dynamic> map = data as Map<dynamic, dynamic>;
      final List<ChatMessage> messages = [];

      map.forEach((key, value) {
        final messageData = value as Map<dynamic, dynamic>;
        messages.add(ChatMessage.fromMap(key.toString(), messageData));
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }

  /// Get a stream of Parent chat messages for a specific device
  Stream<List<ChatMessage>> getParentChatStream(String deviceId) {
    final ref = _db.ref('$deviceId/chat');
    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final Map<dynamic, dynamic> map = data as Map<dynamic, dynamic>;
      final List<ChatMessage> messages = [];

      map.forEach((key, value) {
        final messageData = value as Map<dynamic, dynamic>;
        messages.add(ChatMessage.fromMap(key.toString(), messageData));
      });

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    });
  }



  /// Send a message to Family Chat
  Future<void> sendFamilyMessage(String deviceId, String text, String sender) async {
    // 1. 타임스탬프 생성 (초 단위: 10자리)
    // 현재 milliseconds(13자리)를 1000으로 나누어 초 단위(10자리)로 만듭니다.
    final int timestamp = DateTime.now().millisecondsSinceEpoch;

    // 2. 경로 설정: push() 대신 직접 msg_타임스탬프 키를 생성
    final ref = _db.ref('$deviceId/chat/msg_$timestamp');

    await ref.set({
      'sender': sender,
      'content': text,
      'time': timestamp, // 'timestamp' 대신 예시의 'time'으로 이름 변경
    });
  }
}
