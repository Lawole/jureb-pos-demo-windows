import 'package:flutter/material.dart';

import 'categories_tab.dart';
import 'low_stock_tab.dart';
import 'products_tab.dart';
import 'purchase_orders_tab.dart';
import 'suppliers_tab.dart';

class InventoryHome extends StatelessWidget {
  const InventoryHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Products', icon: Icon(Icons.inventory_2_outlined)),
              Tab(text: 'Low stock', icon: Icon(Icons.warning_amber_outlined)),
              Tab(text: 'Categories', icon: Icon(Icons.category_outlined)),
              Tab(text: 'Suppliers', icon: Icon(Icons.local_shipping_outlined)),
              Tab(text: 'Purchase orders', icon: Icon(Icons.receipt_long_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProductsTab(),
            LowStockTab(),
            CategoriesTab(),
            SuppliersTab(),
            PurchaseOrdersTab(),
          ],
        ),
      ),
    );
  }
}
