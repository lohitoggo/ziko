import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---- Areas ----
  Stream<List<Map<String, dynamic>>> watchAllAreas() {
    return _supabase.from('areas').stream(primaryKey: ['id']).map((data) => data.map((d) => {...d, 'areaId': d['id']}).toList());
  }

  Future<void> addArea({
    required String name,
    required double deliveryCharge,
    required double minimumOrder,
    required int estimatedDeliveryMinutes,
  }) async {
    try {
      await _supabase.from('areas').insert({
        'name': name,
        'delivery_charge': deliveryCharge,
        'min_order_amount': minimumOrder,
        'estimated_delivery_minutes': estimatedDeliveryMinutes,
        'is_active': true,
      });
    } catch (e) {
      print('Add area error: $e');
      rethrow;
    }
  }

  Future<void> toggleAreaStatus(String areaId, bool isActive) async {
    await _supabase.from('areas').update({'is_active': isActive}).eq('id', areaId);
  }

  Future<void> updateAreaDetails(String areaId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('areas').update({
        'name': data['name'],
        'delivery_charge': data['deliveryCharge'],
        'min_order_amount': data['minimumOrder'],
        'estimated_delivery_minutes': data['estimatedDeliveryMinutes'],
      }).eq('id', areaId);
    } catch (e) {
      print('Update area error: $e');
      rethrow;
    }
  }

  // ---- Restaurants/Businesses ----
  Stream<List<Map<String, dynamic>>> watchAllRestaurants() {
    return _supabase.from('businesses').stream(primaryKey: ['id']).map((data) => data.map((d) => {...d, 'restaurantId': d['id']}).toList());
  }

  Future<void> updateRestaurantStatus(String restaurantId, String status) async {
    await _supabase.from('businesses').update({'status': status}).eq('id', restaurantId);
  }

  Future<void> forceRestaurantOnlineOffline(String restaurantId, bool isOnline) async {
    await _supabase.from('businesses').update({'is_online': isOnline}).eq('id', restaurantId);
  }

  Future<void> updateBusinessDetails(String restaurantId, Map<String, dynamic> data) async {
    try {
      await _supabase.from('businesses').update({
        if (data['name'] != null) 'name': data['name'],
        if (data['owner_name'] != null) 'owner_name': data['owner_name'],
        if (data['owner_phone'] != null) 'owner_phone': data['owner_phone'],
        if (data['category'] != null) 'category': data['category'],
        if (data['area_id'] != null) 'area_id': data['area_id'],
        if (data['address'] != null) 'address': data['address'],
        if (data['commission_rate'] != null) 'commission_rate': data['commission_rate'],
        if (data['upi_id'] != null) 'upi_id': data['upi_id'],
        if (data['license_no'] != null) 'license_no': data['license_no'],
        if (data['logo_url'] != null) 'logo_url': data['logo_url'],
      }).eq('id', restaurantId);
    } catch (e) {
      print('Update business error: $e');
      rethrow;
    }
  }

  // ---- Users (Riders/Customers) ----
  Stream<List<Map<String, dynamic>>> watchAllUsersByRole(String role) {
    if (role == 'rider') {
      return _supabase.from('riders').stream(primaryKey: ['id']).map((data) => data.map((d) => {...d, 'uid': d['id']}).toList());
    }
    return _supabase.from('profiles').stream(primaryKey: ['id']).eq('role', role).map((data) => data.map((d) => {...d, 'uid': d['id']}).toList());
  }

  Future<void> blockUser(String uid, bool isBlocked) async {
    // Check both tables to be sure
    await _supabase.from('profiles').update({'is_active': !isBlocked}).eq('id', uid);
    await _supabase.from('riders').update({'is_active': !isBlocked}).eq('id', uid);
  }

  Future<void> settleRiderCash(String riderUid) async {
    await _supabase.from('riders').update({'cash_on_hand': 0.0}).eq('id', riderUid);
  }

  Future<void> updateUserDetails(String uid, Map<String, dynamic> data) async {
    try {
      // If it's a rider, update the riders table
      final isRider = await _supabase.from('riders').select().eq('id', uid).maybeSingle();
      if (isRider != null) {
        await _supabase.from('riders').update({
          if (data['name'] != null) 'name': data['name'],
          if (data['phone'] != null) 'phone': data['phone'],
          if (data['areaId'] != null) 'area_id': data['areaId'],
          if (data['vehicleType'] != null) 'vehicle_type': data['vehicleType'],
          if (data['identityNo'] != null) 'identity_no': data['identityNo'],
          if (data['bankDetails'] != null) 'bank_details': data['bankDetails'],
        }).eq('id', uid);
      } else {
        await _supabase.from('profiles').update({
          if (data['name'] != null) 'name': data['name'],
          if (data['phone'] != null) 'phone': data['phone'],
          if (data['areaId'] != null) 'area_id': data['areaId'],
        }).eq('id', uid);
      }
    } catch (e) {
      print('Update user error: $e');
      rethrow;
    }
  }

  // ---- Customer Management ----
  Stream<List<Map<String, dynamic>>> watchAllCustomers() {
    return _supabase.from('profiles').stream(primaryKey: ['id']).eq('role', 'customer').map((data) => data.map((d) => {...d, 'uid': d['id']}).toList());
  }

  Stream<List<Map<String, dynamic>>> watchCustomerOrderHistory(String customerUid) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('customer_id', customerUid)
        .order('placed_at', ascending: false)
        .map((data) => data.map((d) => {...d, 'orderId': d['id']}).toList());
  }

  // ---- Orders ----
  Stream<List<Map<String, dynamic>>> watchAllOrders() {
    return _supabase.from('orders').stream(primaryKey: ['id']).order('placed_at', ascending: false).map((data) => data.map((d) => {...d, 'orderId': d['id']}).toList());
  }

  Future<void> assignRiderToOrder(String orderId, String riderUid) async {
    await _supabase.from('orders').update({
      'rider_id': riderUid,
      'status': 'rider_assigned',
    }).eq('id', orderId);
  }

  // ---- Dashboard stats ----
  Stream<Map<String, dynamic>> watchDetailedStats() {
    return _supabase.from('orders').stream(primaryKey: ['id']).map((orders) {
      final now = DateTime.now();

      final totalSales = orders
          .where((o) => o['status'] == 'delivered')
          .fold(0.0, (sumValue, o) => sumValue + (o['total_amount'] ?? 0));

      final todaySales = orders.where((o) {
        if (o['status'] != 'delivered') return false;
        final placedAt = DateTime.tryParse(o['placed_at'] ?? '') ?? DateTime.now();
        return placedAt.day == now.day && placedAt.month == now.month && placedAt.year == now.year;
      }).fold(0.0, (sumValue, o) => sumValue + (o['total_amount'] ?? 0));

      final activeOrders = orders
          .where((o) => !['delivered', 'cancelled', 'rejected'].contains(o['status']))
          .length;

      return {
        'totalSales': totalSales,
        'todaySales': todaySales,
        'activeOrders': activeOrders,
      };
    });
  }

  Future<Map<String, int>> getCounts() async {
    final restaurants = await _supabase.from('businesses').select('id');
    final riders = await _supabase.from('profiles').select('id').eq('role', 'rider');
    final customers = await _supabase.from('profiles').select('id').eq('role', 'customer');
    final orders = await _supabase.from('orders').select('id');
    final areas = await _supabase.from('areas').select('id');

    return {
      'restaurants': (restaurants as List).length,
      'riders': (riders as List).length,
      'customers': (customers as List).length,
      'orders': (orders as List).length,
      'areas': (areas as List).length,
    };
  }

  // ---- System Settings ----
  Stream<Map<String, dynamic>?> watchSystemSettings() {
    return _supabase.from('settings').stream(primaryKey: ['id']).eq('id', 'global').map((data) => data.isEmpty ? null : data.first);
  }

  Future<void> updateSystemSettings(Map<String, dynamic> settings) async {
    try {
      final Map<String, dynamic> dataToSave = {'id': 'global'};
      settings.forEach((key, value) {
        if (key == 'platformFee') {
          dataToSave['platform_fee'] = value;
        } else if (key == 'gstPercentage') {
          dataToSave['gst_percentage'] = value;
        } else if (key == 'promoBannerUrl') {
          dataToSave['promo_banner_url'] = value;
        } else {
          dataToSave[key] = value;
        }
      });

      await _supabase.from('settings').upsert(dataToSave);
    } catch (e) {
      debugPrint('Update settings error: $e');
      rethrow;
    }
  }

  Future<void> toggleMaintenanceMode(bool isEnabled) async {
    await _supabase.from('settings').update({'is_maintenance_mode': isEnabled}).eq('id', 'global');
  }

  // ---- Onboarding ----
  Future<void> onboardBusiness({
    required String name,
    required String ownerPhone,
    required String ownerName,
    required String category,
    required String areaId,
    required String address,
    required double commissionRate,
    String? upiId,
    String? licenseNo,
    String? logoUrl,
  }) async {
    try {
      await _supabase.from('businesses').insert({
        'name': name,
        'owner_phone': ownerPhone,
        'owner_name': ownerName,
        'category': category,
        'area_id': areaId,
        'address': address,
        'commission_rate': commissionRate,
        'upi_id': upiId,
        'license_no': licenseNo,
        'logo_url': logoUrl,
        'status': 'approved',
        'is_online': false,
        'owner_id': null,
      });
    } catch (e) {
      print('Onboard error: $e');
      rethrow;
    }
  }

  Future<void> onboardRider({
    required String name,
    required String phone,
    required String areaId,
    required String vehicleType,
    required String identityNo,
    String? bankDetails,
  }) async {
    try {
      await _supabase.from('riders').insert({
        'name': name,
        'phone': phone,
        'area_id': areaId,
        'vehicle_type': vehicleType,
        'identity_no': identityNo,
        'bank_details': bankDetails,
        'is_active': true,
      });
    } catch (e) {
      print('Onboard rider error: $e');
      rethrow;
    }
  }
}
