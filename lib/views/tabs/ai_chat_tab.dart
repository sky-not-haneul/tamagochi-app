import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/chat_bubble.dart';
import '../../controllers/device_controller.dart';

class AiChatTab extends StatefulWidget {
  const AiChatTab({super.key});

  @override
  State<AiChatTab> createState() => _AiChatTabState();
}

class _AiChatTabState extends State<AiChatTab> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceController = Provider.of<DeviceController>(context);
    final activeDevice = deviceController.activeDevice;

    if (activeDevice == null) {
      return const Center(
        child: Text('상단에서 기기를 선택해주세요.', style: TextStyle(fontSize: 16)),
      );
    }

    final messages = deviceController.getAiMessages(activeDevice.id);
    if (messages.isEmpty) {
      return const Center(child: Text('AI 대화 기록이 없습니다.'));
    }

    final List<Widget> chatWidgets = [];
    DateTime? lastDate;
    String? lastSender;
    DateTime? lastDt;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      DateTime dt;
      try {
        dt = DateTime.parse(msg.timestamp);
      } catch (e) {
        dt = DateTime.now();
      }

      // 날짜 구분선
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      if (lastDate == null || dateOnly != lastDate) {
        chatWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Center(
              child: Text(
                '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
        lastDate = dateOnly;
        lastSender = null;
        lastDt = null;
      }

      // 질문 버블 (사용자 질문)
      if (msg.q != null && msg.q!.isNotEmpty) {
        bool showSender = false;
        if (lastSender != 'user' || (lastDt != null && (dt.hour != lastDt.hour || dt.minute != lastDt.minute))) {
          showSender = true;
        }

        // 질문의 시간 표시 여부 결정
        bool showTime = true;
        if (msg.a != null && msg.a!.isNotEmpty) {
          showTime = false;
        } else if (i < messages.length - 1) {
          final nextMsg = messages[i + 1];
          if (nextMsg.q != null && nextMsg.q!.isNotEmpty) {
            try {
              final nextDt = DateTime.parse(nextMsg.timestamp);
              if (nextDt.year == dt.year && nextDt.month == dt.month && nextDt.day == dt.day && nextDt.hour == dt.hour && nextDt.minute == dt.minute) {
                showTime = false;
              }
            } catch(e) {}
          }
        }

        chatWidgets.add(ChatBubble(
          text: msg.q!,
          isCurrentUser: true,
          timestamp: dt,
          senderName: activeDevice.childName,
          showSender: showSender,
          showTime: showTime,
        ));
        lastSender = 'user';
        lastDt = dt;
      }

      // 답변 버블 (AI 답변)
      if (msg.a != null && msg.a!.isNotEmpty) {
        bool showSender = false;
        if (lastSender != 'ai' || (lastDt != null && (dt.hour != lastDt.hour || dt.minute != lastDt.minute))) {
          showSender = true;
        }

        // 답변의 시간 표시 여부 결정
        bool showTime = true;
        if (i < messages.length - 1) {
          final nextMsg = messages[i + 1];
          if (nextMsg.a != null && nextMsg.a!.isNotEmpty) {
            try {
              final nextDt = DateTime.parse(nextMsg.timestamp);
              if (nextDt.year == dt.year && nextDt.month == dt.month && nextDt.day == dt.day && nextDt.hour == dt.hour && nextDt.minute == dt.minute) {
                showTime = false;
              }
            } catch(e) {}
          }
        }

        chatWidgets.add(ChatBubble(
          text: msg.a!,
          isCurrentUser: false,
          timestamp: dt,
          senderName: '다마고치',
          showSender: showSender,
          showTime: showTime,
        ));
        lastSender = 'ai';
        lastDt = dt;
      }
    }

    _scrollToBottom();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      children: chatWidgets,
    );
  }
}

