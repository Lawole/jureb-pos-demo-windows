import 'package:drift/native.dart';
import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  late PosDatabase db;
  late SaleService sales;
  late InventoryService inventory;
  late TillService till;
  late String staffId;
  late String tillSessionId;

  Future<Product> makeProduct({
    String name = 'Rice 5kg',
    int costPriceKobo = 300000,
    int sellingPriceKobo = 450000,
    bool isVatable = true,
    int initialQuantity = 50,
  }) =>
      inventory.createProduct(
        name: name,
        costPriceKobo: costPriceKobo,
        sellingPriceKobo: sellingPriceKobo,
        unit: ProductUnit.piece,
        staffId: staffId,
        isVatable: isVatable,
        initialQuantity: initialQuantity,
      );

  setUp(() async {
    db = PosDatabase.forTesting(NativeDatabase.memory());
    sales = SaleService(db);
    inventory = InventoryService(db);
    till = TillService(db);
    final auth = AuthService(db.staffDao);
    final staff = await auth.createStaff(
        fullName: 'Cashier', role: StaffRole.cashier, pin: '1234');
    staffId = staff.id;
    final session = await till.openTill(staffId: staffId, openingFloatKobo: 1000000);
    tillSessionId = session.id;
  });

  tearDown(() => db.close());

  group('completeSale', () {
    test('generates a sequential, unique receipt number', () async {
      final product = await makeProduct();
      final line = SaleLineDraft(
          productId: product.id,
          productNameSnapshot: product.name,
          unitPriceKobo: product.sellingPriceKobo,
          quantity: 1,
          isVatable: true);

      final first = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [line],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 483750)],
      );
      final second = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [line],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 483750)],
      );

      expect(first.sale.receiptNumber, isNot(equals(second.sale.receiptNumber)));
      expect(first.sale.receiptNumber, startsWith('R'));
    });

    test('deducts stock for each line sold', () async {
      final product = await makeProduct(initialQuantity: 20);
      await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 3,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 1451250)],
      );
      final updated = await db.productDao.findById(product.id);
      expect(updated!.quantityOnHand, 17);
    });

    test('rejects a sale that would oversell a product, and applies nothing',
        () async {
      final product = await makeProduct(initialQuantity: 2);
      expect(
        () => sales.completeSale(
          tillSessionId: tillSessionId,
          staffId: staffId,
          lines: [
            SaleLineDraft(
                productId: product.id,
                productNameSnapshot: product.name,
                unitPriceKobo: product.sellingPriceKobo,
                quantity: 5,
                isVatable: true),
          ],
          payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 2418750)],
        ),
        throwsArgumentError,
      );
      final unchanged = await db.productDao.findById(product.id);
      expect(unchanged!.quantityOnHand, 2,
          reason: 'an oversold, rejected sale must not touch stock');
    });

    test('rejects underpayment and persists nothing', () async {
      final product = await makeProduct();
      expect(
        () => sales.completeSale(
          tillSessionId: tillSessionId,
          staffId: staffId,
          lines: [
            SaleLineDraft(
                productId: product.id,
                productNameSnapshot: product.name,
                unitPriceKobo: product.sellingPriceKobo,
                quantity: 1,
                isVatable: true),
          ],
          payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 100000)],
        ),
        throwsArgumentError,
      );
      final unchanged = await db.productDao.findById(product.id);
      expect(unchanged!.quantityOnHand, 50);
    });

    test('split payment across cash and card is accepted', () async {
      final product = await makeProduct();
      final result = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 1,
              isVatable: true),
        ],
        payments: const [
          PaymentDraft(method: PaymentMethod.cash, amountKobo: 200000),
          PaymentDraft(method: PaymentMethod.card, amountKobo: 283750),
        ],
      );
      expect(result.changeDueKobo, 0);
      final payments = await db.saleDao.paymentsFor(result.sale.id);
      expect(payments, hasLength(2));
    });

    test('cash overpayment returns correct change', () async {
      final product = await makeProduct();
      final result = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 1,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 500000)],
      );
      expect(result.changeDueKobo, 500000 - 483750);
    });

    test('VAT-exempt product has zero VAT on the sale', () async {
      final product = await makeProduct(isVatable: false, sellingPriceKobo: 100000);
      final result = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: 100000,
              quantity: 1,
              isVatable: false),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 100000)],
      );
      expect(result.sale.vatKobo, 0);
      expect(result.sale.totalKobo, 100000);
    });

    test('rejects an empty cart', () async {
      expect(
        () => sales.completeSale(
          tillSessionId: tillSessionId,
          staffId: staffId,
          lines: const [],
          payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 0)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('hold / resume', () {
    test('holding a sale does not deduct stock', () async {
      final product = await makeProduct(initialQuantity: 10);
      await sales.holdSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 4,
              isVatable: true),
        ],
      );
      final unchanged = await db.productDao.findById(product.id);
      expect(unchanged!.quantityOnHand, 10);
    });

    test('held sale appears in watchHeldSales', () async {
      final product = await makeProduct();
      final held = await sales.holdSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 1,
              isVatable: true),
        ],
      );
      final heldList = await db.saleDao.watchHeldSales().first;
      expect(heldList.map((s) => s.id), contains(held.id));
    });

    test('completing a held sale deducts stock and marks it completed',
        () async {
      final product = await makeProduct(initialQuantity: 10);
      final held = await sales.holdSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 4,
              isVatable: true),
        ],
      );
      final result = await sales.completeHeldSale(
        saleId: held.id,
        staffId: staffId,
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 1935000)],
      );
      expect(result.sale.status, SaleStatus.completed);
      final updatedProduct = await db.productDao.findById(product.id);
      expect(updatedProduct!.quantityOnHand, 6);
    });

    test('cannot complete a sale that is not held', () async {
      final product = await makeProduct();
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 1,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 483750)],
      );
      expect(
        () => sales.completeHeldSale(
          saleId: completed.sale.id,
          staffId: staffId,
          payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 483750)],
        ),
        throwsStateError,
      );
    });

    test('voiding a held sale marks it voided and never touches stock',
        () async {
      final product = await makeProduct(initialQuantity: 10);
      final held = await sales.holdSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 4,
              isVatable: true),
        ],
      );
      await sales.voidHeldSale(held.id);
      final voided = await db.saleDao.findById(held.id);
      expect(voided!.status, SaleStatus.voided);
      final unchanged = await db.productDao.findById(product.id);
      expect(unchanged!.quantityOnHand, 10);
    });
  });

  group('refundSale', () {
    test('full refund restocks and marks the original sale refunded',
        () async {
      final product = await makeProduct(initialQuantity: 10);
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 2,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 967500)],
      );
      final item = (await db.saleDao.itemsFor(completed.sale.id)).single;

      final refund = await sales.refundSale(
        originalSaleId: completed.sale.id,
        tillSessionId: tillSessionId,
        staffId: staffId,
        returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 2)],
        refundMethod: PaymentMethod.cash,
      );

      expect(refund.totalKobo, 967500);
      final refundPayments = await db.saleDao.paymentsFor(refund.id);
      expect(refundPayments.single.amountKobo, -967500);

      final originalAfter = await db.saleDao.findById(completed.sale.id);
      expect(originalAfter!.status, SaleStatus.refunded);

      final productAfter = await db.productDao.findById(product.id);
      expect(productAfter!.quantityOnHand, 10, reason: 'both units restocked');
    });

    test('partial refund marks the original sale partiallyRefunded', () async {
      final product = await makeProduct(initialQuantity: 10);
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 4,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 1935000)],
      );
      final item = (await db.saleDao.itemsFor(completed.sale.id)).single;

      final refund = await sales.refundSale(
        originalSaleId: completed.sale.id,
        tillSessionId: tillSessionId,
        staffId: staffId,
        returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 1)],
        refundMethod: PaymentMethod.cash,
      );

      final originalAfter = await db.saleDao.findById(completed.sale.id);
      expect(originalAfter!.status, SaleStatus.partiallyRefunded);

      final productAfter = await db.productDao.findById(product.id);
      expect(productAfter!.quantityOnHand, 7, reason: '6 sold + 1 back = 7');

      // Refund proportion: 1/4 of a 4-unit line's subtotal+VAT.
      final expectedRefund = (1935000 / 4).round();
      expect(refund.totalKobo, expectedRefund);
      final refundPayments = await db.saleDao.paymentsFor(refund.id);
      expect(refundPayments.single.amountKobo, -expectedRefund);
    });

    test('cannot refund more than what remains on a line', () async {
      final product = await makeProduct(initialQuantity: 10);
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 2,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 967500)],
      );
      final item = (await db.saleDao.itemsFor(completed.sale.id)).single;

      expect(
        () => sales.refundSale(
          originalSaleId: completed.sale.id,
          tillSessionId: tillSessionId,
          staffId: staffId,
          returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 3)],
          refundMethod: PaymentMethod.cash,
        ),
        throwsArgumentError,
      );
    });

    test('cannot refund twice past the remaining quantity across two partial refunds',
        () async {
      final product = await makeProduct(initialQuantity: 10);
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 3,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 1451250)],
      );
      final item = (await db.saleDao.itemsFor(completed.sale.id)).single;

      await sales.refundSale(
        originalSaleId: completed.sale.id,
        tillSessionId: tillSessionId,
        staffId: staffId,
        returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 2)],
        refundMethod: PaymentMethod.cash,
      );

      expect(
        () => sales.refundSale(
          originalSaleId: completed.sale.id,
          tillSessionId: tillSessionId,
          staffId: staffId,
          returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 2)],
          refundMethod: PaymentMethod.cash,
        ),
        throwsArgumentError,
        reason: 'only 1 unit remains refundable after the first refund',
      );
    });

    test('cannot refund a held or already-fully-refunded sale', () async {
      final product = await makeProduct(initialQuantity: 10);
      final completed = await sales.completeSale(
        tillSessionId: tillSessionId,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: product.id,
              productNameSnapshot: product.name,
              unitPriceKobo: product.sellingPriceKobo,
              quantity: 1,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 483750)],
      );
      final item = (await db.saleDao.itemsFor(completed.sale.id)).single;
      await sales.refundSale(
        originalSaleId: completed.sale.id,
        tillSessionId: tillSessionId,
        staffId: staffId,
        returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 1)],
        refundMethod: PaymentMethod.cash,
      );

      expect(
        () => sales.refundSale(
          originalSaleId: completed.sale.id,
          tillSessionId: tillSessionId,
          staffId: staffId,
          returnedLines: [RefundLineInput(saleItemId: item.id, quantity: 1)],
          refundMethod: PaymentMethod.cash,
        ),
        throwsStateError,
      );
    });
  });
}
