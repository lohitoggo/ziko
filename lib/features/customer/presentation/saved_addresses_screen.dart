import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/address_provider.dart';
import '../data/address_model.dart';
import '../../auth/providers/supabase_auth_provider.dart';
import '../../auth/data/area_model.dart';
import '../../auth/providers/area_provider.dart';
import '../../../core/theme/app_theme.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'map_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(userAddressesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      appBar: AppBar(
        title: Text('Saved Addresses', style: GoogleFonts.urbanist(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
      ),
      body: addressesAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
        data: (addresses) => _buildAddressList(addresses, context, ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAddressSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add New Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context, {AddressModel? existing}) {
    final houseCtrl = TextEditingController(text: existing?.houseNumber);
    final villageCtrl = TextEditingController(text: existing?.village);
    final landmarkCtrl = TextEditingController(text: existing?.landmark);
    final pinCtrl = TextEditingController(text: existing?.pinCode);
    final searchCtrl = TextEditingController();
    
    String? selectedAreaId = existing?.areaId;
    double? lat = existing?.latitude;
    double? lon = existing?.longitude;
    bool isFetchingGPS = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final areasAsync = ref.watch(activeAreasProvider);
          
          Future<void> fetchGPS() async {
            setLocalState(() => isFetchingGPS = true);
            try {
              LocationPermission permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
              if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
                setLocalState(() { lat = pos.latitude; lon = pos.longitude; });
              }
            } catch (e) {
              debugPrint('GPS Error: $e');
            } finally {
              setLocalState(() => isFetchingGPS = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing == null ? 'নতুন ঠিকানা যোগ করুন' : 'ঠিকানা এডিট করুন', style: GoogleFonts.urbanist(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),

                  // 1. LOCATION SEARCH & GPS SECTION
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        // Search Bar
                        TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                              onPressed: () async {
                                final query = searchCtrl.text.trim();
                                if (query.isEmpty) return;
                                try {
                                  final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
                                  final response = await http.get(url, headers: {'User-Agent': 'ziko_app'});
                                  if (response.statusCode == 200) {
                                    final List data = json.decode(response.body);
                                    if (data.isNotEmpty) {
                                      setLocalState(() {
                                        lat = double.parse(data[0]['lat']);
                                        lon = double.parse(data[0]['lon']);
                                      });
                                    }
                                  }
                                } catch (e) {}
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: isFetchingGPS ? null : fetchGPS,
                                icon: isFetchingGPS ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location, size: 16),
                                label: Text(lat == null ? 'Get GPS' : 'Update GPS', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (lat != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => MapPickerScreen(initialLocation: LatLng(lat!, lon!))));
                                    if (result != null && result is LatLng) {
                                      setLocalState(() { lat = result.latitude; lon = result.longitude; });
                                    }
                                  },
                                  icon: const Icon(Icons.map, size: 16),
                                  label: const Text('Adjust', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (lat != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                  const SizedBox(width: 6),
                                  Text('লোকেশন পিন পাওয়া গেছে: ${lat!.toStringAsFixed(4)}, ${lon!.toStringAsFixed(4)}', 
                                    style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // 2. AREA SELECTION (CRITICAL)
                  areasAsync.when(
                    data: (areas) => DropdownButtonFormField<String>(
                      initialValue: selectedAreaId,
                      decoration: const InputDecoration(labelText: 'এলাকা নির্বাচন করুন *', prefixIcon: Icon(Icons.map_outlined)),
                      items: areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                      onChanged: (v) => setLocalState(() => selectedAreaId = v),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('এলাকা লোড করা যায়নি'),
                  ),
                  const SizedBox(height: 16),

                  _buildField(houseCtrl, 'বাড়ি নম্বর / ফ্ল্যাট নাম *', Icons.home_outlined),
                  const SizedBox(height: 12),
                  _buildField(villageCtrl, 'গ্রাম / পাড়ার নাম *', Icons.apartment_rounded),
                  const SizedBox(height: 12),
                  _buildField(landmarkCtrl, 'ল্যান্ডমার্ক (চেনার উপায়) *', Icons.assistant_navigation),
                  const SizedBox(height: 12),
                  _buildField(pinCtrl, 'পিন কোড *', Icons.pin_drop_outlined, isNum: true),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (houseCtrl.text.isEmpty || villageCtrl.text.isEmpty || selectedAreaId == null || lat == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('সবগুলো তথ্য এবং লোকেশন পিন নিশ্চিত করুন')));
                          return;
                        }
                        final user = ref.read(supabaseUserProvider);
                        if (user == null) return;

                        await ref.read(addressRepositoryProvider).saveAddress(AddressModel(
                          id: existing?.id ?? '',
                          userId: user.id,
                          houseNumber: houseCtrl.text.trim(),
                          village: villageCtrl.text.trim(),
                          landmark: landmarkCtrl.text.trim(),
                          pinCode: pinCtrl.text.trim(),
                          areaId: selectedAreaId,
                          latitude: lat,
                          longitude: lon,
                          isDefault: existing?.isDefault ?? false,
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(existing == null ? 'ঠিকানা সেভ করুন' : 'আপডেট করুন'),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  Widget _buildAddressList(List<AddressModel> addresses, BuildContext context, WidgetRef ref) {
    if (addresses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No addresses saved yet', style: GoogleFonts.urbanist(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: addresses.length,
      itemBuilder: (context, index) {
        final a = addresses[index];
        final areaAsync = ref.watch(activeAreasProvider);
        final String areaName = areaAsync.maybeWhen(
          data: (list) => list.firstWhere((ar) => ar.id == a.areaId, orElse: () => AreaModel(id: '', name: 'Unknown', deliveryCharge: 0, minimumOrder: 0, estimatedDeliveryMinutes: 0, status: 'active')).name,
          orElse: () => 'Loading...',
        );

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.home_rounded, color: AppColors.primary, size: 20),
            ),
            title: Row(
              children: [
                Expanded(child: Text(a.village, style: GoogleFonts.urbanist(fontWeight: FontWeight.bold, fontSize: 15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(areaName, style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
                if (a.isDefault)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('DEFAULT', style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text('${a.houseNumber}, ${a.landmark}\nPin: ${a.pinCode}', style: const TextStyle(fontSize: 12)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') _confirmDelete(context, ref, a.id);
                if (v == 'edit') _showAddAddressSheet(context, existing: a);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () {
              if (!a.isDefault) {
                ref.read(addressRepositoryProvider).setDefault(a.userId, a.id);
              }
            },
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to remove this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(addressRepositoryProvider).deleteAddress(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
