import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/business_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'customer_home_screen.dart';

class CategoryShopsScreen extends ConsumerWidget {
  final String categoryId;
  final String categoryName;

  const CategoryShopsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(businessesByAreaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F4),
      body: Column(
        children: [
          // 1. Premium Gradient Header (Matching Home Screen)
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 25,
              left: 10,
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
                Expanded(
                  child: Text(
                    categoryName,
                    style: GoogleFonts.sora(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Shops List
          Expanded(
            child: shopsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('Connecting...', style: GoogleFonts.urbanist(color: Colors.grey)),
                  ],
                ),
              ),
              data: (allShops) {
                final shops = categoryId == 'all' 
                    ? allShops 
                    : allShops.where((s) => s.category.trim().toLowerCase() == categoryId.trim().toLowerCase()).toList();

                if (shops.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No $categoryName available in your area', 
                            style: GoogleFonts.urbanist(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    return BusinessCard(business: shops[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
