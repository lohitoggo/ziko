import 'package:supabase_flutter/supabase_flutter.dart';
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
        .map((data) => data.map((d) => {...d, 'orderId': d['id']}).toList());
  }

  // =========================
  // Watch Single Order
  // =========================
  Stream<Map<String, dynamic>?> watchOrder(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) => data.isEmpty ? null : {...data.first, 'orderId': data.first['id']});
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
      print('--- DEBUG: PLACING ORDER DATA ---');
      orderData.forEach((key, value) => print('$key: $value (${value.runtimeType})'));
      
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

      // --- Send Notification to Owner WITH NEW CALL PROTOCOL ---
      try {
        final business = await _supabase.from('businesses').select('owner_id, name').eq('id', restaurantId).single();
        final ownerId = business['owner_id'];
        
        final customerProfile = await _supabase.from('profiles').select('name').eq('id', customerUid).single();
        final realCustomerName = customerProfile['name'] ?? 'Customer';

        if (ownerId != null) {
          final profile = await _supabase.from('profiles').select('notification_id').eq('id', ownerId).single();
          final ownerNotificationId = profile['notification_id'];
          
          if (ownerNotificationId != null) {
            final itemsList = items.map((i) => '${i.quantity}x ${i.food.name}').join(', ');

            await NotificationService.sendNotification(
              targetNotificationId: ownerNotificationId,
              title: 'নতুন অর্ডার এসেছে! 🛍️',
              content: '$realCustomerName একটি নতুন অর্ডার দিয়েছেন।',
              data: {
                'action': 'incoming_order_call',
                'callId': Uuid().v4(),
                'orderId': orderId,
                'amount': totalAmount.toString(),
                'customerName': realCustomerName,
                'items': itemsList, 
                'appointment': appointmentTime,
                'type': 'owner',
                'timeoutSeconds': 30,
              },
            );
          }
        }
      } catch (e) {
        print('Could not send owner call: $e');
      }

      return orderId;
    } catch (e) {
      print('CRITICAL REPOSITORY ERROR: $e');
      rethrow;
    }
  }
}
