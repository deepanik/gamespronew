import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String title;
  final String game;
  final String imageUrl;
  final int entryFee;
  final int prizePool;
  final int totalSlots;
  final int filledSlots;
  final String type; // Solo, Duo, Squad
  final String map;
  final String status; // upcoming, ongoing, completed
  final DateTime startTime;
  final DateTime endTime;
  final String createdBy;
  final String? roomId;
  final String? roomPassword;
  final String rules;
  final String? sponsor;
  final String? winnerId;
  final DateTime createdAt;
  final String description;
  final List<String> winners;
  final List<double> prizeDistribution;

  Tournament({
    required this.id,
    required this.title,
    required this.game,
    required this.imageUrl,
    required this.entryFee,
    required this.prizePool,
    required this.totalSlots,
    required this.filledSlots,
    required this.type,
    required this.map,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.createdBy,
    this.roomId,
    this.roomPassword,
    required this.rules,
    this.sponsor,
    this.winnerId,
    required this.createdAt,
    required this.description,
    this.winners = const [],
    this.prizeDistribution = const [],
  });

  factory Tournament.fromMap(Map<String, dynamic> map, String id) {
    return Tournament(
      id: id,
      title: map['title'] as String,
      game: map['game'] as String,
      imageUrl: map['imageUrl'] as String,
      entryFee: map['entryFee'] as int,
      prizePool: map['prizePool'] as int,
      totalSlots: map['totalSlots'] as int,
      filledSlots: map['filledSlots'] as int,
      type: map['type'] as String,
      map: map['map'] as String,
      status: map['status'] as String,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      createdBy: map['createdBy'] as String,
      roomId: map['roomId'] as String?,
      roomPassword: map['roomPassword'] as String?,
      rules: map['rules'] as String,
      sponsor: map['sponsor'] as String?,
      winnerId: map['winnerId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      description: map['description'] as String,
      winners: List<String>.from(map['winners'] ?? []),
      prizeDistribution: List<double>.from(map['prizeDistribution'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'game': game,
      'imageUrl': imageUrl,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'totalSlots': totalSlots,
      'filledSlots': filledSlots,
      'type': type,
      'map': map,
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'createdBy': createdBy,
      'roomId': roomId,
      'roomPassword': roomPassword,
      'rules': rules,
      'sponsor': sponsor,
      'winnerId': winnerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
      'winners': winners,
      'prizeDistribution': prizeDistribution,
    };
  }

  Tournament copyWith({
    String? id,
    String? title,
    String? game,
    String? imageUrl,
    int? entryFee,
    int? prizePool,
    int? totalSlots,
    int? filledSlots,
    String? type,
    String? map,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    String? createdBy,
    String? roomId,
    String? roomPassword,
    String? rules,
    String? sponsor,
    String? winnerId,
    DateTime? createdAt,
    String? description,
    List<String>? winners,
    List<double>? prizeDistribution,
  }) {
    return Tournament(
      id: id ?? this.id,
      title: title ?? this.title,
      game: game ?? this.game,
      imageUrl: imageUrl ?? this.imageUrl,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      totalSlots: totalSlots ?? this.totalSlots,
      filledSlots: filledSlots ?? this.filledSlots,
      type: type ?? this.type,
      map: map ?? this.map,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdBy: createdBy ?? this.createdBy,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      rules: rules ?? this.rules,
      sponsor: sponsor ?? this.sponsor,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      winners: winners ?? this.winners,
      prizeDistribution: prizeDistribution ?? this.prizeDistribution,
    );
  }

  int get availableSlots => totalSlots - filledSlots;
} 