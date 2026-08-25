import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/user_repository.dart';
import '../data/user_model.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  // Use direct current user check to avoid listener loops with AuthState stream
  final user = Supabase.instance.client.auth.currentUser;
  
  if (user == null) {
    return Stream.value(null);
  }
  
  // Watch the user profile in real-time
  // Added error handling and auto-retry logic via Stream transformation if needed, 
  // but usually didChangeAppLifecycleState in main.dart handles the reconnect.
  return ref.watch(userRepositoryProvider).watchUser(user.id);
});
