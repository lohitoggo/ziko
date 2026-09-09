import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/invoice_model.dart';

class VendorThermalInvoiceScreen extends StatelessWidget {
  final InvoiceModel invoice;
  const VendorThermalInvoiceScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text('Thermal Receipt (POS)', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: 320, // Standard 80mm POS width
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Thermal Header
                Text(invoice.merchantName.toUpperCase(), textAlign: TextAlign.center, style: GoogleFonts.courierPrime(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(invoice.merchantAddress, textAlign: TextAlign.center, style: GoogleFonts.courierPrime(fontSize: 10)),
                const SizedBox(height: 8),
                Text('================================', style: GoogleFonts.courierPrime(fontSize: 11)),
                Text('ORDER RECEIPT', style: GoogleFonts.courierPrime(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('================================', style: GoogleFonts.courierPrime(fontSize: 11)),
                const SizedBox(height: 8),

                // Order Metadata
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORDER ID: #${invoice.orderId.length > 8 ? invoice.orderId.substring(0, 8).toUpperCase() : invoice.orderId}', style: GoogleFonts.courierPrime(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('ORDER STATUS: ${invoice.orderStatus}', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('PLACED TIME: ${invoice.formattedDate}', style: GoogleFonts.courierPrime(fontSize: 10)),
                      Text('PAYMENT: ${invoice.paymentMethod} (${invoice.paymentStatus})', style: GoogleFonts.courierPrime(fontSize: 10, fontWeight: FontWeight.bold)),
                      Text('CUSTOMER: ${invoice.customerName}', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('PHONE: ${invoice.customerPhone}', style: GoogleFonts.courierPrime(fontSize: 10)),
                      if (invoice.customerAddress.isNotEmpty) Text('ADDR: ${invoice.customerAddress}', style: GoogleFonts.courierPrime(fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text('--------------------------------', style: GoogleFonts.courierPrime(fontSize: 11)),

                // Itemized Header
                Row(
                  children: [
                    Expanded(flex: 3, child: Text('ITEM', style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 1, child: Text('AMT', textAlign: TextAlign.right, style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                ),
                Text('--------------------------------', style: GoogleFonts.courierPrime(fontSize: 11)),

                // Item Rows
                ...invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: Text(item.name, style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('₹${item.totalPrice.toInt()}', textAlign: TextAlign.right, style: GoogleFonts.courierPrime(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                )),

                Text('--------------------------------', style: GoogleFonts.courierPrime(fontSize: 11)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL ITEMS:', style: GoogleFonts.courierPrime(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('${invoice.items.fold(0, (s, i) => s + i.quantity)}', style: GoogleFonts.courierPrime(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL AMOUNT:', style: GoogleFonts.courierPrime(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('₹${invoice.grandTotal.toInt()}', style: GoogleFonts.courierPrime(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('================================', style: GoogleFonts.courierPrime(fontSize: 11)),
                const SizedBox(height: 12),

                // QR Code for Order Verification
                QrImageView(
                  data: invoice.orderId,
                  version: QrVersions.auto,
                  size: 100.0,
                ),
                const SizedBox(height: 4),
                Text('Scan QR for Pass Verification', style: GoogleFonts.courierPrime(fontSize: 9, color: Colors.grey)),
                const SizedBox(height: 12),
                Text('*** Powered by ziko ***', style: GoogleFonts.courierPrime(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
