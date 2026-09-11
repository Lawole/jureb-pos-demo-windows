import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/daos/counter_dao.dart';
import '../../database/daos/sale_dao.dart';
import '../../database/database.dart';
import '../../database/tables/sales_tables.dart';
import 'inventory_service.dart';
import 'sales_calculator.dart';

class SaleLineDraft {
  const SaleLineDraft({
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPriceKobo,
    required this.quantity,
    required this.isVatable,
    this.lineDiscountKobo = 0,
  });

  final String productId;
  final String productNameSnapshot;
  final int unitPriceKobo;
  final double quantity;
  final bool isVatable;
  final int lineDiscountKobo;
}

class PaymentDraft {
  const PaymentDraft({
    required this.method,
    required this.amountKobo,
    this.reference,
  });

  final PaymentMethod method;
  final int amountKobo;
  final String? reference;
}

class RefundLineInput {
  const RefundLineInput({required this.saleItemId, required this.quantity});

  final String saleItemId;
  final double quantity;
}

class CompletedSale {
  const CompletedSale({required this.sale, required this.changeDueKobo});

  final Sale sale;
  final int changeDueKobo;
}

const _epsilon = 0.0001;

/// Checkout, hold/resume, and refund logic — the highest-stakes code in the
/// app, since a wrong total or a stock/sale mismatch here is a wrong
/// receipt or a drawer that never reconciles. Every write here happens
/// inside a single transaction with the corresponding stock movement, so
/// a crash mid-sale can never leave one without the other.
class SaleService {
  SaleService(this._db)
      : _saleDao = _db.saleDao,
        _counterDao = _db.counterDao,
        _inventory = InventoryService(_db);

  final PosDatabase _db;
  final SaleDao _saleDao;
  final CounterDao _counterDao;
  final InventoryService _inventory;
  static const _uuid = Uuid();

  Future<String> _nextReceiptNumber() async {
    final n = await _counterDao.next('receipt_number');
    return 'R${n.toString().padLeft(6, '0')}';
  }

  List<CartLineInput> _toCartInputs(List<SaleLineDraft> lines) => lines
      .map((l) => CartLineInput(
            unitPriceKobo: l.unitPriceKobo,
            quantity: l.quantity,
            isVatable: l.isVatable,
            lineDiscountKobo: l.lineDiscountKobo,
          ))
      .toList();

  Future<void> _insertLineItems(
    String saleId,
    List<SaleLineDraft> lines,
    CartTotals totals,
  ) async {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final result = totals.lines[i];
      await _saleDao.insertSaleItem(SaleItemsCompanion.insert(
        id: _uuid.v4(),
        saleId: saleId,
        productId: line.productId,
        productNameSnapshot: line.productNameSnapshot,
        unitPriceKobo: line.unitPriceKobo,
        quantity: line.quantity,
        isVatable: line.isVatable,
        discountKobo: Value(result.discountKobo),
        lineSubtotalKobo: result.subtotalKobo,
        lineVatKobo: result.vatKobo,
        lineTotalKobo: result.totalKobo,
      ));
    }
  }

  Future<void> _deductStockForLines(
    List<SaleLineDraft> lines,
    String staffId,
    String saleId,
  ) async {
    for (final line in lines) {
      final wholeUnits = line.quantity.round();
      if (wholeUnits > 0) {
        await _inventory.recordMovementForSale(
          productId: line.productId,
          quantity: wholeUnits,
          isReturn: false,
          staffId: staffId,
          saleId: saleId,
        );
      }
    }
  }

  /// Completes a walk-up sale in one step: computes VAT/discount totals,
  /// validates the tendered payments cover the total, deducts stock, and
  /// persists everything atomically. Throws [ArgumentError] if payments
  /// fall short of the total, or if any line would oversell a product.
  Future<CompletedSale> completeSale({
    required String tillSessionId,
    required String staffId,
    required List<SaleLineDraft> lines,
    required List<PaymentDraft> payments,
    String? customerId,
    int cartDiscountKobo = 0,
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('A sale needs at least one item');
    }
    final totals =
        SalesCalculator.computeCart(_toCartInputs(lines), cartDiscountKobo: cartDiscountKobo);
    final changeDue = SalesCalculator.changeDueKobo(
      totalKobo: totals.totalKobo,
      paymentsKobo: payments.map((p) => p.amountKobo).toList(),
    );

    final id = _uuid.v4();
    await _db.transaction(() async {
      final receiptNumber = await _nextReceiptNumber();
      await _saleDao.insertSale(SalesCompanion.insert(
        id: id,
        receiptNumber: receiptNumber,
        tillSessionId: tillSessionId,
        staffId: staffId,
        customerId: Value(customerId),
        status: SaleStatus.completed,
        subtotalKobo: totals.subtotalKobo,
        cartDiscountKobo: Value(totals.cartDiscountKobo),
        vatKobo: totals.vatKobo,
        totalKobo: totals.totalKobo,
        notes: Value(notes),
        completedAt: Value(DateTime.now()),
      ));
      await _insertLineItems(id, lines, totals);
      await _deductStockForLines(lines, staffId, id);
      for (final payment in payments) {
        await _saleDao.insertPayment(PaymentsCompanion.insert(
          id: _uuid.v4(),
          saleId: id,
          method: payment.method,
          amountKobo: payment.amountKobo,
          reference: Value(payment.reference),
        ));
      }
    });

    final sale = (await _saleDao.findById(id))!;
    return CompletedSale(sale: sale, changeDueKobo: changeDue);
  }

  /// Parks a cart for later without taking payment or touching stock —
  /// stock only leaves the shop once [completeHeldSale] is actually paid.
  Future<Sale> holdSale({
    required String tillSessionId,
    required String staffId,
    required List<SaleLineDraft> lines,
    String? customerId,
    int cartDiscountKobo = 0,
    String? notes,
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Cannot hold an empty cart');
    }
    final totals =
        SalesCalculator.computeCart(_toCartInputs(lines), cartDiscountKobo: cartDiscountKobo);
    final id = _uuid.v4();
    await _db.transaction(() async {
      final receiptNumber = await _nextReceiptNumber();
      await _saleDao.insertSale(SalesCompanion.insert(
        id: id,
        receiptNumber: receiptNumber,
        tillSessionId: tillSessionId,
        staffId: staffId,
        customerId: Value(customerId),
        status: SaleStatus.held,
        subtotalKobo: totals.subtotalKobo,
        cartDiscountKobo: Value(totals.cartDiscountKobo),
        vatKobo: totals.vatKobo,
        totalKobo: totals.totalKobo,
        notes: Value(notes),
        heldAt: Value(DateTime.now()),
      ));
      await _insertLineItems(id, lines, totals);
    });
    return (await _saleDao.findById(id))!;
  }

  Future<void> voidHeldSale(String saleId) async {
    final sale = await _saleDao.findById(saleId);
    if (sale == null || sale.status != SaleStatus.held) {
      throw StateError('Only a held sale can be voided');
    }
    await _saleDao.updateSaleStatus(saleId, SaleStatus.voided);
  }

  /// Takes payment against a previously held sale, deducting stock now
  /// that the sale is actually happening.
  Future<CompletedSale> completeHeldSale({
    required String saleId,
    required String staffId,
    required List<PaymentDraft> payments,
  }) async {
    final sale = await _saleDao.findById(saleId);
    if (sale == null) throw ArgumentError('Sale $saleId not found');
    if (sale.status != SaleStatus.held) {
      throw StateError('Sale ${sale.receiptNumber} is not on hold');
    }
    final changeDue = SalesCalculator.changeDueKobo(
      totalKobo: sale.totalKobo,
      paymentsKobo: payments.map((p) => p.amountKobo).toList(),
    );

    await _db.transaction(() async {
      final items = await _saleDao.itemsFor(saleId);
      for (final item in items) {
        final wholeUnits = item.quantity.round();
        if (wholeUnits > 0) {
          await _inventory.recordMovementForSale(
            productId: item.productId,
            quantity: wholeUnits,
            isReturn: false,
            staffId: staffId,
            saleId: saleId,
          );
        }
      }
      for (final payment in payments) {
        await _saleDao.insertPayment(PaymentsCompanion.insert(
          id: _uuid.v4(),
          saleId: saleId,
          method: payment.method,
          amountKobo: payment.amountKobo,
          reference: Value(payment.reference),
        ));
      }
      await _saleDao.updateSaleStatus(saleId, SaleStatus.completed,
          completedAt: DateTime.now());
    });

    final updated = (await _saleDao.findById(saleId))!;
    return CompletedSale(sale: updated, changeDueKobo: changeDue);
  }

  /// Refunds some or all quantity from one or more lines of a completed
  /// sale. Creates a new [Sale] row (status `refunded`) linked via
  /// `originalSaleId`, restocks the returned quantities, records a negative
  /// cash/tender movement, and rolls the original sale's status up to
  /// `refunded`/`partiallyRefunded`. Refund amounts are the *original*
  /// line's discount/VAT proportionally allocated to the returned
  /// quantity, never recomputed — a refund reverses what was actually
  /// charged, it doesn't reprice the sale.
  Future<Sale> refundSale({
    required String originalSaleId,
    required String tillSessionId,
    required String staffId,
    required List<RefundLineInput> returnedLines,
    required PaymentMethod refundMethod,
    String? notes,
  }) async {
    if (returnedLines.isEmpty) {
      throw ArgumentError('A refund needs at least one item');
    }
    final original = await _saleDao.findById(originalSaleId);
    if (original == null) {
      throw ArgumentError('Sale $originalSaleId not found');
    }
    if (original.status != SaleStatus.completed &&
        original.status != SaleStatus.partiallyRefunded) {
      throw StateError(
          'Sale ${original.receiptNumber} is ${original.status.name} and cannot be refunded further');
    }

    final originalItems = await _saleDao.itemsFor(originalSaleId);
    final itemsById = {for (final item in originalItems) item.id: item};

    var refundSubtotal = 0;
    var refundVat = 0;
    final refundLineData = <(SaleItem item, RefundLineInput input, int subtotal, int vat)>[];

    for (final line in returnedLines) {
      final item = itemsById[line.saleItemId];
      if (item == null) {
        throw ArgumentError('Unknown sale item ${line.saleItemId}');
      }
      final remaining = item.quantity - item.returnedQuantity;
      if (line.quantity <= 0 || line.quantity > remaining + _epsilon) {
        throw ArgumentError(
            'Cannot refund ${line.quantity} of "${item.productNameSnapshot}" — only $remaining left to refund');
      }
      final ratio = line.quantity / item.quantity;
      final lineSubtotal = SalesCalculator.roundToKobo(item.lineSubtotalKobo * ratio);
      final lineVat = SalesCalculator.roundToKobo(item.lineVatKobo * ratio);
      refundSubtotal += lineSubtotal;
      refundVat += lineVat;
      refundLineData.add((item, line, lineSubtotal, lineVat));
    }
    final refundTotal = refundSubtotal + refundVat;

    final refundId = _uuid.v4();
    await _db.transaction(() async {
      final receiptNumber = await _nextReceiptNumber();
      await _saleDao.insertSale(SalesCompanion.insert(
        id: refundId,
        receiptNumber: receiptNumber,
        tillSessionId: tillSessionId,
        staffId: staffId,
        customerId: Value(original.customerId),
        status: SaleStatus.refunded,
        originalSaleId: Value(original.id),
        subtotalKobo: refundSubtotal,
        vatKobo: refundVat,
        totalKobo: refundTotal,
        notes: Value(notes),
        completedAt: Value(DateTime.now()),
      ));

      for (final (item, input, subtotal, vat) in refundLineData) {
        await _saleDao.insertSaleItem(SaleItemsCompanion.insert(
          id: _uuid.v4(),
          saleId: refundId,
          productId: item.productId,
          productNameSnapshot: item.productNameSnapshot,
          unitPriceKobo: item.unitPriceKobo,
          quantity: input.quantity,
          isVatable: item.isVatable,
          lineSubtotalKobo: subtotal,
          lineVatKobo: vat,
          lineTotalKobo: subtotal + vat,
        ));
        await _saleDao.updateItemReturnedQuantity(
          item.id,
          item.returnedQuantity + input.quantity,
        );
        final wholeUnits = input.quantity.round();
        if (wholeUnits > 0) {
          await _inventory.recordMovementForSale(
            productId: item.productId,
            quantity: wholeUnits,
            isReturn: true,
            staffId: staffId,
            saleId: refundId,
          );
        }
      }

      await _saleDao.insertPayment(PaymentsCompanion.insert(
        id: _uuid.v4(),
        saleId: refundId,
        method: refundMethod,
        amountKobo: -refundTotal,
      ));

      final updatedItems = await _saleDao.itemsFor(originalSaleId);
      final fullyReturned = updatedItems
          .every((i) => i.returnedQuantity >= i.quantity - _epsilon);
      await _saleDao.updateSaleStatus(
        originalSaleId,
        fullyReturned ? SaleStatus.refunded : SaleStatus.partiallyRefunded,
      );
    });

    return (await _saleDao.findById(refundId))!;
  }
}
