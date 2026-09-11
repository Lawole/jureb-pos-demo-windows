import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/catalog_tables.dart';

part 'supplier_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SupplierDao extends DatabaseAccessor<PosDatabase> with _$SupplierDaoMixin {
  SupplierDao(super.db);

  Stream<List<Supplier>> watchAll() => (select(suppliers)
        ..where((s) => s.isDeleted.equals(false))
        ..orderBy([(s) => OrderingTerm.asc(s.name)]))
      .watch();

  Future<Supplier?> findById(String id) =>
      (select(suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);

  Future<bool> updateSupplier(SuppliersCompanion entry) =>
      update(suppliers).replace(entry);

  Future<void> softDelete(String id) => (update(suppliers)
        ..where((s) => s.id.equals(id)))
      .write(const SuppliersCompanion(isDeleted: Value(true)));
}
