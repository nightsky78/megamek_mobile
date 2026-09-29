import 'package:flutter/material.dart';

/// Shared chat widget (Lobby + Game "Chat" bottom sheet, Phase 3: "Bottom-
/// Sheets/Tabs für ... Chat ... statt nebeneinander angeordneter Panels").
class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key, required this.chatLog, required this.onSend});

  final List<String> chatLog;
  final void Function(String text) onSend;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.chatLog.length != oldWidget.chatLog.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: widget.chatLog.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: widget.chatLog.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(widget.chatLog[index]),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSend(text);
    _controller.clear();
  }
}
