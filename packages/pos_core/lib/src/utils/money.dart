/// All monetary values in this app are represented as integer kobo
/// (1 naira = 100 kobo) to avoid floating-point rounding errors in
/// cash/VAT/discount math. Never store or compare money as `double`.
extension type const Kobo(int value) implements int {
  factory Kobo.fromNaira(num naira) => Kobo((naira * 100).round());

  double get naira => value / 100;
}

/// Rounds to the nearest whole kobo. Used after percentage math
/// (VAT, discounts) which can otherwise produce fractional kobo.
int roundKobo(num value) => value.round();

class NairaFormatter {
  const NairaFormatter._();

  /// Till-facing format: no decimals, thousands separators, ₦ prefix.
  /// e.g. 1234567 kobo -> "₦12,346" (rounded to the nearest naira).
  static String forTill(int kobo) {
    final naira = (kobo / 100).round();
    return '₦${_withThousands(naira)}';
  }

  /// Full precision format for on-screen receipts/reports: shows kobo as
  /// 2 decimals. e.g. 1234567 kobo -> "₦12,345.67"
  static String forReceipt(int kobo) {
    final naira = kobo ~/ 100;
    final remainder = (kobo % 100).abs().toString().padLeft(2, '0');
    return '₦${_withThousands(naira)}.$remainder';
  }

  /// Same precision as [forReceipt] but ASCII-only ("NGN" instead of ₦),
  /// for PDF/thermal printer output: the base PDF fonts have no ₦ glyph,
  /// and most thermal printers can't render it either even with a driver —
  /// this is the format Nigerian receipts commonly use in print.
  static String forPrint(int kobo) {
    final naira = kobo ~/ 100;
    final remainder = (kobo % 100).abs().toString().padLeft(2, '0');
    return 'NGN ${_withThousands(naira)}.$remainder';
  }

  static String _withThousands(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return negative ? '-${buffer.toString()}' : buffer.toString();
  }
}
