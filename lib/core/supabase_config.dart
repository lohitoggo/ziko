import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL', fallback: '');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  
  // OneSignal Config
  static String get oneSignalAppId => dotenv.get('ONESIGNAL_APP_ID', fallback: '');
  static String get oneSignalRestKey => dotenv.get('ONESIGNAL_REST_KEY', fallback: '');
}
