import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/business_provider.dart';
import '../data/business_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/payment/payment_service.dart';
import '../../../core/services/payment/bharatpe_service_impl.dart';
import 'order_success_screen.dart';
import 'saved_addresses_screen.dart';
import '../../auth/presentation/change_phone_screen.dart';
import '../../auth/data/phone_auth_service.dart';
import '../providers/address_provider.dart';
import '../data/address_model.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../promos/providers/promo_provider.dart';
import '../../promos/data/promo_model.dart';
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
  final _promoCtrl = TextEditingController();
  PromoCode? _appliedPromo;

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

  void _applyPromoCode(double subtotal) {
    final codeStr = _promoCtrl.text.trim().toUpperCase();
    if (codeStr.isEmpty) return;

    final promosAsync = ref.read(allPromoCodesProvider);
    final list = promosAsync.value ?? [];

    final found = list.firstWhere(
      (p) => p.code == codeStr && p.isActive,
      orElse: () => PromoCode(id: '', code: '', discountType: 'flat', discountValue: 0, isActive: false),
    );

    if (found.code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('অবৈধ বা নিষ্ক্রিয় কুপন কোড'), backgroundColor: Colors.red));
      return;
    }

    if (subtotal < found.minOrderAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('এই কুপনটি ব্যবহার করতে ন্যূনতম ₹${found.minOrderAmount.toInt()} টাকার অর্ডার প্রয়োজন'), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _appliedPromo = found;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('কুপন ${found.code} সফলভাবে প্রয়োগ করা হয়েছে! 🎉'), backgroundColor: Colors.green));
  }

  @override
  void dispose() {
    _houseCtrl.dispose(); _villageCtrl.dispose(); _landmarkCtrl.dispose(); _pinCtrl.dispose(); _noteCtrl.dispose(); _promoCtrl.dispose();
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
                    final promoDiscount = _appliedPromo != null ? _appliedPromo!.calculateDiscount(subtotal) : 0.0;
                    final rawTotal = subtotal + deliveryCharge + platformFee + gst - promoDiscount;
                    final total = rawTotal < 0 ? 0.0 : rawTotal;
                    final belowMinimum = subtotal < orderArea.minimumOrder;

                    final enableCod = (settings?['enable_cod'] ?? true) && !isSalon;
                    final enableWallet = settings?['enable_wallet'] ?? true;
                    final enableRazorpay = settings?['enable_razorpay'] ?? true;
                    final enableCashfree = settings?['enable_cashfree'] ?? true;
                    final enablePhonepe = settings?['enable_phonepe'] ?? true;

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
                                      ]))
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            if (addresses.isEmpty) {
                                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen()));
                                            } else {
                                              _showAddressPicker(primaryColor, textColor, cardColor);
                                            }
                                          },
                                          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                                          label: Text(
                                            addresses.isEmpty ? '+ ADD NEW DELIVERY ADDRESS' : 'SELECT DELIVERY ADDRESS',
                                            style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryColor,
                                            side: BorderSide(color: primaryColor),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          ),
                                        ),
                                      ),
                                  ]),
                                )),
                              const SizedBox(height: 20),
                              _SectionCard(title: 'Payment Method', icon: Icons.account_balance_wallet_outlined, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: Column(children: [
                                if (enableWallet) ...[
                                  _PaymentTile(label: 'Ziko Credits / Wallet', subtitle: 'Pay instantly using Ziko wallet', icon: Icons.account_balance_wallet_rounded, value: 'wallet', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'wallet'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                  const SizedBox(height: 12),
                                ],
                                if (enableCod) ...[
                                  _PaymentTile(label: 'Cash on Delivery', subtitle: 'Pay after receiving', icon: Icons.payments_outlined, value: 'cod', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'cod'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                  const SizedBox(height: 12),
                                ],
                                if (enableRazorpay) ...[
                                  _PaymentTile(label: 'Online with Razorpay', subtitle: isSalon ? 'Prepaid required' : 'UPI, card, wallet', icon: Icons.qr_code_scanner_rounded, value: 'razorpay', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'razorpay'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                  const SizedBox(height: 12),
                                ],
                                if (enableCashfree) ...[
                                  _PaymentTile(label: 'Online with Cashfree', subtitle: 'UPI, Card, Net Banking', icon: Icons.account_balance_wallet_rounded, value: 'cashfree', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'cashfree'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                  const SizedBox(height: 12),
                                ],
                                if (enablePhonepe) ...[
                                  _PaymentTile(label: 'Online with PhonePe', subtitle: 'Instant PhonePe UPI Payment', icon: Icons.phone_android_rounded, value: 'phonepe', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'phonepe'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                                  const SizedBox(height: 12),
                                ],
                                _PaymentTile(label: 'BharatPe UPI / QR', subtitle: 'Scan QR or Pay via any UPI App', icon: Icons.qr_code_2_rounded, value: 'bharatpe', groupValue: _paymentMethod, onTap: () => setState(() => _paymentMethod = 'bharatpe'), isSalon: isSalon, primaryColor: primaryColor, textColor: textColor, cardColor: cardColor),
                              ])),
                              const SizedBox(height: 20),

                              // PROMO CODES SECTION
                              _SectionCard(
                                title: 'Coupons & Offers',
                                icon: Icons.local_offer_outlined,
                                cardColor: cardColor,
                                textColor: textColor,
                                primaryColor: primaryColor,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _promoCtrl,
                                            style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                            decoration: InputDecoration(
                                              hintText: 'Enter Promo Code (e.g. WELCOME50)',
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _applyPromoCode(subtotal),
                                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          child: Text(_appliedPromo == null ? 'APPLY' : 'CHANGE', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    if (_appliedPromo != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Applied: ${_appliedPromo!.code}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                          TextButton(
                                            onPressed: () => setState(() { _appliedPromo = null; _promoCtrl.clear(); }),
                                            child: const Text('REMOVE', style: TextStyle(color: Colors.red, fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              _SectionCard(title: 'Bill Summary', icon: Icons.receipt_long_rounded, cardColor: cardColor, textColor: textColor, primaryColor: primaryColor, child: Column(children: [
                                _billRow('Item Total', subtotal, textColor, mutedTextColor),
                                _billRow('Delivery Charge', deliveryCharge, textColor, mutedTextColor, isFree: deliveryCharge == 0),
                                _billRow('Platform Fee', platformFee, textColor, mutedTextColor),
                                if (promoDiscount > 0) _billRow('Promo Discount', promoDiscount, Colors.green, Colors.green, isDiscount: true),
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
                                  
                                  if (_paymentMethod == 'wallet') {
                                    final walletBalance = ref.read(userWalletBalanceProvider(user.uid)).value ?? 0.0;
                                    if (walletBalance < total) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('পর্যাপ্ত ওয়ালেট ব্যালেন্স নেই। আপনার ব্যালেন্স: ₹${walletBalance.toInt()}'), backgroundColor: Colors.red),
                                      );
                                      return;
                                    }
                                    await ref.read(walletRepositoryProvider).addDebit(
                                      userId: user.uid,
                                      amount: total,
                                      title: 'Order Payment',
                                      description: 'Paid using Ziko Credits',
                                    );
                                    await _processOrderPlacement(ref, user, orderArea, itemsList, subtotal, total, platformFee, gst, 'paid', 'WALLET_${DateTime.now().millisecondsSinceEpoch}', isSalon);
                                  } else if (_paymentMethod == 'razorpay' || _paymentMethod == 'cashfree' || _paymentMethod == 'phonepe') {
                                    PaymentGateway gateway = PaymentGateway.razorpay;
                                    if (_paymentMethod == 'cashfree') gateway = PaymentGateway.cashfree;
                                    if (_paymentMethod == 'phonepe') gateway = PaymentGateway.phonepe;

                                    final paymentService = paymentServiceFor(gateway);
                                    await paymentService.openPayment(amount: total, orderId: 'ORD_${DateTime.now().millisecondsSinceEpoch}', customerName: user.name ?? 'Customer', customerPhone: user.phone, customerEmail: user.email ?? '',
                                      onSuccess: (paymentId) => _processOrderPlacement(ref, user, orderArea, itemsList, subtotal, total, platformFee, gst, 'paid', paymentId, isSalon),
                                      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: $error'))),
                                    );
                                  } else if (_paymentMethod == 'bharatpe') {
                                    final tempOrderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';
                                    final uniqueAmount = BharatPeServiceImpl.calculateUniquePayableAmount(total, tempOrderId);
                                    final orderCreatedAtMs = DateTime.now().millisecondsSinceEpoch;

                                    setState(() => _isPlacing = true);
                                    try {
                                      final orderId = await ref.read(orderRepositoryProvider).placeOrder(
                                        customerUid: user.uid,
                                        restaurantId: itemsList.first.food.restaurantId,
                                        areaId: _selectedAddress?.areaId ?? user.areaId!,
                                        items: itemsList,
                                        subtotal: subtotal,
                                        deliveryCharge: isSalon ? 0.0 : orderArea.deliveryCharge,
                                        platformFee: platformFee,
                                        gst: gst,
                                        totalAmount: total,
                                        payableAmount: uniqueAmount,
                                        paymentMethod: 'bharatpe',
                                        paymentStatus: 'pending',
                                        latitude: _selectedAddress?.latitude,
                                        longitude: _selectedAddress?.longitude,
                                        houseNumber: isSalon ? '' : (_selectedAddress?.houseNumber ?? ''),
                                        village: isSalon ? '' : (_selectedAddress?.village ?? ''),
                                        landmark: isSalon ? '' : (_selectedAddress?.landmark ?? ''),
                                        pinCode: isSalon ? '' : (_selectedAddress?.pinCode ?? ''),
                                        deliveryNote: _noteCtrl.text.trim(),
                                        appointmentTime: isSalon ? '${DateFormat('yyyy-MM-dd').format(ref.read(cartProvider.notifier).selectedDate)} | ${ref.read(cartProvider.notifier).selectedSlot}' : null,
                                      );

                                      setState(() => _isPlacing = false);

                                      if (mounted) {
                                        _showBharatPePaymentDialog(
                                          context: context,
                                          ref: ref,
                                          orderId: orderId,
                                          payableAmount: uniqueAmount,
                                          orderCreatedAtMs: orderCreatedAtMs,
                                          isSalon: isSalon,
                                          category: itemsList.first.food.category,
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isPlacing = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                    }
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

  void _showBharatPePaymentDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String orderId,
    required double payableAmount,
    required int orderCreatedAtMs,
    required bool isSalon,
    required String category,
  }) {
    double currentAmount = payableAmount;
    Timer? pollingTimer;
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final upiUri = BharatPeServiceImpl.getUpiIntentUri(
              payableAmount: currentAmount,
              orderId: orderId,
              isStatic: false,
            );

            pollingTimer ??= Timer.periodic(const Duration(seconds: 4), (timer) async {
              if (isVerifying) return;
              setDialogState(() => isVerifying = true);

              final verified = await ref.read(orderRepositoryProvider).verifyAndConfirmBharatPeOrder(
                orderId: orderId,
                expectedAmount: currentAmount,
                orderCreatedAtMs: orderCreatedAtMs,
              );

              if (verified) {
                timer.cancel();
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  ref.read(cartProvider.notifier).clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => OrderSuccessScreen(orderId: orderId, isSalon: isSalon, category: category)),
                  );
                }
              } else {
                if (mounted) setDialogState(() => isVerifying = false);
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.deepOrange),
                  const SizedBox(height: 8),
                  Text('Secure QR Payment', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Scan to Pay via any UPI App', style: GoogleFonts.urbanist(fontSize: 12, color: Colors.grey)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade200)),
                      child: Column(
                        children: [
                          Text(
                            'Order Total: ₹$payableAmount',
                            style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.deepOrange),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'নিচের QR কোডটি অন্য কোনো ফোন দিয়ে (GPay/PhonePe/Paytm) স্ক্যান করে পেমেন্ট সম্পন্ন করুন।\n\nপেমেন্ট সফল হওয়ার সাথে সাথেই এই পেজটি অটোমেটিক কনফার্ম হয়ে যাবে!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: QrImageView(
                        data: upiUri,
                        version: QrVersions.auto,
                        size: 240.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text(isVerifying ? 'Checking payment status...' : 'Waiting for payment scan...', style: GoogleFonts.urbanist(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    pollingTimer?.cancel();
                    Navigator.pop(dialogCtx);
                    // On cancel, actually delete the pending order from DB since it's a prepaid requirement
                    try {
                      await ref.read(orderRepositoryProvider).cancelOrder(orderId, reason: 'Payment cancelled by user');
                    } catch(e) {
                      debugPrint('Failed to cancel un-paid BharatPe order: $e');
                    }
                  },
                  child: const Text('Cancel Payment', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      pollingTimer?.cancel();
    });
  }

  void _showPhoneVerificationRequired(String phone, bool isSalon, Color primary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhoneVerificationSheet(
        phone: phone,
        isSalon: isSalon,
        primary: primary,
        onVerified: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ফোন নম্বর সফলভাবে ভেরিফাই করা হয়েছে! এবার প্লেস অর্ডার চাপুন। ✅'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  Widget _billRow(String label, double val, Color text, Color muted, {bool isFree = false, bool isDiscount = false}) {
    final textVal = isFree ? 'FREE' : (isDiscount ? '-₹${val.toInt()}' : '₹${val.toInt()}');
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w500, color: muted)), Text(textVal, style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.w700, color: (isFree || isDiscount) ? Colors.green : text))]));
  }
}

class _PhoneVerificationSheet extends ConsumerStatefulWidget {
  final String phone;
  final bool isSalon;
  final Color primary;
  final VoidCallback onVerified;

  const _PhoneVerificationSheet({
    required this.phone,
    required this.isSalon,
    required this.primary,
    required this.onVerified,
  });

  @override
  ConsumerState<_PhoneVerificationSheet> createState() => _PhoneVerificationSheetState();
}

class _PhoneVerificationSheetState extends ConsumerState<_PhoneVerificationSheet> {
  final _phoneAuth = PhoneAuthService();
  final _otpCtrl = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    setState(() => _isLoading = true);
    await _phoneAuth.sendOtp(
      phoneNumber: widget.phone,
      onCodeSent: (id) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP পাঠানো হয়েছে ✅'), backgroundColor: Colors.green),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  void _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সঠিক OTP কোড দিন')));
      return;
    }

    setState(() => _isLoading = true);
    final success = await _phoneAuth.verifyOtp(otp);
    if (mounted) setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(currentUserProvider);
      if (mounted) {
        Navigator.pop(context);
        widget.onVerified();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ভুল OTP কোড! আবার চেষ্টা করুন।'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSalon = widget.isSalon;
    final primary = widget.primary;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isSalon ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.phonelink_lock_rounded, size: 36, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            'ফোন নম্বর ভেরিফাই করুন 📱',
            textAlign: TextAlign.center,
            style: GoogleFonts.urbanist(fontSize: 18, fontWeight: FontWeight.w900, color: isSalon ? Colors.white : AppColors.charcoal),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'নম্বর: ${widget.phone}',
                style: GoogleFonts.urbanist(fontSize: 14, fontWeight: FontWeight.bold, color: primary),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePhoneScreen()));
                },
                child: const Text('পরিবর্তন করুন', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_codeSent) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('SEND OTP (ওটিপি পাঠান)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ),
            ),
          ] else ...[
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                labelText: '৬ ডিজিটের ওটিপি লিখুন',
                prefixIcon: const Icon(Icons.security_rounded),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('VERIFY OTP (ভেরিফাই করুন)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _sendOtp,
                child: const Text('Resend OTP (পুনরায় পাঠান)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
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
