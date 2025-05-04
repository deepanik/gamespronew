import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String title;
  final String description;
  final String game;
  final String type;
  final String map;
  final int entryFee;
  final int prizePool;
  final int totalSlots;
  final int filledSlots;
  final String rules;
  final DateTime startTime;
  final String status;
  final String? bannerUrl;
  final String? roomCode;
  final String? roomPassword;
  final String? youtubeLink;
  final String? sponsor;
  final String imageUrl;
  final int prizeDistribution;
  final String createdBy;
  final String? winnerId;
  final DateTime createdAt;
  final List<String> winners;

  Tournament({
    required this.id,
    required this.title,
    required this.description,
    required this.game,
    required this.type,
    required this.map,
    required this.entryFee,
    required this.prizePool,
    required this.totalSlots,
    required this.filledSlots,
    required this.rules,
    required this.startTime,
    required this.status,
    this.bannerUrl,
    this.roomCode,
    this.roomPassword,
    this.youtubeLink,
    this.sponsor,
    required this.imageUrl,
    required this.prizeDistribution,
    required this.createdBy,
    this.winnerId,
    required this.createdAt,
    this.winners = const [],
  });

  factory Tournament.fromMap(Map<String, dynamic> map, String id) {
    return Tournament(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      game: map['game'] ?? '',
      type: map['type'] ?? '',
      map: map['map'] ?? '',
      entryFee: map['entryFee'] ?? 0,
      prizePool: map['prizePool'] ?? 0,
      totalSlots: map['totalSlots'] ?? 0,
      filledSlots: map['filledSlots'] ?? 0,
      rules: map['rules'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'upcoming',
      bannerUrl: map['bannerUrl'],
      roomCode: map['roomCode'],
      roomPassword: map['roomPassword'],
      youtubeLink: map['youtubeLink'],
      sponsor: map['sponsor'],
      imageUrl: map['imageUrl'] ?? '',
      prizeDistribution: map['prizeDistribution'] ?? 0,
      createdBy: map['createdBy'] ?? '',
      winnerId: map['winnerId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      winners: List<String>.from(map['winners'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'game': game,
      'type': type,
      'map': map,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'totalSlots': totalSlots,
      'filledSlots': filledSlots,
      'rules': rules,
      'startTime': Timestamp.fromDate(startTime),
      'status': status,
      'bannerUrl': bannerUrl,
      'roomCode': roomCode,
      'roomPassword': roomPassword,
      'youtubeLink': youtubeLink,
      'sponsor': sponsor,
      'imageUrl': imageUrl,
      'prizeDistribution': prizeDistribution,
      'createdBy': createdBy,
      'winnerId': winnerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'winners': winners,
    };
  }

  Tournament copyWith({
    String? id,
    String? title,
    String? description,
    String? game,
    String? type,
    String? map,
    int? entryFee,
    int? prizePool,
    int? totalSlots,
    int? filledSlots,
    String? rules,
    DateTime? startTime,
    String? status,
    String? bannerUrl,
    String? roomCode,
    String? roomPassword,
    String? youtubeLink,
    String? sponsor,
    String? imageUrl,
    int? prizeDistribution,
    String? createdBy,
    String? winnerId,
    DateTime? createdAt,
    List<String>? winners,
  }) {
    return Tournament(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      game: game ?? this.game,
      type: type ?? this.type,
      map: map ?? this.map,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      totalSlots: totalSlots ?? this.totalSlots,
      filledSlots: filledSlots ?? this.filledSlots,
      rules: rules ?? this.rules,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      roomCode: roomCode ?? this.roomCode,
      roomPassword: roomPassword ?? this.roomPassword,
      youtubeLink: youtubeLink ?? this.youtubeLink,
      sponsor: sponsor ?? this.sponsor,
      imageUrl: imageUrl ?? this.imageUrl,
      prizeDistribution: prizeDistribution ?? this.prizeDistribution,
      createdBy: createdBy ?? this.createdBy,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
      winners: winners ?? this.winners,
    );
  }

  int get availableSlots => totalSlots - filledSlots;
} 