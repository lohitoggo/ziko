import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/business_model.dart';
import '../data/food_item_model.dart';
import '../providers/business_provider.dart';
import '../providers/food_item_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/recently_viewed_provider.dart';
import '../../rider/providers/rider_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'business_details_screen.dart';
import 'item_details_screen.dart';
import 'customer_main_shell.dart';
import 'category_shops_screen.dart';
import 'cart_screen.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 👋';
    if (hour < 17) return 'Good Afternoon 👋';
    return 'Good Evening 👋';
  }

  Widget _headerActionIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessesAsync = ref.watch(businessesByAreaProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. ORIGINAL HEADER RESTORED (With Icons)
          SliverAppBar(
            pinned: true, floating: true, backgroundColor: const Color(0xFFF45D27),
            expandedHeight: 155, elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF45D27), Color(0xFFFF8A00)])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 45),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getGreeting(), style: GoogleFonts.sora(color: Colors.white70, fontSize: 13)),
                                userAsync.when(
                                  skipLoadingOnReload: true,
                                  data: (user) => Text(user?.name ?? 'Guest User', style: GoogleFonts.sora(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                  loading: () => Container(width: 100, height: 20, color: Colors.white24),
                                  error: (_, __) => const Text('Welcome!'),
                                ),
                              ],
                            ),
                          ),
                          // --- RESTORED ICONS ---
                          _headerActionIcon(Icons.notifications_none_rounded, () {}),
                          const SizedBox(width: 12),
                          _headerActionIcon(Icons.person_outline_rounded, () {
                            ref.read(customerTabControllerProvider.notifier).state = 3;
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: userAsync.when(
                              skipLoadingOnReload: true,
                              data: (user) => areasAsync.when(
                                skipLoadingOnReload: true,
                                data: (areas) {
                                  final area = areas.firstWhere((a) => a.id == user?.areaId, orElse: () => areas.first);
                                  return Text('${area.name}•${area.estimatedDeliveryMinutes} mins', style: GoogleFonts.sora(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600));
                                },
                                loading: () => const Text('...', style: TextStyle(color: Colors.white)),
                                error: (_, __) => const Text('Select Area', style: TextStyle(color: Colors.white)),
                              ),
                              loading: () => const SizedBox(),
                              error: (_, __) => const SizedBox(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70),
              child: Container(
                height: 70, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
                child: const _SearchBar(),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                const _HorizontalCategories(),

                settingsAsync.when(
                  skipLoadingOnReload: true,
                  data: (settings) => _PremiumBannerCarousel(bannerUrls: List<String>.from(settings?['banner_urls'] ?? [])),
                  loading: () => const SizedBox(height: 160),
                  error: (_, __) => const SizedBox(),
                ),

                const _QuickActionsSection(),

                businessesAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => Column(children: List.generate(3, (index) => const _BusinessCardShimmer())),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (shops) {
                    if (shops.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No shops found')));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(context, 'Trending Near You 🔥', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'all', categoryName: 'Trending Shops')));
                        }),
                        _HorizontalShopList(shops: shops.take(5).toList()),

                        _buildSectionHeader(context, 'Recommended For You ✨', null),
                        const _RecommendedItemsList(category: 'all'),

                        if (shops.any((s) => s.category == 'restaurant' || s.category == 'food')) ...[
                          _buildSectionHeader(context, 'Popular Restaurants 🍛', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'restaurant', categoryName: 'Popular Restaurants')));
                          }),
                          _HorizontalShopList(shops: shops.where((s) => s.category == 'restaurant' || s.category == 'food').toList()),
                        ],

                        if (shops.any((s) => s.category == 'grocery')) ...[
                          _buildSectionHeader(context, 'Fresh Groceries 🍎', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'grocery', categoryName: 'Popular Groceries')));
                          }),
                          _HorizontalShopList(shops: shops.where((s) => s.category == 'grocery').toList()),
                        ],

                        if (shops.any((s) => s.category == 'salon')) ...[
                          _buildSectionHeader(context, 'Premium Salons 💇', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'salon', categoryName: 'Popular Salons')));
                          }),
                          _HorizontalShopList(shops: shops.where((s) => s.category == 'salon').toList()),
                        ],

                        _buildSectionHeader(context, 'All Nearby Shops 🏠', () {}),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          itemCount: shops.length,
                          itemBuilder: (ctx, i) => BusinessCard(business: shops[i]),
                        ),

                        const SizedBox(height: 50),
                        _buildFooter(),
                        const SizedBox(height: 80),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      // --- RESTORED FLOATING ACTION BUTTON ---
      floatingActionButton: const _FloatingCartButton(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback? onSeeAll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text('See All', style: GoogleFonts.sora(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text('ziko super app', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.charcoal, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        Text('© 2024 ziko. All Rights Reserved.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HorizontalShopList extends ConsumerWidget {
  final List<BusinessModel> shops;
  const _HorizontalShopList({required this.shops});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(activeAreasProvider);
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 20),
        itemCount: shops.length,
        itemBuilder: (ctx, i) {
          final b = shops[i];
          return areasAsync.when(
            skipLoadingOnReload: true,
            data: (areas) {
              final area = areas.firstWhere((a) => a.id == b.areaId, orElse: () => areas.first);
              return _TrendingShopCard(business: b, deliveryTime: area.estimatedDeliveryMinutes.toString());
            },
            loading: () => _TrendingShopCard(business: b, deliveryTime: '...'),
            error: (_, __) => _TrendingShopCard(business: b, deliveryTime: '30'),
          );
        },
      ),
    );
  }
}

class _RecommendedItemsList extends ConsumerWidget {
  final String category;
  const _RecommendedItemsList({required this.category});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recommendedItemsProvider);
    return itemsAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        final filtered = category == 'all' ? items : items.where((i) => i.category == category).toList();
        if (filtered.isEmpty) return const SizedBox();
        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _RecommendedItemCard(item: filtered[i]),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RecommendedItemCard extends ConsumerWidget {
  final FoodItemModel item;
  const _RecommendedItemCard({required this.item});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 140, margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: SizedBox(height: 85, width: double.infinity, child: item.imageUrl != null ? CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade50), errorWidget: (c, u, e) => _itemPlaceholder()) : _itemPlaceholder())),
          Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(item.description, style: GoogleFonts.urbanist(fontSize: 9, color: AppColors.muted), maxLines: 1),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₹${item.finalPrice.toInt()}', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              // --- RESTORED QUICK ADD BUTTON ---
              InkWell(
                onTap: () {
                  final cartNotifier = ref.read(cartProvider.notifier);
                  final isSalon = item.category.toLowerCase().contains('salon');
                  
                  cartNotifier.addItem(item, isSalon: isSalon, onSalonLimit: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('স্যালন সার্ভিসের জন্য একবারই বুকিং সম্ভব'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  });
                  
                  if (!isSalon || cartNotifier.quantityOf(item.id) == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.name} added to cart'), duration: const Duration(seconds: 1))
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                ),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
  Widget _itemPlaceholder() => Container(color: AppColors.primary.withValues(alpha: 0.05), child: const Center(child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 30)));
}

class _FloatingCartButton extends ConsumerWidget {
  const _FloatingCartButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartNotifier = ref.watch(cartProvider.notifier);
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty) return const SizedBox();
    return Padding(padding: const EdgeInsets.only(bottom: 70), child: FloatingActionButton.extended(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
      backgroundColor: AppColors.primary, elevation: 12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Stack(alignment: Alignment.center, children: [const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 24), Positioned(top: -2, right: -2, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text('${cartNotifier.totalItems}', style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold))))]),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text('View Cart', style: GoogleFonts.urbanist(color: Colors.white70, fontSize: 12)), Text('₹${cartNotifier.totalAmount.toInt()}', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))]),
        const SizedBox(width: 30), const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
      ]),
    ));
  }
}

class _PremiumBannerCarousel extends StatefulWidget {
  final List<String> bannerUrls;
  const _PremiumBannerCarousel({required this.bannerUrls});
  @override
  State<_PremiumBannerCarousel> createState() => _PremiumBannerCarouselState();
}

class _PremiumBannerCarouselState extends State<_PremiumBannerCarousel> {
  int _currentIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CarouselSlider(
        options: CarouselOptions(
          height: 150, autoPlay: true, enlargeCenterPage: true, viewportFraction: 0.94,
          autoPlayInterval: const Duration(seconds: 5), autoPlayAnimationDuration: const Duration(milliseconds: 800),
          autoPlayCurve: Curves.fastOutSlowIn, onPageChanged: (index, reason) => setState(() => _currentIndex = index),
        ),
        items: widget.bannerUrls.map((url) => Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 10))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, placeholder: (c, u) => Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (c, u, e) => Container(color: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.broken_image_outlined, color: AppColors.primary)))),
        )).toList(),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: widget.bannerUrls.asMap().entries.map((entry) => AnimatedContainer(duration: const Duration(milliseconds: 300), width: _currentIndex == entry.key ? 20 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _currentIndex == entry.key ? AppColors.primary : Colors.grey.shade300))).toList()),
    ]);
  }
}

class _HorizontalCategories extends ConsumerWidget {
  const _HorizontalCategories();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCat = ref.watch(selectedCategoryProvider);
    final categories = [
      {'id': 'all', 'name': 'All', 'icon': Icons.grid_view_rounded, 'color': [const Color(0xFF6448FE), const Color(0xFF5FC6FF)]},
      {'id': 'restaurant', 'name': 'Food', 'icon': Icons.restaurant_rounded, 'color': [const Color(0xFFFE6454), const Color(0xFFFEB58A)]},
      {'id': 'grocery', 'name': 'Grocery', 'icon': Icons.shopping_basket_rounded, 'color': [const Color(0xFF2AF598), const Color(0xFF009EFD)]},
      {'id': 'salon', 'name': 'Salon', 'icon': Icons.content_cut_rounded, 'color': [const Color(0xFFFCCB90), const Color(0xFFD57EEB)]},
      {'id': 'medicine', 'name': 'Medicine', 'icon': Icons.medical_services_rounded, 'color': [const Color(0xFFFF0844), const Color(0xFFFFB199)]},
      {'id': 'electronics', 'name': 'Tech', 'icon': Icons.devices_rounded, 'color': [const Color(0xFF662D8C), const Color(0xFFED1E79)]},
      {'id': 'meat', 'name': 'Meat', 'icon': Icons.set_meal_rounded, 'color': [const Color(0xFFF093FB), const Color(0xFFF5576C)]},
      {'id': 'more', 'name': 'More', 'icon': Icons.more_horiz_rounded, 'color': [const Color(0xFF30E8D8), const Color(0xFF16A085)]},
    ];
    return SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: categories.length, itemBuilder: (ctx, i) {
      final cat = categories[i]; final colors = cat['color'] as List<Color>;
      return Padding(padding: const EdgeInsets.only(right: 12), child: GestureDetector(onTap: () => ref.read(selectedCategoryProvider.notifier).state = cat['id'] as String, child: Column(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300), height: 48, width: 48, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selectedCat == cat['id'] ? AppColors.primary : Colors.transparent, width: 2.0)), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors), boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]), child: Icon(cat['icon'] as IconData, color: Colors.white, size: 24))),
        const SizedBox(height: 6),
        Text(cat['name'] as String, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: selectedCat == cat['id'] ? FontWeight.w800 : FontWeight.w600, color: selectedCat == cat['id'] ? AppColors.primary : AppColors.charcoal)),
      ])));
    }));
  }
}

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();
  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'Order Again', 'icon': Icons.history_rounded, 'color': Colors.blue},
      {'label': 'Best Offers', 'icon': Icons.local_offer_rounded, 'color': Colors.orange},
      {'label': 'Top Rated', 'icon': Icons.star_rounded, 'color': AppColors.softGreen},
      {'label': 'New Stores', 'icon': Icons.storefront_rounded, 'color': Colors.purple},
      {'label': 'Flash Sale', 'icon': Icons.bolt_rounded, 'color': Colors.red},
    ];
    return Container(height: 85, margin: const EdgeInsets.symmetric(vertical: 2), child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: actions.length, itemBuilder: (context, index) {
      final action = actions[index]; final color = action['color'] as Color;
      return Container(width: 75, margin: const EdgeInsets.only(right: 10), child: InkWell(onTap: () {}, borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.1), width: 1.0)), child: Icon(action['icon'] as IconData, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(action['label'] as String, textAlign: TextAlign.center, style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.charcoal)),
      ])));
    }));
  }
}

class BusinessCard extends StatelessWidget {
  final BusinessModel business;
  const BusinessCard({required this.business});
  @override
  Widget build(BuildContext context) {
    final b = business;
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6))]),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessDetailsScreen(business: b))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: SizedBox(height: 150, width: double.infinity, child: b.logoUrl != null ? CachedNetworkImage(imageUrl: b.logoUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: AppColors.primary.withValues(alpha: 0.05)), errorWidget: (c, u, e) => _fallbackImage()) : _fallbackImage())),
            Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)), child: Text(_getShopOffer(b), style: GoogleFonts.urbanist(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
            Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: b.isOnline ? AppColors.softGreen : Colors.grey.shade700, borderRadius: BorderRadius.circular(8)), child: Text(b.isOnline ? 'OPEN' : 'CLOSED', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
          ]),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(b.name, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.charcoal))), _buildRatingBadge(b.avgRating)]),
            const SizedBox(height: 4),
            Row(children: [Text(b.category.toUpperCase(), style: GoogleFonts.urbanist(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)), Text(' • ', style: TextStyle(color: Colors.grey.shade300)), Expanded(child: Text(b.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 12)))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.access_time_rounded, size: 13, color: AppColors.softGreen), const SizedBox(width: 4), Text('25-30 mins', style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(width: 8), Expanded(child: Row(children: [const Icon(Icons.delivery_dining_rounded, size: 13, color: Colors.blue), const SizedBox(width: 4), Flexible(child: Text('FREE DELIVERY', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w800)))]))]),
          ])),
        ]),
      ),
    );
  }
  Widget _buildRatingBadge(double rating) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.softGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 14), const SizedBox(width: 2), Text(rating.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.softGreen))]));
  Widget _fallbackImage() => Container(color: AppColors.primary.withValues(alpha: 0.08), child: const Center(child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 40)));
}

class _TrendingShopCard extends StatelessWidget {
  final BusinessModel business;
  final String deliveryTime;
  const _TrendingShopCard({required this.business, required this.deliveryTime});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210, margin: const EdgeInsets.only(right: 15, bottom: 8, top: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6))]),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessDetailsScreen(business: business))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: SizedBox(height: 110, width: double.infinity, child: business.logoUrl != null ? CachedNetworkImage(imageUrl: business.logoUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade100), errorWidget: (c, u, e) => _fallbackImage()) : _fallbackImage())),
            Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 12), const SizedBox(width: 2), Text(business.avgRating.toStringAsFixed(1), style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 10))]))),
          ]),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(business.name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Row(children: [const Icon(Icons.access_time_rounded, size: 12, color: AppColors.softGreen), const SizedBox(width: 4), Text('$deliveryTime mins • ', style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)), Text(business.category.toUpperCase(), style: GoogleFonts.urbanist(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w700))])])),
        ]),
      ),
    );
  }
  Widget _fallbackImage() => Container(color: AppColors.primary.withValues(alpha: 0.08), child: const Center(child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 40)));
}

class _BusinessCardShimmer extends StatelessWidget {
  const _BusinessCardShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), height: 240,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade100, highlightColor: Colors.white,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 130, width: double.infinity, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22)))),
          Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 20, width: 150, color: Colors.white), const SizedBox(height: 10), Container(height: 14, width: double.infinity, color: Colors.white)]))
        ]),
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))]),
      child: TextField(
        onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
        textAlignVertical: TextAlignVertical.center, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.charcoal),
        decoration: InputDecoration(
          hintText: 'Search restaurants, groceries, salons...',
          hintStyle: GoogleFonts.urbanist(color: AppColors.muted.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: const Padding(padding: EdgeInsets.only(left: 16, right: 8), child: Icon(Icons.search_rounded, color: AppColors.primary, size: 24)),
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
    );
  }
}

String _getShopOffer(BusinessModel b) {
  if (b.avgRating >= 4.5) return 'TOP RATED';
  if (b.category == 'restaurant') return 'FLAT ₹50 OFF';
  return 'SPECIAL OFFER';
}
