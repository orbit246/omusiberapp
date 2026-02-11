import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';

class ExcelService {
  /// Parses an Excel file from a file path and returns a List of Sheets,
  /// where each sheet is a List of Rows, and each row is a List of dynamic data.
  static Future<Map<String, List<List<dynamic>>>> parseExcelFile(
    String filePath,
  ) async {
    return compute(_parseExcelInBackground, filePath);
  }

  /// Parses Excel bytes and returns a List of Sheets.
  static Future<Map<String, List<List<dynamic>>>> parseExcelBytes(
    List<int> bytes,
  ) async {
    return compute(_parseExcelBytesInBackground, bytes);
  }

  static Map<String, List<List<dynamic>>> _parseExcelInBackground(
    String filePath,
  ) {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);
    Map<String, List<List<dynamic>>> result = {};

    for (var table in excel.tables.keys) {
      if (excel.tables[table]?.maxRows == 0) continue; // Skip empty sheets

      List<List<dynamic>> rows = [];
      for (var row in excel.tables[table]!.rows) {
        rows.add(row.map((cell) => cell?.value).toList());
      }
      if (rows.isNotEmpty) {
        result[table] = rows;
      }
    }
    return result;
  }

  static Map<String, List<List<dynamic>>> _parseExcelBytesInBackground(
    List<int> bytes,
  ) {
    var excel = Excel.decodeBytes(bytes);
    Map<String, List<List<dynamic>>> result = {};

    for (var table in excel.tables.keys) {
      if (excel.tables[table]?.maxRows == 0) continue; // Skip empty sheets

      List<List<dynamic>> rows = [];
      for (var row in excel.tables[table]!.rows) {
        rows.add(row.map((cell) => cell?.value).toList());
      }
      if (rows.isNotEmpty) {
        result[table] = rows;
      }
    }
    return result;
  }
}
