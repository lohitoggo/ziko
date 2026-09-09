import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../payouts/providers/payout_provider.dart';
import '../../payouts/data/payout_model.dart';
import '../../../core/theme/app_theme.dart';

class AdminPayoutsTab extends ConsumerStatefulWidget {
  const AdminPayoutsTab({super.key});

  @override
  ConsumerState<AdminPayoutsTab> createState() => _AdminPayoutsTabState();
}

class _AdminPayoutsTabState extends ConsumerState<AdminPayoutsTab> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(allPayoutRequestsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _filterChip('সব', 'all'),
                const SizedBox(width: 8),
                _filterChip('পেন্ডিং ⏳', 'pending'),
                const SizedBox(width: 8),
                _filterChip('সম্পন্ন ✅', 'paid'),
                const SizedBox(width: 8),
                _filterChip('বাতিল ❌', 'rejected'),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: requestsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (requests) {
                  final filtered = _selectedFilter == 'all'
                      ? requests
                      : requests.where((r) => r.status == _selectedFilter).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('কোনো পে-আউট রিকোয়েস্ট নেই', style: GoogleFonts.urbanist(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final req = filtered[i];
                      return _buildPayoutCard(req);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final sel = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
      selected: sel,
      selectedColor: AppColors.primary,
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildPayoutCard(PayoutRequest req) {
    Color statusColor = Colors.orange;
    if (req.status == 'paid') statusColor = Colors.green;
    if (req.status == 'rejected') statusColor = Colors.red;

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Chip(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      req.userType.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    backgroundColor: req.userType == 'rider' ? Colors.blue : Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Text(req.userName, style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text('₹${req.amount.toInt()}', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('ফোন: ${req.userPhone} | তারিখ: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 20),

          // Bank & UPI Details
          if (req.bankDetails != null) ...[
            Text('পে-আউট পেমেন্ট ডিটেইলস:', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            const SizedBox(height: 4),
            if (req.bankDetails!.accountNumber.isNotEmpty && req.bankDetails!.accountNumber != 'N/A') ...[
              Text('হোল্ডার: ${req.bankDetails!.accountHolderName}', style: const TextStyle(fontSize: 13)),
              Text('ব্যাংক: ${req.bankDetails!.bankName} | Acc: ${req.bankDetails!.accountNumber}', style: const TextStyle(fontSize: 13)),
              Text('IFSC: ${req.bankDetails!.ifscCode}', style: const TextStyle(fontSize: 13)),
            ],
            if (req.bankDetails!.upiId.isNotEmpty)
              Text('UPI ID: ${req.bankDetails!.upiId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
          ] else ...[
            const Text('কোনো ব্যাংক ডিটেইলস পাওয়া যায়নি', style: TextStyle(fontSize: 12, color: Colors.red)),
          ],

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  req.status.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (req.status == 'pending')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (req.bankDetails?.upiId != null && req.bankDetails!.upiId.isNotEmpty) ...[
                      ElevatedButton.icon(
                        onPressed: () => _payViaUpiApp(context, req.bankDetails!.upiId, req.userName, req.amount, req.id),
                        icon: const Icon(Icons.phone_android_rounded, size: 16),
                        label: Text('Direct Pay 📲', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _updateStatus(req.id, 'rejected'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, visualDensity: VisualDensity.compact),
                          child: const Text('বাতিল'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _updateStatus(req.id, 'paid'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, visualDensity: VisualDensity.compact),
                          child: const Text('PAID (অনুমোদন)'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _payViaUpiApp(BuildContext context, String upiId, String payeeName, double amount, String reqId) async {
    final cleanUpi = upiId.trim();
    if (cleanUpi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID দেওয়া নেই')));
      return;
    }

    final upiUriStr = 'upi://pay?pa=$cleanUpi&pn=${Uri.encodeComponent(payeeName)}&am=${amount.toInt()}&cu=INR&tn=${Uri.encodeComponent('Ziko Payout')}';
    final Uri upiUri = Uri.parse(upiUriStr);

    try {
      if (await canLaunchUrl(upiUri)) {
        await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(upiUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPI অ্যাপ খোলা সম্ভব হয়নি: $e (আপনি সরাসরি PhonePe/GPay-তে $cleanUpi টাইপ করে পে করতে পারেন)'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await ref.read(payoutRepositoryProvider).updatePayoutStatus(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('স্ট্যাটাস পরিবর্তিত হয়েছে: $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
