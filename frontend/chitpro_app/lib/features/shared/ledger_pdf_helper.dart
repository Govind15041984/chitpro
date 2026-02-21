import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LedgerPdfHelper {
  static Future<void> generateAndShare({
    required String name,
    required String mobile,
    required List<dynamic> rows,
    required int totalBalance,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text("ACCOUNT STATEMENT", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 10),

              // Member Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Member: $name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text("Mobile: $mobile"),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Total Outstanding", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("INR $totalBalance", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                headers: ['Month', 'Payable', 'Paid', 'Balance'],
                data: rows.map((r) => [
                  r['month_no'].toString(),
                  "Rs. ${r['net_payable']}",
                  "Rs. ${r['paid_amount']}",
                  "Rs. ${r['balance']}"
                ]).toList(),
              ),

              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Generated via ChitPro App", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    // Save and Share
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Statement_${name.replaceAll(' ', '_')}.pdf");
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Account Statement for $name');
  }
}