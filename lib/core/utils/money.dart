/// Rupee formatting and parsing. Amounts are always whole paise (int).
library;

/// "₹1,23,456" (Indian digit grouping). Paise are shown only when non-zero:
/// "₹250.50". Negative amounts get a leading minus.
String formatRupees(int paise) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rest = abs % 100;
  final grouped = _indianGrouping(rupees.toString());
  final decimals = rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹$grouped$decimals';
}

/// 1234567 -> "12,34,567": last three digits, then groups of two.
String _indianGrouping(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) parts.insert(0, head);
  return '${parts.join(',')},$last3';
}

/// Parses what someone types into the amount box: "250", "250.5",
/// "1,200", "₹ 99.99". Returns paise, or null if it isn't a positive amount
/// with at most two decimals.
int? parseRupees(String input) {
  final cleaned = input.replaceAll(RegExp(r'[₹,\s]'), '');
  final match = RegExp(r'^(\d{1,9})(?:\.(\d{0,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final rupees = int.parse(match.group(1)!);
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  final paise = rupees * 100 + int.parse(decimals);
  return paise > 0 ? paise : null;
}

/// Plain number for editing/CSV: 25050 -> "250.50", 25000 -> "250".
String rupeesPlain(int paise) {
  final rupees = paise ~/ 100;
  final rest = paise % 100;
  return rest == 0 ? '$rupees' : '$rupees.${rest.toString().padLeft(2, '0')}';
}
