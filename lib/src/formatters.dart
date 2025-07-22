String normalizeStatus(String value) {
  final cleaned = value.trim().toLowerCase();
  if (cleaned.isEmpty) {
    throw ArgumentError('Status cannot be empty.');
  }
  return cleaned.replaceAll(RegExp(r'\s+'), '_');
}

String formatCurrency(num value) {
  return '\$${value.toStringAsFixed(2)}';
}

String formatDate(DateTime date) {
  return date.toIso8601String().split('T').first;
}

String renderTable(List<String> headers, List<List<String>> rows) {
  final widths = List<int>.generate(headers.length, (index) {
    final headerWidth = headers[index].length;
    final rowWidth = rows
        .map((row) => row[index].length)
        .fold<int>(0, (prev, len) => len > prev ? len : prev);
    return headerWidth > rowWidth ? headerWidth : rowWidth;
  });

  String renderRow(List<String> cells) {
    final padded = <String>[];
    for (var i = 0; i < cells.length; i++) {
      padded.add(cells[i].padRight(widths[i]));
    }
    return padded.join(' | ');
  }

  final buffer = StringBuffer();
  buffer.writeln(renderRow(headers));
  buffer.writeln(widths.map((width) => '-' * width).join('-+-'));
  for (final row in rows) {
    buffer.writeln(renderRow(row));
  }
  return buffer.toString().trimRight();
}
