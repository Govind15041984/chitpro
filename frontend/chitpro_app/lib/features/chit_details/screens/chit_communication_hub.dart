import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../data/chit_group_api.dart';

class ChitCommunicationHub {
  // 1. BROADCAST LOGIC (FOR GROUPS)
  static Widget buildBroadcastSection({
    required BuildContext context,
    required String chitGroupId,
    required String? whatsappGroupLink,
    required String groupName,
    required String amount,
    required String next_run_date,
    required String current_month,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.campaign, color: Colors.white),
        ),
        title: const Text(
          "Broadcast Auction Alert",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: const Text(
          "Announce date & time to the group",
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.green),
          onTap: () async {
            if (whatsappGroupLink == null || whatsappGroupLink.isEmpty) {
              _showAddLinkDialog(context, chitGroupId);
              return;
            }

            String formattedDate = "TBA";
            try {
              DateTime parsedDate = DateTime.parse(next_run_date);
              formattedDate = DateFormat('dd-MMM-yyyy').format(parsedDate);
            } catch (_) {}

            final msg = "📢 *சீட்டு ஏல அறிவிப்பு*\n\n"
                "$groupName (₹$amount) - $current_month வது சீட்டு "
                "$formattedDate இரவு 8 மணிக்கு நடைபெறும்.";

            final String encodedMsg = Uri.encodeComponent(msg);
            String connector = whatsappGroupLink.contains('?') ? "&" : "?";
            final String finalUrl = "$whatsappGroupLink${connector}text=$encodedMsg";

            final uri = Uri.parse(finalUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              await Clipboard.setData(ClipboardData(text: msg));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("WhatsApp could not be opened. Message copied.")),
              );
            }

          }

      ),
    );
  }

  // 2. INDIVIDUAL REMINDER (FOR LATE PAYERS)
  static Widget buildContactActions(Map<String, dynamic> member, String groupName) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CALL ACTION
        IconButton(
          icon: const Icon(Icons.phone_in_talk, color: Colors.blue, size: 20),
          onPressed: () => launchUrl(Uri.parse("tel:${member['mobile_number']}")),
        ),
        // WHATSAPP ACTION
        IconButton(
          icon: const Icon(Icons.chat, color: Colors.green, size: 20),
          onPressed: () async {
            String msg =
                "வணக்கம் ${member['name']},\n\n"
                "$groupName-ன் இந்த மாத தவணை இன்னும் நிலுவையில் உள்ளது.\n"
                "தயவு செய்து விரைவில் செலுத்தவும்.\n\n"
                "நன்றி 🙏";
            String url =
                "https://wa.me/${member['mobile_number']}?text=${Uri.encodeComponent(msg)}";
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    );
  }

  // 3. 🔥 NEW: Open WhatsApp Group directly (for compact header icon)
  static Future<void> openWhatsAppGroup({
    required BuildContext context,
    required String? whatsappGroupLink,
  }) async {
    if (whatsappGroupLink == null || whatsappGroupLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WhatsApp group link not available")),
      );
      return;
    }

    final String link = whatsappGroupLink.startsWith("http")
        ? whatsappGroupLink
        : "https://$whatsappGroupLink";

    final Uri uri = Uri.parse(link);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open WhatsApp. Is it installed?")),
      );
    }
  }


  // 4. 🔥 NEW: Open Broadcast Bottom Sheet (for compact header icon)
  static void openBroadcastDialog({
    required BuildContext context,
    required String chitGroupId,
    required String groupName,
    required String amount,
    required String? whatsappGroupLink,
    required String next_run_date,
    required String current_month,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return buildBroadcastSection(
          context: context,
          chitGroupId: chitGroupId,
          whatsappGroupLink: whatsappGroupLink,
          groupName: groupName,
          amount: amount,
          next_run_date: next_run_date,
          current_month: current_month
        );
      },
    );
  }

  // 5. 🏆 WINNER BROADCAST (POST-AUCTION) - WhatsApp Native Share
  static Future<void> sendWinnerBroadcast({
    required BuildContext context,
    required String groupName,
    required int chitAmount,
    required int monthNo,
    required String chitType,
    required int monthlyDue,
    required int discountAmount,
    required int payoutAmount,
    required List<Map<String, dynamic>> rounds,
  }) async {
    if (rounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No winners to broadcast")),
      );
      return;
    }

    final buffer = StringBuffer();

    buffer.writeln("*$groupName (₹$chitAmount) – $monthNo வது சீட்டு முடிவு*");
    buffer.writeln("");

    buffer.writeln("🏆 வெற்றி பெற்றவர்கள்:\n");
    for (final r in rounds) {
      final name = r["winning_member_name"] ?? "Member";
      final no = r["winning_member_no"] ?? "-";

      buffer.writeln("$name (வரிசை எண்: $no) – ரூ $payoutAmount");
      buffer.writeln("");
    }

    buffer.writeln("💰 இந்த மாதம் செலுத்த வேண்டிய பணம்: ரூ $monthlyDue");
    buffer.writeln("");

    if (chitType.toUpperCase() == "AUCTION" && discountAmount > 0) {
      buffer.writeln("💸 தள்ளுபடி: ரூ $discountAmount");
    }

    buffer.writeln("");
    //buffer.writeln("📌 இன்று முடிந்தவரை செலுத்தவும்.");
    buffer.writeln("– ChitPro");

    final msg = buffer.toString();
    await Share.share(msg);
  }

  static Future<void> sendUpcomingAuctionBroadcastDirect({
    required BuildContext context,
    required String chitGroupId,
    required String? whatsappGroupLink,   // kept for future use
    required String groupName,
    required String amount,
    required String next_run_date,
    required String current_month,
  }) async {
    String formattedDate = "TBA";
    try {
      DateTime parsedDate = DateTime.parse(next_run_date);
      formattedDate = DateFormat('dd-MMM-yyyy').format(parsedDate);
    } catch (_) {}

    final msg = "📢 *சீட்டு ஏல அறிவிப்பு*\n\n"
        "$groupName (₹$amount) - $current_month வது சீட்டு "
        "$formattedDate இரவு 8 மணிக்கு நடைபெறும்.";

    await Share.share(msg);   // ✅ Auto-fills message in WhatsApp share
  }



  static void _showAddLinkDialog(BuildContext context, String chitGroupId) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set WhatsApp Group Link"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Paste the WhatsApp 'Invite via Link' here.",
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "https://chat.whatsapp.com/...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await ChitGroupApi.saveGroupLink(chitGroupId, controller.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link saved successfully! Refreshing...")),
                );
              }
            },
            child: const Text("Save Link"),
          ),
        ],
      ),
    );
  }
}
