import 'dart:io';
import 'package:excel/excel.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelService {
  /// Reads first column or searches for "Phone" column
  Future<List<String>> importNumbers(File file) async {
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    List<String> numbers = [];

    for (var table in excel.tables.keys) {
      if (excel.tables[table] == null) continue;

      for (var row in excel.tables[table]!.rows) {
        if (row.isEmpty) continue;

        // Simple strategy: take first column that looks like a number
        // In a real app, user might pick column.
        for (var cell in row) {
          if (cell?.value == null) continue;
          String val = cell!.value.toString();

          // Basic clean
          String clean = val.replaceAll(RegExp(r"[^0-9+]"), "");
          if (clean.length >= 3) {
            numbers.add(clean);
            break; // Found a number in this row, move to next
          }
        }
      }
    }
    return numbers;
  }

  /// Exports session data to Excel
  Future<void> exportSession(
    String sessionName,
    List<BulkNumberModel> numbers,
  ) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sheet1'];

    // Header
    sheet.appendRow([
      TextCellValue('Phone Number'),
      TextCellValue('Status'),
      TextCellValue('Notes'),
      TextCellValue('Last Called At'),
    ]);

    // Set Column Widths (A=0, B=1, C=2, D=3)
    sheet.setColumnWidth(0, 20.0); // Phone
    sheet.setColumnWidth(1, 15.0); // Status
    sheet.setColumnWidth(2, 50.0); // Notes (Wide)
    sheet.setColumnWidth(3, 25.0); // Date

    // Data
    int rowIndex = 2; // Start after Header (Row 1)
    for (var number in numbers) {
      sheet.appendRow([
        TextCellValue(number.phoneNumber),
        TextCellValue(number.status.name.toUpperCase()),
        TextCellValue(number.notes), // Non-nullable
        TextCellValue(number.lastCalledAt?.toIso8601String() ?? '-'),
      ]);

      // Style Notes Cell (Column C / Index 2)
      var noteCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex - 1),
      );
      noteCell.cellStyle = CellStyle(
        textWrapping: TextWrapping.WrapText,
        verticalAlign: VerticalAlign.Top,
      );

      rowIndex++;
    }

    // Save
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        "Dialer_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx";
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(fileBytes);

    // Share
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Bulk Dialer Report: $sessionName');
  }
}
