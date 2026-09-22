import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'payment_service.dart';

class BharatPeServiceImpl implements PaymentService {
  static const String _bharatPeBaseUrl =
      'https://payments-tesseract.bharatpe.in/api/v1/merchant/transactions';

  static const MethodChannel _upiChannel = MethodChannel('com.ziko/upi_intent');

  /// Launches Android Native UPI Intent to open native app chooser (PhonePe, GPay, Paytm, BHIM, etc.)
  static Future<bool> launchNativeUpiIntent(String upiUri) async {
    try {
      final bool result = await _upiChannel.invokeMethod('launchUpiIntent', {'url': upiUri});
      return result;
    } catch (e) {
      debugPrint('Error launching native UPI intent: $e');
      return false;
    }
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
    // For BharatPe, payment is handled interactively via CheckoutScreen's QR & UPI Deep Link dialog,
    // which polls verifyBharatPePayment. Here we can invoke onSuccess or let checkout screen manage.
    onSuccess(orderId);
  }

  /// Calculates a unique payable amount by adding a small unique fractional paisa
  /// based on the order ID hash, preventing amount collisions for concurrent orders.
  static double calculateUniquePayableAmount(double baseAmount, String orderId) {
    int hash = orderId.hashCode.abs();
    double randomFraction = (hash % 90 + 10) / 1000.0; // e.g., 0.010 to 0.099
    double payable = baseAmount + randomFraction;
    return double.parse(payable.toStringAsFixed(2));
  }

  /// Builds the UPI deep link URI for BharatPe VPA
  static String getUpiIntentUri({
    double? payableAmount,
    required String orderId,
    bool isStatic = false,
  }) {
    final merchantVpa = dotenv.env['BHARATPE_VPA'] ?? 'BHARATPE.8Y0H1P2P9B54003@fbpe';
    final merchantName = dotenv.env['BHARATPE_MERCHANT_NAME'] ?? 'LK ENTERPRISE';

    final encodedVpa = merchantVpa.replaceAll('@', '%40');
    final encodedName = merchantName.replaceAll(' ', '+');

    if (isStatic || payableAmount == null) {
      return 'upi://pay?pa=$encodedVpa&pn=$encodedName&cu=INR';
    }

    final String am = payableAmount.toStringAsFixed(2);
    
    // USER REQUEST: Make transaction ID extremely short (5 chars) and remove message/note entirely.
    final safeTrId = orderId.replaceAll('-', '');
    final veryShortTr = safeTrId.length > 5 ? safeTrId.substring(0, 5) : safeTrId;

    // Bare minimum intent to avoid GPay/PhonePe strict filters. Removed 'tn' (note) completely.
    return 'upi://pay?pa=$encodedVpa&pn=$encodedName&am=$am&tr=$veryShortTr&cu=INR';
  }

  /// Fetches transactions from BharatPe Merchant API within the specified time window
  static Future<List<Map<String, dynamic>>> getBharatPeTransactions({
    required int startMs,
    required int endMs,
  }) async {
    final merchantId = dotenv.env['BHARATPE_MERCHANT_ID'] ?? '68424909';
    final token = dotenv.env['BHARATPE_TOKEN'] ?? '';

    if (token.isEmpty) {
      debugPrint('BHARATPE_TOKEN is not configured in dotenv');
      return [];
    }

    try {
      final uri = Uri.parse(_bharatPeBaseUrl).replace(
        queryParameters: {
          'module': 'PAYMENT_QR',
          'merchantId': merchantId,
          'sDate': startMs.toString(),
          'eDate': endMs.toString(),
          'pageSize': '10',
          'pageCount': '0',
          'isFromOtDashboard': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'token': token,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          final transactions = data['data']?['transactions'];
          if (transactions is List) {
            return List<Map<String, dynamic>>.from(transactions);
          }
        }
      } else {
        debugPrint('BharatPe API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('BharatPe API exception: $e');
    }

    return [];
  }

  /// Verifies if a payment matching the expected amount and order creation timestamp has arrived
  static Future<Map<String, dynamic>?> verifyBharatPePayment({
    required double expectedAmount,
    required int orderCreatedAtMs,
  }) async {
    final startMs = orderCreatedAtMs - (2 * 60 * 1000); // 2 minutes before order creation
    final endMs = DateTime.now().millisecondsSinceEpoch + (60 * 1000); // 1 minute buffer into future

    final transactions = await getBharatPeTransactions(
      startMs: startMs,
      endMs: endMs,
    );

    final merchantId = dotenv.env['BHARATPE_MERCHANT_ID'] ?? '68424909';

    final candidates = transactions.where((txn) {
      final txnMerchantId = txn['merchantId']?.toString();
      final txnType = txn['type']?.toString();
      final txnStatus = txn['status']?.toString();
      final txnAmount = num.tryParse(txn['amount']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final txnTimestamp = num.tryParse(txn['paymentTimestamp']?.toString() ?? '0')?.toInt() ?? 0;

      return txnMerchantId == merchantId &&
          txnType == 'PAYMENT_RECV' &&
          txnStatus == 'SUCCESS' &&
          (txnAmount - expectedAmount).abs() < 0.01 && // Float comparison tolerance
          txnTimestamp >= orderCreatedAtMs;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    // Return the first matching successful transaction
    final txn = candidates.first;
    return {
      'transactionId': txn['id']?.toString() ?? '',
      'internalUtr': txn['internalUtr']?.toString() ?? '',
      'bankReferenceNo': txn['bankReferenceNo']?.toString() ?? '',
      'amount': num.tryParse(txn['amount']?.toString() ?? '0')?.toDouble() ?? expectedAmount,
      'paymentTimestamp': num.tryParse(txn['paymentTimestamp']?.toString() ?? '0')?.toInt() ?? 0,
      'payerName': txn['payerName']?.toString() ?? '',
      'payerHandle': txn['payerHandle']?.toString() ?? '',
    };
  }

  @override
  void dispose() {
    // Nothing to dispose
  }
}
