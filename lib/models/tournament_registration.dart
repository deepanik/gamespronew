import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentRegistration {
  final String id;
  final String userId;
  final String tournamentId;
  final String username;
  final DateTime registeredAt;

  TournamentRegistration({
    required this.id,
    required this.userId,
    required this.tournamentId,
    required this.username,
    required this.registeredAt,
  });

  factory TournamentRegistration.fromMap(Map<String, dynamic> map, String id) {
    return TournamentRegistration(
      id: id,
      userId: map['userId'] as String,
      tournamentId: map['tournamentId'] as String,
      username: map['username'] as String,
      registeredAt: (map['registeredAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tournamentId': tournamentId,
      'username': username,
      'registeredAt': Timestamp.fromDate(registeredAt),
    };
  }

  TournamentRegistration copyWith({
    String? id,
    String? userId,
    String? tournamentId,
    String? username,
    DateTime? registeredAt,
  }) {
    return TournamentRegistration(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tournamentId: tournamentId ?? this.tournamentId,
      username: username ?? this.username,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
} 