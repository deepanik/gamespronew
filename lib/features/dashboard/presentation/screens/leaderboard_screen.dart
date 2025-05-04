import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedGame = 'All';
  final List<String> _games = ['All', 'Free Fire', 'PUBG Mobile', 'Call of Duty Mobile', 'BGMI'];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedGame,
              items: _games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedGame = v!),
              decoration: const InputDecoration(labelText: 'Game'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedGame == 'All'
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .orderBy('wins', descending: true)
                      .limit(20)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('users')
                      .where('gamePreference', isEqualTo: _selectedGame)
                      .orderBy('wins', descending: true)
                      .limit(20)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs;
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.leaderboard, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No players found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary.withOpacity(0.7))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index].data() as Map<String, dynamic>;
                    final isCurrentUser = users[index].id == _userId;
                    final rank = index + 1;
                    return Card(
                      elevation: isCurrentUser ? 8 : 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: isCurrentUser ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Theme.of(context).cardColor,
                      child: ListTile(
                        leading: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              backgroundImage: (user['profilePicUrl'] != null && user['profilePicUrl'].toString().isNotEmpty)
                                  ? NetworkImage(user['profilePicUrl'])
                                  : null,
                              child: (user['profilePicUrl'] == null || user['profilePicUrl'].toString().isEmpty)
                                  ? Text(user['username'] != null && user['username'].isNotEmpty ? user['username'][0].toUpperCase() : '?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary))
                                  : null,
                            ),
                            if (rank <= 3)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Icon(
                                  rank == 1
                                      ? Icons.emoji_events
                                      : rank == 2
                                          ? Icons.emoji_events_outlined
                                          : Icons.emoji_events_rounded,
                                  color: rank == 1
                                      ? Colors.amber
                                      : rank == 2
                                          ? Colors.grey
                                          : Colors.brown,
                                  size: 24,
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          user['username'] ?? 'Player',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal),
                        ),
                        subtitle: Text('Wins: ${user['wins'] ?? 0}'),
                        trailing: Text('#$rank', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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