import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/call_notification_service.dart';
import 'tracking/tracking_repository.dart';

class RiderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TrackingRepository _trackingRepo = TrackingRepository();

  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    await _supabase.from('profiles').update({'is_online': isOnline}).eq('id', uid);
  }

  Stream<bool> watchOnlineStatus(String uid) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((data) => data.isEmpty ? false : (data.first['is_online'] ?? false));
  }

  // যে অর্ডারগুলো "ready" অবস্থায় আছে এবং রাইডারের বাছাই করা এরিয়াগুলোর সাথে মেলে
  Stream<List<Map<String, dynamic>>> watchAvailableOrders(List<String> areaIds) {
    if (areaIds.isEmpty) return Stream.value([]);
    
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .inFilter('area_id', areaIds) // Filter by all selected areas
        .map((data) => data.where((d) => d['status'] == 'ready' && (d['rider_id'] == null || d['rider_id'] == '')).map((d) => {...d, 'orderId': d['id']}).toList());
  }

  // এই রাইডারকে assign করা অর্ডারগুলো
  Stream<List<Map<String, dynamic>>> watchMyDeliveries(String riderUid) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('rider_id', riderUid)
        .map((data) => data.where((d) => ['rider_assigned', 'picked_up', 'out_for_delivery'].contains(d['status'])).map((d) => {...d, 'orderId': d['id']}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchMyCompletedDeliveries(String riderUid) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('rider_id', riderUid)
        .order('delivered_at', ascending: false)
        .map((data) => data.where((d) => d['status'] == 'delivered').map((d) => {...d, 'orderId': d['id']}).toList());
  }

  Future<void> acceptOrder(String orderId, String riderUid) async {
    await _supabase.from('orders').update({
      'rider_id': riderUid,
      'status': 'rider_assigned',
    }).eq('id', orderId);
    
    // Stop any existing call UI if accept was from within app
    CallNotificationService.stopCall();
  }

  Future<void> updateDeliveryStatus(String orderId, String status) async {
    final data = <String, dynamic>{'status': status};
    if (status == 'picked_up') {
      // Need picked_up_at column if tracking specifically
    } else if (status == 'delivered') {
      data['delivered_at'] = DateTime.now().toIso8601String();
      data['payment_status'] = 'paid';
    }
    await _supabase.from('orders').update(data).eq('id', orderId);

    // --- Manage Real-time Tracking based on status ---
    if (status == 'picked_up') {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _trackingRepo.startTracking(orderId, user.id);
      }
    } else if (status == 'delivered') {
      _trackingRepo.stopTracking(orderId);
    }

    // --- Send Notification to Customer ---
    try {
      final orderDoc = await _supabase.from('orders').select('customer_id').eq('id', orderId).single();
      final customerId = orderDoc['customer_id'];
      
      String title = 'ডেলিভারি আপডেট 🚴';
      String content = 'আপনার অর্ডারটির অবস্থা: $status';

      if (status == 'picked_up') content = 'রাইডার আপনার অর্ডারটি দোকান থেকে সংগ্রহ করেছে। 🛵';
      if (status == 'out_for_delivery') content = 'রাইডার আপনার ঠিকানার উদ্দেশ্যে রওনা হয়েছে। 📍';
      if (status == 'delivered') content = 'অর্ডার সফলভাবে ডেলিভারি করা হয়েছে। উপভোগ করুন! 😊';

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
      print('Could not send delivery notification: $e');
    }
  }

  Future<void> registerRider(Map<String, dynamic> data) async {
    // Use ID for conflict resolution for more reliable profile updates
    await _supabase.from('riders').upsert(data, onConflict: 'id');
  }

  Stream<Map<String, dynamic>?> watchMyRiderProfile(String riderUid) {
    return _supabase.from('riders').stream(primaryKey: ['id']).eq('id', riderUid).map((data) => data.isEmpty ? null : data.first);
  }
}
