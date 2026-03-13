import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

class FamilyService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  Future<String> _getFid() async {
    final fidRaw = await FirebaseInstallations.instance.getId();
    return fidRaw.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  /// 스마트 FCM 토큰 업데이트 (기기 내부의 FID가 존재하는 곳에만 업데이트)
  Future<void> smartUpdateFcmToken() async {
    try {
      final String fid = await _getFid();
      final String? token = await _notificationService.getFcmToken();
      if (token == null) {
        debugPrint('[FCM] Token is null. Skipping smart update.');
        return;
      }

      final now = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{};

      // 1. 전체 데이터 스냅샷 가져오기
      final DataSnapshot snapshot = await _db.get();
      if (!snapshot.exists || snapshot.value is! Map) {
        debugPrint('[FCM] No data found in DB. Skipping smart update.');
        return;
      }

      final Map<dynamic, dynamic> rootMap = Map<dynamic, dynamic>.from(snapshot.value as Map);

      // 2. 각 기기 노드를 순회하며 해당 FID가 있는 'family' 맵 찾기
      for (var entry in rootMap.entries) {
        final String key = entry.key.toString();
        final dynamic value = entry.value;

        // legacy 'family' 루트 노드는 무시
        if (key == 'family') continue;

        if (value is Map) {
          final Map<dynamic, dynamic> deviceData = Map<dynamic, dynamic>.from(value);
          if (deviceData.containsKey('family') && deviceData['family'] is Map) {
            final Map<dynamic, dynamic> deviceFamily = Map<dynamic, dynamic>.from(deviceData['family'] as Map);
            if (deviceFamily.containsKey(fid)) {
              updates['$key/family/$fid/fcmToken'] = token;
              updates['$key/family/$fid/lastUpdated'] = now;
              debugPrint('[FCM] Found FID in device node: $key');
            }
          }
        }
      }

      // 3. 변경사항이 있을 때만 업데이트 (루트 family는 더 이상 건드리지 않음)
      if (updates.isNotEmpty) {
        await _db.update(updates);
        debugPrint('[FCM] Smart update successful for $fid. Updated ${updates.length} fields.');
      } else {
        debugPrint("[FCM] No existing device entries found for $fid.");
      }
    } catch (e) {
      debugPrint('[FCM] Error in smart update: $e');
    }
  }
}