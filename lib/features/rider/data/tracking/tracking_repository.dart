import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/location/location_service.dart';

class TrackingRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  final Map<String, StreamSubscription<Position>>
  _subscriptions = {};

  final Map<String, DateTime> _lastSentAt = {};

  final Map<String, Position> _lastSentPosition = {};

  static const _minimumInterval =
  Duration(seconds: 4);

  static const _minimumDistanceInMeters = 10.0;

  bool isTracking(String orderId) {
    return _subscriptions.containsKey(orderId);
  }

  Future<bool> startTracking(
      String orderId,
      String riderId,
      ) async {
    await _subscriptions.remove(orderId)?.cancel();

    _lastSentAt.remove(orderId);
    _lastSentPosition.remove(orderId);

    final permission =
    await LocationService.ensureRiderTrackingPermission();

    if (!permission) {
      print(
        'TRACKING: permission/service not ready.',
      );
      return false;
    }

    Position initialPosition;

    try {
      initialPosition =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print(
        'TRACKING: initial GPS failed: $e',
      );
      return false;
    }

    final initialSaved =
    await _sendPosition(
      orderId,
      riderId,
      initialPosition,
      force: true,
    );

    if (!initialSaved) {
      print(
        'TRACKING: initial Supabase save failed.',
      );
      return false;
    }

    print(
      'TRACKING: initial location saved.',
    );

    _subscriptions[orderId] =
        LocationService
            .getRiderLocationStream()
            .listen(
              (position) {
            unawaited(
              _sendPosition(
                orderId,
                riderId,
                position,
              ),
            );
          },
          onError: (Object error) {
            print(
              'TRACKING: GPS stream error: $error',
            );
          },
          cancelOnError: false,
        );

    return true;
  }

  Future<bool> _sendPosition(
      String orderId,
      String riderId,
      Position position, {
        bool force = false,
      }) async {
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite) {
      return false;
    }

    final now = DateTime.now().toUtc();

    final lastAt = _lastSentAt[orderId];
    final lastPosition =
    _lastSentPosition[orderId];

    final elapsed =
    lastAt == null
        ? _minimumInterval
        : now.difference(lastAt);

    final moved =
    lastPosition == null
        ? double.infinity
        : Geolocator.distanceBetween(
      lastPosition.latitude,
      lastPosition.longitude,
      position.latitude,
      position.longitude,
    );

    if (!force &&
        elapsed < _minimumInterval &&
        moved < _minimumDistanceInMeters) {
      return true;
    }

    try {
      await _supabase
          .from('rider_tracking')
          .upsert(
        {
          'order_id': orderId,
          'rider_id': riderId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'heading': position.heading,
          'speed': position.speed,
          'updated_at':
          now.toIso8601String(),
        },
        onConflict: 'order_id',
      );

      _lastSentAt[orderId] = now;
      _lastSentPosition[orderId] = position;

      print(
        'TRACKING: location saved '
            '${position.latitude}, '
            '${position.longitude} '
            'accuracy=${position.accuracy}',
      );

      return true;
    } catch (e) {
      print(
        'TRACKING: Supabase save failed: $e',
      );
      return false;
    }
  }

  Future<void> stopTracking(
      String orderId,
      ) async {
    await _subscriptions
        .remove(orderId)
        ?.cancel();

    _lastSentAt.remove(orderId);
    _lastSentPosition.remove(orderId);

    // Keep existing behaviour for now.
    await _supabase
        .from('rider_tracking')
        .delete()
        .eq('order_id', orderId);
  }

  Future<void> dispose() async {
    for (final subscription
    in _subscriptions.values) {
      await subscription.cancel();
    }

    _subscriptions.clear();
  }

  Stream<Map<String, dynamic>?>
  watchRiderLocation(
      String orderId,
      ) {
    return _supabase
        .from('rider_tracking')
        .stream(
      primaryKey: ['order_id'],
    )
        .eq('order_id', orderId)
        .map(
          (data) =>
      data.isEmpty ? null : data.first,
    );
  }
}