import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../chit_details/data/member_ledger_api.dart';
import '../../shared/ledger_pdf_helper.dart'; // Make sure this path matches your folder!

class MemberLedgerScreen extends StatefulWidget {
  final String personKey;
  final String name;
  final String chitGroupId;

  const MemberLedgerScreen({
    super.key,
    required this.personKey,
    required this.name,
    required this.chitGroupId,
  });

  @override
  State<MemberLedgerScreen> createState() => _MemberLedgerScreenState();
}

class _MemberLedgerScreenState extends State<MemberLedgerScreen> {
  late Future<List<dynamic>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ledgerFuture = MemberLedgerApi.getPersonLedgerAllMonths(
      chitGroupId: widget.chitGroupId,
      personKey: widget.personKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF004D40)),
        title: const Text("Account Statement",
            style: TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ledgerFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)));
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(child: Text("No ledger entries found"));
          }

          final rows = snap.data!;
          final int totalBalance = rows.fold(0, (sum, item) => sum + (item["balance"] as int));

          return Column(
            children: [
              _buildSummaryHeader(totalBalance),
              _buildTableHeader(),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) => _buildPassbookRow(rows[index]),
                ),
              ),
              _buildBottomActions(rows, totalBalance),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(int totalBalance) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF1A237E).withValues(alpha: 0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
              Text("Mobile: ${widget.personKey}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("OUTSTANDING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text("₹$totalBalance",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: totalBalance > 0 ? Colors.red : Colors.green)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200))
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text("MONTH", style: _hStyle)),
          Expanded(flex: 3, child: Text("PAYABLE", style: _hStyle)),
          Expanded(flex: 3, child: Text("PAID", style: _hStyle)),
          Expanded(flex: 3, child: Text("BALANCE", style: _hStyle, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildPassbookRow(dynamic r) {
    final int bal = r["balance"] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text("${r["month_no"]}", style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text("₹${r["net_payable"]}")),
          Expanded(flex: 3, child: Text("₹${r["paid_amount"]}", style: const TextStyle(color: Color(0xFF004D40)))),
          Expanded(
              flex: 3,
              child: Text(bal == 0 ? "PAID" : "₹$bal",
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.bold, color: bal == 0 ? Colors.green : Colors.red)
              )
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(List<dynamic> rows, int total) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handlePdf(rows, total),
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text("PDF", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleWhatsApp(rows, total),
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text("WHATSAPP", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleWhatsApp(List<dynamic> rows, int total) {
    String msg = "📊 *ACCOUNT STATEMENT*\n";
    msg += "--------------------------\n";
    msg += "*Member:* ${widget.name}\n";
    msg += "*Mobile:* ${widget.personKey}\n";
    msg += "--------------------------\n\n";

    for (var r in rows) {
      final int bal = r["balance"] ?? 0;
      msg += "📅 *Month ${r['month_no']}*\n";
      msg += "   Due: ₹${r['net_payable']} | Paid: ₹${r['paid_amount']}\n";
      msg += "   Bal: ${bal == 0 ? "✅ PAID" : "₹$bal"}\n\n";
    }

    msg += "--------------------------\n";
    msg += "*TOTAL OUTSTANDING: ₹$total*\n";
    msg += "--------------------------\n";
    msg += "_Generated via ChitPro App_";

    Share.share(msg);
  }

  void _handlePdf(List<dynamic> rows, int total) async {
    await LedgerPdfHelper.generateAndShare(
      name: widget.name,
      mobile: widget.personKey,
      rows: rows,
      totalBalance: total,
    );
  }

  static const _hStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey);
}