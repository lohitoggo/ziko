import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/business_model.dart';
import '../data/food_item_model.dart';
import '../providers/food_item_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../../core/theme/app_theme.dart';
import 'cart_screen.dart';
import 'item_details_screen.dart';

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  final BusinessModel business;
  const BusinessDetailsScreen({super.key, required this.business});

  @override
  ConsumerState<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends ConsumerState<BusinessDetailsScreen> {
  int _currentImageIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(recentlyViewedProvider.notifier).addView(widget.business.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsByBusinessProvider(widget.business.id));
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);

    final displayImages = widget.business.bannerUrls.isNotEmpty 
        ? widget.business.bannerUrls 
        : (widget.business.logoUrl != null ? [widget.business.logoUrl!] : []);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Premium Image Carousel Header
              SliverAppBar(
                expandedHeight: 250, // Back to premium height
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 290, // Exactly match expandedHeight
                          viewportFraction: 1.0,
                          autoPlay: false,
                          enableInfiniteScroll: displayImages.length > 1,
                          onPageChanged: (index, reason) => setState(() => _currentImageIndex = index),
                        ),
                        items: displayImages.map((url) => Hero(
                          tag: 'shop_logo_${widget.business.id}',
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.grey.shade200),
                            errorWidget: (c, u, e) => _bannerFallback(),
                          ),
                        )).toList(),
                      ),
                      // Image Counter
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1}/${displayImages.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleAction(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
                    Row(
                      children: [
                        Consumer(builder: (context, ref, _) {
                          // Heart Icon logic for Business could be added if needed, 
                          // but usually heart is on specific items.
                          return _circleAction(Icons.favorite_border_rounded, () {});
                        }),
                        const SizedBox(width: 12),
                        _circleAction(Icons.share_outlined, () {}),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Store Information Card
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20), // Restored original padding
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.business.name,
                              style: GoogleFonts.urbanist(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.charcoal),
                            ),
                          ),
                          _statusBadge(widget.business.isOnline),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.business.description,
                        style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _infoTile(Icons.star_rounded, widget.business.avgRating.toStringAsFixed(1), AppColors.gold),
                          userAsync.when(
                            data: (user) => areasAsync.when(
                              data: (areasList) {
                                final List<AreaModel> areas = List<AreaModel>.from(areasList);
                                if (areas.isEmpty) return const SizedBox.shrink();

                                final AreaModel area = areas.firstWhere(
                                  (a) => a.id == user?.areaId, 
                                  orElse: () => areas.first,
                                );
                                final areaText ='${area.name}•${area.estimatedDeliveryMinutes} min';
                                return Row(
                                  children: [
                                    _infoTile(Icons.access_time_filled_rounded, areaText, AppColors.softGreen),
                                    _vDivider(),
                                    _infoTile(Icons.delivery_dining_rounded, area.deliveryCharge == 0 ? 'FREE' : '₹${area.deliveryCharge.toInt()}', Colors.blue),
                                  ],
                                );
                              },
                              loading: () => const Text('...'),
                              error: (_, _) => const Text('Error'),
                            ),
                            loading: () => const Text('...'),
                            error: (_, _) => const Text('Error'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      
                      // Search Menu
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search in Items...',
                            hintStyle: GoogleFonts.urbanist(color: Colors.grey, fontSize: 14),
                            icon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Dynamic Category Chips
              itemsAsync.when(
                data: (items) {
                  // Dynamically extract unique categories from items
                  final categories = ['All', ...items.map((e) => e.category).toSet()];
                  
                  return SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      minHeight: 60,
                      maxHeight: 60,
                      child: Container(
                        color: const Color(0xFFFFF8F4), // Blend with background
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: categories.length,
                          itemBuilder: (ctx, i) {
                            final isSelected = _selectedCategory == categories[i];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ChoiceChip(
                                label: Text(categories[i]),
                                selected: isSelected,
                                onSelected: (v) => setState(() => _selectedCategory = categories[i]),
                                backgroundColor: Colors.white,
                                selectedColor: AppColors.primary,
                                labelStyle: GoogleFonts.urbanist(
                                  color: isSelected ? Colors.white : AppColors.charcoal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade200)),
                                showCheckmark: false,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // 5. Menu Items List
              itemsAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (items) {
                  final filteredItems = items.where((item) {
                    final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return const SliverFillRemaining(child: Center(child: Text('No items found')));
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CompactFoodCard(
                          item: filteredItems[i],
                          quantity: cartNotifier.quantityOf(filteredItems[i].id),
                          onAdd: () {
                            final isSalon = widget.business.category.toLowerCase().contains('salon');
                            cartNotifier.addItem(filteredItems[i], isSalon: isSalon, onSalonLimit: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('স্যালন সার্ভিসের জন্য একবারই বুকিং সম্ভব'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            });
                          },
                          onRemove: () => cartNotifier.removeItem(filteredItems[i].id),
                        ),
                        childCount: filteredItems.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Working Offline', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 6. Floating Cart Bar (Universal Support)
          if (cart.isNotEmpty)
            Positioned(
              bottom: 20, left: 16, right: 16,
              child: _FloatingCheckoutBar(
                itemCount: cartNotifier.totalItems,
                totalAmount: cartNotifier.totalAmount,
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.charcoal, size: 20),
      ),
    );
  }

  Widget _statusBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: online ? AppColors.softGreen.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        online ? 'OPEN' : 'CLOSED',
        style: TextStyle(color: online ? AppColors.softGreen : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _vDivider() => Container(height: 15, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 12));

  Widget _bannerFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFF45D27), Color(0xFFFF8A00)]),
      ),
      child: const Center(child: Icon(Icons.storefront_rounded, color: Colors.white70, size: 60)),
    );
  }
}

class _CompactFoodCard extends StatelessWidget {
  final FoodItemModel item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CompactFoodCard({
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(item.isVeg ? Icons.eco_rounded : Icons.set_meal_rounded, color: item.isVeg ? Colors.green : Colors.red, size: 16),
                        Consumer(builder: (context, ref, _) {
                          final isInWishlist = ref.watch(isInWishlistProvider(item.id)).value ?? false;
                          return IconButton(
                            icon: Icon(isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                color: isInWishlist ? Colors.red : Colors.grey.shade400, size: 20),
                            onPressed: () async {
                              final user = ref.read(supabaseUserProvider);
                              if (user != null) {
                                await ref.read(wishlistRepositoryProvider).toggleWishlist(user.id, item.id);
                                ref.invalidate(isInWishlistProvider(item.id));
                              }
                            },
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.name, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
                    const SizedBox(height: 4),
                    Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('₹${item.finalPrice.toInt()}', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900)),
                        if (item.hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text('₹${item.price.toInt()}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Image and Add Button
              Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Hero(
                        tag: 'item_image_${item.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl ?? '',
                            width: 110, height: 110,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => Container(color: Colors.grey.shade100, child: const Icon(Icons.fastfood_rounded, color: Colors.grey)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -15,
                        child: quantity == 0 
                          ? ElevatedButton(
                              onPressed: onAdd,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                elevation: 4,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)],
                              ),
                              child: Row(
                                children: [
                                  IconButton(icon: const Icon(Icons.remove, color: Colors.white, size: 16), onPressed: onRemove, constraints: const BoxConstraints(minWidth: 32)),
                                  Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Colors.white, size: 16), 
                                    onPressed: onAdd,
                                    constraints: const BoxConstraints(minWidth: 32)
                                  ),
                                ],
                              ),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCheckoutBar extends StatelessWidget {
  final int itemCount;
  final double totalAmount;
  const _FloatingCheckoutBar({required this.itemCount, required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$itemCount ITEMS', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('₹${totalAmount.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text('VIEW CART', style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverAppBarDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override double get minExtent => minHeight;
  @override double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;

  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => true;
}
