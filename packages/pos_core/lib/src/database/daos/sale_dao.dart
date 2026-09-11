import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sales_tables.dart';

part 'sale_dao.g.dart';

@DriftAccessor(tables: [Sales, SaleItems, Payments])
class SaleDao extends DatabaseAccessor<PosDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Future<Sale?> findById(String id) =>
      (select(sales)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Sale?> findByReceiptNumber(String receiptNumber) =>
      (select(sales)..where((s) => s.receiptNumber.equals(receiptNumber)))
          .getSingleOrNull();

  Stream<List<Sale>> watchHeldSales() => (select(sales)
        ..where((s) => s.status.equals(SaleStatus.held.name))
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
      .watch();

  Future<List<SaleItem>> itemsFor(String saleId) =>
      (select(saleItems)..where((i) => i.saleId.equals(saleId))).get();

  Stream<List<SaleItem>> watchItemsFor(String saleId) =>
      (select(saleItems)..where((i) => i.saleId.equals(saleId))).watch();

  Future<List<Payment>> paymentsFor(String saleId) =>
      (select(payments)..where((p) => p.saleId.equals(saleId))).get();

  Future<int> insertSale(SalesCompanion entry) => into(sales).insert(entry);

  Future<int> insertSaleItem(SaleItemsCompanion entry) =>
      into(saleItems).insert(entry);

  Future<int> insertPayment(PaymentsCompanion entry) =>
      into(payments).insert(entry);

  Future<void> updateItemReturnedQuantity(String itemId, double returnedQuantity) =>
      (update(saleItems)..where((i) => i.id.equals(itemId))).write(
        SaleItemsCompanion(returnedQuantity: Value(returnedQuantity)),
      );

  Future<void> updateSaleStatus(String id, SaleStatus status,
          {DateTime? completedAt}) =>
      (update(sales)..where((s) => s.id.equals(id))).write(
        SalesCompanion(
          status: Value(status),
          completedAt: completedAt == null
              ? const Value.absent()
              : Value(completedAt),
        ),
      );

  /// Sums cash tenders (positive for sales, negative for cash refunds)
  /// across every sale/refund posted under [tillSessionId] — the figure a
  /// till reconciliation compares against the physically counted drawer.
  Future<int> sumCashMovementForTillSession(String tillSessionId) async {
    final query = selectOnly(payments)
      ..addColumns([payments.amountKobo.sum()])
      ..join([
        innerJoin(sales, sales.id.equalsExp(payments.saleId)),
      ])
      ..where(sales.tillSessionId.equals(tillSessionId) &
          payments.method.equals(PaymentMethod.cash.name));
    final row = await query.getSingle();
    return row.read(payments.amountKobo.sum()) ?? 0;
  }

  Stream<List<Sale>> watchSalesForTillSession(String tillSessionId) =>
      (select(sales)
            ..where((s) => s.tillSessionId.equals(tillSessionId))
            ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .watch();
}
