import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service.dart';
import '../../features/admin/providers/admin_provider.dart';
import '../../features/customer/providers/business_provider.dart';

class ConnectivityWrapper extends ConsumerWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);

    return Stack(
      children: [
        child,
        if (status == ConnectivityStatus.isDisconnected)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.redAccent,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 12),
                      const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          // Manual check
                          ref.read(connectivityProvider.notifier).checkConnection();
                          
                          // Force invalidation of critical state to trigger re-fetch
                          ref.invalidate(systemSettingsProvider);
                          ref.invalidate(businessesByAreaProvider);
                        },
                        child: const Text(
                          'RETRY',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
