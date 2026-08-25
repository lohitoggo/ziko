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

    final displayImages = widget.item.imageUrls.isNotEmpty 
        ? widget.item.imageUrls 
        : (widget.item.imageUrl != null ? [widget.item.imageUrl!] : []);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Premium Image Gallery
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
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
                            placeholder: (c, u) => Container(color: Colors.grey.shade100),
                            errorWidget: (c, u, e) => _itemFallback(),
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
                    _circleAction(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
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
                            iconColor: isInWishlist ? Colors.red : AppColors.charcoal,
                          );
                        }),
                        const SizedBox(width: 12),
                        _circleAction(Icons.share_outlined, () {}),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Product Information
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
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
                                color: AppColors.charcoal,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _vegNonVegBadge(widget.item.isVeg),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                                  const SizedBox(width: 4),
                                  Text(widget.item.avgRating.toString(), 
                                    style: GoogleFonts.urbanist(fontWeight: FontWeight.w800, fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text('${(widget.item.stock + 50)}+ Sold',
                        style: GoogleFonts.urbanist(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w700)),

                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),

                      // 3. Price Section
                      Row(
                        children: [
                          Text('₹${widget.item.finalPrice.toInt()}', 
                            style: GoogleFonts.urbanist(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
                          if (widget.item.hasDiscount) ...[
                            const SizedBox(width: 12),
                            Text('₹${widget.item.price.toInt()}', 
                              style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough)),
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
                      
                      Text('Description', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.description,
                        maxLines: _isExpanded ? 10 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.urbanist(color: AppColors.muted, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                      ),
                      InkWell(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Text(_isExpanded ? 'Read Less' : 'Read More', 
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),

                      const SizedBox(height: 20),
                      
                      // Appointment Info (Simplified since selection is in Cart)
                      businessAsync.maybeWhen(
                        data: (b) => b?.category == 'salon' 
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text('Note: You can select your booking date and time in the Cart after adding all desired services.', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted))),
                                ],
                              ),
                            )
                          : _buildDeliveryInfo(userAsync, areasAsync),
                        orElse: () => _buildDeliveryInfo(userAsync, areasAsync),
                      ),
                      
                      const SizedBox(height: 20),
                      _reviewsSection(),
                      
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
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        _qtyBtn(Icons.remove, () => cartNotifier.removeItem(widget.item.id)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$quantity', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                        _qtyBtn(Icons.add, () => cartNotifier.addItem(widget.item)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (quantity == 0) cartNotifier.addItem(widget.item);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(quantity == 0 ? 'ADD TO CART' : 'VIEW CART', 
                            style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                          if (quantity > 0) ...[
                            const SizedBox(width: 10),
                            Text('• ₹${(widget.item.finalPrice * quantity).toInt()}', 
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
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

  Widget _circleAction(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor ?? AppColors.charcoal, size: 20),
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

  Widget _buildAppointmentSystem() {
    final businessAsync = ref.watch(businessProvider(widget.item.restaurantId));
    final selectedDate = ref.watch(selectedDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    // NEW: Global shop occupancy
    final bookedSlotsAsync = ref.watch(businessBookedSlotsProvider('${widget.item.restaurantId}|$dateStr'));
    
    return businessAsync.when(
      data: (business) {
        if (business?.category != 'salon') return const SizedBox.shrink();

        final selectedSlot = ref.watch(selectedSlotProvider);
        final bookedSlots = bookedSlotsAsync.value ?? [];
        final now = DateTime.now();
        final isToday = selectedDate.year == now.year && 
                        selectedDate.month == now.month && 
                        selectedDate.day == now.day;

        // MULTI-SLOT CALCULATION (Master Logic)
        final cart = ref.watch(cartProvider);
        int totalDuration = 0;
        for (var item in cart.values) {
          totalDuration += (item.food.duration as num).toInt();
        }
        // Add current item duration ONLY if it's not already in the cart
        if (!cart.containsKey(widget.item.id)) {
          totalDuration += (widget.item.duration as num).toInt();
        }

        // 1. HOLIDAY CHECK
        final String dayName = DateFormat('EEEE').format(selectedDate);
        final bool isOffDay = business!.offDay == dayName;

        if (isOffDay) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24)),
            child: Column(
              children: [
                const Icon(Icons.event_busy_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('দোকান আজ বন্ধ', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.red)),
                Text('আজ সাপ্তাহিক ছুটির দিন ($dayName)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }

        // 2. DYNAMIC SLOT GENERATION (Double Shift Support)
        final List<String> generatedSlots = [];
        try {
          // Helper to normalize and parse time string reliably
          DateTime parseTime(String t) => DateFormat.jm().parse(t.trim().toUpperCase());

          // Shift 1
          final start1 = parseTime(business.openingTime);
          final end1 = parseTime(business.closingTime);
          var curr1 = DateTime(2024, 1, 1, start1.hour, start1.minute);
          final targetEnd1 = DateTime(2024, 1, 1, end1.hour, end1.minute);
          while (curr1.isBefore(targetEnd1)) {
            generatedSlots.add(DateFormat.jm().format(curr1));
            curr1 = curr1.add(const Duration(minutes: 15));
          }

          // Shift 2 (Optional)
          if (business.hasDoubleShift) {
            final start2 = parseTime(business.openingTime2);
            final end2 = parseTime(business.closingTime2);
            var curr2 = DateTime(2024, 1, 1, start2.hour, start2.minute);
            final targetEnd2 = DateTime(2024, 1, 1, end2.hour, end2.minute);
            while (curr2.isBefore(targetEnd2)) {
              generatedSlots.add(DateFormat.jm().format(curr2));
              curr2 = curr2.add(const Duration(minutes: 15));
            }
          }
        } catch (e) {
          generatedSlots.addAll(widget.item.availableSlots);
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Pick a Date', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900)),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                onSurface: AppColors.charcoal,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        ref.read(selectedDateProvider.notifier).state = picked;
                        ref.read(selectedSlotProvider.notifier).state = null;
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                    label: Text('CALENDAR', style: GoogleFonts.urbanist(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Horizontal Date Picker (Quick select)
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 14,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().add(Duration(days: index));
                    final isSelected = date.day == selectedDate.day && date.month == selectedDate.month;
                    return InkWell(
                      onTap: () {
                        ref.read(selectedDateProvider.notifier).state = date;
                        ref.read(selectedSlotProvider.notifier).state = null;
                      },
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.white : AppColors.charcoal, fontSize: 18, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              Text('Select Time Slot', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Shop Hours: ${business.openingTime} - ${business.closingTime}', style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              
              if (generatedSlots.isEmpty)
                const Text('No slots available', style: TextStyle(color: Colors.grey, fontSize: 13))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: generatedSlots.length,
                  itemBuilder: (context, index) {
                    final slot = generatedSlots[index];
                    
                    bool isSlotAvailable = true;
                    String blockReason = "";
                    
                    try {
                      // PRECISION CHECK: Check if all needed 15-min blocks are free
                      int blocksNeeded = (totalDuration / 15).ceil();

                      for (int i = 0; i < blocksNeeded; i++) {
                        if (index + i >= generatedSlots.length) {
                          isSlotAvailable = false;
                          blockReason = "End";
                          break;
                        }
                        
                        final checkSlot = generatedSlots[index + i];
                        final normCheck = checkSlot.replaceAll(' ', '').toLowerCase().trim();
                        
                        // Check if booked in GLOBAL atomic timeline
                        if (bookedSlots.any((b) => b.replaceAll(' ', '').toLowerCase().trim() == normCheck)) {
                          isSlotAvailable = false;
                          blockReason = "Full";
                          break;
                        }

                        // Check if passed (for Today)
                        if (isToday) {
                          final timeParts = DateFormat.jm().parse(checkSlot);
                          final slotTime = DateTime(now.year, now.month, now.day, timeParts.hour, timeParts.minute);
                          if (slotTime.isBefore(now.add(const Duration(minutes: 10)))) {
                            isSlotAvailable = false;
                            blockReason = "Past";
                            break;
                          }
                        }
                      }
                    } catch (e) {}

                    final isSelected = selectedSlot == slot;
                    
                    // Highlight preview range (Atomic Blocks)
                    bool isOccupiedByPreview = false;
                    if (selectedSlot != null) {
                      int blocksNeeded = (totalDuration / 15).ceil();
                      final pickedIndex = generatedSlots.indexOf(selectedSlot);
                      if (index >= pickedIndex && index < pickedIndex + blocksNeeded) {
                        isOccupiedByPreview = true;
                      }
                    }

                    return InkWell(
                      onTap: !isSlotAvailable ? null : () => ref.read(selectedSlotProvider.notifier).state = slot,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: !isSlotAvailable 
                              ? Colors.grey.shade100 
                              : (isOccupiedByPreview ? AppColors.primary : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isSlotAvailable 
                                ? Colors.grey.shade200 
                                : (isOccupiedByPreview ? AppColors.primary : Colors.grey.shade300)
                          ),
                          boxShadow: isOccupiedByPreview ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)] : null,
                        ),
                        child: Text(
                          blockReason.isNotEmpty && !isSlotAvailable ? slot : slot,
                          style: GoogleFonts.urbanist(
                            color: !isSlotAvailable ? Colors.grey.shade400 : (isOccupiedByPreview ? Colors.white : AppColors.charcoal),
                            fontWeight: FontWeight.bold, 
                            fontSize: 10,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              
              if (bookedSlots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text('Live Occupancy: ${bookedSlots.length} segments taken today', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDeliveryInfo(AsyncValue userAsync, AsyncValue areasAsync) {
    final businessAsync = ref.watch(businessProvider(widget.item.restaurantId));
    final isSalon = businessAsync.value?.category == 'salon';
    if (isSalon) return const SizedBox.shrink();

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

  Widget _reviewsSection() {
    final reviewsAsync = ref.watch(itemReviewsProvider(widget.item.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('রিভিউ এবং রেটিং', style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
            reviewsAsync.when(
              data: (reviews) {
                if (reviews.length <= 3) return Text('${reviews.length} টি রিভিউ', style: GoogleFonts.hindSiliguri(fontSize: 12, color: Colors.grey));
                return TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AllReviewsScreen(itemId: widget.item.id, itemName: widget.item.name)));
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text('সব দেখুন', style: GoogleFonts.hindSiliguri(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
                child: Center(child: Text('এখনো কোনো রিভিউ নেই। প্রথম রিভিউটি আপনি দিন!', style: GoogleFonts.hindSiliguri(color: Colors.grey, fontSize: 13))),
              );
            }

            final double avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

            return Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Text(avg.toStringAsFixed(1), style: GoogleFonts.urbanist(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.charcoal)),
                        const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                        Text('গড় রেটিং', style: GoogleFonts.hindSiliguri(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) {
                          final star = 5 - index;
                          final count = reviews.where((r) => r.rating.round() == star).length;
                          return _ratingBar(star, count / reviews.length);
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.grey.shade100,
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
                                    Text(review.userName, style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.charcoal)),
                                    Text(DateFormat('dd MMM yyyy').format(review.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                              color: i < review.rating.round() ? AppColors.gold : Colors.grey.shade100
                            )),
                          ),
                          const SizedBox(height: 6),
                          Text(review.comment, style: GoogleFonts.hindSiliguri(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500, height: 1.3)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Error loading reviews: $err'),
        ),
      ],
    );
  }

  Widget _ratingBar(int star, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$star', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: LinearProgressIndicator(value: value, backgroundColor: Colors.grey.shade100, color: AppColors.softGreen, minHeight: 4, borderRadius: BorderRadius.circular(10))),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return IconButton(onPressed: onTap, icon: Icon(icon, size: 18, color: AppColors.primary), constraints: const BoxConstraints(minWidth: 40, minHeight: 40));
  }

  Widget _itemFallback() {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF45D27), Color(0xFFFF8A00)])),
      child: const Center(child: Icon(Icons.fastfood_rounded, color: Colors.white70, size: 80)),
    );
  }
}
