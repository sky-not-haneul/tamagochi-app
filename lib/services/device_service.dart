import 'package:firebase_database/firebase_database.dart';

class DeviceService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> registerDevice(String arduinoId, Map<String, dynamic> deviceData) async {
    await _db.child(arduinoId).update(deviceData).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('서버 연결 시간이 초과되었습니다. 네트워크 상태나 Firebase 설정을 확인해주세요.');
      },
    );
  }

  Future<Map?> fetchFamilyRole(String deviceId) async {
    final snapshot = await _db.child('$deviceId/family').get();
    if (snapshot.value is Map) {
      return snapshot.value as Map;
    }
    return null;
  }
}
