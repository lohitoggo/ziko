import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { isConnected, isDisconnected, isChecking }

class ConnectivityService extends StateNotifier<ConnectivityStatus> {
  Timer? _timer;
  final Ref _ref;

  ConnectivityService(this._ref) : super(ConnectivityStatus.isChecking) {
    _startMonitoring();
  }

  void _startMonitoring() {
    checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkConnection();
    });
  }

  Future<void> checkConnection() async {
    final previousStatus = state;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (state != ConnectivityStatus.isConnected) {
          state = ConnectivityStatus.isConnected;
          // If we just went from disconnected to connected, trigger a global refresh
          if (previousStatus == ConnectivityStatus.isDisconnected) {
            _refreshAllData();
          }
        }
      } else {
        state = ConnectivityStatus.isDisconnected;
      }
    } catch (_) {
      state = ConnectivityStatus.isDisconnected;
    }
  }

  void _refreshAllData() {
    debugPrint('DEBUG: Internet restored. Invalidating critical providers...');
    // We will invalidate providers from main.dart or here if we have references
    // For now, let's emit a signal or just let the main.dart listener handle it
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityService, ConnectivityStatus>((ref) {
  return ConnectivityService(ref);
});
