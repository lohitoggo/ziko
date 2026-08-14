import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/call_notification_service.dart';

class RestaurantOwnerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Stream<Map<String, dynamic>?> watchMyBusiness(String ownerUid) {
    return _supabase
        .from('businesses')
        .stream(primaryKey: ['id'])
        .eq('owner_id', ownerUid)
        .map((data) {
      if (data.isEmpty) return null;
      final business = data.first;
      return {...business, 'restaurantId': business['id']};
    });
  }

  Stream<Map<String, dynamic>?> watchMyRestaurant(String ownerUid) {
    return watchMyBusiness(ownerUid);
  }

  Future<void> toggleOnline(String businessId, bool isOnline) async {
    await _supabase.from('businesses').update({'is_online': isOnline}).eq('id', businessId);
  }

  Future<void> updateBusinessProfile(String businessId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('businesses').update({
        if (data['name'] != null) 'name': data['name'],
        if (data['description'] != null) 'description': data['description'],
        if (data['address'] != null) 'address': data['address'],
        if (data['logoUrl'] != null) 'logo_url': data['logoUrl'],
        if (data['logo_url'] != null) 'logo_url': data['logo_url'],
        if (data['banner_urls'] != null) 'banner_urls': data['banner_urls'],
        if (data['owner_name'] != null) 'owner_name': data['owner_name'],
        if (data['owner_phone'] != null) 'owner_phone': data['owner_phone'],
        if (data['upi_id'] != null) 'upi_id': data['upi_id'],
        if (data['license_no'] != null) 'license_no': data['license_no'],
        if (data['opening_time'] != null) 'opening_time': data['opening_time'],
        if (data['closing_time'] != null) 'closing_time': data['closing_time'],
        if (data['opening_time_2'] != null) 'opening_time_2': data['opening_time_2'],
        if (data['closing_time_2'] != null) 'closing_time_2': data['closing_time_2'],
        if (data['has_double_shift'] != null) 'has_double_shift': data['has_double_shift'],
        if (data['available_slots'] != null) 'available_slots': data['available_slots'],
        if (data['off_day'] != null) 'off_day': data['off_day'],
      }).eq('id', businessId);
    } catch (e) {
      print('Update business profile error: $e');
      rethrow;
    }
  }

  // ---- Menu Items ----

  Stream<List<Map<String, dynamic>>> watchMyItems(String businessId) {
    return _supabase
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .map((data) => data.map((d) => {...d, 'itemId': d['id']}).toList());
  }

  Future<void> addItem({
    required String businessId,
    required String name,
    required String description,
    required bool isVeg,
    required double price,
    required double discountPrice,
    required int stock,
    int duration = 30,
    List<String> imageUrls = const [],
    List<String> availableSlots = const [],
  }) async {
    try {
      await _supabase.from('items').insert({
        'business_id': businessId,
        'name': name,
        'description': description,
        'is_veg': isVeg,
        'price': price,
        'discount_price': discountPrice,
        'stock': stock,
        'duration': duration,
        'is_available': true,
        'image_urls': imageUrls,
        'available_slots': availableSlots,
      });
    } catch (e) {
      print('Add item repository error: $e');
      rethrow;
    }
  }

  Future<void> updateItem(String itemId, Map<String, dynamic> data) async {
    await _supabase.from('items').update({
      if (data['name'] != null) 'name': data['name'],
      if (data['description'] != null) 'description': data['description'],
      if (data['isVeg'] != null) 'is_veg': data['isVeg'],
      if (data['price'] != null) 'price': data['price'],
      if (data['discountPrice'] != null) 'discount_price': data['discountPrice'],
      if (data['stock'] != null) 'stock': data['stock'],
      if (data['duration'] != null) 'duration': data['duration'],
      if (data['isAvailable'] != null) 'is_available': data['isAvailable'],
      if (data['imageUrls'] != null) 'image_urls': data['imageUrls'],
      if (data['availableSlots'] != null) 'available_slots': data['availableSlots'],
    }).eq('id', itemId);
  }

  Future<void> deleteItem(String itemId) async {
    await _supabase.from('items').delete().eq('id', itemId);
  }

  // ---- Orders ----

  Stream<List<Map<String, dynamic>>> watchMyOrders(String businessId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('placed_at')
        .map((data) {
      // SORT LOCALLY to ensure descending order works with Supabase Stream
      final list = data.map((d) => {...d, 'orderId': d['id']}).toList();
      list.sort((a, b) => (b['placed_at'] ?? '').compareTo(a['placed_at'] ?? ''));
      return list;
    });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);

    // Stop any existing call UI if accepted from dashboard
    if (status == 'accepted') {
      CallNotificationService.stopCall();
    }

    // --- Send Notification to Customer or Rider ---
    try {
      final orderDoc = await _supabase.from('orders').select('customer_id, area_id, total_amount, business_id, appointment_time, delivery_charge').eq('id', orderId).single();
      final customerId = orderDoc['customer_id'];

      // Fetch Customer Name
      final customerProfile = await _supabase.from('profiles').select('name').eq('id', customerId).single();
      final realCustomerName = customerProfile['name'] ?? 'Customer';

      // IF STATUS IS READY -> NOTIFY RIDERS WITH NEW CALL PROTOCOL
      if (status == 'ready') {
        try {
          var isAutoAssign = true;
          try {
            final settingsRes = await _supabase.from('system_settings').select('is_auto_assign_enabled').maybeSingle();
            if (settingsRes != null) isAutoAssign = settingsRes['is_auto_assign_enabled'] ?? true;
          } catch (e) {
            final altSettings = await _supabase.from('settings').select('is_auto_assign_enabled').maybeSingle();
            if (altSettings != null) isAutoAssign = altSettings['is_auto_assign_enabled'] ?? true;
          }

          if (isAutoAssign) {
            final orderAreaId = orderDoc['area_id'];
            
            // FETCH ALL ONLINE RIDERS with all area fields
            final riders = await _supabase
                .from('profiles')
                .select('id, notification_id, area_id, area_ids')
                .eq('role', 'rider')
                .eq('is_online', true);

            print('🛵 RIDER-DEBUG: Total Online Riders Found = ${riders.length}');

            final orderItems = await _supabase.from('order_items').select('name, quantity').eq('order_id', orderId);
            final itemsList = (orderItems as List).map((i) => '${i['quantity']}x ${i['name']}').join(', ');

            int successCount = 0;
            for (var r in riders) {
              final String? nid = r['notification_id'];
              
              if (nid == null || nid.isEmpty) {
                print('🛵 RIDER-DEBUG: Skipping Rider ${r['id']} (No Notification ID)');
                continue;
              }
              
              // THE ULTIMATE FIX: If a rider is ONLINE, send them the call regardless of area matching
              // This ensures NO ORDER is ever lost due to null area data in profiles
              const bool isGlobalMatch = true; 

              if (isGlobalMatch) {
                print('🛵 RIDER-ALERT: SENDING GLOBAL CALL to Rider $nid');
                await NotificationService.sendNotification(
                  targetNotificationId: nid,
                  title: 'নতুন ডেলিভারি উপলব্ধ! 🛵',
                  content: 'আপনার এলাকায় একটি নতুন অর্ডার রেডি হয়েছে।',
                  data: {
                    'action': 'incoming_order_call',
                    'callId': Uuid().v4(),
                    'orderId': orderId,
                    'amount': orderDoc['total_amount']?.toString() ?? '0',
                    'customerName': realCustomerName,
                    'items': itemsList,
                    'appointment': orderDoc['appointment_time']?.toString() ?? '',
                    'commission': orderDoc['delivery_charge']?.toString() ?? '0',
                    'type': 'rider',
                    'timeoutSeconds': 45,
                  },
                );
                successCount++;
              }
            }
            print('🛵 RIDER-ALERT: GLOBAL BROADCAST DONE. successCount=$successCount');
          }
        } catch (settingsError) {
          print('CRITICAL: Error in rider notification logic: $settingsError');
        }
      }

      // Standard Notification to Customer
      String title = 'অর্ডার আপডেট 📢';
      String content = 'আপনার অর্ডারটির স্ট্যাটাস পরিবর্তিত হয়েছে: $status';
      // ... same logic as before ...

      if (status == 'accepted') content = 'আপনার অর্ডারটি গ্রহণ করা হয়েছে! 😊';
      if (status == 'preparing') content = 'আপনার অর্ডারটি এখন প্রস্তুত হচ্ছে। 👨‍🍳';
      if (status == 'ready') content = 'আপনার অর্ডারটি এখন সম্পূর্ণ তৈরি। 🛍️';

      final profile = await _supabase.from('profiles').select('notification_id').eq('id', customerId).single();
      final customerNotificationId = profile['notification_id'];

      if (customerNotificationId != null) {
        await NotificationService.sendNotification(
          targetNotificationId: customerNotificationId,
          title: title,
          content: content,
        );
      }
    } catch (e) {
      print('Could not send customer notification: $e');
    }
  }

  Future<void> registerBusiness(Map<String, dynamic> data) async {
    try {
      // Using upsert with owner_id as the conflict target (based on our UNIQUE constraint)
      await _supabase.from('businesses').upsert(
          data,
          onConflict: 'owner_id'
      );
    } catch (e) {
      print('Register business error: $e');
      rethrow;
    }
  }

  // --- Manual Slot Blocking ---
  Future<void> manualBlockSlot({
    required String businessId,
    required String appointmentTime, // Format: "yyyy-MM-dd | 09:00 AM"
    required String ownerUid,
  }) async {
    try {
      await _supabase.from('orders').insert({
        'business_id': businessId,
        'customer_id': ownerUid, // Marked as blocked by owner
        'status': 'accepted', // Auto-accepted
        'appointment_time': appointmentTime,
        'total_amount': 0,
        'payment_method': 'manual',
        'payment_status': 'paid',
        'is_salon_pass_verified': true,
      });
    } catch (e) {
      print('Manual block error: $e');
      rethrow;
    }
  }
}