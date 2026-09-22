import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../providers/admin_provider.dart';
import 'admin_area_draw_screen.dart';

class AdminAreasTab extends ConsumerWidget {
  const AdminAreasTab({super.key});

  void _showAddAreaSheet(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existingArea}) {
    final nameCtrl = TextEditingController(text: existingArea?['name']);
    final chargeCtrl = TextEditingController(text: existingArea != null ? (existingArea['delivery_charge'] ?? existingArea['deliveryCharge'] ?? 0).toString() : '');
    final minOrderCtrl = TextEditingController(text: existingArea != null ? (existingArea['min_order_amount'] ?? existingArea['minimumOrder'] ?? 0).toString() : '');
    final timeCtrl = TextEditingController(text: existingArea != null ? (existingArea['estimated_delivery_minutes'] ?? existingArea['estimatedDeliveryMinutes'] ?? 0).toString() : '');

    List<ll.LatLng> currentPolygon = [];
    final rawPolygon = existingArea?['boundary_polygon'] ?? existingArea?['polygon_points'];
    if (rawPolygon != null && rawPolygon is List) {
      for (var pt in rawPolygon) {
        if (pt is Map) {
          final lat = double.tryParse(pt['lat']?.toString() ?? '');
          final lng = double.tryParse(pt['lng']?.toString() ?? pt['lon']?.toString() ?? '');
          if (lat != null && lng != null) {
            currentPolygon.add(ll.LatLng(lat, lng));
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
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
                    Text(existingArea == null ? 'নতুন এলাকা যোগ করুন' : 'এলাকা এডিট করুন',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'এলাকার নাম *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: chargeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ডেলিভারি চার্জ (₹)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minOrderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'ন্যূনতম অর্ডার (₹)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'আনুমানিক ডেলিভারি সময় (মিনিট)'),
                    ),
                    const SizedBox(height: 16),

                    // DRAW MAP BOUNDARY BUTTON
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            currentPolygon.isNotEmpty ? Icons.check_circle_rounded : Icons.map_outlined,
                            color: currentPolygon.isNotEmpty ? Colors.green : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ম্যাপের বাউন্ডারি (Polygon)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  currentPolygon.isNotEmpty
                                      ? '${currentPolygon.length} টি বাউন্ডারি পয়েন্ট সেভ করা আছে'
                                      : 'ম্যাপে পিন দিয়ে বাউন্ডারি ড্র করুন',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final result = await Navigator.push<List<ll.LatLng>>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminAreaDrawScreen(
                                    initialPolygon: currentPolygon,
                                    areaName: name,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setLocalState(() {
                                  currentPolygon = result;
                                });
                              }
                            },
                            icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                            label: Text(currentPolygon.isEmpty ? 'ড্র করুন' : 'এডিট'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentPolygon.isNotEmpty ? Colors.green : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          final charge = double.tryParse(chargeCtrl.text.trim()) ?? 0;
                          final minOrder = double.tryParse(minOrderCtrl.text.trim()) ?? 0;
                          final time = int.tryParse(timeCtrl.text.trim()) ?? 0;

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('এলাকার নাম দিন')),
                            );
                            return;
                          }

                          final List<Map<String, double>> formattedPolygon = currentPolygon
                              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                              .toList();

                          if (existingArea == null) {
                            await ref.read(adminRepositoryProvider).addArea(
                              name: name,
                              deliveryCharge: charge,
                              minimumOrder: minOrder,
                              estimatedDeliveryMinutes: time,
                              boundaryPolygon: formattedPolygon,
                            );
                          } else {
                            await ref.read(adminRepositoryProvider).updateAreaDetails(existingArea['areaId'], {
                              'name': name,
                              'deliveryCharge': charge,
                              'minimumOrder': minOrder,
                              'estimatedDeliveryMinutes': time,
                              'boundaryPolygon': formattedPolygon,
                            });
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(existingArea == null ? 'যোগ করুন' : 'আপডেট করুন', style: const TextStyle(fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(allAreasProvider);
    final repo = ref.read(adminRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAreaSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('এলাকা যোগ করুন'),
      ),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('সমস্যা: $e')),
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(child: Text('এখনো কোনো এলাকা যোগ করা হয়নি'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              final isActive = area['is_active'] ?? area['isActive'] ?? true;
              final rawPolygon = area['boundary_polygon'] ?? area['polygon_points'];
              final hasPolygon = rawPolygon != null && rawPolygon is List && rawPolygon.isNotEmpty;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(area['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPolygon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('MAPPED 🗺️', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () => _showAddAreaSheet(context, ref, existingArea: area),
                          ),
                        ],
                      ),
                    ],
                  ),
                  subtitle: Text(
                      'চার্জ: ₹${area['delivery_charge'] ?? area['deliveryCharge'] ?? 0} • ন্যূনতম: ₹${area['min_order_amount'] ?? area['minimumOrder'] ?? 0} • ${area['estimated_delivery_minutes'] ?? area['estimatedDeliveryMinutes'] ?? 0} মিনিট'),
                  trailing: Switch(
                    value: isActive,
                    onChanged: (val) => repo.toggleAreaStatus(area['areaId'], val),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
