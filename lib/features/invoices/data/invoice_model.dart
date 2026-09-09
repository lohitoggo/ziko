import 'package:intl/intl.dart';

class InvoiceItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    final qty = ((map['quantity'] ?? map['qty'] ?? 1) as num).toInt();
    final price = ((map['price'] ?? map['food']?['price'] ?? 0) as num).toDouble();
    final sub = ((map['subtotal'] ?? (price * qty)) as num).toDouble();
    return InvoiceItem(
      name: map['name'] ?? map['food']?['name'] ?? map['title'] ?? 'Item',
      quantity: qty,
      unitPrice: price,
      totalPrice: sub,
    );
  }
}

class InvoiceModel {
  final String invoiceNo;
  final String orderId;
  final DateTime orderDate;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String merchantName;
  final String merchantAddress;
  final List<InvoiceItem> items;
  final double subtotal;
  final double deliveryCharge;
  final double platformFee;
  final double gst;
  final double grandTotal;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;

  InvoiceModel({
    required this.invoiceNo,
    required this.orderId,
    required this.orderDate,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.merchantName,
    required this.merchantAddress,
    required this.items,
    required this.subtotal,
    required this.deliveryCharge,
    required this.platformFee,
    required this.gst,
    required this.grandTotal,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
  });

  factory InvoiceModel.fromOrderMap(Map<String, dynamic> order, {List<Map<String, dynamic>>? fetchedItems, Map<String, dynamic>? user, Map<String, dynamic>? merchant}) {
    final rawItems = fetchedItems ?? (order['items'] as List?) ?? [];
    final itemList = rawItems.map((i) => InvoiceItem.fromMap(Map<String, dynamic>.from(i))).toList();

    final orderIdStr = order['id']?.toString() ?? order['orderId']?.toString() ?? 'ZK-${DateTime.now().millisecondsSinceEpoch}';
    final invNo = 'INV-${orderIdStr.length > 8 ? orderIdStr.substring(0, 8).toUpperCase() : orderIdStr.toUpperCase()}';

    final dateStr = order['placed_at'] ?? order['created_at'];
    final date = dateStr != null ? (DateTime.tryParse(dateStr.toString()) ?? DateTime.now()) : DateTime.now();

    final house = order['house_number'] ?? '';
    final village = order['village'] ?? '';
    final landmark = order['landmark'] ?? '';
    final pin = order['pin_code'] ?? '';
    final fullAddr = '$house, $village, $landmark, $pin'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');

    final double totalAmt = ((order['total_amount'] ?? order['totalAmount'] ?? 0) as num).toDouble();
    final double delCharge = ((order['delivery_charge'] ?? order['deliveryCharge'] ?? 0) as num).toDouble();
    final double platFee = ((order['platform_fee'] ?? order['platformFee'] ?? 2) as num).toDouble();
    final double gstVal = ((order['gst'] ?? 0) as num).toDouble();

    double sub = ((order['subtotal'] ?? 0) as num).toDouble();
    if (sub == 0 && itemList.isNotEmpty) {
      sub = itemList.fold(0.0, (sum, item) => sum + item.totalPrice);
    }
    if (sub == 0 && totalAmt > 0) {
      final calcSub = totalAmt - delCharge - platFee - gstVal;
      sub = calcSub < 0 ? totalAmt : calcSub;
    }

    return InvoiceModel(
      invoiceNo: invNo,
      orderId: orderIdStr,
      orderDate: date,
      customerName: user?['name'] ?? order['customer_name'] ?? 'Customer',
      customerPhone: user?['phone'] ?? order['customer_phone'] ?? 'N/A',
      customerAddress: fullAddr.isEmpty ? 'Home Delivery' : fullAddr,
      merchantName: merchant?['name'] ?? order['restaurant_name'] ?? 'Merchant',
      merchantAddress: merchant?['address'] ?? 'Local Store',
      items: itemList,
      subtotal: sub,
      deliveryCharge: delCharge,
      platformFee: platFee,
      gst: gstVal,
      grandTotal: totalAmt,
      paymentMethod: (order['payment_method'] ?? order['paymentMethod'] ?? 'COD').toString().toUpperCase(),
      paymentStatus: (order['payment_status'] ?? order['paymentStatus'] ?? 'pending').toString().toUpperCase(),
      orderStatus: (order['status'] ?? 'placed').toString().toUpperCase(),
    );
  }

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(orderDate);
}
