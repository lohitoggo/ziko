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
    
    final String cat = businessAsync.value?.category.toLowerCase() ?? '';
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

    final headerGradient = isSalon 
        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF000000), Color(0xFF1A1A1B)])
        : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryColor, primaryColor.withValues(alpha: 0.8)]);

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20, left: 16, right: 16,
            ),
            decoration: BoxDecoration(
              gradient: headerGradient,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
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
                      isSalon ? 'Booking Review' : 'Your Cart',
                      style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${cartNotifier.totalItems} items selected',
                      style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: items.isEmpty
                ? _buildEmptyState(isSalon, primaryColor, textColor)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CartItemCard(
                              item: item,
                              isSalon: isSalon,
                              onAdd: () {
                                cartNotifier.addItem(item.food, isSalon: isSalon, onSalonLimit: () {
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

                        if (isSalon) 
                          businessAsync.when(
                            data: (business) => business != null 
                                ? _buildSalonBooking(business, primaryColor, cardColor) 
                                : const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Text('Loading shop details...', style: TextStyle(color: Colors.grey)),
                                  ),
                            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.white)),
                          ),

                        const SizedBox(height: 25),
                        
                        userAsync.when(
                          skipLoadingOnReload: true,
                          data: (user) => areasAsync.when(
                            skipLoadingOnReload: true,
                            data: (areasList) {
                              final List<AreaModel> areas = List<AreaModel>.from(areasList);
                              if (areas.isEmpty) return const SizedBox.shrink();

                              final AreaModel area = areas.firstWhere((a) => a.id == user?.areaId, orElse: () => areas.first);
                              final deliveryFee = isSalon ? 0.0 : area.deliveryCharge;
                              
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
                                    isSalon: isSalon,
                                    cardColor: cardColor,
                                    textColor: textColor,
                                    primaryColor: primaryColor,
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
      
      bottomNavigationBar: items.isEmpty
          ? null
          : userAsync.when(
              data: (user) => areasAsync.when(
                data: (areasList) {
                  final List<AreaModel> areas = List<AreaModel>.from(areasList);
                  if (areas.isEmpty) return const SizedBox.shrink();

                  final AreaModel area = areas.firstWhere((a) => a.id == user?.areaId, orElse: () => areas.first);
                  final deliveryFee = isSalon ? 0.0 : area.deliveryCharge;
                  
                  return settingsAsync.when(
                    data: (settings) {
                      final platformFee = (settings?['platform_fee'] ?? 2).toDouble();
                      final grandTotal = cartNotifier.totalAmount + deliveryFee + platformFee;
                      return _buildCheckoutBar(context, grandTotal, isSalon, cartNotifier.selectedSlot, primaryColor, textColor);
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

  Widget _buildSalonBooking(BusinessModel business, Color gold, Color card) {
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
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Booking Appointment', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              IconButton(onPressed: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: gold)), child: child!),
                );
                if (picked != null) cartNotifier.setAppointment(null, picked);
              }, icon: Icon(Icons.calendar_month_rounded, color: gold, size: 20)),
            ],
          ),
          const SizedBox(height: 10),
          
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
                      color: isSelected ? gold : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? gold : Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EEE').format(date).toUpperCase(), style: TextStyle(color: isSelected ? Colors.black : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(date.day.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          Text('Select Time Slot ($totalDuration min service)', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 12),

          bookedSlotsAsync.when(
            loading: () => LinearProgressIndicator(color: gold, backgroundColor: Colors.white10),
            error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            data: (bookedSlots) {
              final List<String> slotsToDisplay = business.availableSlots;

              return GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2),
                itemCount: slotsToDisplay.length,
                itemBuilder: (context, index) {
                  final slot = slotsToDisplay[index];
                  bool isSlotAvailable = true;
                  
                  int blocksNeeded = (totalDuration / 15).ceil();
                  for (int i = 0; i < blocksNeeded; i++) {
                    if (index + i >= slotsToDisplay.length) { isSlotAvailable = false; break; }
                    final check = slotsToDisplay[index + i].replaceAll(' ', '').toLowerCase().trim();
                    if (bookedSlots.any((b) => b.replaceAll(' ', '').toLowerCase().trim() == check)) { isSlotAvailable = false; break; }
                    
                    if (isToday) {
                      try {
                        final st = DateFormat.jm().parse(slotsToDisplay[index + i].trim().toUpperCase());
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
                        color: !isSlotAvailable ? Colors.white.withValues(alpha: 0.02) : (isOccupiedPreview ? gold : Colors.white.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(10), 
                        border: Border.all(color: !isSlotAvailable ? Colors.white.withValues(alpha: 0.05) : (isOccupiedPreview ? gold : Colors.white10)),
                      ),
                      child: FittedBox(
                        child: Text(slot, style: GoogleFonts.urbanist(color: !isSlotAvailable ? Colors.white24 : (isOccupiedPreview ? Colors.black : Colors.white), fontWeight: FontWeight.bold, fontSize: 9)),
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

  Widget _buildEmptyState(bool isSalon, Color primary, Color textColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.05), shape: BoxShape.circle),
            child: Icon(isSalon ? Icons.auto_awesome_rounded : Icons.shopping_bag_outlined, size: 80, color: primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text('Your cart is empty', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(isSalon ? 'Add luxury treatments to book!' : 'Add something delicious to start!', style: GoogleFonts.urbanist(fontSize: 14, color: isSalon ? Colors.white60 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBillDetails({
    required double itemTotal, required double deliveryFee, required double platformFee, required double grandTotal, 
    bool isSalon = false, required Color cardColor, required Color textColor, required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isSalon ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill Details', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 16),
          _billRow('Item Total', itemTotal, textColor, isSalon),
          if (!isSalon) _billRow('Delivery Fee', deliveryFee, textColor, isSalon, isFree: deliveryFee == 0),
          _billRow('Platform Fee', platformFee, textColor, isSalon),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, thickness: 0.5, color: isSalon ? Colors.white10 : Colors.grey.shade100)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('To Pay', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
              Text('₹${grandTotal.toInt()}', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, double amount, Color textColor, bool isSalon, {bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: isSalon ? Colors.white60 : Colors.grey)),
          Text(isFree ? 'FREE' : '₹${amount.toInt()}', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w700, color: isFree ? Colors.green : textColor)),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(BuildContext context, double totalAmount, bool isSalon, String? selectedSlot, Color primary, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isSalon ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isSalon ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('₹${totalAmount.toInt()}', style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
              Text('GRAND TOTAL', style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: primary, letterSpacing: 0.5)),
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
                backgroundColor: primary, foregroundColor: isSalon ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text((isSalon && selectedSlot == null) ? 'SELECT TIME' : 'CHECKOUT', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final dynamic item; final VoidCallback onAdd; final VoidCallback onRemove; final bool isSalon;
  const _CartItemCard({required this.item, required this.onAdd, required this.onRemove, this.isSalon = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = isSalon ? const Color(0xFFFFD700) : AppColors.primary;
    final textColor = isSalon ? Colors.white : AppColors.charcoal;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSalon ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.food.imageUrl != null && item.food.imageUrl!.isNotEmpty
                ? CachedNetworkImage(imageUrl: item.food.imageUrl!, width: 65, height: 65, fit: BoxFit.cover, placeholder: (c, u) => Container(color: Colors.grey.shade100))
                : Container(width: 65, height: 65, color: primaryColor.withValues(alpha: 0.05), child: Icon(isSalon ? Icons.auto_awesome : Icons.fastfood_rounded, color: primaryColor, size: 28)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food.name, style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w800, color: textColor), maxLines: 1),
                Text('₹${item.food.finalPrice.toInt()} per unit', style: GoogleFonts.urbanist(fontSize: 12, color: isSalon ? Colors.white60 : AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('₹${(item.food.finalPrice * item.quantity).toInt()}', style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w900, color: primaryColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              _qtyBtn(Icons.remove, onRemove, primaryColor),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${item.quantity}', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w900, color: primaryColor))),
              _qtyBtn(Icons.add, onAdd, primaryColor),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 16, color: color)));
  }
}
