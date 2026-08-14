class BusinessModel {
  final String id;
  final String name;
  final String areaId;
  final String description;
  final String address;
  final String? logoUrl;
  final bool isOnline;
  final bool isActive; // Added for 'Hold' status tracking
  final double avgRating;
  final String category; // 'restaurant', 'salon', 'grocery', 'electronics'
  final String status;
  final String? ownerName;
  final String? ownerPhone;
  final String? licenseNo;
  final String? upiId;
  final double? commissionRate;
  final double? latitude;
  final double? longitude;
  final List<String> bannerUrls;
  final List<String> areaIds;
  
  // New Operating Hours Fields
  final String openingTime; // e.g., "09:00 AM"
  final String closingTime; // e.g., "09:00 PM"
  final String offDay;      // e.g., "Monday"
  final bool hasDoubleShift;
  final String openingTime2;
  final String closingTime2;
  final List<String> availableSlots;

  BusinessModel({
    required this.id,
    required this.name,
    required this.areaId,
    required this.description,
    required this.address,
    this.logoUrl,
    required this.isOnline,
    required this.isActive,
    required this.avgRating,
    required this.category,
    required this.status,
    this.ownerName,
    this.ownerPhone,
    this.licenseNo,
    this.upiId,
    this.commissionRate,
    this.latitude,
    this.longitude,
    this.bannerUrls = const [],
    this.areaIds = const [],
    this.openingTime = "09:00 AM",
    this.closingTime = "09:00 PM",
    this.offDay = "None",
    this.hasDoubleShift = false,
    this.openingTime2 = "05:00 PM",
    this.closingTime2 = "09:00 PM",
    this.availableSlots = const [],
  });

  factory BusinessModel.fromMap(String id, Map<String, dynamic> map) {
    final banners = map['banner_urls'] != null && map['banner_urls'] is List
        ? (map['banner_urls'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final areas = map['area_ids'] != null && map['area_ids'] is List
        ? (map['area_ids'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return BusinessModel(
      id: id,
      name: map['name'] ?? '',
      areaId: map['area_id'] ?? '',
      description: map['description'] ?? '',
      address: map['address'] ?? '',
      logoUrl: map['logo_url'],
      isOnline: map['is_online'] ?? false,
      isActive: map['is_active'] ?? true, // Sync with DB column
      avgRating: (map['avg_rating'] ?? 0).toDouble(),
      category: map['category'] ?? 'restaurant',
      status: map['status'] ?? 'pending',
      ownerName: map['owner_name'],
      ownerPhone: map['owner_phone'],
      licenseNo: map['license_no'],
      upiId: map['upi_id'],
      commissionRate: (map['commission_rate'] ?? 0.0).toDouble(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      bannerUrls: banners,
      areaIds: areas,
      openingTime: map['opening_time'] ?? "09:00 AM",
      closingTime: map['closing_time'] ?? "09:00 PM",
      offDay: map['off_day'] ?? "None",
      hasDoubleShift: map['has_double_shift'] ?? false,
      openingTime2: map['opening_time_2'] ?? "05:00 PM",
      closingTime2: map['closing_time_2'] ?? "09:00 PM",
      availableSlots: map['available_slots'] != null 
          ? List<String>.from(map['available_slots']) 
          : [],
    );
  }
}
