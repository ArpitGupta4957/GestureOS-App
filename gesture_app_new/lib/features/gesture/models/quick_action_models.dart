import 'dart:typed_data';

class QuickShortcut {
  final String id;
  final String label;
  final String actionType; // 'FLASHLIGHT', 'WIFI', 'APP', 'CALL'
  final String actionValue; 

  QuickShortcut({
    required this.id,
    required this.label,
    required this.actionType, 
    required this.actionValue,
  });

  factory QuickShortcut.fromJson(Map<String, dynamic> json) {
    return QuickShortcut(
      id: json['id'],
      label: json['label'],
      actionType: json['actionType'],
      actionValue: json['actionValue'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'actionType': actionType,
      'actionValue': actionValue,
    };
  }
}

class FrequentContact {
  final String name;
  final String number;
  final int timesContacted;

  FrequentContact({required this.name, required this.number, required this.timesContacted});
}

class AppUsage {
  final String packageName;
  final String appName;
  final int usageTime;
  final Uint8List? iconData;

  AppUsage({
    required this.packageName,
    required this.appName,
    required this.usageTime,
    this.iconData,
  });
}
