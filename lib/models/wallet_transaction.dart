import 'package:cloud_firestore/cloud_firestore.dart';

class WalletTransaction {
  final String id;
  final String uid;
  final int amount;
  final String type; // earn, spend
  final String description;
  final DateTime timestamp;

  WalletTransaction({
    required this.id,
    required this.uid,
    required this.amount,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      uid: map['uid'] as String,
      amount: map['amount'] as int,
      type: map['type'] as String,
      description: map['description'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'amount': amount,
      'type': type,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  WalletTransaction copyWith({
    String? id,
    String? uid,
    int? amount,
    String? type,
    String? description,
    DateTime? timestamp,
  }) {
    return WalletTransaction(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
    );
  }
} 