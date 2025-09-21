import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLogger {
  static final _supabase = Supabase.instance.client;

  static Future<void> logAction({
    required String action,
    required String targetId,
    required String targetType,
    Map<String, dynamic>? details,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint("⚠️ No logged-in admin to log action.");
      return;
    }

    try {
      final res = await _supabase.functions.invoke(
        'log_action',
        body: {
          'admin_id': user.id,
          'action': action,
          'target_id': targetId,
          'target_type': targetType,
          'details': details,
        },
      );

      if (res.status == 200) {
        debugPrint("✅ Log saved: ${res.data}");
      } else {
        debugPrint("⚠️ Log failed [${res.status}]: ${res.data}");
      }
    } catch (e) {
      debugPrint("❌ Error logging action: $e");
    }
  }
}
