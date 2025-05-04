import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:games_pro/features/tournament/presentation/screens/tournament_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedGame = 'All';
  String _selectedType = 'All';
  String _selectedStatus = 'upcoming';

  final List<String> _games = ['All', 'PUBG', 'Free Fire', 'Call of Duty'];
  final List<String> _types = ['All', 'Solo', 'Duo', 'Squad'];
  final List<String> _statuses = ['upcoming', 'ongoing', 'completed'];
  List<String> _pinnedGames = [];
  User? _user;
  Map<String, bool> _gameHasUpcoming = {};
  Stream<QuerySnapshot>? _upcomingStream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _fetchPinnedGames();
    _upcomingStream = FirebaseFirestore.instance
        .collection('tournaments')
        .where('status', isEqualTo: 'upcoming')
        .snapshots();
  }

  Future<void> _fetchPinnedGames() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    final data = doc.data();
    if (data != null && data['pinnedGames'] != null) {
      setState(() {
        _pinnedGames = List<String>.from(data['pinnedGames']);
      });
    }
  }

  Future<void> _togglePin(String game) async {
    if (_user == null) return;
    setState(() {
      if (_pinnedGames.contains(game)) {
        _pinnedGames.remove(game);
      } else {
        _pinnedGames.add(game);
      }
    });
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
      'pinnedGames': _pinnedGames
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournaments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Premium Game Grid View
            SizedBox(
              height: 140,
              child: StreamBuilder<QuerySnapshot>(
                stream: _upcomingStream,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final docs = snapshot.data!.docs;
                    final Map<String, bool> hasUpcoming = {};
                    for (final game in _games) {
                      if (game == 'All') continue;
                      hasUpcoming[game] = docs.any((doc) => (doc['game'] ?? '') == game);
                    }
                    _gameHasUpcoming = hasUpcoming;
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _games.length,
                    itemBuilder: (context, index) {
                      final game = _games[index];
                      final isPinned = _pinnedGames.contains(game);
                      final hasUpcoming = _gameHasUpcoming[game] ?? false;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedGame = game);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                          width: 110,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.13),
                              width: 1.5,
                            ),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                Colors.white.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                      child: Text(
                                        game.isNotEmpty ? game[0].toUpperCase() : '?',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      game,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _togglePin(game),
                                  child: Icon(
                                    isPinned ? Icons.star : Icons.star_border,
                                    color: isPinned ? Colors.amber : Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              if (hasUpcoming)
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Upcoming',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Match Type Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _types.map((type) {
                  final isSelected = _selectedType == type;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ChoiceChip(
                      label: Text(type, style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedType = type),
                      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                      backgroundColor: Colors.white.withOpacity(0.12),
                      labelStyle: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      items: _statuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStatus = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tournaments')
                    .where('status', isEqualTo: _selectedStatus)
                    .orderBy('startTime')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: \\${snapshot.error}', style: const TextStyle(color: Colors.white)));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final tournaments = snapshot.data!.docs
                      .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                      .where((tournament) {
                    if (_selectedGame != 'All' && tournament.game != _selectedGame) {
                      return false;
                    }
                    if (_selectedType != 'All' && tournament.type != _selectedType) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (tournaments.isEmpty) {
                    return const Center(child: Text('No tournaments found', style: TextStyle(color: Colors.white70)));
                  }

                  return ListView.builder(
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final tournament = tournaments[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentDetailScreen(tournament: tournament),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.13),
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 36,
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                      child: Text(
                                        tournament.title.isNotEmpty ? tournament.title[0].toUpperCase() : '?',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tournament.title,
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${tournament.game} - ${tournament.type}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Entry Fee: ${tournament.entryFee} coins',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${tournament.filledSlots}/${tournament.totalSlots} Slots',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                    Text(
                                      'Prize Pool: ${tournament.prizePool} coins',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: tournament.filledSlots / tournament.totalSlots,
                                  backgroundColor: Colors.white.withOpacity(0.2),
                                  color: Theme.of(context).colorScheme.primary,
                                  minHeight: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Tournaments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedGame,
              decoration: const InputDecoration(labelText: 'Game'),
              items: _games.map((game) {
                return DropdownMenuItem(
                  value: game,
                  child: Text(game),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGame = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedGame = 'All';
                _selectedType = 'All';
              });
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 