import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String id;
  final String uid;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.uid,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map, String id) {
    return SupportTicket(
      id: id,
      uid: map['uid'] as String,
      subject: map['subject'] as String,
      message: map['message'] as String,
      status: map['status'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'subject': subject,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SupportTicket copyWith({
    String? id,
    String? uid,
    String? subject,
    String? message,
    String? status,
    DateTime? createdAt,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 