import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/business_model.dart';
import '../data/food_item_model.dart';
import '../providers/business_provider.dart';
import '../providers/cart_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'business_details_screen.dart';
import 'item_details_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'customer_main_shell.dart';
import 'category_shops_screen.dart';
import '../../grocery/presentation/grocery_home_screen.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../grocery/presentation/widgets/product_card.dart';
import '../../grocery/data/models/product_model.dart';
import '../../../core/widgets/floating_cart_button.dart';

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
    final selectedCat = ref.watch(selectedCategoryProvider);

    // --- Dynamic Theme Logic (Salon, Grocery, Meat, Medicine, Tech) ---
    final isSalon = selectedCat == 'salon';
    final isGrocery = selectedCat == 'grocery';
    final isMeat = selectedCat == 'meat';
    final isMedicine = selectedCat == 'medicine';
    final isTech = selectedCat == 'electronics';

    final bgColor = isSalon ? const Color(0xFF121214) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;
    
    final primaryColor = isSalon 
        ? const Color(0xFFFFD700) 
        : (isGrocery ? const Color(0xFF00B251) 
            : (isMeat ? const Color(0xFFE11D48) 
                : (isMedicine ? const Color(0xFFFF0844)
                    : (isTech ? const Color(0xFF662D8C) : const Color(0xFFF45D27)))));
    
    final headerGradient = isSalon 
        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000000), Color(0xFF1A1A1B)])
        : (isGrocery 
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF00B251), Color(0xFF8CC63F)])
            : (isMeat 
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF991B1B), Color(0xFFE11D48)])
                : (isMedicine
                    ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF0844), Color(0xFFFFB199)])
                    : (isTech
                        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF662D8C), Color(0xFFED1E79)])
                        : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF45D27), Color(0xFFFF8A00)])))));

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
        color: bgColor,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true, floating: true, backgroundColor: isSalon ? Colors.black : primaryColor,
              expandedHeight: 155, elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(gradient: headerGradient),
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
                                    data: (user) => Text(user?.name ?? 'Guest User', style: GoogleFonts.sora(color: isSalon ? primaryColor : Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                                    loading: () => Container(width: 100, height: 20, color: Colors.white24),
                                    error: (_, _) => const Text('Welcome!'),
                                  ),
                                ],
                              ),
                            ),
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
                          Icon(Icons.location_on_rounded, color: isSalon ? primaryColor : Colors.white, size: 14),
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
                                  error: (_, _) => const Text('Select Area', style: TextStyle(color: Colors.white)),
                                ),
                                loading: () => const SizedBox(),
                                error: (_, _) => const SizedBox(),
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOutCubic,
                  height: 70, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(35))),
                  child: _SearchBar(isSalon: isSalon, isGrocery: isGrocery, isMeat: isMeat, isMedicine: isMedicine, isTech: isTech, primaryColor: primaryColor),
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
                    skipLoadingOnRefresh: true,
                    data: (settings) => _PremiumBannerCarousel(bannerUrls: List<String>.from(settings?['banner_urls'] ?? [])),
                    loading: () => const SizedBox(height: 160),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                  _QuickActionsSection(isSalon: isSalon),

                  businessesAsync.when(
                    skipLoadingOnReload: true,
                    skipLoadingOnRefresh: true,
                    loading: () => Column(children: List.generate(3, (index) => const _BusinessCardShimmer())),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Offline: Showing last loaded shops', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ),
                    ),
                    data: (shops) {
                      if (shops.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No shops found')));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- TOP TRENDING (ONLY IN ALL TAB) ---
                          if (selectedCat == 'all') ...[
                            _buildSectionHeader(context, 'Trending Near You 🔥', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'all', categoryName: 'Trending Shops')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.take(5).toList(), isSalon: false, isGrocery: false),
                          ],

                          // --- ALL CATEGORY SMART SECTIONS ---
                          if (selectedCat == 'all') ...[
                             _buildSectionHeader(context, 'Recommended For You ✨', null, textColor, primaryColor),
                             _RecommendedItemsList(category: 'all', isSalon: isSalon),

                             // 1. RESTAURANT SECTION
                             if (shops.any((s) => s.category == 'restaurant' || s.category == 'food')) ...[
                               _buildSectionHeader(context, 'Popular Restaurants 🍛', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'restaurant';
                               }, textColor, primaryColor),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'restaurant' || s.category == 'food').toList(), isSalon: false),
                               
                               _buildSectionHeader(context, 'Best Dishes for You 🍔', null, textColor, primaryColor),
                               _RecommendedItemsList(category: 'restaurant', isSalon: false),
                               const SizedBox(height: 10),
                             ],

                             // 2. GROCERY SECTION
                             if (shops.any((s) => s.category == 'grocery')) ...[
                               _buildSectionHeader(context, 'Grocery Stores 🛒', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'grocery';
                               }, textColor, const Color(0xFF00B251)),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'grocery').toList(), isSalon: false, isGrocery: true),
                               
                               _buildSectionHeader(context, 'Fresh Groceries 🥦', () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceryHomeScreen()));
                               }, textColor, const Color(0xFF00B251)),
                               const _HorizontalGroceryItemList(),
                               const SizedBox(height: 10),
                             ],

                             // 3. SALON SECTION (Default Background for All Tab)
                             if (shops.any((s) => s.category == 'salon')) ...[
                               _buildSectionHeader(context, 'Premium Salons 💇', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'salon';
                               }, textColor, const Color(0xFFFFD700)),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'salon').toList(), isSalon: true),

                               const SizedBox(height: 10),
                               _buildSectionHeader(context, 'Luxury Salon Services ✨', null, textColor, const Color(0xFFFFD700)),
                               _RecommendedItemsList(category: 'salon', isSalon: true),
                               const SizedBox(height: 10),
                             ],

                             // 4. MEAT SECTION
                             if (shops.any((s) => s.category == 'meat')) ...[
                               _buildSectionHeader(context, 'Meat & Fish Shops 🍖', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'meat';
                               }, textColor, const Color(0xFFE11D48)),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'meat').toList(), isSalon: false, isMeat: true),

                               _buildSectionHeader(context, 'Fresh Cuts & More 🥩', null, textColor, const Color(0xFFE11D48)),
                               _RecommendedItemsList(category: 'meat', isSalon: false),
                               const SizedBox(height: 10),
                             ],

                             // 5. MEDICINE SECTION
                             if (shops.any((s) => s.category == 'medicine')) ...[
                               _buildSectionHeader(context, 'Pharmacies & Medicine 💊', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'medicine';
                               }, textColor, const Color(0xFFFF0844)),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'medicine').toList(), isSalon: false),

                               _buildSectionHeader(context, 'Common Medicines 🏥', null, textColor, const Color(0xFFFF0844)),
                               _RecommendedItemsList(category: 'medicine', isSalon: false),
                               const SizedBox(height: 10),
                             ],

                             // 6. TECH/ELECTRONICS SECTION
                             if (shops.any((s) => s.category == 'electronics' || s.category == 'tech')) ...[
                               _buildSectionHeader(context, 'Electronics & Tech 📱', () {
                                 ref.read(selectedCategoryProvider.notifier).state = 'electronics';
                               }, textColor, const Color(0xFF662D8C)),
                               _HorizontalShopList(shops: shops.where((s) => s.category == 'electronics' || s.category == 'tech').toList(), isSalon: false),

                               _buildSectionHeader(context, 'Latest Gadgets 🎧', null, textColor, const Color(0xFF662D8C)),
                               _RecommendedItemsList(category: 'electronics', isSalon: false),
                             ],
                          ],

                          // --- SPECIAL CONTENT FOR FOOD TAB ---
                          if (selectedCat == 'restaurant') ...[
                            _buildSectionHeader(context, 'Popular Restaurants 🍛', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'restaurant', categoryName: 'Popular Restaurants')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'restaurant' || s.category == 'food').toList(), isSalon: false),
                            
                            _buildSectionHeader(context, 'Best Dishes for You 🍔', null, textColor, primaryColor),
                            _RecommendedItemsList(category: 'restaurant', isSalon: false),
                          ],

                          // --- SPECIAL CONTENT FOR GROCERY TAB ---
                          if (isGrocery) ...[
                            _buildSectionHeader(context, 'Grocery Stores 🛒', () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceryHomeScreen()));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'grocery').toList(), isSalon: false, isGrocery: true),

                            _buildSectionHeader(context, 'Fresh Items 🥦', () {
                               Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceryHomeScreen()));
                            }, textColor, primaryColor),
                            const _HorizontalGroceryItemList(),
                          ],

                          // --- SPECIAL CONTENT FOR SALON TAB ---
                          if (isSalon) ...[
                            _buildSectionHeader(context, 'Premium Salons 💇', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'salon', categoryName: 'Premium Salons')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'salon').toList(), isSalon: true),

                            _buildSectionHeader(context, 'Salon Services 💇', null, textColor, primaryColor),
                            _RecommendedItemsList(category: 'salon', isSalon: isSalon),
                          ],

                          // --- SPECIAL CONTENT FOR MEAT TAB ---
                          if (isMeat) ...[
                            _buildSectionHeader(context, 'Meat & Fish Shops 🍖', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'meat', categoryName: 'Meat Shops')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'meat').toList(), isSalon: false, isMeat: true),

                            _buildSectionHeader(context, 'Fresh Cuts 🥩', null, textColor, primaryColor),
                            _RecommendedItemsList(category: 'meat', isSalon: false),
                          ],

                          // --- SPECIAL CONTENT FOR MEDICINE TAB ---
                          if (isMedicine) ...[
                            _buildSectionHeader(context, 'Pharmacies 💊', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'medicine', categoryName: 'Pharmacies')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'medicine').toList(), isSalon: false),

                            _buildSectionHeader(context, 'Medicines 🏥', null, textColor, primaryColor),
                            _RecommendedItemsList(category: 'medicine', isSalon: false),
                          ],

                          // --- SPECIAL CONTENT FOR TECH TAB ---
                          if (isTech) ...[
                            _buildSectionHeader(context, 'Tech Shops 📱', () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryShopsScreen(categoryId: 'electronics', categoryName: 'Tech Shops')));
                            }, textColor, primaryColor),
                            _HorizontalShopList(shops: shops.where((s) => s.category == 'electronics' || s.category == 'tech').toList(), isSalon: false),

                            _buildSectionHeader(context, 'Gadgets 🎧', null, textColor, primaryColor),
                            _RecommendedItemsList(category: 'electronics', isSalon: false),
                          ],

                          _buildSectionHeader(context, 'All Nearby Shops 🏠', () {}, textColor, primaryColor),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            itemCount: shops.length,
                            itemBuilder: (ctx, i) => BusinessCard(business: shops[i], isSalon: isSalon, isGrocery: isGrocery, isMeat: isMeat),
                          ),

                          const SizedBox(height: 50),
                          _buildFooter(textColor),
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
      ),
      floatingActionButton: const FloatingCartButton(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback? onSeeAll, Color textColor, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: textColor)),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text('See All', style: GoogleFonts.sora(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFooter(Color textColor) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text('ziko super app', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 10),
        Text('© 2024 ziko. All Rights Reserved.', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HorizontalShopList extends ConsumerWidget {
  final List<BusinessModel> shops;
  final bool isSalon;
  final bool isGrocery;
  final bool isMeat;
  const _HorizontalShopList({required this.shops, this.isSalon = false, this.isGrocery = false, this.isMeat = false});
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
              return _TrendingShopCard(business: b, deliveryTime: area.estimatedDeliveryMinutes.toString(), isSalon: isSalon, isGrocery: isGrocery, isMeat: isMeat);
            },
            loading: () => _TrendingShopCard(business: b, deliveryTime: '...', isSalon: isSalon, isGrocery: isGrocery, isMeat: isMeat),
            error: (_, _) => _TrendingShopCard(business: b, deliveryTime: '30', isSalon: isSalon, isGrocery: isGrocery, isMeat: isMeat),
          );
        },
      ),
    );
  }
}

class _RecommendedItemsList extends ConsumerWidget {
  final String category;
  final bool isSalon;
  const _RecommendedItemsList({required this.category, this.isSalon = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(recommendedItemsProvider);
    final shopsAsync = ref.watch(businessesByAreaProvider);

    return itemsAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        return shopsAsync.when(
          data: (shops) {
            final List<FoodItemModel> filtered;
            
            if (category == 'all') {
              filtered = items;
            } else if (category == 'salon') {
              final salonShopIds = shops
                  .where((s) => s.category.toLowerCase() == 'salon')
                  .map((s) => s.id)
                  .toSet();
              filtered = items.where((i) => salonShopIds.contains(i.restaurantId)).toList();
            } else if (category == 'meat') {
              final meatShopIds = shops
                  .where((s) => s.category.toLowerCase().contains('meat'))
                  .map((s) => s.id)
                  .toSet();
              filtered = items.where((i) => meatShopIds.contains(i.restaurantId)).toList();
            } else if (category == 'medicine') {
              final medShopIds = shops
                  .where((s) => s.category.toLowerCase().contains('medicine'))
                  .map((s) => s.id)
                  .toSet();
              filtered = items.where((i) => medShopIds.contains(i.restaurantId)).toList();
            } else if (category == 'electronics' || category == 'tech') {
              final techShopIds = shops
                  .where((s) => s.category.toLowerCase().contains('electronics') || s.category.toLowerCase().contains('tech'))
                  .map((s) => s.id)
                  .toSet();
              filtered = items.where((i) => techShopIds.contains(i.restaurantId)).toList();
            } else if (category == 'restaurant' || category == 'food') {
              final foodShopIds = shops
                  .where((s) => s.category.toLowerCase().contains('restau') || 
                                s.category.toLowerCase().contains('food'))
                  .map((s) => s.id)
                  .toSet();
              filtered = items.where((i) => foodShopIds.contains(i.restaurantId)).toList();
            } else {
              final targetCat = category.toLowerCase();
              filtered = items.where((i) => i.category.toLowerCase().contains(targetCat)).toList();
            }

            if (filtered.isEmpty) return const SizedBox();
            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 20),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _RecommendedItemCard(item: filtered[i], isSalon: isSalon),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _RecommendedItemCard extends ConsumerWidget {
  final FoodItemModel item;
  final bool isSalon;
  const _RecommendedItemCard({required this.item, this.isSalon = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = isSalon ? const Color(0xFFFFD700) : AppColors.primary;
    final cardBg = isSalon ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;

    return Container(
      width: 140, margin: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSalon ? 0.1 : 0.03), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ]
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: SizedBox(height: 85, width: double.infinity, child: item.imageUrl != null ? CachedNetworkImage(imageUrl: item.imageUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade50), errorWidget: (c, u, e) => _itemPlaceholder(primaryColor)) : _itemPlaceholder(primaryColor))),
          Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w700, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(item.description, style: GoogleFonts.urbanist(fontSize: 9, color: isSalon ? Colors.white70 : AppColors.muted), maxLines: 1),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₹${item.finalPrice.toInt()}', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w800, color: isSalon ? primaryColor : AppColors.charcoal)),
              InkWell(
                onTap: () {
                  final cartNotifier = ref.read(cartProvider.notifier);
                  final isSalonItem = item.category.toLowerCase().contains('salon');
                  cartNotifier.addItem(item, isSalon: isSalonItem);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.add_rounded, color: primaryColor, size: 18),
                ),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }
  Widget _itemPlaceholder(Color color) => Container(color: color.withValues(alpha: 0.05), child: Center(child: Icon(Icons.fastfood_rounded, color: color, size: 30)));
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
    final isSalon = selectedCat == 'salon';
    final isGrocery = selectedCat == 'grocery';
    final isMeat = selectedCat == 'meat';
    final isMedicine = selectedCat == 'medicine';
    final isTech = selectedCat == 'electronics';

    final categories = [
      {'id': 'all', 'name': 'All', 'icon': Icons.grid_view_rounded, 'color': [const Color(0xFF6448FE), const Color(0xFF5FC6FF)]},
      {'id': 'restaurant', 'name': 'Food', 'icon': Icons.restaurant_rounded, 'color': [const Color(0xFFFE6454), const Color(0xFFFEB58A)]},
      {'id': 'grocery', 'name': 'Grocery', 'icon': Icons.shopping_basket_rounded, 'color': [const Color(0xFF2AF598), const Color(0xFF009EFD)]},
      {'id': 'salon', 'name': 'Salon', 'icon': Icons.content_cut_rounded, 'color': [const Color(0xFFD4AF37), const Color(0xFF000000)]},
      {'id': 'meat', 'name': 'Meat', 'icon': Icons.set_meal_rounded, 'color': [const Color(0xFFF093FB), const Color(0xFFF5576C)]},
      {'id': 'medicine', 'name': 'Medicine', 'icon': Icons.medical_services_rounded, 'color': [const Color(0xFFFF0844), const Color(0xFFFFB199)]},
      {'id': 'electronics', 'name': 'Tech', 'icon': Icons.devices_rounded, 'color': [const Color(0xFF662D8C), const Color(0xFFED1E79)]},
      {'id': 'more', 'name': 'More', 'icon': Icons.more_horiz_rounded, 'color': [const Color(0xFF30E8D8), const Color(0xFF16A085)]},
    ];
    return SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: categories.length, itemBuilder: (ctx, i) {
      final cat = categories[i]; final colors = cat['color'] as List<Color>;
      final isSelected = selectedCat == cat['id'];
      final activeColor = isSalon ? const Color(0xFFFFD700) : (isGrocery ? const Color(0xFF00B251) : (isMeat ? const Color(0xFFE11D48) : (isMedicine ? const Color(0xFFFF0844) : (isTech ? const Color(0xFF662D8C) : AppColors.primary))));

      return Padding(padding: const EdgeInsets.only(right: 12), child: GestureDetector(
        onTap: () {
          ref.read(selectedCategoryProvider.notifier).state = cat['id'] as String;
        },
        child: Column(children: [
        AnimatedContainer(duration: const Duration(milliseconds: 300), height: 48, width: 48, padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? activeColor : Colors.transparent, width: 2.0)), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors), boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))]), child: Icon(cat['icon'] as IconData, color: Colors.white, size: 24))),
        const SizedBox(height: 6),
        Text(cat['name'] as String, style: GoogleFonts.urbanist(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? activeColor : (isSalon ? Colors.white70 : AppColors.charcoal))),
      ])));
    }));
  }
}

class _QuickActionsSection extends StatelessWidget {
  final bool isSalon;
  const _QuickActionsSection({super.key, this.isSalon = false});

  void _handleActionTap(BuildContext context, String id) {
    if (id == 'order_again') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
    } else if (id == 'best_offers') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'best_offers', categoryName: 'Best Offers & Discounts')));
    } else if (id == 'top_rated') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'top_rated', categoryName: 'Top Rated Stores (4.0+)')));
    } else if (id == 'new_stores') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'new_stores', categoryName: 'Newly Added Stores')));
    } else if (id == 'flash_sale') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryShopsScreen(categoryId: 'flash_sale', categoryName: 'Flash Sale & Deals')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'id': 'order_again', 'label': 'Order Again', 'icon': Icons.history_rounded, 'color': Colors.blue},
      {'id': 'best_offers', 'label': 'Best Offers', 'icon': Icons.local_offer_rounded, 'color': Colors.orange},
      {'id': 'top_rated', 'label': 'Top Rated', 'icon': Icons.star_rounded, 'color': AppColors.gold},
      {'id': 'new_stores', 'label': 'New Stores', 'icon': Icons.storefront_rounded, 'color': Colors.purple},
      {'id': 'flash_sale', 'label': 'Flash Sale', 'icon': Icons.bolt_rounded, 'color': Colors.red},
    ];
    return Container(height: 85, margin: const EdgeInsets.symmetric(vertical: 2), child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: actions.length, itemBuilder: (context, index) {
      final action = actions[index]; final color = action['color'] as Color;
      final labelColor = isSalon ? Colors.white : AppColors.charcoal;
      final id = action['id'] as String;

      return Container(width: 75, margin: const EdgeInsets.only(right: 10), child: InkWell(onTap: () => _handleActionTap(context, id), borderRadius: BorderRadius.circular(18), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: isSalon ? 0.15 : 0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.2), width: 1.0)), child: Icon(action['icon'] as IconData, color: color, size: 22)),
        const SizedBox(height: 6),
        Text(action['label'] as String, textAlign: TextAlign.center, style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.w800, color: labelColor)),
      ])));
    }));
  }
}

class BusinessCard extends StatelessWidget {
  final BusinessModel business;
  final bool isSalon;
  final bool isGrocery;
  final bool isMeat;
  const BusinessCard({super.key, required this.business, this.isSalon = false, this.isGrocery = false, this.isMeat = false});
  @override
  Widget build(BuildContext context) {
    final b = business;
    final cardBg = isSalon ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;
    final primaryColor = isSalon ? const Color(0xFFFFD700) : (isGrocery ? const Color(0xFF00B251) : (isMeat ? const Color(0xFFE11D48) : AppColors.primary));

    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 20, right: 20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 6))]),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (b.category.toLowerCase() == 'grocery') {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceryHomeScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessDetailsScreen(business: b)));
          }
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: SizedBox(height: 150, width: double.infinity, child: b.logoUrl != null ? CachedNetworkImage(imageUrl: b.logoUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: AppColors.primary.withValues(alpha: 0.05)), errorWidget: (c, u, e) => _fallbackImage(primaryColor)) : _fallbackImage(primaryColor))),
            Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)), child: Text(_getShopOffer(b), style: GoogleFonts.urbanist(color: (isSalon || isGrocery || isMeat) ? Colors.black : Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
            Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: b.isOnline ? AppColors.softGreen : Colors.grey.shade700, borderRadius: BorderRadius.circular(8)), child: Text(b.isOnline ? 'OPEN' : 'CLOSED', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)))),
          ]),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(b.name, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w800, color: textColor))), _buildRatingBadge(b.avgRating)]),
            const SizedBox(height: 4),
            Row(children: [Text(b.category.toUpperCase(), style: GoogleFonts.urbanist(color: primaryColor, fontSize: 10, fontWeight: FontWeight.w700)), Text(' • ', style: TextStyle(color: Colors.grey.shade300)), Expanded(child: Text(b.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: isSalon ? Colors.white70 : AppColors.muted, fontSize: 12)))]),
            const SizedBox(height: 10),
            Row(children: [const Icon(Icons.access_time_rounded, size: 13, color: AppColors.softGreen), const SizedBox(width: 4), Text(isSalon ? 'Luxury Service' : '25-30 mins', style: GoogleFonts.urbanist(color: isSalon ? Colors.white70 : AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)), const SizedBox(width: 8), if (!isSalon) Expanded(child: Row(children: [const Icon(Icons.delivery_dining_rounded, size: 13, color: Colors.blue), const SizedBox(width: 4), Flexible(child: Text('FREE DELIVERY', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.urbanist(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w800)))]))]),
          ])),
        ]),
      ),
    );
  }
  Widget _buildRatingBadge(double rating) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.softGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 14), const SizedBox(width: 2), Text(rating.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.softGreen))]));
  Widget _fallbackImage(Color color) => Container(color: color.withValues(alpha: 0.08), child: Center(child: Icon(Icons.storefront_rounded, color: color, size: 40)));
}

class _TrendingShopCard extends StatelessWidget {
  final BusinessModel business;
  final String deliveryTime;
  final bool isSalon;
  final bool isGrocery;
  final bool isMeat;
  const _TrendingShopCard({required this.business, required this.deliveryTime, this.isSalon = false, this.isGrocery = false, this.isMeat = false});
  @override
  Widget build(BuildContext context) {
    final primaryColor = isSalon ? const Color(0xFFFFD700) : (isGrocery ? const Color(0xFF00B251) : (isMeat ? const Color(0xFFE11D48) : AppColors.primary));
    final cardBg = isSalon ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;

    return Container(
      width: 210, margin: const EdgeInsets.only(right: 15, bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSalon ? 0.1 : 0.04), 
            blurRadius: 12, 
            offset: const Offset(0, 6)
          )
        ]
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (business.category.toLowerCase() == 'grocery') {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GroceryHomeScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BusinessDetailsScreen(business: business)));
          }
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: SizedBox(height: 110, width: double.infinity, child: business.logoUrl != null ? CachedNetworkImage(imageUrl: business.logoUrl!, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade100), errorWidget: (c, u, e) => _fallbackImage(primaryColor)) : _fallbackImage(primaryColor))),
            Positioned(bottom: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star_rounded, color: AppColors.gold, size: 12), const SizedBox(width: 2), Text(business.avgRating.toStringAsFixed(1), style: GoogleFonts.urbanist(fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white))]))),
          ]),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(business.name, style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Row(children: [Icon(isSalon ? Icons.auto_awesome_rounded : (isGrocery ? Icons.shopping_basket_rounded : (isMeat ? Icons.set_meal_rounded : Icons.access_time_rounded)), size: 12, color: (isSalon || isGrocery || isMeat) ? primaryColor : AppColors.softGreen), const SizedBox(width: 4), Text(isSalon ? 'Luxury • ' : (isGrocery ? 'Fresh • ' : (isMeat ? 'Fresh Meat • ' : '$deliveryTime mins • ')), style: GoogleFonts.urbanist(color: (isSalon || isGrocery || isMeat) ? Colors.white70 : AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)), Text(business.category.toUpperCase(), style: GoogleFonts.urbanist(color: primaryColor, fontSize: 9, fontWeight: FontWeight.w700))])])),
        ]),
      ),
    );
  }
  Widget _fallbackImage(Color color) => Container(color: color.withValues(alpha: 0.08), child: Center(child: Icon(Icons.storefront_rounded, color: color, size: 40)));
}

class _BusinessCardShimmer extends StatelessWidget {
  const _BusinessCardShimmer();
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
  final bool isSalon;
  final bool isGrocery;
  final bool isMeat;
  final bool isMedicine;
  final bool isTech;
  final Color primaryColor;
  const _SearchBar({required this.isSalon, this.isGrocery = false, this.isMeat = false, this.isMedicine = false, this.isTech = false, required this.primaryColor});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52, decoration: BoxDecoration(color: (isSalon || isGrocery || isMeat || isMedicine || isTech) ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(30), border: (isSalon || isGrocery || isMeat || isMedicine || isTech) ? Border.all(color: Colors.white10) : null, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))]),
      child: TextField(
        onChanged: (val) => ref.read(searchQueryProvider.notifier).state = val,
        textAlignVertical: TextAlignVertical.center, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w500, color: (isSalon || isGrocery || isMeat || isMedicine || isTech) ? Colors.white : AppColors.charcoal),
        decoration: InputDecoration(
          hintText: isSalon ? 'Search luxury salons...' : (isGrocery ? 'Search fresh groceries...' : (isMeat ? 'Search fresh meat & fish...' : (isMedicine ? 'Search medicines...' : (isTech ? 'Search gadgets & tech...' : 'Search restaurants, groceries...')))),
          hintStyle: GoogleFonts.urbanist(color: (isSalon || isGrocery || isMeat || isMedicine || isTech) ? Colors.white38 : AppColors.muted.withValues(alpha: 0.5), fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 8), child: Icon(Icons.search_rounded, color: primaryColor, size: 24)),
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

class _HorizontalGroceryItemList extends ConsumerWidget {
  const _HorizontalGroceryItemList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(allProductsProvider);
    return productsAsync.when(
      skipLoadingOnReload: true,
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        final displayProducts = products.take(8).toList();

        return SizedBox(
          height: 215,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: displayProducts.length,
            itemBuilder: (ctx, i) {
              final product = displayProducts[i];
              return Container(
                width: 145,
                margin: const EdgeInsets.only(right: 15),
                child: GroceryProductCard(
                  product: product,
                  onAdd: () {
                    final foodItem = product.toFoodItem();
                    ref.read(cartProvider.notifier).addItem(foodItem);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} added to cart'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF00B251),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
