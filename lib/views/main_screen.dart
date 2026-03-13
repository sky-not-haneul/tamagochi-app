import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../routes/app_routes.dart';
import 'tabs/ai_chat_tab.dart';
import 'tabs/family_chat_tab.dart';
import '../controllers/device_controller.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _tabs = const [
    AiChatTab(),
    FamilyChatTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final deviceController = Provider.of<DeviceController>(context);
    final registeredDevices = deviceController.registeredDevices;
    final activeDevice = deviceController.activeDevice;

    return Scaffold(
      appBar: AppBar(
        title: deviceController.isLoading
            ? const SizedBox(
                height: 20, 
                width: 20, 
                child: CircularProgressIndicator(strokeWidth: 2))
            : registeredDevices.isEmpty
                ? const Text('등록된 기기 없음')
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Device>(
                      value: activeDevice,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                      onChanged: (Device? newDevice) {
                        if (newDevice != null) {
                          deviceController.setActiveDevice(newDevice);
                        }
                      },
                      items: registeredDevices.map<DropdownMenuItem<Device>>((Device device) {
                        return DropdownMenuItem<Device>(
                          value: device,
                          child: Text(device.childName),
                        );
                      }).toList(),
                    ),
                  ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          )
        ],
      ),
      body: deviceController.isLoading
          ? const Center(child: CircularProgressIndicator())
          : registeredDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.watch_off_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        '등록된 기기가 없습니다.\n기기를 등록해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.registerDevice);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('기기 등록하기'),
                      ),
                    ],
                  ),
                )
              : IndexedStack(
                  index: _currentIndex,
                  children: _tabs,
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AI 챗',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.family_restroom),
            label: '가족 챗',
          ),
        ],
      ),
    );
  }
}
