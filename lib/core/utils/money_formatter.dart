import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MoneyFormatter {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$ ',
    decimalDigits: 2,
  );

  const MoneyFormatter._();

  static String format(num value) => _currency.format(value);

  static String formatForInput(num value) => format(value);

  static double? parse(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (value.isEmpty || value == '-' || value == ',' || value == '.') return null;

    final negative = value.startsWith('-') || value.endsWith('-');
    value = value.replaceAll('-', '');

    final lastComma = value.lastIndexOf(',');
    final lastDot = value.lastIndexOf('.');

    if (lastComma > lastDot) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    } else if (lastDot > lastComma) {
      value = value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }

    final parsed = double.tryParse(value);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }
}

class MoneyInputFormatter extends TextInputFormatter {
  final bool allowNegative;

  const MoneyInputFormatter({this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final isNegative = allowNegative && newValue.text.contains('-');
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      final text = isNegative ? '-' : '';
      return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }

    final cents = int.parse(digits);
    final value = (cents / 100) * (isNegative ? -1 : 1);
    final formatted = MoneyFormatter.formatForInput(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
