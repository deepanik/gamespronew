import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/team_model.dart';
import 'team_profile_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Teams')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search teams...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('teams')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No teams found.'));
                }
                final teams = snapshot.data!.docs
                    .map((doc) => TeamModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .where((team) => _search.isEmpty || team.name.toLowerCase().contains(_search.toLowerCase()))
                    .toList();
                if (teams.isEmpty) {
                  return const Center(child: Text('No teams match your search.'));
                }
                return ListView.separated(
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: team.logoUrl.isNotEmpty ? NetworkImage(team.logoUrl) : null,
                          child: team.logoUrl.isEmpty ? Text(team.name[0].toUpperCase()) : null,
                        ),
                        title: Text(team.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Row(
                          children: [
                            Icon(Icons.people, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('${team.members.length}'),
                            const SizedBox(width: 16),
                            Icon(team.privacy == 'public' ? Icons.public : Icons.lock, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(team.privacy.capitalize()),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamProfileScreen(teamId: team.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension StringCasingExtension on String {
  String capitalize() => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
} 