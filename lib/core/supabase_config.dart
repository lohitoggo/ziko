import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL', fallback: '');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');
  
  // OneSignal Config
  static String get oneSignalAppId => dotenv.get('ONESIGNAL_APP_ID', fallback: '');
  static String get oneSignalRestKey => dotenv.get('ONESIGNAL_REST_KEY', fallback: '');

  // MapmyIndia (Mapple) Config
  static String get mappleRestKey => dotenv.get('MAPPLE_REST_KEY', fallback: '');
  static String get mappleMapSdkKey => dotenv.get('MAPPLE_MAP_SDK_KEY', fallback: '');
  static String get mappleClientId => dotenv.get('MAPPLE_CLIENT_ID', fallback: '');
  static String get mappleClientSecret => dotenv.get('MAPPLE_CLIENT_SECRET', fallback: '');

  // Google Maps Config
  static String get googleMapsApiKey =>
      dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');

  static String get googleRoutesApiKey =>
      dotenv.get('GOOGLE_ROUTES_API_KEY', fallback: '');
}
