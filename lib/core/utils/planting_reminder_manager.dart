import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class PlantingCrop {
  final String id;
  final String cropType;
  final DateTime plantedDate;

  const PlantingCrop({
    required this.id,
    required this.cropType,
    required this.plantedDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'cropType': cropType,
        'plantedDate': plantedDate.millisecondsSinceEpoch,
      };

  factory PlantingCrop.fromJson(Map<String, dynamic> json) => PlantingCrop(
        id: json['id'] as String,
        cropType: json['cropType'] as String,
        plantedDate:
            DateTime.fromMillisecondsSinceEpoch(json['plantedDate'] as int),
      );
}

class PlantingReminderManager {
  static bool isAndroidOverride = Platform.isAndroid;
  static const _prefsKey = 'my_planting_crops';

  static Future<List<PlantingCrop>> loadCrops(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((m) => PlantingCrop.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCrops(
      SharedPreferences prefs, List<PlantingCrop> crops) async {
    final raw = jsonEncode(crops.map((c) => c.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  static Future<void> scheduleReminders(PlantingCrop crop) async {
    if (!isAndroidOverride) return;

    final now = DateTime.now();
    for (final entry in _milestones) {
      final days = entry['days'] as int;
      final targetDate = crop.plantedDate.add(Duration(days: days));
      if (targetDate.isAfter(now)) {
        final delay = targetDate.difference(now);
        await Workmanager().registerOneOffTask(
          'planting_${crop.id}_${days}d',
          'planting_reminder',
          existingWorkPolicy: ExistingWorkPolicy.keep,
          initialDelay: delay,
          inputData: {'crop_type': crop.cropType, 'days': days},
        );
      }
    }
  }

  static const _milestones = [
    {'days': 7},
    {'days': 30},
    {'days': 60},
  ];
}
