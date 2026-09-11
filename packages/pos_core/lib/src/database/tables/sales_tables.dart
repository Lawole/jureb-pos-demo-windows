import 'package:drift/drift.dart';

import 'catalog_tables.dart';
import 'customer_table.dart';
import 'staff_table.dart';
import 'till_tables.dart';

enum SaleStatus { held, completed, voided, refunded, partiallyRefunded }

/// Sale header. Amounts are the sum of [SaleItems] after per-line and
/// whole-cart discounts, kept denormalized here for fast receipt/report
/// reads without re-summing items every time.
class Sales extends Table {
  TextColumn get id => text()();

  /// Sequential, human-readable, unique receipt number shown to the
  /// customer (e.g. "STORE1-000123"). Distinct from [id] (a uuid) so ids
  /// stay sync-safe while receipt numbers stay short and per-till-sequential.
  TextColumn get receiptNumber => text().unique()();

  TextColumn get tillSessionId => text().references(TillSessions, #id)();
  TextColumn get staffId => text().references(Staff, #id)();
  TextColumn get customerId => text().nullable().references(Customers, #id)();

  TextColumn get status => textEnum<SaleStatus>()();

  /// Set when this sale is a return/refund against an earlier sale.
  TextColumn get originalSaleId => text().nullable().references(Sales, #id)();

  IntColumn get subtotalKobo => integer()();
  IntColumn get cartDiscountKobo => integer().withDefault(const Constant(0))();
  IntColumn get vatKobo => integer()();
  IntColumn get totalKobo => integer()();

  TextColumn get notes => text().nullable()();

  /// Set when the sale is parked with "hold sale" and not yet finalized.
  DateTimeColumn get heldAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// One product line within a sale. Price/VAT/name are snapshotted at time
/// of sale so later product edits never rewrite historical receipts.
class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();

  TextColumn get productNameSnapshot => text()();
  IntColumn get unitPriceKobo => integer()();

  /// Quantity as a real number to support weighed goods (e.g. 1.5 kg).
  RealColumn get quantity => real()();

  BoolColumn get isVatable => boolean()();
  IntColumn get discountKobo => integer().withDefault(const Constant(0))();

  IntColumn get lineSubtotalKobo => integer()();
  IntColumn get lineVatKobo => integer()();
  IntColumn get lineTotalKobo => integer()();

  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  TextColumn get voidReason => text().nullable()();

  /// Cumulative quantity already refunded against this line, across
  /// possibly multiple partial refunds. Lets a refund validate "at most
  /// what's left" instead of re-deriving it by scanning every past refund.
  RealColumn get returnedQuantity => real().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

enum PaymentMethod { cash, card, transfer, other }

/// A single tender against a sale. A sale can have multiple rows here for
/// split payments (e.g. part cash, part transfer).
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get method => textEnum<PaymentMethod>()();
  IntColumn get amountKobo => integer()();

  /// POS terminal reference / bank transfer reference, for reconciliation.
  TextColumn get reference => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
