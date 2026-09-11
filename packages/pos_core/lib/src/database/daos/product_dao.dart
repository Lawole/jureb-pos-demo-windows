import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/catalog_tables.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductDao extends DatabaseAccessor<PosDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Future<Product?> findById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Product?> findByBarcode(String barcode) =>
      (select(products)..where((p) => p.barcode.equals(barcode)))
          .getSingleOrNull();

  /// Backs the product list screen: filters to active, non-deleted products,
  /// optionally by category, and matches [query] against name/barcode/sku —
  /// the three fields a cashier or stock clerk would actually type or scan.
  Stream<List<Product>> watchAll({String? categoryId, String query = ''}) {
    final statement = select(products)
      ..where((p) => p.isDeleted.equals(false));

    if (categoryId != null) {
      statement.where((p) => p.categoryId.equals(categoryId));
    }
    if (query.isNotEmpty) {
      final like = '%$query%';
      statement.where((p) =>
          p.name.like(like) | p.barcode.like(like) | p.sku.like(like));
    }
    statement.orderBy([(p) => OrderingTerm.asc(p.name)]);
    return statement.watch();
  }

  Stream<List<Product>> watchLowStock() => (select(products)
        ..where((p) =>
            p.isDeleted.equals(false) &
            p.isActive.equals(true) &
            p.quantityOnHand.isSmallerOrEqual(p.lowStockThreshold)))
      .watch();

  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  Future<bool> updateProduct(ProductsCompanion entry) =>
      update(products).replace(entry);

  Future<void> softDelete(String id) => (update(products)
        ..where((p) => p.id.equals(id)))
      .write(ProductsCompanion(
    isDeleted: const Value(true),
    updatedAt: Value(DateTime.now()),
  ));

  /// Adjusts [Products.quantityOnHand] by [delta] inside the caller's
  /// transaction. Never called directly by UI code — always go through
  /// `InventoryService.adjustStock` so the change is also recorded in
  /// [StockMovements].
  Future<void> applyQuantityDelta(String productId, int delta) async {
    final product = await findById(productId);
    if (product == null) {
      throw StateError('Product $productId not found');
    }
    final newQuantity = product.quantityOnHand + delta;
    if (newQuantity < 0) {
      throw ArgumentError(
          'Stock adjustment would take ${product.name} below zero '
          '(${product.quantityOnHand} + $delta)');
    }
    await (update(products)..where((p) => p.id.equals(productId))).write(
      ProductsCompanion(
        quantityOnHand: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
