import 'package:intl/intl.dart';

class MoneyFormatter {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$ ',
    decimalDigits: 2,
  );

  const MoneyFormatter._();

  static String format(num value) => _currency.format(value);

  static double? parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (value.isEmpty || value == '-' || value == ',' || value == '.') return null;

    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');

    if (lastComma > lastDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      value = value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }

    return double.tryParse(value);
  }
}
