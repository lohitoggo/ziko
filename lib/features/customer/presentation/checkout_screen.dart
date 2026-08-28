import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../data/business_model.dart';
import '../../rider/providers/rider_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/payment/payment_service.dart';
import '../../auth/data/phone_auth_service.dart';
import 'order_success_screen.dart';
import 'saved_addresses_screen.dart';
import '../providers/address_provider.dart';
import '../data/address_model.dart';
import 'package:intl/intl.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'cod';
  bool _isPlacing = false;
  bool _useSavedAddress = true;
  AddressModel? _selectedAddress;

  final _houseCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  void _updateAddressFields(AddressModel addr) {
    setState(() {
      _selectedAddress = addr;
      _houseCtrl.text = addr.houseNumber;
      _villageCtrl.text = addr.village;
      _landmarkCtrl.text = addr.landmark;
      _pinCtrl.text = addr.pinCode;
      _useSavedAddress = true;
    });
  }

  @override
  void dispose() {
    _houseCtrl.dispose(); _villageCtrl.dispose(); _landmarkCtrl.dispose(); _pinCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);
    final userAddressesAsync = ref.watch(userAddressesProvider);
    final defaultAddr = ref.watch(defaultAddressProvider);

    final allAreas = areasAsync.value ?? [];

    if (_selectedAddress == null && defaultAddr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _selectedAddress == null) _updateAddressFields(defaultAddr); });
    }

    userAddressesAsync.whenData((addresses) {
      if (addresses.isEmpty && _useSavedAddress) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && _useSavedAddress) setState(() => _useSavedAddress = false); });
      }
    });

    final subtotal = cartNotifier.totalAmount;
    final itemsList = cart.values.toList();

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const SizedBox();

        return areasAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (areasList) {
            if (allAreas.isEmpty) return const Scaffold(body: Center(child: Text('No areas available')));

            final String? selectedAddressAreaId = _selectedAddress?.areaId;
            final AreaModel orderArea = allAreas.firstWhere((a) => a.id == selectedAddressAreaId, orElse: () => allAreas.first);

            final restaurantId = itemsList.isNotEmpty ? itemsList.first.food.restaurantId : '';
            final bool isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(restaurantId);
            final businessAsync = isValidUuid ? ref.watch(businessProvider(restaurantId)) : const AsyncValue<BusinessModel?>.data(null);

            return settingsAsync.when(
              loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (settings) {
                return businessAsync.when(
                  loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (business) {
                    final String cat = business?.category.toLowerCase() ?? '';
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

                    final platformFee = (settings?['platform_fee'] ?? 2.0).toDouble();
                    final gstRate = (settings?['gst_percentage'] ?? 0.0).toDouble() / 100;
                    final gst = subtotal * gstRate;
                    final deliveryCharge = isSalon ? 0.0 : orderArea.deliveryCharge;
                    final total = subtotal + deliveryCharge + platformFee + gst;
                    final belowMinimum = subtotal < orderArea.minimumOrder;

                    if (isSalon && _paymentMethod == 'cod') {
                      Future.delayed(Duration.zero, () { if (mounted) setState(() => _paymentMethod = 'razorpay'); });
                    }

                    return Scaffold(
                      backgroundColor: bgColor,
                      body: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 16, right: 16),
                            decoration: BoxDecoration(gradient: headerGradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30))),
                            child: Row(children: [
                              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                              const SizedBox(width: 8),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(isSalon ? 'Complete Booking' : 'Checkout', style: GoogleFonts.urbanist(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                                Text(isSalon ? 'Premium appointment service' : 'Complete your order', style: GoogleFonts.urbanist(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                              ]),
                            ]),
                          ),
                          Expanded(
                            child: ListView(padding: const EdgeInsets.all(20), children: [
                              if (isSalon)
                                _SectionCard(title: 'Appointment Info', icon: Icons.event_available_rounded, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: Container(
                                  padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
                                  child: Row(children: [
                                    Icon(Icons.access_time_filled_rounded, color: primaryColor),
                                    const SizedBox(width: 12),
                                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Scheduled Slot', style: GoogleFonts.urbanist(fontSize: 11, color: mutedTextColor, fontWeight: FontWeight.bold)),
                                      Text('${DateFormat('dd MMM').format(cartNotifier.selectedDate)} at ${cartNotifier.selectedSlot ?? "Not selected"}', style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
                                    ]),
                                  ]),
                                )),
                              if (isSalon) const SizedBox(height: 20),
                              if (!isSalon)
                                _SectionCard(title: 'Delivery Address', icon: Icons.location_on_outlined, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: userAddressesAsync.when(
                                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 12, color: Colors.red)),
                                  data: (addresses) => Column(children: [
                                    if (_selectedAddress != null)
                                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryColor.withValues(alpha: 0.1))), child: Row(children: [
                                        Icon(Icons.home_work_rounded, color: primaryColor, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_selectedAddress!.village, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)), Text('${_selectedAddress!.houseNumber}, ${_selectedAddress!.landmark}', style: TextStyle(fontSize: 12, color: mutedTextColor))])),
                                        TextButton(onPressed: () => _showAddressPicker(primaryColor, textColor, cardColor), child: Text('CHANGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primaryColor))),
                                      ])),
                                  ]),
                                )),
                              const SizedBox(height: 20),
                              _SectionCard(title: 'Payment Method', icon: Icons.account_balance_wallet_outlined, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: Column(children: [
                                if (!isSalon) _PaymentTile(label: 'Cash on Delivery', subtitle: 'Pay after receiving', icon: Icons.payments_outlined, value: 'cod', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'cod'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                const SizedBox(height: 12),
                                _PaymentTile(label: 'Online with Razorpay', subtitle: isSalon ? 'Prepaid required' : 'UPI, card, wallet', icon: Icons.qr_code_scanner_rounded, value: 'razorpay', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'razorpay'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                const SizedBox(height: 12),
                                _PaymentTile(label: 'Online with Cashfree', subtitle: 'UPI, Card, Net Banking', icon: Icons.account_balance_wallet_rounded, value: 'cashfree', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'cashfree'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                              ])),
                              const SizedBox(height: 20),
                              _SectionCard(title: 'Bill Summary', icon: Icons.receipt_long_rounded, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: Column(children: [
                                _billRow('Item Total', subtotal, textColor, mutedTextColor),
                                _billRow('Delivery Charge', deliveryCharge, textColor, mutedTextColor, isFree: deliveryCharge == 0),
                                _billRow('Platform Fee', platformFee, textColor, mutedTextColor),
                                Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: isSalon ? Colors.white10 : Colors.grey.shade200)),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Amount', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)), Text('₹${total.toInt()}', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor))]),
                              ])),
                              const SizedBox(height: 40),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            decoration: BoxDecoration(color: cardColor, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isSalon ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                            child: Row(children: [
                              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('₹${total.toInt()}', style: GoogleFonts.urbanist(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
                                Text(isSalon ? 'BOOKING TOTAL' : 'GRAND TOTAL', style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5)),
                              ]),
                              const SizedBox(width: 20),
                              Expanded(child: ElevatedButton(
                                onPressed: (belowMinimum || _isPlacing || (!isSalon && _selectedAddress == null)) ? null : () async {
                                  if (!user.isPhoneVerified) { _showPhoneVerificationRequired(user.phone, isSalon, primaryColor); return; }
                                  if (!isSalon && _selectedAddress == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a delivery address first'))); return; }
                                  
                                  if (_paymentMethod == 'razorpay' || _paymentMethod == 'cashfree') {
                                    final paymentService = paymentServiceFor(_paymentMethod == 'cashfree' ? PaymentGateway.cashfree : PaymentGateway.razorpay);
                                    await paymentService.openPayment(amount: total, orderId: 'ORD_${DateTime.now().millisecondsSinceEpoch}', customerName: user.name ?? 'Customer', customerPhone: user.phone, customerEmail: user.email ?? '',
                                      onSuccess: (paymentId) => _processOrderPlacement(ref, user, orderArea, itemsList, subtotal, total, platformFee, gst, 'paid', paymentId, isSalon),
                                      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $error'))),
                                    );
                                  } else {
                                    await _processOrderPlacement(ref, user, orderArea, itemsList, subtotal, total, platformFee, gst, 'pending', null, isSalon);
                                  }
                                },
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: primaryColor, foregroundColor: isSalon ? Colors.black : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                child: _isPlacing ? const CircularProgressIndicator(color: Colors.white) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(isSalon ? 'CONFIRM BOOKING' : 'PLACE ORDER', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(width: 10), const Icon(Icons.check_circle_outline_rounded, size: 20)]),
                              )),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddressPicker(Color primary, Color text, Color card) {
    showModalBottomSheet(context: context, backgroundColor: card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) {
      final addresses = ref.watch(userAddressesProvider).value ?? [];
      return Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Select Address', style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w800, color: text)),
        const SizedBox(height: 20),
        Flexible(child: ListView.builder(shrinkWrap: true, itemCount: addresses.length, itemBuilder: (ctx, i) => ListTile(leading: Icon(Icons.location_on_outlined, color: primary), title: Text(addresses[i].village, style: TextStyle(fontWeight: FontWeight.bold, color: text)), onTap: () { setState(() { _selectedAddress = addresses[i]; }); Navigator.pop(context); }))),
      ]));
    });
  }

  Future<void> _processOrderPlacement(WidgetRef ref, var user, AreaModel area, var items, double subtotal, double total, double platformFee, double gst, String paymentStatus, String? paymentId, bool isSalon) async {
    setState(() => _isPlacing = true);
    try {
      final orderId = await ref.read(orderRepositoryProvider).placeOrder(customerUid: user.uid, restaurantId: items.first.food.restaurantId, areaId: _selectedAddress?.areaId ?? user.areaId!, items: items, subtotal: subtotal, deliveryCharge: isSalon ? 0.0 : area.deliveryCharge, platformFee: platformFee, gst: gst, totalAmount: total, paymentMethod: _paymentMethod, paymentStatus: paymentStatus, paymentId: paymentId, latitude: _selectedAddress?.latitude, longitude: _selectedAddress?.longitude, houseNumber: isSalon ? '' : (_selectedAddress?.houseNumber ?? ''), village: isSalon ? '' : (_selectedAddress?.village ?? ''), landmark: isSalon ? '' : (_selectedAddress?.landmark ?? ''), pinCode: isSalon ? '' : (_selectedAddress?.pinCode ?? ''), deliveryNote: _noteCtrl.text.trim(), appointmentTime: isSalon ? '${DateFormat('yyyy-MM-dd').format(ref.read(cartProvider.notifier).selectedDate)} | ${ref.read(cartProvider.notifier).selectedSlot}' : null);
      if (mounted) { ref.read(cartProvider.notifier).clear(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId, isSalon: isSalon, category: items.first.food.category))); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _isPlacing = false); }
  }

  void _showPhoneVerificationRequired(String phone, bool isSalon, Color primary) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isSalon ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.phonelink_lock_rounded, size: 50, color: primary), const SizedBox(height: 16), Text('Verify Phone', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900, color: isSalon ? Colors.white : Colors.black)), const SizedBox(height: 30)])));
  }

  Widget _billRow(String label, double val, Color text, Color muted, {bool isFree = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: muted)), Text(isFree ? 'FREE' : '₹${val.toInt()}', style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w700, color: isFree ? Colors.green : text))]));
  }

  Widget _premiumField(TextEditingController ctrl, String label, IconData icon, Color primary, Color text, Color card, {int maxLines = 1}) {
    return TextField(controller: ctrl, maxLines: maxLines, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600, color: text), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.grey, fontSize: 13), prefixIcon: Icon(icon, color: primary.withValues(alpha: 0.7)), filled: true, fillColor: text == Colors.white ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)));
  }
}

class _SectionCard extends StatelessWidget {
  final String title; final IconData icon; final Widget child; final Color cardColor; final Color textColor; final Color primaryColor;
  const _SectionCard({required this.title, required this.icon, required this.child, required this.cardColor, required this.textColor, required this.primaryColor});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, size: 18, color: primaryColor), const SizedBox(width: 8), Text(title, style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w800, color: textColor))]), const SizedBox(height: 16), child]));
  }
}

class _PaymentTile extends StatelessWidget {
  final String label; final String subtitle; final IconData icon; final String value; final String groupValue; final VoidCallback onTap; final bool isSalon; final Color primaryColor; final Color textColor; final Color cardColor;
  const _PaymentTile({required this.label, required this.subtitle, required this.icon, required this.value, required this.groupValue, required this.onTap, required this.isSalon, required this.primaryColor, required this.textColor, required this.cardColor});
  @override Widget build(BuildContext context) {
    final sel = value == groupValue;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sel ? primaryColor.withValues(alpha: 0.05) : (isSalon ? Colors.white.withValues(alpha: 0.02) : Colors.white), border: Border.all(color: sel ? primaryColor : (isSalon ? Colors.white10 : Colors.grey.shade100), width: 1.5), borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sel ? primaryColor.withValues(alpha: 0.1) : (isSalon ? Colors.white10 : Colors.grey.shade50), shape: BoxShape.circle), child: Icon(icon, color: sel ? primaryColor : Colors.grey, size: 20)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)), Text(subtitle, style: GoogleFonts.urbanist(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500))])), Icon(sel ? Icons.check_circle_rounded : Icons.radio_button_off_rounded, color: sel ? primaryColor : Colors.grey.shade300, size: 22)])));
  }
}
