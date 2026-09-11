import 'package:meta/meta.dart';

/// Nigerian standard VAT rate (7.5%), applied per line item where the
/// product is flagged vatable. Kept as a named constant (not user-editable)
/// because it's a statutory rate, not a store setting.
const double kNigerianVatRate = 0.075;

@immutable
class CartLineInput {
  const CartLineInput({
    required this.unitPriceKobo,
    required this.quantity,
    required this.isVatable,
    this.lineDiscountKobo = 0,
  });

  final int unitPriceKobo;
  final double quantity;
  final bool isVatable;

  /// Flat discount applied to this line only, before VAT and before the
  /// whole-cart discount is allocated.
  final int lineDiscountKobo;
}

@immutable
class CartLineResult {
  const CartLineResult({
    required this.grossKobo,
    required this.discountKobo,
    required this.subtotalKobo,
    required this.vatKobo,
    required this.totalKobo,
  });

  final int grossKobo;
  final int discountKobo;
  final int subtotalKobo;
  final int vatKobo;
  final int totalKobo;
}

@immutable
class CartTotals {
  const CartTotals({
    required this.lines,
    required this.subtotalKobo,
    required this.vatKobo,
    required this.cartDiscountKobo,
    required this.totalKobo,
  });

  final List<CartLineResult> lines;

  /// Sum of line subtotals, after per-line discounts, before VAT and before
  /// the whole-cart discount.
  final int subtotalKobo;
  final int vatKobo;
  final int cartDiscountKobo;
  final int totalKobo;
}

/// All sale-total, VAT, discount, and split-payment math lives here as pure
/// functions with no DB/UI dependency, so it can be unit-tested exhaustively
/// and reused unchanged by a future mobile client. This is the one part of
/// the app that must never be wrong — a wrong total is a wrong receipt.
class SalesCalculator {
  const SalesCalculator._();

  /// Computes per-line and cart totals. [cartDiscountKobo] is a flat
  /// whole-cart discount applied proportionally across lines (by each
  /// line's share of the post-line-discount subtotal) before VAT, matching
  /// how Nigerian retailers usually want VAT charged only on the net price
  /// actually paid.
  static CartTotals computeCart(
    List<CartLineInput> lines, {
    int cartDiscountKobo = 0,
  }) {
    if (cartDiscountKobo < 0) {
      throw ArgumentError.value(cartDiscountKobo, 'cartDiscountKobo',
          'must not be negative');
    }

    final preCartDiscountLines = lines.map((line) {
      final gross = roundToKobo(line.unitPriceKobo * line.quantity);
      final discount = line.lineDiscountKobo.clamp(0, gross);
      return (gross: gross, discount: discount, net: gross - discount);
    }).toList();

    final preCartDiscountTotal =
        preCartDiscountLines.fold<int>(0, (sum, l) => sum + l.net);

    final effectiveCartDiscount =
        cartDiscountKobo.clamp(0, preCartDiscountTotal);

    final results = <CartLineResult>[];
    var allocatedCartDiscount = 0;
    var subtotalSum = 0;
    var vatSum = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final pre = preCartDiscountLines[i];
      final isLast = i == lines.length - 1;

      // Proportional allocation of the cart discount by this line's share
      // of the pre-cart-discount net total; the last line absorbs any
      // rounding remainder so allocated amounts always sum exactly.
      final share = isLast
          ? effectiveCartDiscount - allocatedCartDiscount
          : preCartDiscountTotal == 0
              ? 0
              : roundToKobo(
                  effectiveCartDiscount * pre.net / preCartDiscountTotal);
      allocatedCartDiscount += share;

      final lineSubtotal = pre.net - share;
      final lineVat =
          line.isVatable ? roundToKobo(lineSubtotal * kNigerianVatRate) : 0;
      final lineTotal = lineSubtotal + lineVat;
      final totalLineDiscount = pre.discount + share;

      results.add(CartLineResult(
        grossKobo: pre.gross,
        discountKobo: totalLineDiscount,
        subtotalKobo: lineSubtotal,
        vatKobo: lineVat,
        totalKobo: lineTotal,
      ));

      subtotalSum += lineSubtotal;
      vatSum += lineVat;
    }

    return CartTotals(
      lines: results,
      subtotalKobo: subtotalSum,
      vatKobo: vatSum,
      cartDiscountKobo: effectiveCartDiscount,
      totalKobo: subtotalSum + vatSum,
    );
  }

  /// Validates that a set of split-payment tenders exactly covers
  /// [totalKobo], returning any change due (for cash overpayment).
  /// Throws [ArgumentError] if payments fall short.
  static int changeDueKobo({
    required int totalKobo,
    required List<int> paymentsKobo,
  }) {
    final paid = paymentsKobo.fold<int>(0, (sum, p) => sum + p);
    if (paid < totalKobo) {
      throw ArgumentError(
          'Payments (₦${paid / 100}) do not cover the total (₦${totalKobo / 100})');
    }
    return paid - totalKobo;
  }

  static int roundToKobo(num value) => value.round();
}
