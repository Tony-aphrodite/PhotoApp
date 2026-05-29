import 'package:intl/intl.dart';

/// Formats prices as Mexican Pesos (MXN).
/// Uses '$' symbol with 'MXN' suffix to disambiguate from USD.
class CurrencyFormatter {
  static final NumberFormat _format = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _formatNoDecimals = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 0,
  );

  /// Format with two decimals, e.g. "$1,234.56 MXN"
  static String format(num amount) => '${_format.format(amount)} MXN';

  /// Format without decimals, e.g. "$1,234 MXN"
  static String formatNoDecimals(num amount) =>
      '${_formatNoDecimals.format(amount)} MXN';

  /// Compact form for tight UI spaces, e.g. "$1,234.56"
  static String compact(num amount) => _format.format(amount);
}
