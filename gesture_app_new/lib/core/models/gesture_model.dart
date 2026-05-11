import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

class GestureModel {
  final int? id; // Server ID (nullable if offline-created)
  final String uuid; // Local Unique ID (Source of Truth)
  final String name;
  final String? triggerText;
  final List<Offset> points;
  final String actionType;
  final String actionValue;
  final String? contactId;
  final String? photoUri;
  final String? localPhotoPath;
  final bool isSynced;
  final bool isFavorite;
  final bool isTextEnabled;
  final bool isShapeEnabled;
  final DateTime createdAt;

  GestureModel({
    this.id,
    required this.uuid,
    required this.name,
    this.triggerText,
    required this.points,
    required this.actionType,
    required this.actionValue,
    this.contactId,
    this.photoUri,
    this.localPhotoPath,
    this.isSynced = false,
    this.isFavorite = false,
    this.isTextEnabled = true,
    this.isShapeEnabled = true,
    required this.createdAt,
  });

  factory GestureModel.create({
    required String name,
    String? triggerText,
    required List<Offset> points,
    required String actionType,
    required String actionValue,
    String? contactId,
    String? photoUri,
    String? localPhotoPath,
    bool isFavorite = false,
    bool isTextEnabled = true,
    bool isShapeEnabled = true,
  }) {
    return GestureModel(
      id: null,
      uuid: generateUuid(),
      name: name,
      triggerText: triggerText,
      points: points,
      actionType: actionType,
      actionValue: actionValue,
      contactId: contactId,
      photoUri: photoUri,
      localPhotoPath: localPhotoPath,
      isSynced: false, // Needs sync
      isFavorite: isFavorite,
      isTextEnabled: isTextEnabled,
      isShapeEnabled: isShapeEnabled,
      createdAt: DateTime.now(),
    );
  }

  factory GestureModel.fromJson(Map<String, dynamic> json) {
    dynamic raw =
        json['points_json'] ??
        json['points']; // DB uses 'points', API 'points_json'

    // Handle points parsing (String from DB or List from API)
    List<dynamic> decodedPoints = [];
    if (raw is String) {
      try {
        decodedPoints = jsonDecode(raw);
      } catch (e) {
        debugPrint("❌ [GestureModel] JSON decode error: $e");
        decodedPoints = [];
      }
    } else {
      decodedPoints = (raw as List<dynamic>? ?? []);
    }

    final points = decodedPoints.map((p) {
      if (p is Map) {
        return Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble());
      }
      return Offset.zero;
    }).toList();

    return GestureModel(
      id: json['id'], // May be null or int
      uuid: json['uuid'] ?? json['local_id'] ?? generateUuid(),
      name: json['name'] ?? '',
      triggerText: json['trigger_text'],
      points: points,
      actionType: json['action_type'] ?? '',
      actionValue: json['action_value'] ?? '',
      contactId: json['contact_id'],
      photoUri: json['photo_uri'],
      localPhotoPath: json['local_photo_path'],
      isSynced: json['needs_sync'] != null
          ? json['needs_sync'] == 0
          : (json['is_synced'] == 1 || json['is_synced'] == true),
      isFavorite: json['is_favorite'] == 1 || json['is_favorite'] == true,
      isTextEnabled: json['is_text_enabled'] == null
          ? true
          : (json['is_text_enabled'] == 1 || json['is_text_enabled'] == true),
      isShapeEnabled: json['is_shape_enabled'] == null
          ? true
          : (json['is_shape_enabled'] == 1 || json['is_shape_enabled'] == true),
      createdAt:
          DateTime.tryParse(
            json['created_at'].toString().replaceAll(" ", "T"),
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final pointsList = points.map((p) => {'x': p.dx, 'y': p.dy}).toList();
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'trigger_text': triggerText,
      // API expects 'points_json' (and 'points' for legacy compatibility)
      'points': pointsList,
      'points_json': pointsList,
      'action_type': actionType,
      'action_value': actionValue,
      'contact_id': contactId,
      'photo_uri': photoUri,
      'local_photo_path': localPhotoPath,
      'is_synced': isSynced,
      'is_favorite': isFavorite,
      'is_text_enabled': isTextEnabled,
      'is_shape_enabled': isShapeEnabled,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper for DB Insert
  Map<String, dynamic> toDbMap() {
    final pointsJson = jsonEncode(
      points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    );
    return {
      'id': id, // INTEGER NULL
      'uuid': uuid, // TEXT PRIMARY KEY
      'name': name,
      'trigger_text': triggerText,
      'points': pointsJson,
      'action_type': actionType,
      'action_value': actionValue,
      'contact_id': contactId,
      'photo_uri': photoUri,
      'local_photo_path': localPhotoPath,
      'is_favorite': isFavorite ? 1 : 0,
      'is_text_enabled': isTextEnabled ? 1 : 0,
      'is_shape_enabled': isShapeEnabled ? 1 : 0,
      'needs_sync': isSynced ? 0 : 1,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  GestureModel copyWith({
    int? id,
    String? uuid,
    String? name,
    String? triggerText,
    List<Offset>? points,
    String? actionType,
    String? actionValue,
    String? contactId,
    String? photoUri,
    String? localPhotoPath,
    bool? isSynced,
    bool? isFavorite,
    bool? isTextEnabled,
    bool? isShapeEnabled,
    DateTime? createdAt,
  }) {
    return GestureModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      triggerText: triggerText ?? this.triggerText,
      points: points ?? this.points,
      actionType: actionType ?? this.actionType,
      actionValue: actionValue ?? this.actionValue,
      contactId: contactId ?? this.contactId,
      photoUri: photoUri ?? this.photoUri,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      isSynced: isSynced ?? this.isSynced,
      isFavorite: isFavorite ?? this.isFavorite,
      isTextEnabled: isTextEnabled ?? this.isTextEnabled,
      isShapeEnabled: isShapeEnabled ?? this.isShapeEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String generateUuid() {
    final random = Random();
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = random.nextInt(100000);
    return "local_${ms}_$rand";
  }
}
