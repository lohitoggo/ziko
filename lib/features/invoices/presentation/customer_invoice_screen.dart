import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/invoice_model.dart';
import '../../../core/theme/app_theme.dart';

class CustomerInvoiceScreen extends StatelessWidget {
  final InvoiceModel invoice;
  const CustomerInvoiceScreen({super.key, required this.invoice});

  Future<void> _downloadOrPrintPdf(BuildContext context, InvoiceModel invoice) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ziko', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
                        pw.Text('A Unit of LK Enterprise', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text('Jhikira, Howrah, West Bengal, India', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(color: PdfColors.orange100, borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, height: 20),

                // Invoice Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('INVOICE NO: ${invoice.invoiceNo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('ORDER ID: #${invoice.orderId}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('ORDER PLACED: ${invoice.formattedDate}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('ORDER STATUS: ${invoice.orderStatus}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: invoice.orderStatus == 'DELIVERED' ? PdfColors.green : PdfColors.deepOrange)),
                        pw.Text('PAYMENT METHOD: ${invoice.paymentMethod}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('PAYMENT STATUS: ${invoice.paymentStatus}', style: pw.TextStyle(fontSize: 10, color: PdfColors.green)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, height: 20),

                // Billed To & Merchant
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILLED TO (CUSTOMER):', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.Text(invoice.customerName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.customerPhone, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(invoice.customerAddress, style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('MERCHANT / STORE:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.Text(invoice.merchantName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoice.merchantAddress, style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // Table
                pw.Text('ORDER ITEMS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['ITEM', 'QTY', 'PRICE', 'TOTAL'],
                  data: invoice.items.map((item) => [
                    item.name,
                    '${item.quantity}',
                    'INR ${item.unitPrice.toInt()}',
                    'INR ${item.totalPrice.toInt()}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                ),
                pw.SizedBox(height: 16),

                // Summary
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)), pw.Text('INR ${invoice.subtotal.toInt()}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Delivery Fee:', style: const pw.TextStyle(fontSize: 10)), pw.Text('INR ${invoice.deliveryCharge.toInt()}', style: const pw.TextStyle(fontSize: 10))]),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Platform Fee:', style: const pw.TextStyle(fontSize: 10)), pw.Text('INR ${invoice.platformFee.toInt()}', style: const pw.TextStyle(fontSize: 10))]),
                        if (invoice.gst > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GST:', style: const pw.TextStyle(fontSize: 10)), pw.Text('INR ${invoice.gst.toInt()}', style: const pw.TextStyle(fontSize: 10))]),
                        pw.Divider(thickness: 1),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.Text('INR ${invoice.grandTotal.toInt()}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange))]),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Text('Thank you for ordering with ziko! Computer-generated tax invoice.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Ziko_Invoice_${invoice.invoiceNo}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: Text('Tax Invoice & Receipt', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download / Print PDF',
            onPressed: () => _downloadOrPrintPdf(context, invoice),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ziko', style: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          Text('A Unit of LK Enterprise', style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          Text('Jhikira, Howrah, West Bengal, India', style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('TAX INVOICE', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // Invoice Details Meta
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _labelVal('INVOICE NO:', invoice.invoiceNo),
                          const SizedBox(height: 6),
                          _labelVal('ORDER ID:', '#${invoice.orderId.length > 10 ? invoice.orderId.substring(0, 10).toUpperCase() : invoice.orderId}'),
                          const SizedBox(height: 6),
                          _labelVal('ORDER PLACED TIME:', invoice.formattedDate),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _labelVal('ORDER STATUS:', invoice.orderStatus, isHighlight: invoice.orderStatus == 'DELIVERED'),
                          const SizedBox(height: 6),
                          _labelVal('PAYMENT METHOD:', invoice.paymentMethod),
                          const SizedBox(height: 6),
                          _labelVal('PAYMENT STATUS:', invoice.paymentStatus, isHighlight: true),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // Customer & Merchant Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BILLED TO (CUSTOMER):', style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(invoice.customerName, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(invoice.customerPhone, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey.shade700)),
                            Text(invoice.customerAddress, style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('MERCHANT / STORE:', style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Text(invoice.merchantName, textAlign: TextAlign.end, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(invoice.merchantAddress, textAlign: TextAlign.end, style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Itemized Table
                  Text('ORDER ITEMS', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text('ITEM', style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('PRICE', textAlign: TextAlign.right, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),

                        // Items Rows
                        ...invoice.items.map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(item.name, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600))),
                              Expanded(flex: 1, child: Text('${item.quantity}', textAlign: TextAlign.center, style: GoogleFonts.urbanist(fontSize: 12))),
                              Expanded(flex: 1, child: Text('₹${item.unitPrice.toInt()}', textAlign: TextAlign.right, style: GoogleFonts.urbanist(fontSize: 12))),
                              Expanded(flex: 1, child: Text('₹${item.totalPrice.toInt()}', textAlign: TextAlign.right, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Summary
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        children: [
                          _summaryRow('Subtotal', invoice.subtotal),
                          _summaryRow('Delivery Charge', invoice.deliveryCharge),
                          _summaryRow('Platform Fee', invoice.platformFee),
                          if (invoice.gst > 0) _summaryRow('GST / Taxes', invoice.gst),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GRAND TOTAL', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w900)),
                              Text('₹${invoice.grandTotal.toInt()}', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Footer Disclaimer
                  Center(
                    child: Column(
                      children: [
                        Text('Thank you for ordering with ziko!', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Text('This is a computer-generated invoice and does not require a physical signature.', textAlign: TextAlign.center, style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Download PDF Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _downloadOrPrintPdf(context, invoice),
                icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                label: Text('DOWNLOAD / PRINT PDF INVOICE', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _labelVal(String label, String val, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        Text(val, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold, color: isHighlight ? Colors.green : AppColors.charcoal)),
      ],
    );
  }

  Widget _summaryRow(String label, double val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey.shade700)),
          Text('₹${val.toInt()}', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
