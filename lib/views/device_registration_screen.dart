import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/notification_service.dart';
import '../services/device_service.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:provider/provider.dart';
import '../controllers/device_controller.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _childNameController = TextEditingController();

  String _selectedRole = '엄마'; // Default role
  bool _isLoading = false;

  final List<String> _roles = ['엄마', '아빠', '이모', '삼촌', '할머니', '할아버지', '기타'];

  Future<String> _getUniqueDeviceId() async {
    try {
      // Firebase Installation ID 가져오기
      String id = await FirebaseInstallations.instance.getId();

      // FID는 보통 특수문자가 포함되지 않은 안전한 문자열을 반환하지만,
      // 만약의 상황을 대비해 Firebase 키 규칙에 어긋나는 문자가 있는지 체크/치환합니다.
      return id.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    } catch (e) {
      debugPrint("FID 가져오기 실패: $e");
      // 실패 시 폴백(Fallback)으로 기존 방식을 쓰거나 고유값을 생성합니다.
      return 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final arduinoId = _deviceIdController.text.trim();
        final childName = _childNameController.text.trim();
        final role = _selectedRole;
        final phoneId = await _getUniqueDeviceId();
        // FCM 토큰 가져오기 (실제 토큰 사용)
        final notificationService = NotificationService();
        final fcmToken = await notificationService.getFcmToken() ?? 'unknown';

        final now = DateTime.now();
        final formattedDate = now.toIso8601String();

        // 1. 기기 내부 정보 업데이트 (기존 데이터 보존을 위해 arduinoId 하위만 구성)
        final deviceUpdate = {
          'childName': childName,
          'family/$phoneId': {
            'role': role,
            'fcmToken': fcmToken,
            'lastUpdated': formattedDate,
          }
        };

        // 2. 서비스로 등록
        final deviceService = DeviceService();
        
        // 기기 존재 여부 확인 (최초 등록 시에만 createdAt 추가)
        final existingDevice = await FirebaseDatabase.instance.ref().child(arduinoId).get();
        if (!existingDevice.exists) {
          deviceUpdate['createdAt'] = formattedDate;
        }

        await deviceService.registerDevice(arduinoId, deviceUpdate);

        // FCM 토큰 등록 (DeviceController 활용)
        if (mounted) {
          final deviceController =
              Provider.of<DeviceController>(context, listen: false);
          await deviceController.registerDeviceFcmToken(
            arduinoId: arduinoId,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('기기가 성공적으로 등록되었습니다.')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('등록 중 오류가 발생했습니다: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 기기 등록'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '다마고치 스마트워치 등록',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(
                  labelText: '아두이노 기기 번호',
                  hintText: '예: NRF-12345678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.memory),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '기기 번호를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _childNameController,
                decoration: const InputDecoration(
                  labelText: '아이 이름',
                  hintText: '예: 홍길동',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.child_care),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '아이 이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: '가족 관계',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                items: _roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    if (newValue != null) {
                      _selectedRole = newValue;
                    }
                  });
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _submitForm,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('등록 완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
