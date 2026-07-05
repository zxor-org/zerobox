import 'dart:io';

import 'package:flutter/material.dart';

Future<Color?> loadDesktopAccentColor() async {
  if (!Platform.isLinux) {
    return null;
  }

  return await _loadGnomeAccentColor() ??
      await _loadKdeAccentColor('kreadconfig6') ??
      await _loadKdeAccentColor('kreadconfig5');
}

Future<Color?> _loadGnomeAccentColor() async {
  final result = await _run('gsettings', [
    'get',
    'org.gnome.desktop.interface',
    'accent-color',
  ]);
  if (result == null) {
    return null;
  }
  final value = result.replaceAll("'", '').replaceAll('"', '').trim();
  return _gnomeAccentColors[value];
}

Future<Color?> _loadKdeAccentColor(String executable) async {
  final result = await _run(executable, [
    '--file',
    'kdeglobals',
    '--group',
    'General',
    '--key',
    'AccentColor',
  ]);
  if (result == null) {
    return null;
  }
  return _parseColor(result.trim());
}

Future<String?> _run(String executable, List<String> arguments) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
    ).timeout(const Duration(milliseconds: 800));
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString().trim();
    return output.isEmpty ? null : output;
  } catch (_) {
    return null;
  }
}

Color? _parseColor(String value) {
  final hex = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(value);
  if (hex != null) {
    return Color(int.parse('0xFF${hex.group(1)}'));
  }

  final rgb = RegExp(
    r'^(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})$',
  ).firstMatch(value);
  if (rgb == null) {
    return null;
  }
  final r = int.parse(rgb.group(1)!).clamp(0, 255);
  final g = int.parse(rgb.group(2)!).clamp(0, 255);
  final b = int.parse(rgb.group(3)!).clamp(0, 255);
  return Color.fromARGB(255, r, g, b);
}

const _gnomeAccentColors = <String, Color>{
  'blue': Color(0xFF3584E4),
  'teal': Color(0xFF2190A4),
  'green': Color(0xFF3A944A),
  'yellow': Color(0xFFC88800),
  'orange': Color(0xFFED5B00),
  'red': Color(0xFFE62D42),
  'pink': Color(0xFFD56199),
  'purple': Color(0xFF9141AC),
  'slate': Color(0xFF6F8396),
};
