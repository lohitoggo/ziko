class AddressModel {
  final String id;
  final String userId;
  final String houseNumber;
  final String village;
  final String landmark;
  final String pinCode;
  final String? areaId; // New: Link to a specific service area
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  AddressModel({
    required this.id,
    required this.userId,
    required this.houseNumber,
    required this.village,
    required this.landmark,
    required this.pinCode,
    this.areaId,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      houseNumber: map['house_number'] ?? '',
      village: map['village'] ?? '',
      landmark: map['landmark'] ?? '',
      pinCode: map['pin_code'] ?? '',
      areaId: map['area_id'],
      latitude: (map['latitude'] != null) ? double.tryParse(map['latitude'].toString()) : null,
      longitude: (map['longitude'] != null) ? double.tryParse(map['longitude'].toString()) : null,
      isDefault: map['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'house_number': houseNumber,
      'village': village,
      'landmark': landmark,
      'pin_code': pinCode,
      'area_id': areaId,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
  }
}
