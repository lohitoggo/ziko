class AppUser {
  final String uid;
  final String phone;
  final String? name;
  final String role; // "customer", "restaurant", "rider", "admin", or "" if not set
  final String? areaId;
  final bool isActive;
  final String? email;
  final String? secondaryPhone;
  final String? address;
  final String? pinCode;
  final double? latitude;
  final double? longitude;
  final String? vehicleType; // For Riders
  final String? identityNo; // NID/Aadhar for verification
  final String? bankDetails; // For Payouts (Riders/Owners)

  AppUser({
    required this.uid,
    required this.phone,
    this.name,
    this.role = '',
    this.areaId,
    this.isActive = true,
    this.email,
    this.secondaryPhone,
    this.address,
    this.pinCode,
    this.latitude,
    this.longitude,
    this.vehicleType,
    this.identityNo,
    this.bankDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': uid, // Supabase primary key is 'id'
      'phone': phone,
      'name': name,
      'role': role,
      'area_id': areaId,
      'is_active': isActive,
      'email': email,
      'secondary_phone': secondaryPhone,
      'address': address,
      'pin_code': pinCode,
      'latitude': latitude,
      'longitude': longitude,
      'vehicle_type': vehicleType,
      'identity_no': identityNo,
      'bank_details': bankDetails,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['id'] ?? '',
      phone: map['phone'] ?? '',
      name: map['name'],
      role: map['role'] ?? '',
      areaId: map['area_id'],
      isActive: map['is_active'] ?? true,
      email: map['email'],
      secondaryPhone: map['secondary_phone'],
      address: map['address'],
      pinCode: map['pin_code'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      vehicleType: map['vehicle_type'],
      identityNo: map['identity_no'],
      bankDetails: map['bank_details'],
    );
  }

  AppUser copyWith({
    String? name,
    String? role,
    String? areaId,
    bool? isActive,
    String? email,
    String? secondaryPhone,
    String? address,
    String? pinCode,
    double? latitude,
    double? longitude,
    String? vehicleType,
    String? identityNo,
    String? bankDetails,
  }) {
    return AppUser(
      uid: uid,
      phone: phone,
      name: name ?? this.name,
      role: role ?? this.role,
      areaId: areaId ?? this.areaId,
      isActive: isActive ?? this.isActive,
      email: email ?? this.email,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      address: address ?? this.address,
      pinCode: pinCode ?? this.pinCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      vehicleType: vehicleType ?? this.vehicleType,
      identityNo: identityNo ?? this.identityNo,
      bankDetails: bankDetails ?? this.bankDetails,
    );
  }
}
