class AreaModel {
  final String id;
  final String name;
  final double deliveryCharge;
  final double minimumOrder;
  final int estimatedDeliveryMinutes;
  final String status;

  AreaModel({
    required this.id,
    required this.name,
    required this.deliveryCharge,
    required this.minimumOrder,
    required this.estimatedDeliveryMinutes,
    required this.status,
  });

  factory AreaModel.fromMap(String id, Map<String, dynamic> map) {
    return AreaModel(
      id: id,
      name: map['name'] ?? '',
      deliveryCharge: (map['delivery_charge'] ?? 0).toDouble(),
      minimumOrder: (map['min_order_amount'] ?? 0).toDouble(),
      estimatedDeliveryMinutes: map['estimated_delivery_minutes'] ?? 0,
      status: (map['is_active'] ?? true) ? 'active' : 'inactive',
    );
  }
}