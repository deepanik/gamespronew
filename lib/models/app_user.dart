import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String username;
  final String email;
  final String phone;
  final String profilePicUrl;
  final int coins;
  final double walletBalance;
  final int totalMatches;
  final int wins;
  final String referralCode;
  final String? referredBy;
  final bool isAdmin;
  final String deviceId;
  final DateTime joinedAt;

  AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.phone,
    required this.profilePicUrl,
    required this.coins,
    required this.walletBalance,
    required this.totalMatches,
    required this.wins,
    required this.referralCode,
    this.referredBy,
    required this.isAdmin,
    required this.deviceId,
    required this.joinedAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      profilePicUrl: map['profilePicUrl'] as String,
      coins: map['coins'] as int,
      walletBalance: (map['walletBalance'] as num).toDouble(),
      totalMatches: map['totalMatches'] as int,
      wins: map['wins'] as int,
      referralCode: map['referralCode'] as String,
      referredBy: map['referredBy'] as String?,
      isAdmin: map['isAdmin'] as bool,
      deviceId: map['deviceId'] as String,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'phone': phone,
      'profilePicUrl': profilePicUrl,
      'coins': coins,
      'walletBalance': walletBalance,
      'totalMatches': totalMatches,
      'wins': wins,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'isAdmin': isAdmin,
      'deviceId': deviceId,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? username,
    String? email,
    String? phone,
    String? profilePicUrl,
    int? coins,
    double? walletBalance,
    int? totalMatches,
    int? wins,
    String? referralCode,
    String? referredBy,
    bool? isAdmin,
    String? deviceId,
    DateTime? joinedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      coins: coins ?? this.coins,
      walletBalance: walletBalance ?? this.walletBalance,
      totalMatches: totalMatches ?? this.totalMatches,
      wins: wins ?? this.wins,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      isAdmin: isAdmin ?? this.isAdmin,
      deviceId: deviceId ?? this.deviceId,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
} 