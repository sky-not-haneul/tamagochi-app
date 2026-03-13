import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_input_field.dart';
import '../../controllers/device_controller.dart';
import '../../services/chat_service.dart';
import '../../services/device_service.dart';

class FamilyChatTab extends StatefulWidget {
  const FamilyChatTab({super.key});

  @override
  State<FamilyChatTab> createState() => _FamilyChatTabState();
}

class _FamilyChatTabState extends State<FamilyChatTab> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage(String deviceId, String text) async {
    if (text.trim().isEmpty) return;
    String senderRole = 'family'; // Default from 'parent' to 'family'
    try {
      final deviceService = DeviceService();
      final familyMap = await deviceService.fetchFamilyRole(deviceId);
      if (familyMap != null && familyMap.isNotEmpty) {
        final first = familyMap.values.first;
        if (first is Map && first['role'] != null) {
          senderRole = first['role'].toString();
        }
      }
    } catch (e) {
      // ignore, fallback to 'family'
    }
    await _chatService.sendFamilyMessage(deviceId, text, senderRole);
    _scrollToBottom();
  }

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

    final String userRole = activeDevice.userRole;
    final messages = deviceController.getFamilyMessages(activeDevice.id);

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('가족에게 첫 메시지를 보내보세요.'))
              : _buildChatContent(messages, activeDevice, userRole),
        ),
        ChatInputField(onSend: (text) => _sendMessage(activeDevice.id, text)),
      ],
    );
  }

  Widget _buildChatContent(List<ChatMessage> messages, Device activeDevice, String userRole) {
    final List<Widget> chatWidgets = [];
    DateTime? lastDate;
    String? lastSender;
    DateTime? lastDt;

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final isChild = msg.sender == 'child';
      final text = msg.content ?? msg.text;
      DateTime dt;
      try {
        dt = DateTime.parse(msg.timestamp);
      } catch (e) {
        dt = DateTime.now();
      }

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

      bool showTime = true;
      if (i < messages.length - 1) {
        final nextMsg = messages[i + 1];
        try {
          final nextDt = DateTime.parse(nextMsg.timestamp);
          if (nextMsg.sender == msg.sender &&
              nextDt.year == dt.year &&
              nextDt.month == dt.month &&
              nextDt.day == dt.day &&
              nextDt.hour == dt.hour &&
              nextDt.minute == dt.minute) {
            showTime = false;
          }
        } catch (e) {}
      }

      bool showSender = false;
      if (lastSender != msg.sender || (lastDt != null && (dt.hour != lastDt.hour || dt.minute != lastDt.minute))) {
        showSender = true;
      }

      final bool isMe = msg.sender == userRole;
      final senderName = isChild ? activeDevice.childName : (isMe ? '나' : msg.sender);

      chatWidgets.add(ChatBubble(
        text: text,
        isCurrentUser: !isChild,
        timestamp: dt,
        senderName: senderName,
        showSender: showSender,
        showTime: showTime,
      ));

      lastSender = msg.sender;
      lastDt = dt;
    }

    // 자동 스크롤 하단 이동
    _scrollToBottom();

    return ListView(
      controller: _scrollController,
      shrinkWrap: true, // column 안에 있을 때 필요할 수 있음
      physics: const AlwaysScrollableScrollPhysics(), // 스크롤 가능하도록 수정
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      children: chatWidgets,
    );
  }
}


