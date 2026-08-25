import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/supabase_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/call_notification_service.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'core/services/foreground_service.dart';
import 'core/connectivity/connectivity_wrapper.dart';
import 'core/connectivity/connectivity_service.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/customer/providers/business_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Load Environment Variables (Robust check)
  try {
    await dotenv.load(fileName: ".env");
    print('DEBUG: .env file loaded successfully.');
  } catch (e) {
    print('CRITICAL ERROR: Failed to load .env file: $e');
  }

  // 1. Initialize Essential Services
  ForegroundService.init();
  CallNotificationService.initGlobalListeners();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // 4. Initialize OneSignal
  await NotificationService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // CRITICAL: Catch native call actions (Accept/Reject) when app resumes
    if (state == AppLifecycleState.resumed) {
      CallNotificationService.checkPendingOrderAction();
      
      // REFRESH SUPABASE SESSION & REALTIME
      _refreshSupabaseConnection();
    }
  }

  Future<void> _refreshSupabaseConnection() async {
    try {
      debugPrint('DEBUG: Refreshing Supabase connection on app resume...');
      
      // 1. Refresh Session if needed
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.isExpired) {
        await Supabase.instance.client.auth.refreshSession();
        debugPrint('DEBUG: Supabase session refreshed.');
      }

      // 2. RE-INITIALIZE REALTIME
      // Force WebSocket reconnect
      Supabase.instance.client.realtime.disconnect();
      Future.delayed(const Duration(milliseconds: 500), () {
        Supabase.instance.client.realtime.connect();
        debugPrint('DEBUG: Supabase realtime re-connected.');
      });
      
    } catch (e) {
      debugPrint('ERROR: Failed to refresh Supabase connection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // AUTO-RELOAD LOGIC: Listen for connectivity restoration
        ref.listen(connectivityProvider, (previous, next) {
          if (next == ConnectivityStatus.isConnected && previous == ConnectivityStatus.isDisconnected) {
            debugPrint('DEBUG: Connection restored. Force refreshing UI...');
            // Invalidate critical data providers to force reload
            ref.invalidate(systemSettingsProvider);
            ref.invalidate(businessesByAreaProvider);
          }
        });

        return MaterialApp(
          title: 'Ziko',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            return ConnectivityWrapper(child: child!);
          },
          home: const AuthWrapper(),
        );
      },
    );
  }
}
