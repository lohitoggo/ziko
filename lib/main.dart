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
import 'core/presentation/splash_screen.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'core/services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Load Environment Variables
  await dotenv.load(fileName: ".env");

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ziko',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}
