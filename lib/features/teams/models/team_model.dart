class TeamModel {
  final String id;
  final String name;
  final String logoUrl;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final List<String> members;
  final String privacy; // 'public' or 'private'
  final Map<String, String> roles; // userId -> role
  final List<String> joinRequests;

  TeamModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.members,
    required this.privacy,
    required this.roles,
    required this.joinRequests,
  });

  factory TeamModel.fromMap(Map<String, dynamic> map, String id) {
    return TeamModel(
      id: id,
      name: map['name'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      members: List<String>.from(map['members'] ?? []),
      privacy: map['privacy'] ?? 'public',
      roles: Map<String, String>.from(map['roles'] ?? {}),
      joinRequests: List<String>.from(map['joinRequests'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'members': members,
      'privacy': privacy,
      'roles': roles,
      'joinRequests': joinRequests,
    };
  }
} 