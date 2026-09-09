import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/support_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';

class SupportChatScreen extends ConsumerStatefulWidget {
  const SupportChatScreen({super.key});

  @override
  ConsumerState<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends ConsumerState<SupportChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final state = ref.watch(supportProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Ziko Branded Humanized Live Support Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
              left: 12,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: _buildAgentAvatar(radius: 20),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Ziko Live Support',
                            style: GoogleFonts.urbanist(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                      Text(
                        state.isLoading ? 'typing...' : 'সাপোর্ট এক্সিকিউটিভ • অনলাইন',
                        style: GoogleFonts.urbanist(
                          color: state.isLoading ? Colors.white : Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: state.isLoading ? FontWeight.w800 : FontWeight.w600,
                          fontStyle: state.isLoading ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Reset Chat',
                  onPressed: () => ref.read(supportProvider.notifier).resetChat(),
                ),
              ],
            ),
          ),

          // 2. Chat Messages Area (WhatsApp Style with Typing Bubble)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: state.messages.length + (state.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < state.messages.length) {
                  final message = state.messages[index];
                  return _ChatBubble(message: message);
                } else {
                  return const _TypingBubble();
                }
              },
            ),
          ),

          // 3. Quick Support Chips
          _SuggestionsSection(onSelect: (displayText, apiText) {
            ref.read(supportProvider.notifier).sendMessage(apiText, displayMsg: displayText).then((_) {
              _scrollToBottom();
            });
          }),

          // 4. Modern Input Section
          _InputSection(
            controller: _controller,
            focusNode: _focusNode,
            onSend: () {
              final text = _controller.text;
              if (text.trim().isEmpty) return;
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

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAgentAvatar(radius: 16),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final value = _controller.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (index) {
                    final delay = index * 0.25;
                    final animVal = ((value - delay) % 1.0);
                    final opacity = (animVal < 0.5 ? animVal * 2 : (1.0 - animVal) * 2).clamp(0.25, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: Opacity(
                        opacity: opacity,
                        child: const CircleAvatar(
                          radius: 3.5,
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildAgentAvatar({double radius = 20}) {
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFFFF3ED),
    child: ClipOval(
      child: Image.asset(
        'assets/images/support_agent.png',
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (context, error, stackTrace) {
          return CachedNetworkImage(
            imageUrl: 'https://img.freepik.com/free-psd/3d-rendering-avatar_23-2150833293.jpg',
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            placeholder: (c, u) => Container(color: const Color(0xFFFFF3ED)),
            errorWidget: (c, u, e) => const Icon(Icons.headset_mic_rounded, color: AppColors.primary, size: 20),
          );
        },
      ),
    ),
  );
}

class _SuggestionsSection extends StatelessWidget {
  final Function(String, String) onSelect;
  const _SuggestionsSection({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _QuickOption(label: 'আমার অর্ডারের অবস্থান 📦', onTap: () => onSelect('আমার অর্ডারের অবস্থান 📦', 'Check my order status. Respond politely in Bengali as a customer support executive.')),
            _QuickOption(label: 'ডেলিভারিতে দেরি হচ্ছে ⏳', onTap: () => onSelect('ডেলিভারিতে দেরি হচ্ছে ⏳', 'My delivery is late. Respond politely in Bengali as a customer support executive.')),
            _QuickOption(label: 'রিফান্ড ও ক্যানসেলেশন 💰', onTap: () => onSelect('রিফান্ড ও ক্যানসেলেশন 💰', 'Tell me about refund and cancellation. Respond in Bengali.')),
            _QuickOption(label: 'সাপোর্ট ম্যানেজারের নম্বর 📞', onTap: () => onSelect('সাপোর্ট নম্বর 📞', 'Give me customer care phone number. Respond in Bengali.')),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.isUser;
    final bool hasPhone = message.text.contains(RegExp(r'\+?[0-9]{10,13}'));
    final user = ref.watch(currentUserProvider).value;
    final userPic = user?.profileImageUrl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Support Executive Avatar on Left
          if (!isUser) ...[
            _buildAgentAvatar(radius: 16),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isUser ? 0.08 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.urbanist(
                      color: isUser ? Colors.white : AppColors.charcoal,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('hh:mm a').format(message.timestamp),
                    style: GoogleFonts.urbanist(
                      fontSize: 9,
                      color: isUser ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isUser && hasPhone) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _makeCall(message.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.call, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'সরাসরি কথা বলুন (Call Agent)',
                              style: GoogleFonts.urbanist(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Customer Avatar on Right
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: (userPic != null && userPic.isNotEmpty)
                  ? CachedNetworkImageProvider(userPic)
                  : null,
              child: (userPic == null || userPic.isEmpty)
                  ? const Icon(Icons.person, color: AppColors.primary, size: 18)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _InputSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;

  const _InputSection({required this.controller, this.focusNode, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'সাহায্যের জন্য মেসেজ টাইপ করুন...',
                  hintStyle: GoogleFonts.urbanist(fontSize: 13, color: Colors.grey.shade500),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
