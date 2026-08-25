import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/business_provider.dart';
import '../../../core/theme/app_theme.dart';

class AllReviewsScreen extends ConsumerWidget {
  final String itemId;
  final String itemName;

  const AllReviewsScreen({
    super.key,
    required this.itemId,
    required this.itemName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(itemReviewsProvider(itemId));

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('সব রিভিউ', style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
            Text(itemName, style: GoogleFonts.hindSiliguri(fontSize: 12, color: Colors.white70)),
          ],
        ),
        elevation: 0,
      ),
      body: reviewsAsync.when(
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(
              child: Text('কোনো রিভিউ নেই', style: GoogleFonts.hindSiliguri(color: AppColors.muted)),
            );
          }

          final double avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

          return Column(
            children: [
              // Summary Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Text(avg.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
                        const Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                            Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${reviews.length} টি রিভিউ', style: GoogleFonts.hindSiliguri(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) {
                          final star = 5 - index;
                          final count = reviews.where((r) => r.rating.round() == star).length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text('$star', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: reviews.isEmpty ? 0 : count / reviews.length,
                                      backgroundColor: Colors.grey.shade100,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              // Reviews List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade100,
                                backgroundImage: review.profileImageUrl != null 
                                    ? NetworkImage(review.profileImageUrl!) 
                                    : null,
                                child: review.profileImageUrl == null 
                                    ? Icon(Icons.person, size: 20, color: Colors.grey.shade400) 
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review.userName, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.charcoal)),
                                    Text(DateFormat('dd MMM yyyy').format(review.timestamp), style: GoogleFonts.urbanist(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(5, (i) => Icon(
                              Icons.star_rounded, 
                              size: 16, 
                              color: i < review.rating.round() ? AppColors.gold : Colors.grey.shade200
                            )),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            review.comment, 
                            style: GoogleFonts.hindSiliguri(fontSize: 14, color: AppColors.muted, height: 1.4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('রিভিউ লোড করতে সমস্যা হয়েছে: $err')),
      ),
    );
  }
}
