import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Added for kReleaseMode

import 'payment_service.dart';

/// Cashfree test checkout. Secret keys stay in Supabase Edge Function secrets;
/// the app only receives the short-lived payment session id.
class CashfreeServiceImpl implements PaymentService {
  final CFPaymentGatewayService _gateway = CFPaymentGatewayService();
  late void Function(String) _onSuccess;
  late void Function(String) _onFailure;

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

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'cashfree-create-order',
        body: {
          'merchant_order_id': orderId,
          'amount': amount,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_email': customerEmail,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final cashfreeOrderId = data['order_id'] as String?;
      final paymentSessionId = data['payment_session_id'] as String?;
      if (cashfreeOrderId == null || paymentSessionId == null) {
        throw StateError('Cashfree session could not be created.');
      }

      _gateway.setCallback(_verifyPayment, _handlePaymentError);
      final session = CFSessionBuilder()
          .setEnvironment(kReleaseMode ? CFEnvironment.PRODUCTION : CFEnvironment.SANDBOX)
          .setOrderId(cashfreeOrderId)
          .setPaymentSessionId(paymentSessionId)
          .build();
      final checkout = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(
            CFThemeBuilder()
                .setNavigationBarBackgroundColorColor('#F45D27')
                .setNavigationBarTextColor('#FFFFFF')
                .build(),
          )
          .build();
      _gateway.doPayment(checkout);
    } on FunctionException catch (error) {
      _onFailure(
        error.details?.toString() ??
            error.reasonPhrase ??
            'Cashfree order creation failed.',
      );
    } catch (error) {
      _onFailure(error.toString());
    }
  }

  Future<void> _verifyPayment(String orderId) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'cashfree-verify-order',
        body: {'order_id': orderId},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['order_status'] == 'PAID') {
        _onSuccess(orderId);
      } else {
        _onFailure('Payment is not complete yet. Please try again.');
      }
    } on FunctionException catch (error) {
      _onFailure(
        error.details?.toString() ??
            error.reasonPhrase ??
            'Could not verify Cashfree payment.',
      );
    } catch (error) {
      _onFailure('Could not verify Cashfree payment: $error');
    }
  }

  void _handlePaymentError(CFErrorResponse error, String orderId) {
    _onFailure(error.getMessage() ?? 'Cashfree payment failed.');
  }

  @override
  void dispose() {}
}
