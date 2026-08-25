import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/order_repository.dart';
import '../../auth/providers/user_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});

final customerOrdersProvider =
StreamProvider<List<Map<String, dynamic>>>((ref) {
  // CRITICAL FIX: Only watch the uid to avoid loop with profile updates
  final uid = ref.watch(currentUserProvider.select((u) => u.value?.uid));
  
  if (uid == null) return Stream.value([]);
  
  return ref.watch(orderRepositoryProvider)
      .watchCustomerOrders(uid)
      .handleError((e) {
        debugPrint('SUPABASE ORDER REALTIME ERROR: $e');
      });
});

final singleOrderProvider =
StreamProvider.family<Map<String, dynamic>?, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrder(orderId);
});

final orderItemsProvider =
StreamProvider.family<List<Map<String, dynamic>>, String>((ref, orderId) {
  return ref.watch(orderRepositoryProvider).watchOrderItems(orderId);
});

final businessBookedSlotsProvider = StreamProvider.family<List<String>, String>((ref, paramString) {
  // paramString format: "businessId|dateStr"
  final parts = paramString.split('|');
  if (parts.length < 2) return Stream.value([]);
  
  final String businessId = parts[0];
  final String dateStr = parts[1];

  return Supabase.instance.client
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('business_id', businessId)
      .map((data) {
        final List<String> slots = [];
        for (var o in data) {
          final String? appTime = o['appointment_time'];
          final String status = o['status'] ?? 'placed';
          
          if (appTime != null && !['cancelled', 'rejected'].contains(status)) {
            // Check if it's the right date and extract EXACT times
            if (appTime.contains(dateStr)) {
              final parts = appTime.split('|');
              if (parts.length > 1) {
                final String timesPart = parts.last.trim();
                // HIGH PRECISION: Split by comma and add each 15-min segment
                final List<String> segments = timesPart.split(',').map((s) => s.trim()).toList();
                slots.addAll(segments); 
              }
            }
          }
        }
        return slots.toSet().toList(); // Unique global busy segments
      });
});
