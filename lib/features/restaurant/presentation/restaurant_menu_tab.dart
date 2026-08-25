import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/restaurant_owner_provider.dart';
import '../../customer/providers/order_provider.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../../core/services/upload_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:intl/intl.dart';

class RestaurantMenuTab extends ConsumerStatefulWidget {
  final String restaurantId;
  const RestaurantMenuTab({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantMenuTab> createState() => _RestaurantMenuTabState();
}

class _RestaurantMenuTabState extends ConsumerState<RestaurantMenuTab> {
  DateTime _selectedDate = DateTime.now();

  void _showAddEditSheet(
      BuildContext context, {
        Map<String, dynamic>? existingItem,
        bool isSalon = false,
      }) {
    final nameCtrl =
    TextEditingController(text: existingItem?['name'] ?? '');
    final descCtrl =
    TextEditingController(text: existingItem?['description'] ?? '');
    final priceCtrl = TextEditingController(
        text: existingItem != null ? '${existingItem['price']}' : '');
    final discountCtrl = TextEditingController(
        text: existingItem != null ? '${existingItem['discount_price'] ?? 0}' : '0');
    final stockCtrl = TextEditingController(
        text: existingItem != null ? '${existingItem['stock']}' : '');
    final durationCtrl = TextEditingController(
        text: existingItem != null ? '${existingItem['duration'] ?? 30}' : '30');
    
    // SLOTS STATE
    List<String> currentSlots = List<String>.from(existingItem?['available_slots'] ?? []);
    
    // FETCH OPERATING HOURS FROM RESTAURANT DATA
    final business = ref.read(myRestaurantProvider).value;
    final bool has2Shifts = business?['has_double_shift'] ?? false;
    
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay startTime2 = const TimeOfDay(hour: 17, minute: 0);
    TimeOfDay endTime2 = const TimeOfDay(hour: 21, minute: 0);
    
    try {
      if (business != null) {
        final start1 = DateFormat.jm().parse(business['opening_time'] ?? '09:00 AM');
        startTime = TimeOfDay(hour: start1.hour, minute: start1.minute);
        
        final end1 = DateFormat.jm().parse(business['closing_time'] ?? '01:00 PM');
        endTime = TimeOfDay(hour: end1.hour, minute: end1.minute);

        if (has2Shifts) {
          final start2 = DateFormat.jm().parse(business['opening_time_2'] ?? '05:00 PM');
          startTime2 = TimeOfDay(hour: start2.hour, minute: start2.minute);
          
          final end2 = DateFormat.jm().parse(business['closing_time_2'] ?? '09:00 PM');
          endTime2 = TimeOfDay(hour: end2.hour, minute: end2.minute);
        }
      }
    } catch (e) {
      debugPrint('Parsing operating hours error: $e');
    }

    int intervalMinutes = 30;
    bool isVeg = existingItem?['is_veg'] ?? true;
    
    List<String> imageUrls = List<String>.from(existingItem?['image_urls'] ?? []);
    List<File> localImages = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            
            void generateAutoSlots() {
              final List<String> generated = [];
              
              // Shift 1
              var current = DateTime(2024, 1, 1, startTime.hour, startTime.minute);
              final end = DateTime(2024, 1, 1, endTime.hour, endTime.minute);
              while (current.isBefore(end)) {
                generated.add(DateFormat.jm().format(current));
                current = current.add(Duration(minutes: intervalMinutes));
              }

              // Shift 2 (If enabled)
              if (has2Shifts) {
                var current2 = DateTime(2024, 1, 1, startTime2.hour, startTime2.minute);
                final end2 = DateTime(2024, 1, 1, endTime2.hour, endTime2.minute);
                while (current2.isBefore(end2)) {
                  generated.add(DateFormat.jm().format(current2));
                  current2 = current2.add(Duration(minutes: intervalMinutes));
                }
              }

              setModalState(() => currentSlots = generated);
            }

            Future<void> pickImages() async {
              final picker = ImagePicker();
              final pickedFiles = await picker.pickMultiImage();
              if (pickedFiles.isNotEmpty) {
                setModalState(() {
                  localImages.addAll(pickedFiles.map((e) => File(e.path)).toList());
                  if (localImages.length > 5) localImages = localImages.sublist(0, 5);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingItem == null ? 'নতুন আইটেম যোগ করুন' : 'আইটেম সম্পাদনা করুন',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Picker Section
                    const Text('ছবি যোগ করুন (সর্বোচ্চ ৫টি)', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          InkWell(
                            onTap: pickImages,
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                            ),
                          ),
                          ...localImages.map((file) => Stack(
                            children: [
                              Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 12,
                                child: InkWell(
                                  onTap: () => setModalState(() => localImages.remove(file)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )),
                          ...imageUrls.map((url) => Stack(
                            children: [
                              Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4, right: 12,
                                child: InkWell(
                                  onTap: () => setModalState(() => imageUrls.remove(url)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: isSalon ? 'সার্ভিসের নাম' : 'আইটেমের নাম'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'বিবরণ (Description)',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    
                    // --- PRICE & STOCK SECTION (Universal) ---
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'আসল মূল্য (₹) *',
                              prefixIcon: Icon(Icons.sell_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: discountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ডিসকাউন্ট মূল্য (₹)',
                              prefixIcon: Icon(Icons.discount_outlined),
                              hintText: 'না থাকলে ০ লিখুন',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isSalon ? 'কতজনকে সার্ভিস দিতে পারবেন? *' : 'স্টক পরিমাণ *',
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- CATEGORY SPECIFIC FIELDS ---
                    if (isSalon) ...[
                      TextField(
                        controller: durationCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'সার্ভিস ডিউরেশন (মিনিট) *',
                          hintText: 'যেমন: ১৫, ৩০, ৪৫ বা ৬০',
                          prefixIcon: Icon(Icons.timer_outlined),
                          suffixText: 'মিনিট',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* স্যালন সার্ভিসের জন্য সময় (Duration) দেওয়া বাধ্যতামূলক। এটি আপনার বুকিং স্লট ক্যালকুলেশনে ব্যবহৃত হবে।',
                        style: TextStyle(fontSize: 10, color: Colors.blue, fontStyle: FontStyle.italic),
                      ),
                    ] else ...[
                      const Text('অ্যাভেইলেবল স্লট (ঐচ্ছিক)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (v) => currentSlots = v.split(',').map((e) => e.trim()).toList(),
                        decoration: const InputDecoration(
                          labelText: 'স্লট (কমা দিয়ে আলাদা করুন)',
                          hintText: '10 AM, 11 AM, 12 PM',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                      ),
                      if (currentSlots.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: currentSlots.map((s) => Chip(
                            label: Text(s, style: const TextStyle(fontSize: 10)),
                            onDeleted: () => setModalState(() => currentSlots.remove(s)),
                            deleteIconColor: Colors.red,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('টাইপ:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text(isSalon ? 'সার্ভিস' : 'ভেজ'),
                          selected: isVeg,
                          onSelected: (v) => setModalState(() => isVeg = true),
                        ),
                        const SizedBox(width: 8),
                        if (!isSalon)
                          ChoiceChip(
                            label: const Text('নন-ভেজ'),
                            selected: !isVeg,
                            onSelected: (v) => setModalState(() => isVeg = false),
                          ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final repo = ref.read(restaurantOwnerRepositoryProvider);
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                          final discount = double.tryParse(discountCtrl.text.trim()) ?? 0;
                          final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                          final duration = int.tryParse(durationCtrl.text.trim()) ?? 30;
                          final slots = currentSlots;

                          if (name.isEmpty || price <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('নাম এবং সঠিক মূল্য প্রদান করুন')));
                            return;
                          }

                          // 1. Upload local images if any
                          if (localImages.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ছবি আপলোড হচ্ছে...')));
                            final newUrls = await ref.read(uploadServiceProvider).uploadMultipleImages(localImages, 'items');
                            imageUrls.addAll(newUrls);
                          }

                          try {
                            if (existingItem == null) {
                              await repo.addItem(
                                businessId: widget.restaurantId,
                                name: name,
                                description: descCtrl.text.trim(),
                                isVeg: isVeg,
                                price: price,
                                discountPrice: discount,
                                stock: stock,
                                duration: duration,
                                imageUrls: imageUrls,
                                availableSlots: slots,
                              );
                            } else {
                              await repo.updateItem(existingItem['itemId'], {
                                'name': name,
                                'description': descCtrl.text.trim(),
                                'isVeg': isVeg,
                                'price': price,
                                'discountPrice': discount,
                                'stock': stock,
                                'duration': duration,
                                'imageUrls': imageUrls,
                                'availableSlots': slots,
                              });
                            }
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সফলভাবে সম্পন্ন হয়েছে')));
                            }
                          } catch (e) {
                            if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
                          }
                        },
                        child: Text(existingItem == null ? 'যোগ করুন' : 'আপডেট করুন'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(myItemsProvider(widget.restaurantId));
    final repo = ref.read(restaurantOwnerRepositoryProvider);
    final businessAsync = ref.watch(myRestaurantProvider);
    final isSalon = businessAsync.value?['category'] == 'salon';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context, isSalon: isSalon),
        icon: const Icon(Icons.add),
        label: Text(isSalon ? 'সার্ভিস যোগ করুন' : 'খাবার যোগ করুন'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('সমস্যা: $e')),
        data: (items) {
          final business = businessAsync.value;
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isSalon) _buildGlobalSlotManager(context, business),
                const SizedBox(height: 100),
                Center(child: Text(isSalon ? 'এখনো কোনো সার্ভিস যোগ করা হয়নি\n"সার্ভিস যোগ করুন" চাপুন' : 'এখনো কোনো খাবার যোগ করা হয়নি\n"খাবার যোগ করুন" চাপুন')),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              if (isSalon) _buildGlobalSlotManager(context, business),
              ...items.map((item) {
                final isAvailable = item['is_available'] ?? true;
                final images = List<String>.from(item['image_urls'] ?? []);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: images.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: images.first,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(color: Colors.grey.shade100),
                                errorWidget: (c, u, e) => _itemFallback(item['is_veg'] ?? true),
                              )
                            : _itemFallback(item['is_veg'] ?? true),
                      ),
                    ),
                    title: Text(item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '₹${item['price']} • ${isSalon ? "সার্ভিস" : "স্টক"}: ${item['stock']} • ${isAvailable ? "চালু আছে" : "বন্ধ"}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddEditSheet(context, existingItem: item, isSalon: isSalon);
                        } else if (value == 'toggle') {
                          repo.updateItem(
                              item['itemId'], {'isAvailable': !isAvailable});
                        } else if (value == 'delete') {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('মুছে ফেলবেন?'),
                              content: Text('${item['name']} মুছে ফেলা হবে'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('বাতিল')),
                                TextButton(
                                  onPressed: () {
                                    repo.deleteItem(item['itemId']);
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('মুছুন',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                            value: 'edit', child: Text('সম্পাদনা করুন')),
                        PopupMenuItem(
                            value: 'toggle',
                            child: Text(isAvailable ? (isSalon ? 'বন্ধ করুন' : 'স্টক আউট করুন') : 'চালু করুন')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('মুছে ফেলুন')),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlobalSlotManager(BuildContext context, var business) {
    final List<String> currentSlots = List<String>.from(business?['available_slots'] ?? []);
    int interval = 30;

    // FETCH REAL-TIME BOOKED SLOTS FOR SELECTED DATE
    final String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final bookedSlotsAsync = ref.watch(businessBookedSlotsProvider('${business?['restaurantId']}|$dateStr'));

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text('দোকানের স্লট ম্যানেজ করুন', style: GoogleFonts.urbanist(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                _statusLegend(),
              ],
            ),
            const SizedBox(height: 12),
            
            // --- CALENDAR UI (Mirrored from Customer App) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('শিডিউল দেখুন:', style: GoogleFonts.urbanist(fontSize: 13, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: _selectedDate, 
                      firstDate: DateTime.now().subtract(const Duration(days: 7)), 
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)), child: child!),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  }, 
                  icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20)
                ),
              ],
            ),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 14,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
                  return InkWell(
                    onTap: () => setState(() => _selectedDate = date),
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
            const Divider(height: 30),
            
            // --- SLOT CONFIGURATION ---
            StatefulBuilder(builder: (ctx, setLocalState) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('স্লট ব্যবধান:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      ...[15, 30, 60].map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$m মি.'),
                          selected: interval == m,
                          onSelected: (v) => setLocalState(() => interval = m),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final List<String> generated = [];
                        try {
                          DateTime customParse(String t) {
                            final clean = t.trim().toUpperCase();
                            try {
                              return DateFormat.jm().parse(clean);
                            } catch (e) {
                              final parts = clean.split(' ');
                              final timeParts = parts[0].split(':');
                              int hour = int.parse(timeParts[0]);
                              int minute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
                              final isPm = parts.length > 1 && parts[1] == 'PM';
                              if (isPm && hour < 12) hour += 12;
                              if (!isPm && hour == 12) hour = 0;
                              return DateTime(2024, 1, 1, hour, minute);
                            }
                          }

                          final start1 = customParse(business?['opening_time'] ?? '09:00 AM');
                          final end1 = customParse(business?['closing_time'] ?? '01:00 PM');
                          var c1 = DateTime(2024, 1, 1, start1.hour, start1.minute);
                          final te1 = DateTime(2024, 1, 1, end1.hour, end1.minute);
                          while (c1.isBefore(te1)) { 
                            generated.add(DateFormat.jm().format(c1)); 
                            c1 = c1.add(Duration(minutes: interval)); 
                          }

                          if (business?['opening_time_2'] != null && business?['closing_time_2'] != null) {
                            final start2 = customParse(business?['opening_time_2']);
                            final end2 = customParse(business?['closing_time_2']);
                            var c2 = DateTime(2024, 1, 1, start2.hour, start2.minute);
                            final te2 = DateTime(2024, 1, 1, end2.hour, end2.minute);
                            while (c2.isBefore(te2)) { 
                              generated.add(DateFormat.jm().format(c2)); 
                              c2 = c2.add(Duration(minutes: interval)); 
                            }
                          }

                          await ref.read(restaurantOwnerRepositoryProvider).updateBusinessProfile(business!['restaurantId'], {'available_slots': generated});
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('স্লট সফলভাবে তৈরি হয়েছে')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('সব দিনের স্লট অটো-জেনারেট করুন'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ],
              );
            }),
            
            // --- LIVE SLOT VIEW & MANUAL BLOCKING ---
            if (currentSlots.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('স্লট স্ট্যাটাস (${DateFormat('dd MMM').format(_selectedDate)}):', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              bookedSlotsAsync.when(
                data: (booked) {
                  return Wrap(
                    spacing: 8, runSpacing: 8,
                    children: currentSlots.map((s) {
                      final bool isBooked = booked.any((b) => b.replaceAll(' ', '').toLowerCase().trim() == s.replaceAll(' ', '').toLowerCase().trim());
                      return InkWell(
                        onLongPress: isBooked ? null : () => _showManualBlockDialog(s, business!['restaurantId']),
                        onTap: () {
                           if (!isBooked) {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('স্লটটি বুক করতে চেপে ধরে রাখুন (Long Press)'), duration: Duration(seconds: 1)));
                           }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isBooked ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isBooked ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isBooked ? Icons.lock_clock_rounded : Icons.check_circle_outline_rounded, size: 12, color: isBooked ? Colors.red : Colors.green),
                              const SizedBox(width: 4),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isBooked ? Colors.red.shade700 : Colors.green.shade700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading status: $e'),
              ),
              const SizedBox(height: 10),
              const Text('* খালি স্লট ম্যানুয়ালি বুক করতে সেটির ওপর চেপে ধরে রাখুন।', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  void _showManualBlockDialog(String slot, String businessId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ম্যানুয়াল বুকিং'),
        content: Text('$slot স্লটটি কি অফলাইন কাস্টমারের জন্য বুকড করতে চান?\n\nএটি করলে কাস্টমার অ্যাপে এই সময়টি আর খালি দেখাবে না।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('না')),
          TextButton(
            onPressed: () async {
              try {
                final datePart = DateFormat('yyyy-MM-dd').format(_selectedDate);
                final appointment = '$datePart | $slot';
                final ownerUid = ref.read(supabaseUserProvider)?.id;
                
                if (ownerUid != null) {
                  await ref.read(restaurantOwnerRepositoryProvider).manualBlockSlot(
                    businessId: businessId, 
                    appointmentTime: appointment, 
                    ownerUid: ownerUid
                  );
                  if (mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('স্লটটি সফলভাবে বুকড করা হয়েছে')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ব্যর্থ হয়েছে: $e')));
              }
            }, 
            child: const Text('হ্যাঁ, বুক করুন', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _statusLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(Colors.green, 'Free'),
          const SizedBox(width: 12),
          _legendItem(Colors.red, 'Blocked'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, 
          height: 8, 
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label, 
          style: GoogleFonts.urbanist(
            fontSize: 11, 
            fontWeight: FontWeight.w700, 
            color: Colors.grey.shade700
          ),
        ),
      ],
    );
  }

  Widget _itemFallback(bool isVeg) {
    return Container(
      color: Colors.grey.shade100,
      child: Icon(
        isVeg ? Icons.crop_square : Icons.change_history,
        color: isVeg ? Colors.green : Colors.red,
        size: 20,
      ),
    );
  }
}
