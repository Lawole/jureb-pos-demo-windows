import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/catalog_tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<PosDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchAll() => (select(categories)
        ..where((c) => c.isDeleted.equals(false))
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<Category?> findById(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Future<void> softDelete(String id) => (update(categories)
        ..where((c) => c.id.equals(id)))
      .write(const CategoriesCompanion(isDeleted: Value(true)));
}
