import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../grocery/providers/grocery_providers.dart';
import '../../grocery/presentation/add_grocery_product_screen.dart';
import '../../grocery/presentation/global_product_browse_screen.dart';
import 'admin_master_products_screen.dart';

class AdminGroceryTab extends ConsumerWidget {
  const AdminGroceryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(groceryCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Browse Global Products',
            icon: const Icon(Icons.public_rounded, color: Colors.blue),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalProductBrowseScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('এখনো কোনো গ্রোসারি ক্যাটাগরি নেই।\nঅনুগ্রহ করে ডাটাবেসে ক্যাটাগরি যোগ করুন।', textAlign: TextAlign.center));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: cat.imageUrl != null 
                    ? Image.network(cat.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                    : const Icon(Icons.category, size: 40),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(cat.slug),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminMasterProductsScreen(
                          categoryId: cat.id,
                          categoryName: cat.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (_) => const AddGroceryProductScreen())
          );
        },
        label: const Text('Add Product'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }
}
