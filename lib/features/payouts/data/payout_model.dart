class BankDetails {
  final String userId;
  final String accountHolderName;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String upiId;

  BankDetails({
    required this.userId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    required this.upiId,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
    };
  }

  factory BankDetails.fromMap(Map<String, dynamic> map) {
    return BankDetails(
      userId: map['user_id'] ?? '',
      accountHolderName: map['account_holder_name'] ?? '',
      bankName: map['bank_name'] ?? '',
      accountNumber: map['account_number'] ?? '',
      ifscCode: map['ifsc_code'] ?? '',
      upiId: map['upi_id'] ?? '',
    );
  }
}

class PayoutRequest {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String userType; // 'rider' or 'restaurant'
  final double amount;
  final String status; // 'pending', 'approved', 'paid', 'rejected'
  final BankDetails? bankDetails;
  final DateTime createdAt;

  PayoutRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.userType,
    required this.amount,
    required this.status,
    this.bankDetails,
    required this.createdAt,
  });

  factory PayoutRequest.fromMap(Map<String, dynamic> map) {
    return PayoutRequest(
      id: map['id']?.toString() ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'User',
      userPhone: map['user_phone'] ?? '',
      userType: map['user_type'] ?? 'rider',
      amount: (map['amount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'pending',
      bankDetails: map['bank_details'] != null ? BankDetails.fromMap(Map<String, dynamic>.from(map['bank_details'])) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
