import 'package:pos_core/pos_core.dart';
import 'package:test/test.dart';

void main() {
  group('SalesCalculator.computeCart', () {
    test('single vatable line, no discounts', () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
            unitPriceKobo: 100000, quantity: 2, isVatable: true),
      ]);

      expect(result.subtotalKobo, 200000);
      expect(result.vatKobo, 15000); // 7.5% of 200000
      expect(result.totalKobo, 215000);
      expect(result.lines.single.totalKobo, 215000);
    });

    test('non-vatable line has zero VAT', () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
            unitPriceKobo: 50000, quantity: 1, isVatable: false),
      ]);

      expect(result.vatKobo, 0);
      expect(result.totalKobo, 50000);
    });

    test('mixed vatable and non-vatable lines', () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
            unitPriceKobo: 100000, quantity: 1, isVatable: true),
        const CartLineInput(
            unitPriceKobo: 50000, quantity: 1, isVatable: false),
      ]);

      expect(result.subtotalKobo, 150000);
      expect(result.vatKobo, 7500); // only on the vatable line
      expect(result.totalKobo, 157500);
    });

    test('per-line discount reduces VAT base for that line', () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
          unitPriceKobo: 100000,
          quantity: 1,
          isVatable: true,
          lineDiscountKobo: 20000,
        ),
      ]);

      expect(result.lines.single.subtotalKobo, 80000);
      expect(result.lines.single.vatKobo, 6000); // 7.5% of 80000
      expect(result.lines.single.totalKobo, 86000);
    });

    test('line discount is clamped to the line gross (never negative)', () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
          unitPriceKobo: 10000,
          quantity: 1,
          isVatable: true,
          lineDiscountKobo: 999999,
        ),
      ]);

      expect(result.lines.single.subtotalKobo, 0);
      expect(result.lines.single.vatKobo, 0);
    });

    test('whole-cart discount is allocated proportionally and sums exactly',
        () {
      final result = SalesCalculator.computeCart(
        [
          const CartLineInput(
              unitPriceKobo: 300000, quantity: 1, isVatable: true), // 3000
          const CartLineInput(
              unitPriceKobo: 100000, quantity: 1, isVatable: true), // 1000
        ],
        cartDiscountKobo: 40000, // 400 naira off a 4000 naira cart
      );

      // Line 1 gets 75% share = 30000, line 2 gets 25% share = 10000.
      expect(result.lines[0].discountKobo, 30000);
      expect(result.lines[1].discountKobo, 10000);
      // Discount allocation must sum exactly to the cart discount, no matter
      // rounding — this is what "last line absorbs remainder" guarantees.
      final totalAllocated =
          result.lines.fold<int>(0, (sum, l) => sum + l.discountKobo);
      expect(totalAllocated, 40000);
      expect(result.cartDiscountKobo, 40000);
      expect(result.subtotalKobo, 360000);
    });

    test('cart discount larger than cart total is clamped, never negative',
        () {
      final result = SalesCalculator.computeCart(
        [
          const CartLineInput(
              unitPriceKobo: 10000, quantity: 1, isVatable: true),
        ],
        cartDiscountKobo: 999999,
      );

      expect(result.subtotalKobo, 0);
      expect(result.vatKobo, 0);
      expect(result.cartDiscountKobo, 10000);
    });

    test('negative cart discount is rejected', () {
      expect(
        () => SalesCalculator.computeCart(
          [
            const CartLineInput(
                unitPriceKobo: 10000, quantity: 1, isVatable: true),
          ],
          cartDiscountKobo: -1,
        ),
        throwsArgumentError,
      );
    });

    test('fractional quantity (weighed goods) rounds to the nearest kobo',
        () {
      final result = SalesCalculator.computeCart([
        const CartLineInput(
            unitPriceKobo: 65000, quantity: 1.5, isVatable: true), // ₦650/kg
      ]);

      expect(result.lines.single.grossKobo, 97500); // 650 * 1.5 = 975.00
      expect(result.lines.single.vatKobo, 7313); // round(975 * 0.075 * 100)
    });

    test('empty cart totals to zero', () {
      final result = SalesCalculator.computeCart(const []);
      expect(result.subtotalKobo, 0);
      expect(result.vatKobo, 0);
      expect(result.totalKobo, 0);
      expect(result.lines, isEmpty);
    });
  });

  group('SalesCalculator.changeDueKobo (split payments)', () {
    test('exact single payment yields zero change', () {
      final change =
          SalesCalculator.changeDueKobo(totalKobo: 100000, paymentsKobo: [100000]);
      expect(change, 0);
    });

    test('split cash + transfer covering the total exactly', () {
      final change = SalesCalculator.changeDueKobo(
        totalKobo: 150000,
        paymentsKobo: [100000, 50000],
      );
      expect(change, 0);
    });

    test('cash overpayment returns correct change', () {
      final change = SalesCalculator.changeDueKobo(
        totalKobo: 97500,
        paymentsKobo: [100000],
      );
      expect(change, 2500);
    });

    test('split payments overpaying yields correct change', () {
      final change = SalesCalculator.changeDueKobo(
        totalKobo: 90000,
        paymentsKobo: [50000, 50000],
      );
      expect(change, 10000);
    });

    test('underpayment throws', () {
      expect(
        () => SalesCalculator.changeDueKobo(
            totalKobo: 100000, paymentsKobo: [50000]),
        throwsArgumentError,
      );
    });

    test('no payments against a nonzero total throws', () {
      expect(
        () => SalesCalculator.changeDueKobo(totalKobo: 100, paymentsKobo: []),
        throwsArgumentError,
      );
    });
  });
}
