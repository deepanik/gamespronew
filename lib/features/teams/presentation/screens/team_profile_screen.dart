import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/team_model.dart';
import 'edit_team_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  final String teamId;
  const TeamProfileScreen({super.key, required this.teamId});

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  bool _isLoading = true;
  TeamModel? _team;
  Map<String, dynamic> _members = {};
  String? _userId;
  String? _userRole;
  bool _isMember = false;
  bool _isPending = false;
  List<String> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _userId = user.uid;
      final doc = await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).get();
      if (!doc.exists) return;
      final team = TeamModel.fromMap(doc.data()!, doc.id);
      final membersMap = <String, dynamic>{};
      for (final uid in team.members) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          membersMap[uid] = userDoc.data();
        }
      }
      setState(() {
        _team = team;
        _members = membersMap;
        _userRole = team.roles[_userId!];
        _isMember = team.members.contains(_userId);
        _pendingRequests = team.joinRequests;
        _isPending = team.joinRequests.contains(_userId);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading team: $e')),
      );
    }
  }

  Future<void> _requestToJoin() async {
    try {
      await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
        'joinRequests': FieldValue.arrayUnion([_userId])
      });
      setState(() => _isPending = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Join request sent!')),
      );
      _loadTeam();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending join request: $e')),
      );
    }
  }

  Future<void> _approveRequest(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
        'members': FieldValue.arrayUnion([uid]),
        'roles.$uid': 'member',
        'joinRequests': FieldValue.arrayRemove([uid]),
      });
      _loadTeam();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving request: $e')),
      );
    }
  }

  Future<void> _rejectRequest(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
        'joinRequests': FieldValue.arrayRemove([uid]),
      });
      _loadTeam();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $e')),
      );
    }
  }

  Future<void> _changeRole(String uid, String newRole) async {
    await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
      'roles.$uid': newRole,
    });
    _loadTeam();
  }

  Future<void> _transferCaptaincy(String newCaptainId) async {
    await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
      'roles.$_userId': 'member',
      'roles.$newCaptainId': 'captain',
    });
    _loadTeam();
  }

  Future<void> _leaveTeam() async {
    if (_userRole == 'captain' && _team!.members.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer captaincy before leaving.')),
      );
      return;
    }
    if (_userRole == 'captain' && _team!.members.length == 1) {
      // Disband team
      await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).delete();
      if (mounted) Navigator.pop(context);
      return;
    }
    await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
      'members': FieldValue.arrayRemove([_userId]),
      'roles.$_userId': FieldValue.delete(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_team == null) {
      return const Scaffold(body: Center(child: Text('Team not found')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_team!.name),
        actions: [
          if (_userRole == 'captain' || _userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTeamScreen(team: _team!),
                  ),
                );
                if (updated == true) _loadTeam();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage: _team!.logoUrl.isNotEmpty ? NetworkImage(_team!.logoUrl) : null,
              child: _team!.logoUrl.isEmpty ? Text(_team!.name[0].toUpperCase(), style: const TextStyle(fontSize: 32)) : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _team!.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_team!.privacy == 'public' ? Icons.public : Icons.lock, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(_team!.privacy.capitalize(), style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_team!.description.isNotEmpty)
            Text(_team!.description, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatCard(label: 'Members', value: _team!.members.length.toString()),
              _StatCard(label: 'Created', value: _team!.createdAt.toLocal().toString().split(' ')[0]),
            ],
          ),
          const SizedBox(height: 24),
          if (!_isMember && !_isPending)
            ElevatedButton(
              onPressed: _team!.privacy == 'public' ? _joinTeam : _requestToJoin,
              child: Text(_team!.privacy == 'public' ? 'Join Team' : 'Request to Join'),
            ),
          if (_isPending)
            const Center(child: Text('Join request pending', style: TextStyle(color: Colors.orange))),
          if (_isMember)
            const Center(child: Text('You are a member', style: TextStyle(color: Colors.green))),
          const SizedBox(height: 32),
          if (_isMember)
            ElevatedButton(
              onPressed: _leaveTeam,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(_userRole == 'captain' && _team!.members.length == 1 ? 'Disband Team' : 'Leave Team'),
            ),
          Text('Team Members', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ..._team!.members.map((uid) {
            final user = _members[uid];
            final role = _team!.roles[uid] ?? 'member';
            return Card(
              child: ListTile(
                leading: user != null && user['profilePicUrl'] != null
                    ? CircleAvatar(backgroundImage: NetworkImage(user['profilePicUrl']))
                    : CircleAvatar(child: Text(user != null ? user['username'][0].toUpperCase() : '?')),
                title: Text(user != null ? user['username'] : 'Unknown'),
                subtitle: Text(role.capitalize()),
                trailing: (_userRole == 'captain' || _userRole == 'admin') && uid != _userId
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).update({
                                'members': FieldValue.arrayRemove([uid]),
                                'roles.$uid': FieldValue.delete(),
                              });
                              _loadTeam();
                            },
                          ),
                          if (_userRole == 'captain' && _team!.roles[uid] != 'captain')
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'admin') _changeRole(uid, 'admin');
                                if (value == 'member') _changeRole(uid, 'member');
                                if (value == 'captain') _transferCaptaincy(uid);
                              },
                              itemBuilder: (context) => [
                                if (_team!.roles[uid] == 'member')
                                  const PopupMenuItem(value: 'admin', child: Text('Promote to Admin')),
                                if (_team!.roles[uid] == 'admin')
                                  const PopupMenuItem(value: 'member', child: Text('Demote to Member')),
                                const PopupMenuItem(value: 'captain', child: Text('Transfer Captaincy')),
                              ],
                              icon: const Icon(Icons.more_vert),
                            ),
                          if (_userRole == 'admin' && _team!.roles[uid] == 'member')
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, color: Colors.blue),
                              tooltip: 'Promote to Admin',
                              onPressed: () => _changeRole(uid, 'admin'),
                            ),
                          if (_userRole == 'admin' && _team!.roles[uid] == 'admin')
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, color: Colors.orange),
                              tooltip: 'Demote to Member',
                              onPressed: () => _changeRole(uid, 'member'),
                            ),
                        ],
                      )
                    : null,
              ),
            );
          }).toList(),
          if ((_userRole == 'captain' || _userRole == 'admin') && _pendingRequests.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pending Join Requests', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._pendingRequests.map((uid) => FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    final user = snapshot.data!.data() as Map<String, dynamic>?;
                    return Card(
                      child: ListTile(
                        leading: user != null && user['profilePicUrl'] != null
                            ? CircleAvatar(backgroundImage: NetworkImage(user['profilePicUrl']))
                            : CircleAvatar(child: Text(user != null ? user['username'][0].toUpperCase() : '?')),
                        title: Text(user != null ? user['username'] : 'Unknown'),
                        subtitle: const Text('Pending'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _approveRequest(uid),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _rejectRequest(uid),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )),
                const SizedBox(height: 24),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
      ],
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
} 