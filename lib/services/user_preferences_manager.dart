import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:svga_previewer/models/display_mode.dart';

/// 用户偏好设置管理器
/// 负责保存和加载用户的界面设置，包括显示模式、边框显示、背景颜色等
class UserPreferencesManager {
  static const String _modeKey = 'user_mode';
  static const String _showBorderKey = 'show_border';
  static const String _backgroundColorKey = 'background_color';

  /// 加载用户偏好设置
  /// 
  /// 返回包含所有用户设置的 PreferencesData 对象
  static Future<PreferencesData> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载显示模式
    DisplayMode mode = DisplayMode.showAll;
    final modeString = prefs.getString(_modeKey);
    if (modeString != null) {
      mode = DisplayMode.values.firstWhere(
        (e) => e.name == modeString,
        orElse: () => DisplayMode.showAll,
      );
    }

    // 加载边框显示设置，默认为true
    final showBorder = prefs.getBool(_showBorderKey) ?? true;

    // 加载背景颜色设置，默认为透明
    Color backgroundColor = Colors.transparent;
    final colorValue = prefs.getInt(_backgroundColorKey);
    if (colorValue != null) {
      backgroundColor = Color(colorValue);
    }

    return PreferencesData(
      mode: mode,
      showBorder: showBorder,
      backgroundColor: backgroundColor,
    );
  }

  /// 保存显示模式
  /// 
  /// [mode] 要保存的显示模式
  static Future<void> saveMode(DisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  /// 保存边框显示设置
  /// 
  /// [showBorder] 是否显示边框
  static Future<void> saveShowBorder(bool showBorder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showBorderKey, showBorder);
  }

  /// 保存背景颜色设置
  /// 
  /// [color] 要保存的背景颜色
  static Future<void> saveBackgroundColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backgroundColorKey, color.value);
  }
}

/// 用户偏好设置数据类
/// 封装所有用户偏好设置
class PreferencesData {
  /// 显示模式
  final DisplayMode mode;
  
  /// 是否显示边框
  final bool showBorder;
  
  /// 背景颜色
  final Color backgroundColor;

  PreferencesData({
    required this.mode,
    required this.showBorder,
    required this.backgroundColor,
  });
}

