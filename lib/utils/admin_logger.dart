import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLogger {
  static final _supabase = Supabase.instance.client;

  static Future<void> logAction({
    required String action,
    required String targetId,
    required String targetType,
    Map<String, dynamic>? details,
  }) async {
    final session = _supabase.auth.currentSession;

    if (session == null) {
      debugPrint("⚠️ Cannot log action: No active session.");
      return;
    }

    try {
      final url = Uri.parse(
        "${_supabase.supabaseUrl}/functions/v1/log_action",
      );

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${session.accessToken}",
        },
        body: jsonEncode({
          "action": action,
          "target_id": targetId,
          "target_type": targetType,
          "details": details ?? {},
        }),
      );

      debugPrint("📡 log_action status: ${response.statusCode}");
      debugPrint("📡 log_action body: ${response.body}");

      if (response.statusCode == 200) {
        debugPrint("✅ Admin action logged: $action → $targetType:$targetId");
      } else {
        debugPrint("⚠️ Failed to log action [${response.statusCode}] → ${response.body}");
      }
    } catch (e, st) {
      debugPrint("❌ Error invoking log_action: $e");
      debugPrint("$st");
    }
  }
}
