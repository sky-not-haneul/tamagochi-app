import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class SettingsController with ChangeNotifier {
  final NotificationService _notificationService;

  bool _isAllEnabled = true;
  bool _isAiEnabled = true;
  bool _isFamilyEnabled = true;
  
  bool _isLoading = true;

  SettingsController(this._notificationService) {
    _loadSettings();
  }

  bool get isAllEnabled => _isAllEnabled;
  bool get isAiEnabled => _isAiEnabled;
  bool get isFamilyEnabled => _isFamilyEnabled;
  bool get isLoading => _isLoading;

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    final status = await _notificationService.fetchNotificationStatus();
    _isAllEnabled = status['all'] ?? true;
    _isAiEnabled = status['ai'] ?? true;
    _isFamilyEnabled = status['family'] ?? true;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _updateService() async {
    try {
      await _notificationService.updateNotificationStatus({
        'all': _isAllEnabled,
        'ai': _isAiEnabled,
        'family': _isFamilyEnabled,
      });
    } catch (e) {
      debugPrint("Failed to update notification status: $e");
    }
  }

  void toggleAll(bool value) {
    _isAllEnabled = value;
    _isAiEnabled = value;
    _isFamilyEnabled = value;
    notifyListeners();
    _updateService();
  }

  void toggleAi(bool value) {
    _isAiEnabled = value;
    // Update 'All' toggle based on sub-toggles
    _isAllEnabled = _isAiEnabled && _isFamilyEnabled;
    notifyListeners();
    _updateService();
  }

  void toggleFamily(bool value) {
    _isFamilyEnabled = value;
    // Update 'All' toggle based on sub-toggles
    _isAllEnabled = _isAiEnabled && _isFamilyEnabled;
    notifyListeners();
    _updateService();
  }
}

