import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cashfree_service_impl.dart';
import 'razorpay_service_impl.dart';
import 'phonepe_service_impl.dart';

/// Abstract class to define common payment operations.
/// This allows switching between Razorpay, BulkPe, PhonePe etc., without touching the UI.
abstract class PaymentService {
  Future<void> openPayment({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required Function(String paymentId) onSuccess,
    required Function(String error) onFailure,
  });

  void dispose();
}

enum PaymentGateway { razorpay, cashfree, phonepe }

PaymentService paymentServiceFor(PaymentGateway gateway) {
  switch (gateway) {
    case PaymentGateway.razorpay:
      return RazorpayServiceImpl();
    case PaymentGateway.cashfree:
      return CashfreeServiceImpl();
    case PaymentGateway.phonepe:
      return PhonePeServiceImpl();
  }
}

/// Provider to access the active payment service.
/// The legacy provider continues to return Razorpay. New checkout flows should use
/// [paymentServiceFor] so customers can select a gateway.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return RazorpayServiceImpl();
});
