import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/grocery_providers.dart';
import 'add_grocery_product_screen.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GlobalProductBrowseScreen extends ConsumerStatefulWidget {
  const GlobalProductBrowseScreen({super.key});

  @override
  ConsumerState<GlobalProductBrowseScreen> createState() => _GlobalProductBrowseScreenState();
}

class _GlobalProductBrowseScreenState extends ConsumerState<GlobalProductBrowseScreen> {
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  final List<Map<String, String>> _globalCategories = [
    {'name': 'All', 'tag': 'all'},
    {'name': 'Rice', 'tag': 'rice'},
    {'name': 'Atta & Flour', 'tag': 'atta flour'},
    {'name': 'Cooking Oil', 'tag': 'oil'},
    {'name': 'Ghee & Butter', 'tag': 'ghee butter'},
    {'name': 'Dal & Pulses', 'tag': 'pulses'},
    {'name': 'Biscuits', 'tag': 'biscuits'},
    {'name': 'Snacks', 'tag': 'snacks'},
    {'name': 'Tea & Coffee', 'tag': 'tea coffee'},
    {'name': 'Cold Drinks', 'tag': 'beverages'},
    {'name': 'Milk & Dairy', 'tag': 'dairy'},
    {'name': 'Spices', 'tag': 'masala spices'},
    {'name': 'Chocolates', 'tag': 'chocolates'},
    {'name': 'Personal Care', 'tag': 'shampoo soap'},
    {'name': 'Household', 'tag': 'detergent'},
  ];

  @override
  void initState() {
    super.initState();
    _loadGlobalProducts('all');
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isMoreLoading) {
        _loadMoreProducts();
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _currentPage = 1;
      _loadGlobalProducts(_selectedCategory, keyword: query);
    });
  }

  Future<void> _loadGlobalProducts(String tag, {String? keyword}) async {
    setState(() {
      _selectedCategory = tag;
      _isLoading = true;
      _currentPage = 1;
    });

    final service = ref.read(openFoodFactsServiceProvider);
    final list = await service.fetchProductsByCategory(tag, searchKeyword: keyword, page: 1);

    if (mounted) {
      setState(() {
        _products = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    setState(() => _isMoreLoading = true);
    _currentPage++;

    final service = ref.read(openFoodFactsServiceProvider);
    final list = await service.fetchProductsByCategory(
      _selectedCategory, 
      searchKeyword: _searchController.text, 
      page: _currentPage
    );

    if (mounted) {
      setState(() {
        _products.addAll(list);
        _isMoreLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Global Product Browser', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              // Search Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search by product name or brand...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              // Category Chips
              Container(
                height: 50,
                padding: const EdgeInsets.only(bottom: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _globalCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _globalCategories[index];
                    final isSelected = _selectedCategory == cat['tag'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat['name']!),
                        selected: isSelected,
                        onSelected: (v) {
                          if (v) {
                            _searchController.clear();
                            _loadGlobalProducts(cat['tag']!);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _products.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No products found matching your search.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _products.length + (_isMoreLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _products.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final p = _products[index];
                return _GlobalProductTile(
                  product: p,
                  onImport: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => AddGroceryProductScreen(
                          initialBarcode: p['barcode'],
                        )
                      )
                    );
                  },
                );
              },
            ),
    );
  }
}

class _GlobalProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onImport;

  const _GlobalProductTile({required this.product, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 70, height: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: product['image_url'].isNotEmpty 
                ? CachedNetworkImage(
                    imageUrl: product['image_url'], 
                    fit: BoxFit.contain,
                    placeholder: (c, u) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorWidget: (c, u, e) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                  )
                : const Icon(Icons.shopping_basket_outlined, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'], 
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis
                  ),
                  Text(
                    product['brand'], 
                    style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'BC: ${product['barcode']}', 
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(60, 35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
