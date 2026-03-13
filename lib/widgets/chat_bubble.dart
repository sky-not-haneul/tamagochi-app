import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isCurrentUser;
  final DateTime timestamp;
  final String? senderName;
  final bool showSender;
  final bool showTime;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isCurrentUser,
    required this.timestamp,
    this.senderName,
    this.showSender = false,
    this.showTime = true,
  });

  String _formatTime() {
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    
    // 오전/오후 판별
    final String amPmStr = hour < 12 ? '오전' : '오후';
    
    // 12시간제로 변환 (0시는 12시로, 13시는 1시로)
    int displayHour = hour % 12;
    if (displayHour == 0) displayHour = 12;
    
    final displayMinute = minute.toString().padLeft(2, '0');

    // 앞에 \를 빼야 변수값이 들어갑니다!
    return '$amPmStr $displayHour:$displayMinute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && senderName != null)
            Align(
              alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                child: Text(
                  senderName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isCurrentUser && showTime) _buildTime(),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isCurrentUser ? 16 : 0),
                      bottomRight: Radius.circular(isCurrentUser ? 0 : 16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isCurrentUser && showTime) _buildTime(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTime() {
    return Text(
      _formatTime(),
      style: const TextStyle(
        fontSize: 12,
        color: Colors.grey,
      ),
    );
  }
}
