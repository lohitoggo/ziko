import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/location/location_service.dart';

class TrackingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, StreamSubscription<Position>> _subscriptions = {};
  final Map<String, DateTime> _lastSentAt = {};
  final Map<String, Position> _lastSentPosition = {};

  static const _minimumInterval = Duration(seconds: 4);
  static const _minimumDistanceInMeters = 10.0;

  /// Starts exactly one location stream per active order.  The database write
  /// is throttled so GPS noise cannot consume the Realtime quota.
  Future<void> startTracking(String orderId, String riderId) async {
    if (_subscriptions.containsKey(orderId)) return;

    final hasPermission = await LocationService.ensureRiderTrackingPermission();
    if (!hasPermission) {
      throw StateError('Location permission or service is unavailable.');
    }

    _subscriptions[orderId] = LocationService.getRiderLocationStream().listen(
          (position) => _sendPosition(orderId, riderId, position),
      onError: (Object error, StackTrace stackTrace) {
        // The next GPS event will recover automatically; do not terminate an
        // active delivery merely because one reading failed.
        print('Rider location stream error: $error');
      },
    );
  }

  Future<void> _sendPosition(String orderId, String riderId, Position position) async {
    if (position.accuracy > 60) return;

    final now = DateTime.now().toUtc();
    final lastAt = _lastSentAt[orderId];
    final lastPosition = _lastSentPosition[orderId];
    final elapsed = lastAt == null ? _minimumInterval : now.difference(lastAt);
    final moved = lastPosition == null
        ? double.infinity
        : Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );

    if (elapsed < _minimumInterval && moved < _minimumDistanceInMeters) return;

    try {
      await _supabase.from('rider_tracking').upsert({
        'order_id': orderId,
        'rider_id': riderId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'heading': position.heading,
        'speed': position.speed,
        'updated_at': now.toIso8601String(),
      }, onConflict: 'order_id');
      _lastSentAt[orderId] = now;
      _lastSentPosition[orderId] = position;
    } catch (error) {
      print('Could not save rider location: $error');
    }
  }

  /// Stop tracking (usually called when order delivered)
  Future<void> stopTracking(String orderId) async {
    await _subscriptions.remove(orderId)?.cancel();
    _lastSentAt.remove(orderId);
    _lastSentPosition.remove(orderId);
    await _supabase.from('rider_tracking').delete().eq('order_id', orderId);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Watch real-time location for a specific order (For Customer)
  Stream<Map<String, dynamic>?> watchRiderLocation(String orderId) {
    return _supabase
        .from('rider_tracking')
        .stream(primaryKey: ['order_id'])
        .eq('order_id', orderId)
        .map((data) => data.isEmpty ? null : data.first);
  }
}
