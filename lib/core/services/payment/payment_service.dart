import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'razorpay_service_impl.dart';

/// Abstract class to define common payment operations.
/// This allows switching between Razorpay, BulkPe, etc., without touching the UI.
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

/// Provider to access the active payment service.
/// To switch to BulkPe in the future, just change 'RazorpayServiceImpl' to 'BulkPeServiceImpl'.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return RazorpayServiceImpl();
});
