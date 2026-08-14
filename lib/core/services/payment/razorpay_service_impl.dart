import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'payment_service.dart';

class RazorpayServiceImpl implements PaymentService {
  late Razorpay _razorpay;
  late Function(String) _onSuccess;
  late Function(String) _onFailure;

  RazorpayServiceImpl() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  Future<void> openPayment({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required Function(String paymentId) onSuccess,
    required Function(String error) onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;

    final options = {
      'key': 'rzp_test_TEU2e9njVt2N4C',
      'amount': (amount * 100).toInt(), // Razorpay expects amount in paise
      'name': 'Ziko Marketplace',
      'description': 'Order #$orderId',
      'prefill': {
        'contact': customerPhone,
        'email': customerEmail,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _onFailure(e.toString());
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _onSuccess(response.paymentId ?? '');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _onFailure(response.message ?? 'Payment Failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onFailure('External wallet selected: ${response.walletName}');
  }

  @override
  void dispose() {
    _razorpay.clear();
  }
}
