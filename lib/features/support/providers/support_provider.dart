import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/groq_service.dart';
import '../../customer/providers/order_provider.dart';

class Message {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  Message({required this.text, required this.isUser, required this.timestamp});
}

class SupportState {
  final List<Message> messages;
  final bool isLoading;

  SupportState({required this.messages, this.isLoading = false});

  SupportState copyWith({List<Message>? messages, bool? isLoading}) {
    return SupportState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SupportNotifier extends StateNotifier<SupportState> {
  final GroqService _groqService;
  final Ref _ref;

  SupportNotifier(this._groqService, this._ref) : super(SupportState(messages: []));

  Future<void> _updateContext() async {
    try {
      final orders = _ref.read(customerOrdersProvider).value ?? [];
      if (orders.isEmpty) return;

      // Get the latest active order
      final activeOrder = orders.firstWhere(
        (o) => !['delivered', 'cancelled', 'rejected'].contains(o['status']),
        orElse: () => orders.first,
      );

      final businessId = activeOrder['business_id'];
      final riderId = activeOrder['rider_id'];
      final fullOrderId = activeOrder['id'].toString();
      final shortOrderId = fullOrderId.length > 8 ? fullOrderId.substring(0, 8).toUpperCase() : fullOrderId;

      String context = "Current active order ID: #$shortOrderId. Status: ${activeOrder['status']}.";

      // Fetch Restaurant Info
      final business = await Supabase.instance.client
          .from('businesses')
          .select('name, owner_phone')
          .eq('id', businessId)
          .single();
      
      context += " Restaurant: ${business['name']}. Owner Phone: ${business['owner_phone'] ?? 'Not available'}.";

      // Fetch Rider Info if assigned
      if (riderId != null && riderId.toString().isNotEmpty) {
        final riderProfile = await Supabase.instance.client
            .from('profiles')
            .select('name, phone')
            .eq('id', riderId)
            .single();
        context += " Rider: ${riderProfile['name']}. Rider Phone: ${riderProfile['phone'] ?? 'Not available'}.";
      } else {
        context += " Rider: Not yet assigned.";
      }

      _groqService.setOrderContext(context);
    } catch (e) {
      print('Error updating support context: $e');
    }
  }

  Future<void> sendMessage(String text, {String? displayMsg}) async {
    if (text.trim().isEmpty) return;

    final userMessage = Message(
      text: displayMsg ?? text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    // Update context before sending
    await _updateContext();

    final response = await _groqService.sendMessage(text);

    final botMessage = Message(
      text: response ?? 'Something went wrong. Please try again.',
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, botMessage],
      isLoading: false,
    );
  }

  void resetChat() {
    _groqService.resetChat();
    state = SupportState(messages: []);
  }
}

final groqServiceProvider = Provider((ref) => GroqService());

final supportProvider = StateNotifierProvider<SupportNotifier, SupportState>((ref) {
  final groqService = ref.watch(groqServiceProvider);
  return SupportNotifier(groqService, ref);
});
