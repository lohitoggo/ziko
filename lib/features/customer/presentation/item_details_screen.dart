import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/food_item_model.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../providers/booking_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'cart_screen.dart';
import 'all_reviews_screen.dart';
import '../providers/wishlist_provider.dart';
import '../providers/business_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import 'package:intl/intl.dart';

class ItemDetailsScreen extends ConsumerStatefulWidget {
  final FoodItemModel item;
  const ItemDetailsScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      ref.read(selectedSlotProvider.notifier).state = null;
      ref.read(selectedDateProvider.notifier).state = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartNotifier = ref.read(cartProvider.notifier);
    final quantity = cartNotifier.quantityOf(widget.item.id);
    
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);
    final businessAsync = ref.watch(businessProvider(widget.item.restaurantId));
    final business = businessAsync.value;

    // --- Dynamic Theme Based on Category ---
    final String cat = (business?.category ?? widget.item.category).toLowerCase();
    final bool isSalon = cat == 'salon';
    final bool isGrocery = cat == 'grocery';
    final bool isMeat = cat == 'meat';
    final bool isMedicine = cat == 'medicine';
    final bool isTech = cat == 'electronics' || cat == 'tech';

    final Color primaryColor = isSalon ? const Color(0xFFFFD700) : 
                              (isGrocery ? const Color(0xFF00B251) : 
                              (isMeat ? const Color(0xFFE11D48) : 
                              (isMedicine ? const Color(0xFFFF0844) : 
                              (isTech ? const Color(0xFF662D8C) : AppColors.primary))));

    final bgColor = isSalon ? const Color(0xFF121214) : const Color(0xFFFFF8F4);
    final cardColor = isSalon ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;
    final mutedTextColor = isSalon ? Colors.white70 : AppColors.muted;

    final displayImages = widget.item.imageUrls.isNotEmpty 
        ? widget.item.imageUrls 
        : (widget.item.imageUrl != null ? [widget.item.imageUrl!] : []);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Premium Image Gallery
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: isSalon ? Colors.black : Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 290,
                          viewportFraction: 1.0,
                          autoPlay: false,
                          enableInfiniteScroll: displayImages.length > 1,
                          onPageChanged: (index, reason) => setState(() => _currentImageIndex = index),
                        ),
                        items: displayImages.map((url) => Hero(
                          tag: 'item_image_${widget.item.id}',
                          child: CachedNetworkImage(
                            imageUrl: url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: isSalon ? Colors.black : Colors.grey.shade100),
                            errorWidget: (c, u, e) => _itemFallback(primaryColor),
                          ),
                        )).toList(),
                      ),
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
                    _circleAction(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context), isSalon),
                    Row(
                      children: [
                        Consumer(builder: (context, ref, _) {
                          final isInWishlist = ref.watch(isInWishlistProvider(widget.item.id)).value ?? false;
                          return _circleAction(
                            isInWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                            () async {
                              final user = ref.read(supabaseUserProvider);
                              if (user != null) {
                                await ref.read(wishlistRepositoryProvider).toggleWishlist(user.id, widget.item.id);
                                ref.invalidate(isInWishlistProvider(widget.item.id));
                              }
                            },
                            isSalon,
                            iconColor: isInWishlist ? Colors.red : (isSalon ? Colors.white : AppColors.charcoal),
                          );
                        }),
                        const SizedBox(width: 12),
                        _circleAction(Icons.share_outlined, () {}, isSalon),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Product Information
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: GoogleFonts.urbanist(
                                fontSize: 24, 
                                fontWeight: FontWeight.w900, 
                                color: textColor,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isSalon) Icon(Icons.auto_awesome_rounded, color: primaryColor, size: 24)
                              else _vegNonVegBadge(widget.item.isVeg),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                                  const SizedBox(width: 4),
                                  Text(widget.item.avgRating.toString(), 
                                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 13, color: textColor)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text('${(widget.item.stock + 50)}+ Sold',
                        style: GoogleFonts.urbanist(fontSize: 12, color: isSalon ? primaryColor : Colors.blue, fontWeight: FontWeight.w700)),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: isSalon ? Colors.white10 : Colors.grey.shade200),
                      const SizedBox(height: 10),

                      // 3. Price Section
                      Row(
                        children: [
                          Text('₹${widget.item.finalPrice.toInt()}', 
                            style: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w900, color: isSalon ? primaryColor : textColor)),
                          if (widget.item.hasDiscount) ...[
                            const SizedBox(width: 12),
                            Text('₹${widget.item.price.toInt()}', 
                              style: TextStyle(fontSize: 16, color: isSalon ? Colors.white24 : Colors.grey, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('SAVE ₹${(widget.item.price - widget.item.finalPrice).toInt()}', 
                                style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Text('Description', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.description,
                        maxLines: _isExpanded ? 10 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(color: mutedTextColor, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Text(_isExpanded ? 'Read Less' : 'Read More', 
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),

                      const SizedBox(height: 20),
                      
                      // Appointment Info
                      businessAsync.maybeWhen(
                        data: (b) => b?.category == 'salon' 
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: primaryColor, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('Note: You can select your booking date and time in the Cart after adding all desired services.', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: mutedTextColor))),
                                ],
                              ),
                            )
                          : _buildDeliveryInfo(userAsync, areasAsync),
                        orElse: () => _buildDeliveryInfo(userAsync, areasAsync),
                      ),
                      
                      const SizedBox(height: 20),
                      _reviewsSection(isSalon, textColor, primaryColor),
                      
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 4. Sticky Bottom Bar
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: isSalon ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isSalon ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        _qtyBtn(Icons.remove, () => cartNotifier.removeItem(widget.item.id), primaryColor),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$quantity', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                        ),
                        _qtyBtn(Icons.add, () => cartNotifier.addItem(widget.item, isSalon: isSalon), primaryColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (quantity == 0) cartNotifier.addItem(widget.item, isSalon: isSalon);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryColor,
                        foregroundColor: isSalon ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(quantity == 0 ? 'ADD TO CART' : 'VIEW CART', 
                            style: GoogleFonts.urbanist(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                          if (quantity > 0) ...[
                            const SizedBox(width: 10),
                            Text('• ₹${(widget.item.finalPrice * quantity).toInt()}', 
                              style: TextStyle(color: isSalon ? Colors.black54 : Colors.white70, fontSize: 14)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap, bool isSalon, {Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isSalon ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor ?? (isSalon ? Colors.white : AppColors.charcoal), size: 20),
      ),
    );
  }

  Widget _vegNonVegBadge(bool isVeg) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(border: Border.all(color: isVeg ? Colors.green : Colors.red, width: 2), borderRadius: BorderRadius.circular(4)),
      child: Icon(Icons.circle, size: 8, color: isVeg ? Colors.green : Colors.red),
    );
  }

  Widget _buildDeliveryInfo(AsyncValue userAsync, AsyncValue areasAsync) {
    return userAsync.when(
      data: (user) => areasAsync.when(
        data: (areasList) {
          final List<AreaModel> areas = List<AreaModel>.from(areasList);
          if (areas.isEmpty) return const SizedBox.shrink();
          
          final AreaModel area = areas.firstWhere(
            (a) => a.id == user?.areaId, 
            orElse: () => areas.first,
          );
          final areaText ='${area.name}•${area.estimatedDeliveryMinutes} mins';

          return Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withValues(alpha: 0.1))),
                child: Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, color: Colors.blue, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Standard Delivery', style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 14)),
                          Text(areaText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _reviewsSection(bool isSalon, Color textColor, Color primaryColor) {
    final reviewsAsync = ref.watch(itemReviewsProvider(widget.item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('রিভিউ এবং রেটিং', style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
            reviewsAsync.when(
              data: (reviews) {
                if (reviews.length <= 3) return Text('${reviews.length} টি রিভিউ', style: GoogleFonts.hindSiliguri(fontSize: 12, color: isSalon ? Colors.white60 : Colors.grey));
                return TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AllReviewsScreen(itemId: widget.item.id, itemName: widget.item.name)));
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('সব দেখুন', style: GoogleFonts.hindSiliguri(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold)),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: isSalon ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSalon ? Colors.white10 : Colors.grey.shade100)),
                child: Center(child: Text('এখনো কোনো রিভিউ নেই। প্রথম রিভিউটি আপনি দিন!', style: GoogleFonts.hindSiliguri(color: isSalon ? Colors.white60 : Colors.grey, fontSize: 13))),
              );
            }

            final double avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

            return Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Text(avg.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 32, fontWeight: FontWeight.w900, color: textColor)),
                        const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                        Text('গড় রেটিং', style: GoogleFonts.hindSiliguri(fontSize: 10, color: isSalon ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) {
                          final star = 5 - index;
                          final count = reviews.where((r) => r.rating.round() == star).length;
                          return _ratingBar(star, count / reviews.length, isSalon);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reviews.length > 3 ? 3 : reviews.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isSalon ? Colors.white.withValues(alpha: 0.05) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSalon ? Colors.white10 : Colors.grey.shade100)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: isSalon ? Colors.white10 : Colors.grey.shade100,
                                backgroundImage: review.profileImageUrl != null 
                                    ? CachedNetworkImageProvider(review.profileImageUrl!) 
                                    : null,
                                child: review.profileImageUrl == null 
                                    ? Icon(Icons.person, size: 18, color: Colors.grey.shade400) 
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review.userName, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)),
                                    Text(DateFormat('dd MMM yyyy').format(review.timestamp), style: TextStyle(fontSize: 10, color: isSalon ? Colors.white60 : Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) => Icon(
                              Icons.star_rounded, 
                              size: 14, 
                              color: i < review.rating.round() ? AppColors.gold : (isSalon ? Colors.white10 : Colors.grey.shade100)
                            )),
                          ),
                          const SizedBox(height: 6),
                          Text(review.comment, style: GoogleFonts.hindSiliguri(fontSize: 13, color: isSalon ? Colors.white70 : AppColors.muted, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading reviews: $err', style: TextStyle(color: textColor)),
        ),
      ],
    );
  }

  Widget _ratingBar(int star, double value, bool isSalon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSalon ? Colors.white60 : Colors.black)),
          const SizedBox(width: 8),
          Expanded(child: LinearProgressIndicator(value: value, backgroundColor: isSalon ? Colors.white10 : Colors.grey.shade100, color: AppColors.softGreen, minHeight: 4, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color primaryColor) {
    return IconButton(onPressed: onTap, icon: Icon(icon, size: 18, color: primaryColor), constraints: const BoxConstraints(minWidth: 40, minHeight: 40));
  }

  Widget _itemFallback(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withValues(alpha: 0.8), primaryColor],
        ),
      ),
      child: const Center(child: Icon(Icons.fastfood_rounded, color: Colors.white70, size: 80)),
    );
  }
}
