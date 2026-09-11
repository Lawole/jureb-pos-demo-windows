import 'package:flutter/material.dart';
import 'package:pos_core/pos_core.dart';
import 'package:provider/provider.dart';

import '../../services.dart';
import '../../state/auth_controller.dart';
import 'product_form_dialog.dart';
import 'stock_adjustment_dialog.dart';

/// Lists products with a search box and a category filter. Both are just
/// plain widget state (`_search`, `_categoryId`) — they only matter to this
/// one screen, so there's no need for a shared provider.
class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _search = '';
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final db = context.read<Services>().db;
    final staff = context.watch<AuthController>().currentStaff!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name, barcode, or SKU…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              const SizedBox(width: 12),
              StreamBuilder<List<Category>>(
                stream: db.categoryDao.watchAll(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButton<String?>(
                    value: _categoryId,
                    hint: const Text('All categories'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All categories')),
                      for (final c in categories)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                },
              ),
              const SizedBox(width: 12),
              if (staff.can(Permission.manageProducts))
                FilledButton.icon(
                  onPressed: () => showProductFormDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Product>>(
            stream: db.productDao.watchAll(categoryId: _categoryId, query: _search),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data!;
              if (products.isEmpty) {
                return const Center(child: Text('No products found.'));
              }
              return ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final isLowStock = product.quantityOnHand <= product.lowStockThreshold;
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Text([
                      if (product.barcode != null) 'Barcode: ${product.barcode}',
                      'Unit: ${product.unit.name}',
                      if (!product.isVatable) 'VAT-exempt',
                    ].join(' · ')),
                    leading: CircleAvatar(
                      backgroundColor: isLowStock
                          ? Theme.of(context).colorScheme.errorContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Text('${product.quantityOnHand}', style: const TextStyle(fontSize: 12)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(NairaFormatter.forReceipt(product.sellingPriceKobo)),
                        const SizedBox(width: 12),
                        if (staff.can(Permission.adjustStock))
                          IconButton(
                            tooltip: 'Adjust stock',
                            icon: const Icon(Icons.inventory_2_outlined),
                            onPressed: () => showStockAdjustmentDialog(context, product),
                          ),
                        if (staff.can(Permission.manageProducts))
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showProductFormDialog(context, existing: product),
                          ),
                        if (staff.can(Permission.manageProducts))
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(context, product),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.name}" from the catalog? '
            'It stays on past receipts but will no longer be sellable.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<Services>().inventory.deleteProduct(product.id);
    }
  }
}
