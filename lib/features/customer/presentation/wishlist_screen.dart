import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/wishlist_provider.dart';
import '../providers/cart_provider.dart';
import '../data/food_item_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'item_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Premium Gradient Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 16,
              right: 16,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF45D27), Color(0xFFFF8A00)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Wishlist',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Items you have saved for later',
                      style: GoogleFonts.urbanist(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: wishlistAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) {
                if (wishlistAsync.hasValue) return _buildWishlist(wishlistAsync.value!, context, ref);
                return Center(child: Text('Error: $e'));
              },
              data: (items) => _buildWishlist(items, context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlist(List<FoodItemModel> items, BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: Icon(Icons.favorite_rounded, size: 64, color: Colors.red.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 20),
            Text('Your wishlist is empty', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.charcoal)),
            const SizedBox(height: 8),
            const Text('Save items you love to find them later!', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl ?? '',
                      width: 85, height: 85,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: Colors.grey.shade100),
                      errorWidget: (c, u, e) => Container(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        child: const Icon(Icons.fastfood, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name, 
                          style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.charcoal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.category, 
                          style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '₹${item.finalPrice.toInt()}', 
                              style: GoogleFonts.urbanist(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                            if (item.hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${item.price.toInt()}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.favorite_rounded, color: Colors.red),
                        onPressed: () => ref.read(wishlistRepositoryProvider).toggleWishlist(
                          ref.read(supabaseUserProvider)!.id, 
                          item.id
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => ref.read(cartProvider.notifier).addItem(item),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
