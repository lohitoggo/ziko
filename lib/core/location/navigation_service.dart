import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  /// Launches external Google Maps for Rider Navigation
  static Future<void> launchExternalNavigation(double lat, double lon) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lon&mode=d");
    final Uri appleMapsUrl = Uri.parse("https://maps.apple.com/?q=$lat,$lon");
    final Uri browserUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl);
      } else {
        await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Could not launch navigation: $e');
    }
  }
}
