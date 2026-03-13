import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import '../services/notification_service.dart';
import '../services/chat_service.dart';

class Device {
  final String id;
  final String childName;
  final String userRole;

  Device({
    required this.id,
    required this.childName,
    this.userRole = '나',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userRole == other.userRole;

  @override
  int get hashCode => id.hashCode ^ userRole.hashCode;
}

class DeviceController extends ChangeNotifier {
  final _dbRef = FirebaseDatabase.instance.ref();

  List<Device> _registeredDevices = [];
  List<Device> get registeredDevices => _registeredDevices;

  Device? _activeDevice;
  Device? get activeDevice => _activeDevice;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _currentFid;
  String? get currentFid => _currentFid;
  
  final Set<String> _listeningDevices = {};
  final DateTime _appStartTime = DateTime.now();

  final Map<String, List<ChatMessage>> _aiMessages = {};
  final Map<String, List<ChatMessage>> _familyMessages = {};

  List<ChatMessage> getAiMessages(String deviceId) => _aiMessages[deviceId] ?? [];
  List<ChatMessage> getFamilyMessages(String deviceId) => _familyMessages[deviceId] ?? [];

  /// 현재 사용자의 역할을 가져옵니다.
  Future<String?> getCurrentUserRole(String deviceId) async {
    if (_currentFid == null) return null;
    final snapshot = await _dbRef.child('$deviceId/family/$_currentFid/role').get();
    return snapshot.value?.toString();
  }

  DeviceController() {
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. 현재 사용자의 고유 ID(FID) 가져오기
      final fidRaw = await FirebaseInstallations.instance.getId();
      _currentFid = fidRaw.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
      final fid = _currentFid!;

      // 2. 실시간 데이터베이스 리스너 설정
      _dbRef.onValue.listen((DatabaseEvent event) {
        final data = event.snapshot.value;

        if (data == null) {
          if (_registeredDevices.isNotEmpty) {
            _registeredDevices = [];
            _activeDevice = null;
            notifyListeners();
          }
        } else {
          final Map<dynamic, dynamic> map = data as Map<dynamic, dynamic>;
          final List<Device> loaded = [];

          map.forEach((key, value) {
            if (value is Map && value.containsKey('childName')) {
              final deviceData = value as Map<dynamic, dynamic>;
              final dynamic familyData = deviceData['family'];
              
              if (familyData is Map && familyData.containsKey(fid)) {
                final String role = familyData[fid]['role']?.toString() ?? '나';
                loaded.add(Device(
                    id: key.toString(),
                    childName: deviceData['childName']?.toString() ?? '알 수 없음',
                    userRole: role));
              }
            }
          });

          // 리스트 내용이 변경되었을 때만 notifyListeners() 호출
          bool hasChanged = loaded.length != _registeredDevices.length;
          if (!hasChanged) {
            for (int i = 0; i < loaded.length; i++) {
              if (loaded[i] != _registeredDevices[i]) {
                hasChanged = true;
                break;
              }
            }
          }

          if (hasChanged) {
            _registeredDevices = loaded;
            _setupNotificationListeners();

            if (_registeredDevices.isNotEmpty) {
              if (_activeDevice == null) {
                _activeDevice = _registeredDevices.first;
              } else {
                _activeDevice = _registeredDevices.firstWhere(
                  (d) => d.id == _activeDevice!.id,
                  orElse: () => _registeredDevices.first,
                );
              }
            } else {
              _activeDevice = null;
            }
            notifyListeners();
          }
        }
        _isLoading = false;
      }).onError((error) {
        debugPrint("Firebase Realtime DB Error: $error");
        _isLoading = false;
        _registeredDevices = [];
        _activeDevice = null;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("Error fetching FID in DeviceController: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 등록된 기기들의 채팅방을 감시하여 알림을 띄우고 데이터를 관리합니다.
  void _setupNotificationListeners() {
    if (_currentFid == null) return;

    for (final device in _registeredDevices) {
      if (_listeningDevices.contains(device.id)) continue;

      // 1. AI 채팅방 감시 (ai_log로 통일)
      _dbRef.child('${device.id}/ai_log').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final Map<dynamic, dynamic> map = data;
          final List<ChatMessage> messages = [];
          map.forEach((key, value) {
            messages.add(ChatMessage.fromMap(key.toString(), value as Map));
          });
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _aiMessages[device.id] = messages;
          
          // 새 메시지 알림 처리 (가장 최근 메시지 기준)
          if (messages.isNotEmpty) {
            final lastMsg = messages.last;
            try {
              final dt = DateTime.parse(lastMsg.timestamp);
              if (dt.isAfter(_appStartTime)) {
                NotificationService().showNotification(
                  '${device.childName} 다마고치 답변',
                  lastMsg.a ?? '다마고치가 답변을 보냈습니다.',
                  type: 'ai',
                );
              }
            } catch (e) {}
          }
          notifyListeners();
        }
      });

      // 2. 가족 채팅방 감시 (chat)
      _dbRef.child('${device.id}/chat').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data is Map) {
          final Map<dynamic, dynamic> map = data;
          final List<ChatMessage> messages = [];
          map.forEach((key, value) {
            messages.add(ChatMessage.fromMap(key.toString(), value as Map));
          });
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _familyMessages[device.id] = messages;

          // 새 메시지 알림 처리 (가장 최근 메시지 기준)
          if (messages.isNotEmpty) {
            final lastMsg = messages.last;
            if (lastMsg.sender == 'child') {
              try {
                final dt = DateTime.parse(lastMsg.timestamp);
                if (dt.isAfter(_appStartTime)) {
                  NotificationService().showNotification(
                    '${device.childName} 가족 채팅 (아이)',
                    lastMsg.content ?? lastMsg.text,
                    type: 'family',
                  );
                }
              } catch (e) {}
            }
          }
          notifyListeners();
        }
      });

      _listeningDevices.add(device.id);
      debugPrint("[Notification] Started listening for device: ${device.id}");
    }
  }

  void setActiveDevice(Device device) {
    _activeDevice = device;
    notifyListeners();
  }

  Future<void> registerDeviceFcmToken({required String arduinoId}) async {
    try {
      final notificationService = NotificationService();
      final token = await notificationService.getFcmToken();
      if (token == null) return;

      final fid = _currentFid ?? (await FirebaseInstallations.instance.getId()).replaceAll(RegExp(r'[.#$\[\]/]'), '_');

      await _dbRef.child('$arduinoId/family/$fid').update({
        'fcmToken': token,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      debugPrint("FCM token registered for device $arduinoId");
    } catch (e) {
      debugPrint("Error registering FCM token: $e");
    }
  }
}
