import 'package:flutter/material.dart';
import '../views/main_screen.dart';
import '../views/settings_screen.dart';
import '../views/device_registration_screen.dart';

class AppRoutes {
  static const String main = '/';
  static const String settings = '/settings';
  static const String registerDevice = '/register_device';

  static Map<String, WidgetBuilder> get routes => {
        main: (context) => const MainScreen(),
        settings: (context) => const SettingsScreen(),
        registerDevice: (context) => const DeviceRegistrationScreen(),
      };
}

