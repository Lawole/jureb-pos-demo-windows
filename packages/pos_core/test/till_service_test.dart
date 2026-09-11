import 'package:drift/native.dart';
import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  late PosDatabase db;
  late TillService till;
  late SaleService sales;
  late InventoryService inventory;
  late String staffId;
  late String productId;

  setUp(() async {
    db = PosDatabase.forTesting(NativeDatabase.memory());
    till = TillService(db);
    sales = SaleService(db);
    inventory = InventoryService(db);
    final auth = AuthService(db.staffDao);
    final staff = await auth.createStaff(
        fullName: 'Cashier One', role: StaffRole.cashier, pin: '1234');
    staffId = staff.id;
    final product = await inventory.createProduct(
      name: 'Coke 50cl',
      costPriceKobo: 20000,
      sellingPriceKobo: 30000,
      unit: ProductUnit.piece,
      staffId: staffId,
      initialQuantity: 100,
    );
    productId = product.id;
  });

  tearDown(() => db.close());

  group('openTill', () {
    test('opens with the given float', () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      expect(session.openingFloatKobo, 500000);
      expect(session.status, TillSessionStatus.open);
    });

    test('rejects a negative float', () {
      expect(
        () => till.openTill(staffId: staffId, openingFloatKobo: -1),
        throwsArgumentError,
      );
    });

    test('rejects opening a second till while one is already open', () async {
      await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      expect(
        () => till.openTill(staffId: staffId, openingFloatKobo: 200000),
        throwsA(isA<TillAlreadyOpenException>()),
      );
    });
  });

  group('closeTill reconciliation', () {
    test('exact count matches expected: zero variance', () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 1000000);
      await sales.completeSale(
        tillSessionId: session.id,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: productId,
              productNameSnapshot: 'Coke 50cl',
              unitPriceKobo: 30000,
              quantity: 2,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 64500)],
      );
      // subtotal 60000, vat 4500, total 64500 — paid exactly in cash.

      final result =
          await till.closeTill(tillSessionId: session.id, countedCashKobo: 1064500);
      expect(result.expectedCashKobo, 1064500);
      expect(result.varianceKobo, 0);
    });

    test('drawer short of expected reports negative variance', () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      await sales.completeSale(
        tillSessionId: session.id,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: productId,
              productNameSnapshot: 'Coke 50cl',
              unitPriceKobo: 30000,
              quantity: 1,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 32250)],
      );
      // expected = 500000 + 32250 = 532250; cashier counts 10000 short.
      final result =
          await till.closeTill(tillSessionId: session.id, countedCashKobo: 522250);
      expect(result.varianceKobo, -10000);
    });

    test('card/transfer payments are excluded from the cash reconciliation',
        () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      await sales.completeSale(
        tillSessionId: session.id,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: productId,
              productNameSnapshot: 'Coke 50cl',
              unitPriceKobo: 30000,
              quantity: 10,
              isVatable: true),
        ],
        payments: const [
          PaymentDraft(method: PaymentMethod.card, amountKobo: 322500),
        ],
      );
      final result =
          await till.closeTill(tillSessionId: session.id, countedCashKobo: 500000);
      expect(result.expectedCashKobo, 500000, reason: 'card sale should not affect cash drawer');
      expect(result.varianceKobo, 0);
    });

    test('a cash refund reduces the expected drawer total', () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      final completed = await sales.completeSale(
        tillSessionId: session.id,
        staffId: staffId,
        lines: [
          SaleLineDraft(
              productId: productId,
              productNameSnapshot: 'Coke 50cl',
              unitPriceKobo: 30000,
              quantity: 2,
              isVatable: true),
        ],
        payments: const [PaymentDraft(method: PaymentMethod.cash, amountKobo: 64500)],
      );
      await sales.refundSale(
        originalSaleId: completed.sale.id,
        tillSessionId: session.id,
        staffId: staffId,
        returnedLines: [
          RefundLineInput(
              saleItemId: (await db.saleDao.itemsFor(completed.sale.id)).single.id,
              quantity: 1),
        ],
        refundMethod: PaymentMethod.cash,
      );
      // expected = 500000 (float) + 64500 (sale) - 32250 (half refunded) = 532250
      final result =
          await till.closeTill(tillSessionId: session.id, countedCashKobo: 532250);
      expect(result.expectedCashKobo, 532250);
      expect(result.varianceKobo, 0);
    });

    test('closing an already-closed session throws', () async {
      final session = await till.openTill(staffId: staffId, openingFloatKobo: 500000);
      await till.closeTill(tillSessionId: session.id, countedCashKobo: 500000);
      expect(
        () => till.closeTill(tillSessionId: session.id, countedCashKobo: 500000),
        throwsStateError,
      );
    });
  });
}
