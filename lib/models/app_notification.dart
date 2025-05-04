import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? targetUid;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.targetUid,
    required this.timestamp,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      id: id,
      title: map['title'] as String,
      body: map['body'] as String,
      targetUid: map['targetUid'] as String?,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'targetUid': targetUid,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? targetUid,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      targetUid: targetUid ?? this.targetUid,
      timestamp: timestamp ?? this.timestamp,
    );
  }
} 