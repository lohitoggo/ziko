enum MapProviderType {
  flutterMap,
  googleMaps,
}

class MapGlobalConfig {
  /// THE CENTRAL SWITCH
  /// Change this to MapProviderType.googleMaps for Production Google Maps
  static const MapProviderType activeMapProvider = MapProviderType.googleMaps;
}
