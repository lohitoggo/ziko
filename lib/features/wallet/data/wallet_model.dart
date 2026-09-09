class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final String type; // 'credit' (money added/refunded) or 'debit' (money spent)
  final String title;
  final String description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id']?.toString() ?? '',
      userId: map['user_id'] ?? '',
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      type: map['type'] ?? 'credit',
      title: map['title'] ?? 'Transaction',
      description: map['description'] ?? '',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'type': type,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
