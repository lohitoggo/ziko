import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../rider/providers/rider_provider.dart';
import '../providers/order_provider.dart';
import '../data/business_model.dart';
import 'checkout_screen.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.watch(cartProvider.notifier);
    final items = cart.values.toList();
    
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    final restaurantId = cartNotifier.restaurantId ?? '';
    final businessAsync = ref.watch(businessProvider(restaurantId));
    
    // RELIABLE DETECTION: Use the parent business category
    final bool isSalonBusiness = businessAsync.value?.category.toLowerCase() == 'salon';
    
    // Fallback: Check if any item in cart has 'salon' in its name or category
    final bool hasSalonContext = items.any((item) => 
        item.food.category.toLowerCase().contains('salon') || 
        item.food.name.toLowerCase().contains('salon'));

    final bool showBookingSystem = isSalonBusiness || hasSalonContext;

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
                      'Your Cart',
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${cartNotifier.totalItems} items selected',
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
            child: items.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Items List
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CartItemCard(
                              item: item,
                              onAdd: () {
                                cartNotifier.addItem(item.food, isSalon: showBookingSystem, onSalonLimit: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('স্যালন সার্ভিসের জন্য একবারই বুকিং সম্ভব'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                });
                              },
                              onRemove: () => cartNotifier.removeItem(item.food.id),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),

                        // 3. SALON BOOKING SYSTEM
                        if (showBookingSystem) 
                          businessAsync.when(
                            data: (business) => business != null 
                                ? _buildSalonBooking(business) 
                                : const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text('Loading shop details...'),
                                  ),
                            loading: () => const Center(child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            )),
                            error: (e, _) => Text('Error loading slots: $e'),
                          ),

                        const SizedBox(height: 25),
                        
                        // 4. Bill Details Card (Dynamic)
                        userAsync.when(
                          skipLoadingOnReload: true,
                          data: (user) => areasAsync.when(
                            skipLoadingOnReload: true,
                            data: (areasList) {
                              final List<AreaModel> areas = List<AreaModel>.from(areasList);
                              if (areas.isEmpty) return const SizedBox.shrink();

                              final AreaModel area = areas.firstWhere(
                                (a) => a.id == user?.areaId, 
                                orElse: () => areas.first,
                              );
                              final deliveryFee = showBookingSystem ? 0.0 : area.deliveryCharge;
                              
                              return settingsAsync.when(
                                skipLoadingOnReload: true,
                                data: (settings) {
                                  final platformFee = (settings?['platform_fee'] ?? 2).toDouble();
                                  final grandTotal = cartNotifier.totalAmount + deliveryFee + platformFee;
                                  
                                  return _buildBillDetails(
                                    itemTotal: cartNotifier.totalAmount,
                                    deliveryFee: deliveryFee,
                                    platformFee: platformFee,
                                    grandTotal: grandTotal,
                                    isSalon: showBookingSystem,
                                  );
                                },
                                loading: () => userAsync.hasValue ? const SizedBox.shrink() : const LinearProgressIndicator(),
                                error: (_, _) => const Text('Error loading settings'),
                              );
                            },
                            loading: () => userAsync.hasValue ? const SizedBox.shrink() : const LinearProgressIndicator(),
                            error: (_, _) => const Text('Error loading areas'),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const Text('Error loading profile'),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      
      // 5. Sticky Bottom Checkout Bar (Dynamic)
      bottomNavigationBar: items.isEmpty
          ? null
          : userAsync.when(
              data: (user) => areasAsync.when(
                data: (areasList) {
                  final List<AreaModel> areas = List<AreaModel>.from(areasList);
                  if (areas.isEmpty) return const SizedBox.shrink();

                  final AreaModel area = areas.firstWhere(
                    (a) => a.id == user?.areaId, 
                    orElse: () => areas.first,
                  );
                  final deliveryFee = showBookingSystem ? 0.0 : area.deliveryCharge;
                  
                  return settingsAsync.when(
                    data: (settings) {
                      final platformFee = (settings?['platform_fee'] ?? 2).toDouble();
                      final grandTotal = cartNotifier.totalAmount + deliveryFee + platformFee;
                      return _buildCheckoutBar(context, grandTotal, showBookingSystem, cartNotifier.selectedSlot);
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
    );
  }

  Widget _buildSalonBooking(BusinessModel business) {
    final cartNotifier = ref.watch(cartProvider.notifier);
    final selectedDate = cartNotifier.selectedDate;
    final selectedSlot = cartNotifier.selectedSlot;
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final bookedSlotsAsync = ref.watch(businessBookedSlotsProvider('${business.id}|$dateStr'));
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year && selectedDate.month == now.month && selectedDate.day == now.day;
    final totalDuration = cartNotifier.totalDuration;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Booking Appointment', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
              IconButton(onPressed: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                );
                if (picked != null) cartNotifier.setAppointment(null, picked);
              }, icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20)),
            ],
          ),
          const SizedBox(height: 10),
          
          // Horizontal Date Quick Select
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = date.day == selectedDate.day && date.month == selectedDate.month;
                return InkWell(
                  onTap: () => cartNotifier.setAppointment(null, date),
                  child: Container(
                    width: 55, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.white : AppColors.charcoal, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          Text('Select Time Slot ($totalDuration min service)', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // Generated Slots Grid
          bookedSlotsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading slots: $e'),
            data: (bookedSlots) {
              // PRIORITY: Use slots generated and saved by the Owner
              final List<String> slotsToDisplay = business.availableSlots;

              if (slotsToDisplay.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('এই দোকানের কোনো স্লট পাওয়া যায়নি।', 
                          style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2),
                itemCount: slotsToDisplay.length,
                itemBuilder: (context, index) {
                  final slot = slotsToDisplay[index];
                  bool isSlotAvailable = true;
                  
                  // Atomic Check Logic
                  int blocksNeeded = (totalDuration / 15).ceil();
                  for (int i = 0; i < blocksNeeded; i++) {
                    if (index + i >= slotsToDisplay.length) { isSlotAvailable = false; break; }
                    final check = slotsToDisplay[index + i].replaceAll(' ', '').toLowerCase().trim();
                    if (bookedSlots.any((b) => b.replaceAll(' ', '').toLowerCase().trim() == check)) { isSlotAvailable = false; break; }
                    
                    if (isToday) {
                      try {
                        final clean = slotsToDisplay[index + i].trim().toUpperCase();
                        DateTime st;
                        try {
                          st = DateFormat.jm().parse(clean);
                        } catch (e) {
                          final parts = clean.split(' ');
                          final timeParts = parts[0].split(':');
                          int h = int.parse(timeParts[0]);
                          int m = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
                          if (parts.length > 1 && parts[1] == 'PM' && h < 12) h += 12;
                          if (parts.length > 1 && parts[1] == 'AM' && h == 12) h = 0;
                          st = DateTime(now.year, now.month, now.day, h, m);
                        }
                        final slotDateTime = DateTime(now.year, now.month, now.day, st.hour, st.minute);
                        if (slotDateTime.isBefore(now.add(const Duration(minutes: 10)))) { isSlotAvailable = false; break; }
                      } catch (e) {}
                    }
                  }

                  bool isOccupiedPreview = false;
                  if (selectedSlot != null) {
                    final pIdx = slotsToDisplay.indexOf(selectedSlot);
                    if (index >= pIdx && index < pIdx + blocksNeeded) isOccupiedPreview = true;
                  }

                  return InkWell(
                    onTap: !isSlotAvailable ? null : () => cartNotifier.setAppointment(slot, selectedDate),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200), alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !isSlotAvailable ? Colors.grey.shade100 : (isOccupiedPreview ? AppColors.primary : Colors.white),
                        borderRadius: BorderRadius.circular(10), border: Border.all(color: !isSlotAvailable ? Colors.grey.shade200 : (isOccupiedPreview ? AppColors.primary : Colors.grey.shade300)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(slot, style: GoogleFonts.urbanist(color: !isSlotAvailable ? Colors.grey.shade400 : (isOccupiedPreview ? Colors.white : AppColors.charcoal), fontWeight: FontWeight.bold, fontSize: 9)),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 80, color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.charcoal),
          ),
          const SizedBox(height: 8),
          Text(
            'Add something delicious to start!',
            style: GoogleFonts.urbanist(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetails({
    required double itemTotal,
    required double deliveryFee,
    required double platformFee,
    required double grandTotal,
    bool isSalon = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal),
          ),
          const SizedBox(height: 16),
          _billRow('Item Total', itemTotal),
          if (!isSalon) _billRow('Delivery Fee', deliveryFee, isFree: deliveryFee == 0),
          _billRow('Platform Fee', platformFee, isFee: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 0.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
                style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.charcoal),
              ),
              Text(
                '₹${grandTotal.toInt()}',
                style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, double amount, {bool isFree = false, bool isFee = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted),
          ),
          Text(
            isFree ? 'FREE' : '₹${amount.toInt()}',
            style: GoogleFonts.urbanist(
              fontSize: 14, 
              fontWeight: FontWeight.w700, 
              color: isFree ? Colors.green : AppColors.charcoal
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context, double totalAmount, bool isSalon, String? selectedSlot) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₹${totalAmount.toInt()}',
                style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.charcoal),
              ),
              Text(
                'GRAND TOTAL',
                style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: (isSalon && selectedSlot == null) ? null : () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    (isSalon && selectedSlot == null) ? 'SELECT TIME' : 'CHECKOUT',
                    style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CartItemCard({required this.item, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Item Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.food.imageUrl != null && item.food.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.food.imageUrl!,
                    width: 65, height: 65,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: Colors.grey.shade100),
                  )
                : Container(
                    width: 65, height: 65,
                    color: AppColors.primary.withValues(alpha: 0.05),
                    child: const Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 28),
                  ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.food.name,
                  style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.charcoal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${item.food.finalPrice.toInt()} per unit',
                  style: GoogleFonts.urbanist(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${(item.food.finalPrice * item.quantity).toInt()}',
                  style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ],
            ),
          ),
          
          // Quantity Controller
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _qtyBtn(Icons.remove, onRemove),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ),
                _qtyBtn(Icons.add, onAdd),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
