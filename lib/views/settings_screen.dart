import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/settings_controller.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';
import '../controllers/device_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(NotificationService());
    _controller.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSettingsChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {}); // Rebuild when notification status changes
  }

  @override
  Widget build(BuildContext context) {
    final deviceController = Provider.of<DeviceController>(context);
    final devices = deviceController.registeredDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('기기 및 알림 설정'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.registerDevice);
        },
        icon: const Icon(Icons.add),
        label: const Text('새 기기 등록'),
      ),
      body: deviceController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? const Center(
                  child: Text('등록된 기기가 없습니다.\n우측 하단 버튼을 눌러 기기를 등록해주세요.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                      bottom: 80, top: 16, left: 16, right: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _buildDeviceCard(device);
                  },
                ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.watch),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.childName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "기기 번호: ${device.id}",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              '알림 설정',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('모든 알림 받기'),
              value: _controller.isAllEnabled,
              onChanged: (val) => _controller.toggleAll(val),
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                children: [
                  _buildSmallSwitch(
                    title: 'AI 챗 알림',
                    value: _controller.isAiEnabled,
                    onChanged: (val) => _controller.toggleAi(val),
                  ),
                  _buildSmallSwitch(
                    title: '가족 챗 알림',
                    value: _controller.isFamilyEnabled,
                    onChanged: (val) => _controller.toggleFamily(val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
