import 'dart:convert';

import '../../../api/config_api.dart';
import '../../../core/auth_storage.dart';
import 'package:http/http.dart' as http;
import '../models/chit_draft.dart';
import '../models/chit_schedule.dart';

class ChitScheduleApi {
  static Future<Map<String, dynamic>> saveSchedule(
      String chitGroupId,
      ChitSchedule schedule,
      ) async {
    final token = await AuthStorage.instance.getToken();

    final res = await http.post(
      Uri.parse('$kBaseUrl/chit-schedules/$chitGroupId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(schedule.toJson()),
    );

    return jsonDecode(res.body);
  }
}
