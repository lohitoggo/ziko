import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/cart_item_model.dart';
import '../../../core/notifications/notification_service.dart';

class OrderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================
  // Watch Customer Orders
  // =========================
  Stream<List<Map<String, dynamic>>> watchCustomerOrders(String customerUid) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerUid)
        .order('placed_at', ascending: false)
        .map<List<Map<String, dynamic>>>((data) => data.map((d) => {...d, 'orderId': d['id']}).toList())
        .handleError((error) {
          debugPrint('SUPABASE REALTIME ERROR (Orders): $error');
        });
  }

  // =========================
  // Watch Single Order
  // =========================
  Stream<Map<String, dynamic>?> watchOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map<Map<String, dynamic>?>((data) => data.isEmpty ? null : {...data.first, 'orderId': data.first['id']})
        .handleError((error) {
          debugPrint('SUPABASE REALTIME ERROR (Single Order): $error');
        });
  }

  // =========================
  // Watch Order Items
  // =========================
  Stream<List<Map<String, dynamic>>> watchOrderItems(String orderId) {
    return _supabase
        .from('order_items')
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .map((data) => data);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) async {
    final response = await _supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return List<Map<String, dynamic>>.from(response);
  }

  // =========================
  // Cancel Order (Customer)
  // =========================
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final orderData = await _supabase.from('orders').select().eq('id', orderId).maybeSingle();
    if (orderData == null) return;

    final status = orderData['status'] ?? 'placed';
    if (status != 'placed') {
      throw Exception('দোকানদার কাজ শুরু করে দেওয়ায় এই অর্ডারটি আর বাতিল করা সম্ভব নয়।');
    }

    try {
      await _supabase.from('orders').update({
        'status': 'cancelled',
        'cancellation_reason': reason ?? 'Cancelled by Customer',
      }).eq('id', orderId);
    } catch (e) {
      // Fallback if cancellation_reason column does not exist yet in Postgres
      await _supabase.from('orders').update({
        'status': 'cancelled',
      }).eq('id', orderId);
    }

    // Auto Refund if paid
    final paymentStatus = orderData['payment_status'] ?? 'pending';
    final customerUid = orderData['customer_id'];
    final total = ((orderData['total_amount'] ?? 0) as num).toDouble();

    if ((paymentStatus == 'paid' || orderData['payment_method'] == 'wallet') && customerUid != null && total > 0) {
      try {
        await _supabase.from('wallet_transactions').insert({
          'user_id': customerUid,
          'amount': total,
          'type': 'credit',
          'title': 'অর্ডার ক্যানসেলেশন রিফান্ড',
          'description': 'অর্ডার ক্যানসেল হওয়ায় ব্যালেন্স রিফান্ড হয়েছে',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Wallet refund error: $e');
      }
    }
  }

  // =========================
  // Place Order
  // =========================
  Future<String> placeOrder({
    required String customerUid,
    required String restaurantId,
    required String areaId,
    required List<CartItem> items,
    required double subtotal,
    required double deliveryCharge,
    required double platformFee,
    required double gst,
    required double totalAmount,
    required String paymentMethod,
    required String paymentStatus,
    String? paymentId,
    double? latitude,
    double? longitude,
    String? houseNumber,
    String? village,
    String? landmark,
    String? pinCode,
    String? deliveryNote,
    String? appointmentTime,
  }) async {
    final Map<String, dynamic> orderData = {
      'customer_id': customerUid,
      'business_id': restaurantId,
      'area_id': areaId,
      'status': 'placed',
      'total_amount': totalAmount,
      'delivery_charge': deliveryCharge,
      'platform_fee': platformFee,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'customer_lat': latitude,
      'customer_lon': longitude,
      'house_number': houseNumber,
      'village': village,
      'landmark': landmark,
      'pin_code': pinCode,
      'delivery_note': deliveryNote,
      'appointment_time': appointmentTime,
      'placed_at': DateTime.now().toIso8601String(),
    };

    if (paymentId != null) {
      orderData['payment_id'] = paymentId;
    }

    try {
      final orderResponse = await _supabase.from('orders').insert(orderData).select().single();
      final orderId = orderResponse['id'];

      final List<Map<String, dynamic>> orderItems = items.map((item) => {
        'order_id': orderId,
        'item_id': item.food.id,
        'name': item.food.name,
        'price': item.food.finalPrice,
        'quantity': item.quantity,
        'subtotal': item.subtotal,
      }).toList();

      await _supabase.from('order_items').insert(orderItems);

      // --- Send Notification to Owner ---
      try {
        // Validate if restaurantId is a valid UUID before querying
        final bool isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(restaurantId);
        
        if (isValidUuid) {
          final business = await _supabase.from('businesses').select('owner_id, name').eq('id', restaurantId).maybeSingle();
          
          if (business != null) {
            final ownerId = business['owner_id'];
            final customerProfile = await _supabase.from('profiles').select('name').eq('id', customerUid).maybeSingle();
            final realCustomerName = customerProfile?['name'] ?? 'Customer';

            if (ownerId != null) {
              final profile = await _supabase.from('profiles').select('notification_id').eq('id', ownerId).maybeSingle();
              final ownerNotificationId = profile?['notification_id'];
              
              if (ownerNotificationId != null) {
                final itemsList = items.map((i) => '${i.quantity}x ${i.food.name}').join(', ');

                await NotificationService.sendNotification(
                  targetNotificationId: ownerNotificationId,
                  title: 'নতুন অর্ডার এসেছে! 🛍️',
                  content: '$realCustomerName একটি নতুন অর্ডার দিয়েছেন (${business['name']})।',
                  data: {
                    'action': 'incoming_order_call',
                    'callId': Uuid().v4(),
                    'orderId': orderId,
                    'amount': totalAmount.toString(),
                    'customerName': realCustomerName,
                    'items': itemsList, 
                    'appointment': appointmentTime ?? '',
                    'type': 'owner',
                    'timeoutSeconds': 30,
                  },
                );
              }
            }
          }
        }
      } catch (e) {
        print('Notification error skipped: $e');
      }

      return orderId;
    } catch (e) {
      print('CRITICAL REPOSITORY ERROR: $e');
      rethrow;
    }
  }
}
