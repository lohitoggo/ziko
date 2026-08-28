import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/grocery_providers.dart';
import '../data/models/product_model.dart';
import '../data/models/inventory_model.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';

class AddGroceryProductScreen extends ConsumerStatefulWidget {
  final String? shopId; 
  final String? initialBarcode;
  const AddGroceryProductScreen({super.key, this.shopId, this.initialBarcode});

  @override
  ConsumerState<AddGroceryProductScreen> createState() => _AddGroceryProductScreenState();
}

class _AddGroceryProductScreenState extends ConsumerState<AddGroceryProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _mrpController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descController = TextEditingController();
  
  String? _selectedUnit = 'pc';
  String? _imageUrl;
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onBarcodeScanned(widget.initialBarcode!);
      });
    }
  }

  final List<String> _units = ['pc', 'kg', 'gm', 'L', 'ml', 'packet', 'box'];

  Future<void> _onBarcodeScanned(String barcode) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _barcodeController.text = barcode;
      _isScanning = false;
    });

    final repo = ref.read(groceryRepositoryProvider);
    final existingProduct = await repo.getProductByBarcode(barcode);
    
    if (existingProduct != null) {
      setState(() {
        _nameController.text = existingProduct.name;
        _brandController.text = existingProduct.brand ?? '';
        _imageUrl = existingProduct.imageUrl;
        _quantityController.text = existingProduct.quantityValue ?? '';
        _selectedCategoryId = existingProduct.categoryId;
        _mrpController.text = existingProduct.mrp.toString();
        _priceController.text = existingProduct.defaultSellingPrice.toString();
        _selectedUnit = existingProduct.unit ?? 'pc';
        _descController.text = existingProduct.description ?? '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product found in Master Catalog! ✅')),
        );
      }
    } else {
      final service = ref.read(openFoodFactsServiceProvider);
      final productData = await service.fetchProductByBarcode(barcode);

      if (productData != null) {
        setState(() {
          _nameController.text = productData['name'] ?? '';
          _brandController.text = productData['brand'] ?? '';
          _imageUrl = productData['image_url'];
          _quantityController.text = productData['quantity'] ?? '';
          _descController.text = productData['description'] ?? '';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found online. Please enter manually.')),
          );
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(groceryRepositoryProvider);
      final barcode = _barcodeController.text.trim();
      
      // 1. First, Upsert the Master Product
      final existing = await repo.getProductByBarcode(barcode);
      final productId = existing?.id ?? const Uuid().v4();
      
      final product = GroceryProduct(
        id: productId,
        categoryId: _selectedCategoryId,
        name: _nameController.text.trim(),
        slug: _nameController.text.trim().toLowerCase().replaceAll(' ', '-'),
        brand: _brandController.text.trim(),
        barcode: barcode,
        mrp: double.tryParse(_mrpController.text) ?? 0,
        defaultSellingPrice: double.tryParse(_priceController.text) ?? 0,
        imageUrl: _imageUrl,
        quantityValue: _quantityController.text.trim(),
        unit: _selectedUnit,
        description: _descController.text.trim(),
      );

      await repo.upsertProduct(product);

      // 2. Automated Inventory Logic: 
      // If shopId is provided (Owner mode) use it. 
      // If shopId is NULL (Admin mode), find the main grocery shop.
      String? targetShopId = widget.shopId;
      if (targetShopId == null) {
        targetShopId = await repo.getMainGroceryShopId();
        debugPrint('DEBUG: Admin adding to shop: $targetShopId');
      }

      if (targetShopId != null) {
        // Look for existing inventory entry for this PRODUCT in this SHOP
        final shopInventory = await repo.getShopInventory(targetShopId);
        final existingInv = shopInventory.where((i) => i.productId == productId).toList();
        
        final inventoryId = existingInv.isNotEmpty ? existingInv.first.id : const Uuid().v4();
        
        final inventory = GroceryInventory(
          id: inventoryId,
          productId: productId,
          businessId: targetShopId,
          stockQuantity: int.tryParse(_stockController.text) ?? 0,
          price: double.tryParse(_priceController.text) ?? 0,
          updatedAt: DateTime.now(),
        );
        await repo.updateInventory(inventory);
      } else {
        debugPrint('WARNING: No Grocery shop found to link inventory');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সফলভাবে সেভ করা হয়েছে! ✅'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('CRITICAL ERROR during save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(groceryCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('গ্রোসারি আইটেম যোগ করুন')),
      body: _isScanning 
        ? MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _onBarcodeScanned(barcode.rawValue!);
                  break;
                }
              }
            },
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_imageUrl != null)
                    Center(
                      child: Container(
                        height: 150, width: 150,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(_imageUrl!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isScanning = true),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('বারকোড স্ক্যান করুন'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  const Text('পণ্যর তথ্য', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'পণ্যের নাম *', prefixIcon: Icon(Icons.shopping_bag_outlined)),
                    validator: (v) => v!.isEmpty ? 'নাম প্রয়োজন' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  categoriesAsync.when(
                    data: (list) => DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'ক্যাটাগরি *', prefixIcon: Icon(Icons.category_outlined)),
                      items: list.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'ক্যাটাগরি সিলেক্ট করুন' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading categories'),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _brandController,
                          decoration: const InputDecoration(labelText: 'ব্র্যান্ড', prefixIcon: Icon(Icons.branding_watermark_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(labelText: 'বারকোড', prefixIcon: Icon(Icons.qr_code)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(labelText: 'পরিমাণ (যেমন: 500)', prefixIcon: Icon(Icons.scale_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnit,
                          decoration: const InputDecoration(labelText: 'একক'),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => _selectedUnit = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _mrpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'MRP (₹)', prefixIcon: Icon(Icons.sell_outlined)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'বিক্রয় মূল্য (₹) *', prefixIcon: Icon(Icons.payments_outlined)),
                          validator: (v) => v!.isEmpty ? 'মূল্য দিন' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (widget.shopId != null)
                    TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'বর্তমান স্টক (পিস) *', prefixIcon: Icon(Icons.inventory_2_outlined)),
                      validator: (v) => v!.isEmpty ? 'স্টক দিন' : null,
                    ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'পণ্যের বিবরণ (ঐচ্ছিক)', prefixIcon: Icon(Icons.description_outlined)),
                  ),
                  
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text('পণ্য সেভ করুন', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
    );
  }
}
