import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_service.dart';

// 세션 내 임시 닉네임 (앱 실행 동안 유지)
String _myNickname = _genNickname();

String _genNickname() {
  const adjectives = ['빨간', '파란', '초록', '노란', '하얀', '검은'];
  const nouns = ['대원', '소방관', '지휘관', '구조대', '현장원'];
  final r = Random();
  return adjectives[r.nextInt(adjectives.length)] + nouns[r.nextInt(nouns.length)];
}

class ChatPanel extends StatefulWidget {
  final String sessionCode;
  const ChatPanel({super.key, required this.sessionCode});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  int _prevDocCount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.hasContentDimensions) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    try {
      await FirebaseService.instance
          .sendChatMessage(widget.sessionCode, _myNickname, text);
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.orange.shade50,
          child: Row(children: [
            Icon(Icons.chat_bubble_outline, size: 13, color: Colors.orange.shade700),
            const SizedBox(width: 5),
            Text('현장 채팅',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700)),
            const Spacer(),
            Text(_myNickname,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
        ),
        const Divider(height: 1),
        // 메시지 목록
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseService.instance.chatStream(widget.sessionCode),
            builder: (context, snap) {
              // 에러
              if (snap.hasError) {
                return Center(
                  child: Text('채팅 로드 오류\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.red.shade300)),
                );
              }
              // 로딩
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5)));
              }

              final docs = snap.data?.docs ?? [];

              // 새 메시지 왔을 때만 스크롤
              if (docs.length > _prevDocCount) {
                _prevDocCount = docs.length;
                _scrollToBottom();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text('메시지가 없습니다',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final sender = data['sender'] as String? ?? '';
                  final text = data['text'] as String? ?? '';
                  final isMe = sender == _myNickname;
                  return _ChatBubble(sender: sender, text: text, isMe: isMe);
                },
              );
            },
          ),
        ),
        // 입력창
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: '메시지 입력...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (_) => _send(),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 34,
              height: 34,
              child: Material(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: _send,
                  child:
                      const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String sender;
  final String text;
  final bool isMe;

  const _ChatBubble(
      {required this.sender, required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(sender,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.orange.shade500 : Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 12),
                    ),
                  ),
                  child: Text(text,
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              isMe ? Colors.white : Colors.grey.shade900,
                          height: 1.4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
