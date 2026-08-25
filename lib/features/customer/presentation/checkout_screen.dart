import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../../rider/providers/rider_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../auth/providers/area_provider.dart';
import '../../auth/data/area_model.dart';
import '../../admin/providers/admin_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/payment/payment_service.dart';
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

  // Instant GPS State (Required for logic and error-free build)
  double? _instantLat;
  double? _instantLon;
  bool _isFetchingGPS = false;

  // Manual Address Controllers
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
    _houseCtrl.dispose();
    _villageCtrl.dispose();
    _landmarkCtrl.dispose();
    _pinCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInstantGPS() async {
    setState(() => _isFetchingGPS = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        setState(() {
          _instantLat = pos.latitude;
          _instantLon = pos.longitude;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('আপনার বর্তমান লোকেশন সরাসরি লক করা হয়েছে।'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GPS এরর: $e')));
      }
    } finally {
      if (mounted) setState(() => _isFetchingGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final userAsync = ref.watch(currentUserProvider);
    final areasAsync = ref.watch(activeAreasProvider);
    final settingsAsync = ref.watch(systemSettingsProvider);

    // NEW: Robust Address Sync Logic
    final userAddressesAsync = ref.watch(userAddressesProvider);
    final defaultAddr = ref.watch(defaultAddressProvider);

    // FETCH REAL-TIME AREA DATA FOR PRICING
    final allAreas = areasAsync.value ?? [];

    // Synchronize local state with provider once data is available
    if (_selectedAddress == null && defaultAddr != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedAddress == null) {
          _updateAddressFields(defaultAddr);
        }
      });
    }

    // Auto-switch to manual address if loading finished and NO addresses found
    userAddressesAsync.whenData((addresses) {
      if (addresses.isEmpty && _useSavedAddress) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _useSavedAddress) {
            setState(() => _useSavedAddress = false);
          }
        });
      }
    });

    final subtotal = cartNotifier.totalAmount;
    final itemsList = cart.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const SizedBox();

          return areasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (areasList) {
              if (allAreas.isEmpty) {
                return const Center(child: Text('No areas available'));
              }

              // DYNAMIC PRICING: Find the area linked to the CURRENTLY SELECTED address
              final String? selectedAddressAreaId = _selectedAddress?.areaId;
              final AreaModel orderArea = allAreas.firstWhere(
                (a) => a.id == selectedAddressAreaId,
                orElse: () =>
                    allAreas.first, // Fallback to first area if not matched
              );

              final restaurantId = itemsList.isNotEmpty
                  ? itemsList.first.food.restaurantId
                  : '';
              final businessAsync = ref.watch(businessProvider(restaurantId));

              return settingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (settings) {
                  return businessAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (business) {
                      final bool isSalon = business?.category == 'salon';
                      final selectedSlot = cartNotifier.selectedSlot;
                      final selectedDate = cartNotifier.selectedDate;

                      final platformFee = (settings?['platform_fee'] ?? 2.0)
                          .toDouble();
                      final gstRate =
                          (settings?['gst_percentage'] ?? 0.0).toDouble() / 100;
                      final gst = subtotal * gstRate;

                      final deliveryCharge = isSalon
                          ? 0.0
                          : orderArea.deliveryCharge;
                      final total =
                          subtotal + deliveryCharge + platformFee + gst;
                      final belowMinimum = subtotal < orderArea.minimumOrder;

                      if (isSalon && _paymentMethod == 'cod') {
                        Future.delayed(Duration.zero, () {
                          if (mounted) {
                            setState(() => _paymentMethod = 'razorpay');
                          }
                        });
                      }

                      return Column(
                        children: [
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
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(30),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSalon ? 'Confirm Booking' : 'Checkout',
                                      style: GoogleFonts.urbanist(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      isSalon
                                          ? 'Complete your appointment'
                                          : 'Complete your order',
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
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (isSalon)
                                  _SectionCard(
                                    title: 'Appointment Summary',
                                    icon: Icons.event_available_rounded,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_filled_rounded,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Scheduled Slot',
                                                style: GoogleFonts.urbanist(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${DateFormat('dd MMM').format(selectedDate)} at ${selectedSlot ?? "Not selected"}',
                                                style: GoogleFonts.urbanist(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (isSalon) const SizedBox(height: 20),

                                // SMART ADDRESS SECTION (HIDDEN FOR SALON)
                                if (!isSalon)
                                  _SectionCard(
                                    title: 'Delivery Address',
                                    icon: Icons.location_on_outlined,
                                    child: userAddressesAsync.when(
                                      loading: () => const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(10),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      error: (e, _) => Text(
                                        'Error: $e',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.red,
                                        ),
                                      ),
                                      data: (addresses) {
                                        // CASE 1: NO ADDRESSES SAVED
                                        if (addresses.isEmpty) {
                                          return SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const SavedAddressesScreen(),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.add_location_alt_rounded,
                                                size: 20,
                                              ),
                                              label: Text(
                                                'ADD DELIVERY ADDRESS',
                                                style: GoogleFonts.urbanist(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors
                                                    .primary
                                                    .withValues(alpha: 0.1),
                                                foregroundColor:
                                                    AppColors.primary,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  side: const BorderSide(
                                                    color: AppColors.primary,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }

                                        // CASE 2: ADDRESSES EXIST -> SHOW SELECTED ONE
                                        return Column(
                                          children: [
                                            if (_selectedAddress != null)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.05),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                  border: Border.all(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.home_work_rounded,
                                                      color: AppColors.primary,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            _selectedAddress!
                                                                .village,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                          ),
                                                          Text(
                                                            '${_selectedAddress!.houseNumber}, ${_selectedAddress!.landmark}',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          _showAddressPicker(),
                                                      child: const Text(
                                                        'CHANGE',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                            TextButton.icon(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SavedAddressesScreen(),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.settings_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'MANAGE ALL ADDRESSES',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                if (!isSalon) const SizedBox(height: 20),

                                // ADDITIONAL INFO (NOTE - HIDDEN FOR SALON)
                                if (!isSalon)
                                  _SectionCard(
                                    title: 'Additional Info',
                                    icon: Icons.edit_note_rounded,
                                    child: _premiumField(
                                      _noteCtrl,
                                      'Delivery Note (Optional)',
                                      Icons.edit_note_rounded,
                                      maxLines: 2,
                                    ),
                                  ),
                                if (!isSalon) const SizedBox(height: 20),

                                _SectionCard(
                                  title: 'Payment Method',
                                  icon: Icons.account_balance_wallet_outlined,
                                  child: Column(
                                    children: [
                                      if (!isSalon)
                                        _PaymentTile(
                                          label: 'Cash on Delivery',
                                          subtitle: 'Pay after receiving order',
                                          icon: Icons.payments_outlined,
                                          value: 'cod',
                                          groupValue: _paymentMethod,
                                          onTap: () => setState(
                                            () => _paymentMethod = 'cod',
                                          ),
                                        ),
                                      if (!isSalon) const SizedBox(height: 12),
                                      _PaymentTile(
                                        label: 'Pay Online with Razorpay',
                                        subtitle: isSalon
                                            ? 'Full prepaid booking required'
                                            : 'UPI, card and wallet',
                                        icon: Icons.qr_code_scanner_rounded,
                                        value: 'razorpay',
                                        groupValue: _paymentMethod,
                                        onTap: () => setState(
                                          () => _paymentMethod = 'razorpay',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _PaymentTile(
                                        label: 'Pay Online with Cashfree',
                                        subtitle:
                                            'Test mode — UPI, card and net banking',
                                        icon: Icons
                                            .account_balance_wallet_rounded,
                                        value: 'cashfree',
                                        groupValue: _paymentMethod,
                                        onTap: () => setState(
                                          () => _paymentMethod = 'cashfree',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _SectionCard(
                                  title: 'Bill Summary',
                                  icon: Icons.receipt_long_rounded,
                                  child: Column(
                                    children: [
                                      _billRow('Item Total', subtotal),
                                      _billRow(
                                        'Delivery Charge',
                                        deliveryCharge,
                                        isFree: deliveryCharge == 0,
                                      ),
                                      _billRow('Platform Fee', platformFee),
                                      if (gst > 0) _billRow('GST', gst),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Divider(
                                          height: 1,
                                          thickness: 0.5,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Total Amount',
                                            style: GoogleFonts.urbanist(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.charcoal,
                                            ),
                                          ),
                                          Text(
                                            '₹${total.toInt()}',
                                            style: GoogleFonts.urbanist(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₹${total.toInt()}',
                                      style: GoogleFonts.urbanist(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.charcoal,
                                      ),
                                    ),
                                    Text(
                                      isSalon ? 'BOOKING TOTAL' : 'GRAND TOTAL',
                                      style: GoogleFonts.urbanist(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (belowMinimum)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            'Minimum order: ₹${orderArea.minimumOrder.toInt()}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ElevatedButton(
                                        onPressed:
                                            (belowMinimum ||
                                                _isPlacing ||
                                                _selectedAddress == null ||
                                                _selectedAddress?.latitude ==
                                                    null)
                                            ? null
                                            : () async {
                                                // 1. VALIDATE ADDRESS/GPS
                                                if (_selectedAddress == null) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Please select a delivery address first',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                // 2. CHECK MINIMUM ORDER
                                                if (belowMinimum) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Minimum order amount not met (₹${orderArea.minimumOrder.toInt()})',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                // 3. VALIDATE GPS PIN
                                                if (_selectedAddress
                                                        ?.latitude ==
                                                    null) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'আপনার ঠিকানায় ম্যাপ পিন নেই। দয়া করে এড্রেসটি এডিট করে ম্যাপে পিন দিন।',
                                                      ),
                                                      backgroundColor:
                                                          Colors.orange,
                                                    ),
                                                  );
                                                  return;
                                                }

                                                // REDEFINE isSalon for validation
                                                final bool isSalonOrder =
                                                    itemsList.any(
                                                      (item) => item
                                                          .food
                                                          .category
                                                          .toLowerCase()
                                                          .contains('salon'),
                                                    );

                                                // ONLY REQUIRE SLOT FOR SALON
                                                if (isSalonOrder &&
                                                    selectedSlot == null) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Please select a time slot first',
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                if (isSalonOrder) {
                                                  setState(
                                                    () => _isPlacing = true,
                                                  );
                                                  try {
                                                    final checkTime =
                                                        '${DateFormat('yyyy-MM-dd').format(selectedDate)} | $selectedSlot';
                                                    final existing =
                                                        await Supabase
                                                            .instance
                                                            .client
                                                            .from('orders')
                                                            .select('id')
                                                            .eq(
                                                              'business_id',
                                                              restaurantId,
                                                            )
                                                            .eq(
                                                              'appointment_time',
                                                              checkTime,
                                                            )
                                                            .not(
                                                              'status',
                                                              'in',
                                                              [
                                                                'cancelled',
                                                                'rejected',
                                                              ],
                                                            )
                                                            .maybeSingle();
                                                    if (existing != null) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'SORRY! This slot was just booked by someone else. Please pick another time.',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                      return;
                                                    }
                                                  } catch (e) {
                                                    debugPrint(
                                                      'Slot check error: $e',
                                                    );
                                                  } finally {
                                                    if (mounted) {
                                                      setState(
                                                        () =>
                                                            _isPlacing = false,
                                                      );
                                                    }
                                                  }
                                                }

                                                if (_paymentMethod ==
                                                        'razorpay' ||
                                                    _paymentMethod ==
                                                        'cashfree') {
                                                  final paymentService =
                                                      paymentServiceFor(
                                                        _paymentMethod ==
                                                                'cashfree'
                                                            ? PaymentGateway
                                                                  .cashfree
                                                            : PaymentGateway
                                                                  .razorpay,
                                                      );
                                                  await paymentService.openPayment(
                                                    amount: total,
                                                    orderId:
                                                        'ORD_${DateTime.now().millisecondsSinceEpoch}',
                                                    customerName:
                                                        user.name ?? 'Customer',
                                                    customerPhone: user.phone,
                                                    customerEmail:
                                                        user.email ?? '',
                                                    onSuccess: (paymentId) async {
                                                      await _processOrderPlacement(
                                                        ref,
                                                        user,
                                                        orderArea,
                                                        itemsList,
                                                        subtotal,
                                                        total,
                                                        platformFee,
                                                        gst,
                                                        'paid',
                                                        paymentId,
                                                      );
                                                    },
                                                    onFailure: (error) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Payment Failed: $error',
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                } else {
                                                  await _processOrderPlacement(
                                                    ref,
                                                    user,
                                                    orderArea,
                                                    itemsList,
                                                    subtotal,
                                                    total,
                                                    platformFee,
                                                    gst,
                                                    'pending',
                                                    null,
                                                  );
                                                }
                                              },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isPlacing
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    isSalon
                                                        ? 'CONFIRM BOOKING'
                                                        : 'PLACE ORDER',
                                                    style: GoogleFonts.urbanist(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  const Icon(
                                                    Icons
                                                        .check_circle_outline_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final addresses = ref.watch(userAddressesProvider).value ?? [];
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Address',
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: addresses.length,
                  itemBuilder: (ctx, i) {
                    final a = addresses[i];
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        a.village,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${a.houseNumber}, ${a.landmark}'),
                      onTap: () {
                        setState(() {
                          _selectedAddress = a;
                          _instantLat = a.latitude;
                          _instantLon = a.longitude;
                          _houseCtrl.text = a.houseNumber;
                          _villageCtrl.text = a.village;
                          _landmarkCtrl.text = a.landmark;
                          _pinCtrl.text = a.pinCode;
                          _useSavedAddress = true;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _useSavedAddress = false;
                    _selectedAddress = null;
                    _houseCtrl.clear();
                    _villageCtrl.clear();
                    _landmarkCtrl.clear();
                    _pinCtrl.clear();
                    _instantLat = null;
                    _instantLon = null;
                  });
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add a new address'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processOrderPlacement(
    WidgetRef ref,
    var user,
    AreaModel area,
    var items,
    double subtotal,
    double total,
    double platformFee,
    double gst,
    String paymentStatus,
    String? paymentId,
  ) async {
    setState(() => _isPlacing = true);
    final cartNotifier = ref.read(cartProvider.notifier);
    final restaurantId = items.first.food.restaurantId;

    // FETCH BUSINESS INFO FOR FINAL CHECK
    final business = await ref
        .read(businessRepositoryProvider)
        .getBusinessesOnce(user.areaId!)
        .then((list) => list.firstWhere((b) => b.id == restaurantId));
    final isSalon = business.category == 'salon';

    final selectedSlot = cartNotifier.selectedSlot;
    final selectedDate = cartNotifier.selectedDate;

    String? appointmentString;
    if (isSalon && selectedSlot != null) {
      final datePart = DateFormat('yyyy-MM-dd').format(selectedDate);

      try {
        int totalDuration = 0;
        for (var item in items) {
          totalDuration += (item.food.duration as num).toInt();
        }

        // UNIFIED SOURCE: Use owner's saved global slots
        final List<String> businessSlots = business.availableSlots;
        final startIndex = businessSlots.indexOf(selectedSlot);

        if (startIndex != -1) {
          // Block precisely based on total duration (15-min increments)
          int blocksNeeded = (totalDuration / 15).ceil();
          final List<String> occupied = [];
          for (int i = 0; i < blocksNeeded; i++) {
            if (startIndex + i < businessSlots.length) {
              occupied.add(businessSlots[startIndex + i]);
            }
          }
          // SAVE ALL SEGMENTS TO DATABASE
          appointmentString = '$datePart | ${occupied.join(', ')}';
        } else {
          appointmentString = '$datePart | $selectedSlot';
        }
      } catch (e) {
        appointmentString = '$datePart | $selectedSlot';
      }
    } else if (selectedSlot != null) {
      final datePart = DateFormat('yyyy-MM-dd').format(selectedDate);
      appointmentString = '$datePart | $selectedSlot';
    }

    try {
      final orderId = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            customerUid: user.uid,
            restaurantId: restaurantId,
            areaId: _selectedAddress?.areaId ?? user.areaId!,
            items: items,
            subtotal: subtotal,
            deliveryCharge: isSalon ? 0.0 : area.deliveryCharge,
            platformFee: platformFee,
            gst: gst,
            totalAmount: total,
            paymentMethod: _paymentMethod,
            paymentStatus: paymentStatus,
            paymentId: paymentId,
            latitude: _selectedAddress?.latitude,
            longitude: _selectedAddress?.longitude,
            houseNumber: isSalon ? '' : (_selectedAddress?.houseNumber ?? ''),
            village: isSalon ? '' : (_selectedAddress?.village ?? ''),
            landmark: isSalon ? '' : (_selectedAddress?.landmark ?? ''),
            pinCode: isSalon ? '' : (_selectedAddress?.pinCode ?? ''),
            deliveryNote: _noteCtrl.text.trim(),
            appointmentTime: appointmentString,
          );

      if (mounted) {
        cartNotifier.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderSuccessScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      print('❌ ORDER PLACEMENT CRITICAL ERROR: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('অর্ডার সম্পন্ন করা যায়নি'),
            content: SingleChildScrollView(child: Text('টেকনিক্যাল এরর: $e')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ঠিক আছে'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  Widget _billRow(String label, double value, {bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          Text(
            isFree ? 'FREE' : '₹${value.toInt()}',
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isFree ? Colors.green : AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.urbanist(
          fontSize: 13,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          size: 22,
          color: AppColors.primary.withValues(alpha: 0.7),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.urbanist(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade100,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.primary : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.urbanist(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : Colors.grey.shade300,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
