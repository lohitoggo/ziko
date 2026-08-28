import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/product_model.dart';
import '../../../../core/theme/app_theme.dart';

class GroceryProductCard extends StatelessWidget {
  final GroceryProduct product;
  final VoidCallback onAdd;

  const GroceryProductCard({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    const freshGreen = Color(0xFF00B251);
    const freshYellow = Color(0xFFFFD200);

    return Container(
      margin: const EdgeInsets.only(bottom: 10), // Room for shadow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image Section
          Stack(
            children: [
              Container(
                height: 85,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [freshGreen.withValues(alpha: 0.01), freshYellow.withValues(alpha: 0.02)],
                  ),
                ),
                child: Hero(
                  tag: 'product_${product.id}',
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl ?? '',
                    placeholder: (context, url) => const Center(
                      child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.5)),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.shopping_basket_outlined, color: Colors.grey, size: 20),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (product.mrp > product.defaultSellingPrice)
                Positioned(
                  top: 5, left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [freshGreen, Color(0xFF008E41)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(((product.mrp - product.defaultSellingPrice) / product.mrp) * 100).toStringAsFixed(0)}% OFF',
                      style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),

          // 2. Info Section
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BRAND NAME RE-ADDED
                Text(
                  product.brand?.toUpperCase() ?? 'FRESH',
                  maxLines: 1,
                  style: GoogleFonts.urbanist(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: freshGreen,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.charcoal, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantityValue ?? ""} ${product.unit ?? ""}',
                  style: GoogleFonts.urbanist(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                ),
                
                const SizedBox(height: 10),
                
                // Price and Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${product.defaultSellingPrice.toInt()}',
                            style: GoogleFonts.urbanist(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.charcoal),
                          ),
                          if (product.mrp > product.defaultSellingPrice)
                            Text(
                              '₹${product.mrp.toInt()}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _AddButton(onTap: onAdd, color: freshGreen),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  const _AddButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.0),
        ),
        child: Center(
          child: Text(
            'ADD',
            style: GoogleFonts.urbanist(fontSize: 10, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ),
    );
  }
}
