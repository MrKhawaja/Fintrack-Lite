import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import 'storage_service.dart';

class ExportService {
  final StorageService _storageService;

  ExportService(this._storageService);

  /// Exports a list of transactions to a CSV string.
  String exportToCsv(List<Transaction> transactions) {
    final header = [
      'ID',
      'Amount',
      'Type',
      'CategoryID',
      'Note',
      'Tags',
      'Date',
      'Currency',
    ];

    final rows = <List<String>>[header];

    for (final t in transactions) {
      final category = _storageService.getCategoryById(t.categoryId);
      rows.add([
        t.id,
        t.amount.toStringAsFixed(2),
        t.type,
        category?.name ?? t.categoryId,
        t.note ?? '',
        t.tags.join(';'),
        DateFormat('yyyy-MM-dd HH:mm').format(t.date),
        t.currencyCode,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports transactions as a PDF report and saves to a temporary file.
  /// Returns the file path.
  Future<String> exportToPdf({
    required List<Transaction> transactions,
    required String title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('yyyy-MM-dd');

    // Build rows
    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _pdfCell('Date', bold: true),
          _pdfCell('Category', bold: true),
          _pdfCell('Amount', bold: true),
          _pdfCell('Type', bold: true),
          _pdfCell('Note', bold: true),
        ],
      ),
    ];

    double totalIncome = 0;
    double totalExpense = 0;

    for (final t in transactions) {
      final category = _storageService.getCategoryById(t.categoryId);
      final catName = category?.name ?? t.categoryId;

      if (t.type == 'income') {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }

      tableRows.add(
        pw.TableRow(
          children: [
            _pdfCell(dateFormat.format(t.date)),
            _pdfCell('${category?.icon ?? ''} $catName'),
            _pdfCell('${t.amount.toStringAsFixed(2)} ${t.currencyCode}'),
            _pdfCell(t.type == 'income' ? 'Income' : 'Expense'),
            _pdfCell(t.note ?? ''),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title, style: pw.TextStyle(fontSize: 20)),
          ),
          if (startDate != null && endDate != null)
            pw.Text(
              'Period: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Income: ${totalIncome.toStringAsFixed(2)}',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.green700,
                ),
              ),
              pw.Text(
                'Total Expense: ${totalExpense.toStringAsFixed(2)}',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.red700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(3),
            },
            children: tableRows,
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/fintrack_export_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Opens the system share sheet for a given file.
  Future<void> shareFile(File file) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles([xFile]);
  }
}
