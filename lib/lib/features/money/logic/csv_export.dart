import 'dart:convert';

import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/expense.dart';

/// Builds a CSV of [expenses] (oldest first) that opens cleanly in Excel,
/// Google Sheets and LibreOffice:
/// - UTF-8 with a byte-order mark, so ₹ and non-English notes show correctly
/// - CRLF line endings
/// - fields with commas, quotes or line breaks are quoted
/// - notes starting with = + - @ are prefixed with ' so a spreadsheet never
///   treats them as formulas
List<int> buildExpensesCsv(Iterable<Expense> expenses) {
  final rows = <List<String>>[
    ['Date', 'Category', 'Amount (INR)', 'Note'],
    for (final e
        in expenses.toList()..sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
        }))
      [toIsoDate(e.date), e.category.label, rupeesPlain(e.amount), e.note],
  ];
  final text = rows.map((r) => r.map(_field).join(',')).join('\r\n');
  return [0xEF, 0xBB, 0xBF, ...utf8.encode('$text\r\n')];
}

String _field(String value) {
  var v = value;
  if (v.isNotEmpty && '=+-@'.contains(v[0])) v = "'$v";
  if (v.contains(RegExp('[",\r\n]'))) {
    v = '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// "petal-expenses-2026-11-14.csv"
String csvFileName(DateTime today) => 'petal-expenses-${toIsoDate(today)}.csv';
