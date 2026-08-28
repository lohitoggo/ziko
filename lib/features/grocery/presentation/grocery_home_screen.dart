import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../providers/grocery_providers.dart';
import 'widgets/product_card.dart';
import 'category_products_screen.dart';
import '../../customer/providers/cart_provider.dart';
import '../../customer/presentation/customer_main_shell.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/widgets/floating_cart_button.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/models/product_model.dart';

class GroceryHomeScreen extends ConsumerWidget {
  const GroceryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(groceryCategoriesProvider);
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);
    final allProductsAsync = ref.watch(allProductsProvider);

    const freshGreen = Color(0xFF00B251);

    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning 👋';
      if (hour < 17) return 'Good Afternoon 👋';
      return 'Good Evening 👋';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
          SliverAppBar(
            pinned: true,
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: freshGreen,
            expandedHeight: 155,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [freshGreen, Color(0xFF8CC63F)],
                  ),
                ),
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
                                Text(getGreeting(),
                                    style: GoogleFonts.sora(
                                        color: Colors.white70, fontSize: 13)),
                                userAsync.when(
                                  skipLoadingOnReload: true,
                                  data: (user) => Text(user?.name ?? 'Guest User',
                                      style: GoogleFonts.sora(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  loading: () => Container(
                                      width: 100, height: 20, color: Colors.white24),
                                  error: (_, _) => const Text('Welcome!'),
                                ),
                              ],
                            ),
                          ),
                          _headerIcon(Icons.notifications_none_rounded, () {}),
                          const SizedBox(width: 12),
                          _headerIcon(Icons.person_outline_rounded, () {
                            ref.read(customerTabControllerProvider.notifier).state = 3;
                            Navigator.pop(context);
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: userAsync.when(
                              skipLoadingOnReload: true,
                              data: (user) => areasAsync.when(
                                skipLoadingOnReload: true,
                                data: (areas) {
                                  final area = areas.firstWhere(
                                      (a) => a.id == user?.areaId,
                                      orElse: () => areas.first);
                                  return Text(
                                      '${area.name}•${area.estimatedDeliveryMinutes} mins',
                                      style: GoogleFonts.sora(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600));
                                },
                                loading: () => const Text('...',
                                    style: TextStyle(color: Colors.white)),
                                error: (_, _) => const Text('Select Area',
                                    style: TextStyle(color: Colors.white)),
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
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
                child: _buildSearchBar(ref, freshGreen),
              ),
            ),
          ),

          // 2. MAIN CONTENT (Banners, Categories, Horizontal Sections)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                _GroceryHorizontalCategories(),
                settingsAsync.when(
                  skipLoadingOnReload: true,
                  data: (settings) => _GroceryBannerCarousel(
                      bannerUrls: List<String>.from(settings?['banner_urls'] ?? [])),
                  loading: () => const SizedBox(height: 160),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                const _QuickActionsSection(),

                const SizedBox(height: 20),
                allProductsAsync.when(
                  data: (products) {
                    if (products.isEmpty) return const SizedBox();
                    return Column(
                      children: [
                        _buildHorizontalProductSection(context, ref, 'Trending Now 🔥', products.take(6).toList(), freshGreen),
                        const SizedBox(height: 10),
                        _buildHorizontalProductSection(context, ref, 'Best Sellers 🌟', products.reversed.take(6).toList(), freshGreen),
                        const SizedBox(height: 10),
                        _buildHorizontalProductSection(context, ref, 'Daily Essentials 🥛', products.where((p) => p.categoryId != null).take(6).toList(), freshGreen),
                      ],
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (e, _) => const SizedBox(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    'Explore More Products',
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),

          // 3. REMAINING PRODUCTS GRID (Properly placed as a Sliver)
          allProductsAsync.when(
            data: (products) {
              if (products.isEmpty) return const SliverToBoxAdapter(child: SizedBox());
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return GroceryProductCard(
                        product: product,
                        onAdd: () => _addToCart(context, ref, product, freshGreen),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox()),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: _buildGroceryBottomBar(context, ref),
      floatingActionButton: const FloatingCartButton(),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, GroceryProduct product, Color color) {
    final foodItem = product.toFoodItem();
    ref.read(cartProvider.notifier).addItem(foodItem);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 1),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHorizontalProductSection(
      BuildContext context, WidgetRef ref, String title, List<GroceryProduct> products, Color color) {
    if (products.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              TextButton(onPressed: () {}, child: Text('See All', style: GoogleFonts.sora(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
            ],
          ),
        ),
        SizedBox(
          height: 235, // Adjusted to match product card aspect ratio
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 15),
                child: GroceryProductCard(
                  product: products[i],
                  onAdd: () => _addToCart(context, ref, products[i], color),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildGroceryBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: const Color(0xFF00B251).withValues(alpha: 0.1), width: 1)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(
              left: 10, right: 10, top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF00B251).withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, ref, 0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(context, ref, 1, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
                _navItem(context, ref, 2, Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Saved'),
                _navItem(context, ref, 3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, WidgetRef ref, int index, IconData inactiveIcon, IconData activeIcon, String label) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ref.read(customerTabControllerProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
        child: Icon(inactiveIcon, color: const Color(0xFF00B251).withValues(alpha: 0.5), size: 22),
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: TextField(
        onChanged: (val) => ref.read(grocerySearchQueryProvider.notifier).state = val,
        decoration: InputDecoration(
          hintText: 'Search fresh groceries...',
          hintStyle: GoogleFonts.urbanist(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.search_rounded, color: primaryColor, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _GroceryHorizontalCategories extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(groceryCategoriesProvider);

    return SizedBox(
      height: 90,
      child: categoriesAsync.when(
        data: (categories) => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (ctx, i) {
            final cat = categories[i];
            final colors = _getGradientForIndex(i);
            
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => CategoryProductsScreen(
                      categoryId: cat.id, 
                      categoryName: cat.name
                    )
                  )
                ),
                child: Column(
                  children: [
                    Container(
                      height: 52, width: 52,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colors,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors[0].withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(imageUrl: cat.imageUrl!, fit: BoxFit.cover)
                              : Icon(
                                  _getIconForCategory(cat.name), 
                                  color: Colors.white, 
                                  size: 26
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getShortName(cat.name), 
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        fontSize: 10, 
                        fontWeight: FontWeight.w800, 
                        color: AppColors.charcoal,
                        letterSpacing: -0.2
                      )
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  String _getShortName(String name) {
    final n = name.toLowerCase();
    if (n.contains('rice')) return 'Rice';
    if (n.contains('atta')) return 'Atta';
    if (n.contains('dal') || n.contains('pulse')) return 'Dal';
    if (n.contains('oil')) return 'Oil';
    if (n.contains('ghee')) return 'Ghee';
    if (n.contains('salt')) return 'Salt';
    if (n.contains('spice') || n.contains('masala')) return 'Spices';
    if (n.contains('biscuit')) return 'Biscuits';
    if (n.contains('snack')) return 'Snacks';
    if (n.contains('tea') || n.contains('coffee')) return 'Beverage';
    if (n.contains('drink')) return 'Drinks';
    if (n.contains('dairy') || n.contains('milk')) return 'Dairy';
    if (n.contains('personal')) return 'Personal';
    if (n.contains('household')) return 'Clean';
    if (n.contains('vegetable')) return 'Veg';
    if (n.contains('fruit')) return 'Fruits';
    if (n.contains('egg')) return 'Eggs';
    
    // Fallback: If name is too long, take first word
    if (name.length > 10) return name.split(' ').first;
    return name;
  }

  List<Color> _getGradientForIndex(int index) {
    final List<List<Color>> palettes = [
      [const Color(0xFF00B251), const Color(0xFF8CC63F)], // Green
      [const Color(0xFFFE6454), const Color(0xFFFEB58A)], // Orange/Red
      [const Color(0xFF2AF598), const Color(0xFF009EFD)], // Teal/Blue
      [const Color(0xFF6448FE), const Color(0xFF5FC6FF)], // Purple/Blue
      [const Color(0xFFFCCB90), const Color(0xFFD57EEB)], // Yellow/Pink
      [const Color(0xFFFFD200), const Color(0xFFF45D27)], // Yellow/Orange
      [const Color(0xFFF093FB), const Color(0xFFF5576C)], // Pink
      [const Color(0xFF30E8D8), const Color(0xFF16A085)], // Mint
    ];
    return palettes[index % palettes.length];
  }

  IconData _getIconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('rice') || n.contains('atta')) return Icons.grass_rounded;
    if (n.contains('oil') || n.contains('ghee')) return Icons.opacity_rounded;
    if (n.contains('dal') || n.contains('pulse')) return Icons.grain_rounded;
    if (n.contains('biscuit') || n.contains('cookie')) return Icons.cookie_outlined;
    if (n.contains('snack') || n.contains('namkeen')) return Icons.fastfood_rounded;
    if (n.contains('tea') || n.contains('coffee')) return Icons.coffee_rounded;
    if (n.contains('drink') || n.contains('beverage')) return Icons.local_drink_rounded;
    if (n.contains('dairy') || n.contains('milk')) return Icons.egg_outlined;
    if (n.contains('spice') || n.contains('masala')) return Icons.flare_rounded;
    if (n.contains('chocolate')) return Icons.bakery_dining_rounded;
    if (n.contains('personal') || n.contains('care')) return Icons.face_retouching_natural_rounded;
    if (n.contains('household') || n.contains('clean')) return Icons.clean_hands_rounded;
    if (n.contains('vegetable')) return Icons.eco_rounded;
    if (n.contains('fruit')) return Icons.apple_rounded;
    if (n.contains('egg')) return Icons.egg_alt_rounded;
    return Icons.shopping_bag_outlined;
  }
}

class _GroceryBannerCarousel extends StatefulWidget {
  final List<String> bannerUrls;
  const _GroceryBannerCarousel({required this.bannerUrls});
  @override
  State<_GroceryBannerCarousel> createState() => _GroceryBannerCarouselState();
}

class _GroceryBannerCarouselState extends State<_GroceryBannerCarousel> {
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
          child: ClipRRect(borderRadius: BorderRadius.circular(24), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, placeholder: (c, u) => Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (c, u, e) => Container(color: const Color(0xFF00B251).withValues(alpha: 0.1), child: const Icon(Icons.broken_image_outlined, color: Color(0xFF00B251))))),
        )).toList(),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: widget.bannerUrls.asMap().entries.map((entry) => AnimatedContainer(duration: const Duration(milliseconds: 300), width: _currentIndex == entry.key ? 20 : 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _currentIndex == entry.key ? const Color(0xFF00B251) : Colors.grey.shade300))).toList()),
    ]);
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
      {'label': 'New Items', 'icon': Icons.storefront_rounded, 'color': Colors.purple},
      {'label': 'Flash Sale', 'icon': Icons.bolt_rounded, 'color': Colors.red},
    ];
    return Container(
      height: 85, 
      margin: const EdgeInsets.symmetric(vertical: 2), 
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        padding: const EdgeInsets.symmetric(horizontal: 20), 
        itemCount: actions.length, 
        itemBuilder: (context, index) {
          final action = actions[index]; 
          final color = action['color'] as Color;
          return Container(
            width: 75, 
            margin: const EdgeInsets.only(right: 10), 
            child: InkWell(
              onTap: () {}, 
              borderRadius: BorderRadius.circular(18), 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  Container(
                    padding: const EdgeInsets.all(8), 
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08), 
                      borderRadius: BorderRadius.circular(15), 
                      border: Border.all(color: color.withValues(alpha: 0.1), width: 1.0)
                    ), 
                    child: Icon(action['icon'] as IconData, color: color, size: 22)
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action['label'] as String, 
                    textAlign: TextAlign.center, 
                    style: GoogleFonts.urbanist(
                      fontSize: 9, 
                      fontWeight: FontWeight.w700, 
                      color: AppColors.charcoal
                    )
                  ),
                ]
              )
            )
          );
        }
      )
    );
  }
}
