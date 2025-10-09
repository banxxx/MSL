import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends ChangeNotifier {
  bool _showPlayerCount = true;
  bool _showMotd = true;
  bool _hapticFeedback = true;
  bool _blurIpAddress = false;
  bool _autoRefresh = false;
  int _refreshInterval = 30;
  String _themeMode = 'system';

  bool get showPlayerCount => _showPlayerCount;
  bool get showMotd => _showMotd;
  bool get hapticFeedback => _hapticFeedback;
  bool get blurIpAddress => _blurIpAddress;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  String get themeMode => _themeMode;

  SettingsNotifier() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _showPlayerCount = prefs.getBool('show_player_count') ?? true;
    _showMotd = prefs.getBool('show_motd') ?? true;
    _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
    _blurIpAddress = prefs.getBool('blur_ip_address') ?? false;
    _autoRefresh = prefs.getBool('auto_refresh') ?? false;
    _refreshInterval = prefs.getInt('refresh_interval') ?? 30;
    _themeMode = prefs.getString('theme_mode') ?? 'system';
    notifyListeners();
  }

  // 更新设置并保存
  Future<void> updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();

    switch (key) {
      case 'show_player_count':
        _showPlayerCount = value as bool;
        await prefs.setBool(key, value);
        break;
      case 'show_motd':
        _showMotd = value as bool;
        await prefs.setBool(key, value);
        break;
      case 'haptic_feedback':
        _hapticFeedback = value as bool;
        await prefs.setBool(key, value);
        break;
      case 'blur_ip_address':
        _blurIpAddress = value as bool;
        await prefs.setBool(key, value);
        break;
      case 'auto_refresh':
        _autoRefresh = value as bool;
        await prefs.setBool(key, value);
        break;
      case 'refresh_interval':
        _refreshInterval = value as int;
        await prefs.setInt(key, value);
        break;
      case 'theme_mode':
        _themeMode = value as String;
        await prefs.setString(key, value);
        break;
    }
    notifyListeners();
  }
}