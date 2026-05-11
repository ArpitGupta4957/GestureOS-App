enum CallStatus { pending, called, skipped }

class BulkNumberModel {
  final int? id;
  final int sessionId;
  final String phoneNumber;
  final String? name; // Optional, from Excel
  final String notes;
  final CallStatus status;
  final String? contactId;
  final String? photoUri;
  final String? localPhotoPath;
  final DateTime? lastCalledAt;

  BulkNumberModel({
    this.id,
    required this.sessionId,
    required this.phoneNumber,
    this.name,
    this.notes = '',
    this.status = CallStatus.pending,
    this.contactId,
    this.photoUri,
    this.localPhotoPath,
    this.lastCalledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'phone_number': phoneNumber,
      'name': name,
      'notes': notes,
      'status': status.name,
      'contact_id': contactId,
      'photo_uri': photoUri,
      'local_photo_path': localPhotoPath,
      'last_called_at': lastCalledAt?.toIso8601String(),
    };
  }

  factory BulkNumberModel.fromMap(Map<String, dynamic> map) {
    return BulkNumberModel(
      id: map['id'],
      sessionId: map['session_id'],
      phoneNumber: map['phone_number'],
      name: map['name'],
      notes: map['notes'] ?? '',
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.pending,
      ),
      contactId: map['contact_id'],
      photoUri: map['photo_uri'],
      localPhotoPath: map['local_photo_path'],
      lastCalledAt: map['last_called_at'] != null
          ? DateTime.parse(map['last_called_at'])
          : null,
    );
  }

  BulkNumberModel copyWith({
    int? id,
    int? sessionId,
    String? phoneNumber,
    String? name,
    String? notes,
    CallStatus? status,
    String? contactId,
    String? photoUri,
    String? localPhotoPath,
    DateTime? lastCalledAt,
  }) {
    return BulkNumberModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      contactId: contactId ?? this.contactId,
      photoUri: photoUri ?? this.photoUri,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
      lastCalledAt: lastCalledAt ?? this.lastCalledAt,
    );
  }
}

class DialerSessionModel {
  final int? id;
  final String name; // e.g., "Session 2024-01-16 10:00"
  final String createdAt; // Store as String to avoid parsing issues
  final bool isArchived;

  DialerSessionModel({
    this.id,
    required this.name,
    required this.createdAt,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory DialerSessionModel.fromMap(Map<String, dynamic> map) {
    // Handle created_at safely - it might be DateTime, String, or null
    String createdAtStr;
    final rawCreatedAt = map['created_at'];
    if (rawCreatedAt == null) {
      createdAtStr = DateTime.now().toIso8601String();
    } else if (rawCreatedAt is DateTime) {
      createdAtStr = rawCreatedAt.toIso8601String();
    } else {
      createdAtStr = rawCreatedAt.toString();
    }

    return DialerSessionModel(
      id: map['id'],
      name: map['name'] ?? 'Unnamed Session',
      createdAt: createdAtStr,
      isArchived: map['is_archived'] != null
          ? (map['is_archived'] == 1 || map['is_archived'] == true)
          : false,
    );
  }
}
