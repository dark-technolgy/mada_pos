import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExcelSheetData {
  const ExcelSheetData({
    required this.sheetName,
    required this.headers,
    required this.rows,
  });

  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
}

class ExcelExportService {
  ExcelExportService._();

  static Future<String?> exportSheet({
    required String suggestedFileName,
    required ExcelSheetData sheetData,
  }) async {
    final excel = Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';
    if (sheetData.sheetName != defaultName) {
      excel.rename(defaultName, sheetData.sheetName);
    }
    final sheet = excel[sheetData.sheetName];

    for (var col = 0; col < sheetData.headers.length; col++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = TextCellValue(sheetData.headers[col]);
    }

    for (var row = 0; row < sheetData.rows.length; row++) {
      final values = sheetData.rows[row];
      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1),
            )
            .value = TextCellValue(values[col]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return null;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Excel',
      fileName: suggestedFileName.endsWith('.xlsx')
          ? suggestedFileName
          : '$suggestedFileName.xlsx',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (path == null) return null;

    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return file.path;
  }
}
