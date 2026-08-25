import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/support_provider.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
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
    final state = ref.watch(supportProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ziko AI Support'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(supportProvider.notifier).resetChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: state.messages.length,
              itemBuilder: (context, index) {
                final message = state.messages[index];
                return _ChatBubble(message: message);
              },
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          
          // Suggestions at bottom
          _SuggestionsSection(onSelect: (displayText, apiText) {
            ref.read(supportProvider.notifier).sendMessage(apiText, displayMsg: displayText).then((_) {
              _scrollToBottom();
            });
          }),

          _InputSection(
            controller: _controller,
            onSend: () {
              final text = _controller.text;
              if (text.isEmpty) return;
              _controller.clear();
              ref.read(supportProvider.notifier).sendMessage(text).then((_) {
                _scrollToBottom();
              });
            },
          ),
        ],
      ),
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  final Function(String, String) onSelect;
  const _SuggestionsSection({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _QuickOption(label: 'অর্ডার কোথায়? 📦', onTap: () => onSelect('অর্ডার কোথায়? 📦', 'Check my order status. Respond in Bengali.')),
            _QuickOption(label: 'দেরি হচ্ছে কেন? ⏳', onTap: () => onSelect('দেরি হচ্ছে কেন? ⏳', 'My delivery is late. Respond in Bengali.')),
            _QuickOption(label: 'Order Status 📦', onTap: () => onSelect('Order Status 📦', 'Check my order status')),
            _QuickOption(label: 'Late Delivery ⏳', onTap: () => onSelect('Late Delivery ⏳', 'My delivery is late')),
            _QuickOption(label: 'Missing Items ❌', onTap: () => onSelect('Missing Items ❌', 'Some items are missing in my order')),
            _QuickOption(label: 'রিফান্ড পলিসি 💰', onTap: () => onSelect('রিফান্ড পলিসি 💰', 'Tell me about refund policy. Respond in Bengali.')),
            _QuickOption(label: 'Payment Issue 💳', onTap: () => onSelect('Payment Issue 💳', 'I had a problem with my payment')),
          ],
        ),
      ),
    );
  }
}

class _QuickOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        onPressed: onTap,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Message message;

  const _ChatBubble({required this.message});

  Future<void> _makeCall(String text) async {
    final RegExp phoneRegex = RegExp(r'\+?[0-9]{10,13}');
    final match = phoneRegex.firstMatch(text);
    if (match != null) {
      final number = match.group(0);
      final url = Uri.parse('tel:$number');
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasPhone = message.text.contains(RegExp(r'\+?[0-9]{10,13}'));

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: (!message.isUser && hasPhone) ? () => _makeCall(message.text) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser ? theme.primaryColor : Colors.grey[200],
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: message.isUser ? const Radius.circular(0) : null,
              bottomLeft: !message.isUser ? const Radius.circular(0) : null,
            ),
            border: (!message.isUser && hasPhone) ? Border.all(color: theme.primaryColor, width: 1) : null,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                ),
              ),
              if (!message.isUser && hasPhone)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('Click to call', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputSection({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -1),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Ask for help...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).primaryColor,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
