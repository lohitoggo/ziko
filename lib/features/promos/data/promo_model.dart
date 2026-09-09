class PromoCode {
  final String id;
  final String code;
  final String discountType; // 'flat' or 'percentage'
  final double discountValue; // e.g., 50 or 20 (%)
  final double minOrderAmount; // e.g., 200
  final double maxDiscount; // e.g., 100 (for percentage)
  final bool isActive;
  final DateTime? expiryDate;

  PromoCode({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount = 0.0,
    this.maxDiscount = 1000.0,
    this.isActive = true,
    this.expiryDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code.toUpperCase().trim(),
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount': maxDiscount,
      'is_active': isActive,
      'expiry_date': expiryDate?.toIso8601String(),
    };
  }

  factory PromoCode.fromMap(Map<String, dynamic> map) {
    return PromoCode(
      id: map['id']?.toString() ?? '',
      code: (map['code'] ?? '').toString().toUpperCase(),
      discountType: map['discount_type'] ?? 'flat',
      discountValue: ((map['discount_value'] ?? 0) as num).toDouble(),
      minOrderAmount: ((map['min_order_amount'] ?? 0) as num).toDouble(),
      maxDiscount: ((map['max_discount'] ?? 1000) as num).toDouble(),
      isActive: map['is_active'] ?? true,
      expiryDate: map['expiry_date'] != null ? DateTime.tryParse(map['expiry_date'].toString()) : null,
    );
  }

  /// Calculates discount amount for a given order subtotal
  double calculateDiscount(double subtotal) {
    if (!isActive) return 0.0;
    if (subtotal < minOrderAmount) return 0.0;
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) return 0.0;

    if (discountType == 'flat') {
      return discountValue > subtotal ? subtotal : discountValue;
    } else {
      double calculated = (subtotal * discountValue) / 100.0;
      return calculated > maxDiscount ? maxDiscount : calculated;
    }
  }
}
