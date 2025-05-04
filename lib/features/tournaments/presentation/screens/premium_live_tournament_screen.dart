import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class PremiumLiveTournamentScreen extends StatefulWidget {
  final String tournamentId;

  const PremiumLiveTournamentScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<PremiumLiveTournamentScreen> createState() => _PremiumLiveTournamentScreenState();
}

class _PremiumLiveTournamentScreenState extends State<PremiumLiveTournamentScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _participants = [];
  bool _isAdmin = false;
  StreamSubscription? _tournamentSubscription;
  StreamSubscription? _matchesSubscription;

  @override
  void initState() {
    super.initState();
    _loadTournamentData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _tournamentSubscription?.cancel();
    _matchesSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    _tournamentSubscription = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _tournament = snapshot.data();
        });
      }
    });

    _matchesSubscription = FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('matches')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _matches = snapshot.docs.map((doc) => doc.data()).toList();
      });
    });
  }

  Future<void> _loadTournamentData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();

      if (!tournamentDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tournament not found')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final tournament = tournamentDoc.data()!;
      setState(() {
        _tournament = tournament;
        _isAdmin = tournament['createdBy'] == user.uid;
        _matches = tournament['bracket']?['matches'] ?? [];
      });

      // Load participant details
      final participantDocs = await Future.wait(
        (tournament['participants'] as List).map((uid) =>
          FirebaseFirestore.instance.collection('users').doc(uid).get()),
      );

      setState(() {
        _participants = participantDocs
            .where((doc) => doc.exists)
            .map((doc) => doc.data()!)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMatchScore(String matchId, int player1Score, int player2Score) async {
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(matchId)
          .update({
        'score1': player1Score,
        'score2': player2Score,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating score: $e')),
        );
      }
    }
  }

  Future<void> _declareWinner(String matchId, String winnerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .collection('matches')
          .doc(matchId)
          .update({
        'winner': winnerId,
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declaring winner: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tournament == null) {
      return const Scaffold(
        body: Center(child: Text('Tournament not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTournamentHeader(),
                _buildLiveStats(),
                _buildCurrentMatches(),
                _buildUpcomingMatches(),
                _buildTournamentProgress(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                // Show tournament control panel
                _showTournamentControlPanel();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Tournament Controls'),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_tournament!['title']),
        background: _tournament?['bannerUrl'] != null
            ? Image.network(
                _tournament!['bannerUrl'],
                fit: BoxFit.cover,
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTournamentHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Tournament',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.sports_esports,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(_tournament!['game']),
              const SizedBox(width: 16),
              Icon(
                Icons.people,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text('${_participants.length}/${_tournament!['maxParticipants']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStats() {
    final activeMatches = _matches.where((m) => m['status'] == 'active').length;
    final completedMatches = _matches.where((m) => m['status'] == 'completed').length;
    final totalMatches = _matches.length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Active Matches',
              value: activeMatches.toString(),
              icon: Icons.play_circle,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              title: 'Completed',
              value: completedMatches.toString(),
              icon: Icons.check_circle,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _StatCard(
              title: 'Total Matches',
              value: totalMatches.toString(),
              icon: Icons.format_list_numbered,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMatches() {
    final activeMatches = _matches.where((m) => m['status'] == 'active').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Active Matches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (activeMatches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No active matches'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeMatches.length,
            itemBuilder: (context, index) {
              final match = activeMatches[index];
              return _LiveMatchCard(
                match: match,
                onScoreUpdate: _updateMatchScore,
                onWinnerDeclared: _declareWinner,
                isAdmin: _isAdmin,
              );
            },
          ),
      ],
    );
  }

  Widget _buildUpcomingMatches() {
    final upcomingMatches = _matches.where((m) => m['status'] == 'scheduled').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Upcoming Matches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (upcomingMatches.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No upcoming matches'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingMatches.length,
            itemBuilder: (context, index) {
              final match = upcomingMatches[index];
              return _UpcomingMatchCard(match: match);
            },
          ),
      ],
    );
  }

  Widget _buildTournamentProgress() {
    final completedMatches = _matches.where((m) => m['status'] == 'completed').length;
    final totalMatches = _matches.length;
    final progress = totalMatches > 0 ? completedMatches / totalMatches : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% Complete',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _tournament!['status'];
    Color color;
    IconData icon;

    switch (status) {
      case 'upcoming':
        color = Colors.blue;
        icon = Icons.schedule;
        break;
      case 'ongoing':
        color = Colors.green;
        icon = Icons.play_circle;
        break;
      case 'completed':
        color = Colors.grey;
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.orange;
        icon = Icons.warning;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(
        status.toString().toUpperCase(),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  void _showTournamentControlPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _TournamentControlPanel(
        tournament: _tournament!,
        matches: _matches,
        participants: _participants,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final Function(String, int, int) onScoreUpdate;
  final Function(String, String) onWinnerDeclared;
  final bool isAdmin;

  const _LiveMatchCard({
    required this.match,
    required this.onScoreUpdate,
    required this.onWinnerDeclared,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Match ${match['matchNumber']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match['player1'] ?? 'TBD',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                final currentScore = match['score1'] ?? 0;
                                if (currentScore > 0) {
                                  onScoreUpdate(
                                    match['id'],
                                    currentScore - 1,
                                    match['score2'] ?? 0,
                                  );
                                }
                              },
                            ),
                            Text(
                              '${match['score1'] ?? 0}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                onScoreUpdate(
                                  match['id'],
                                  (match['score1'] ?? 0) + 1,
                                  match['score2'] ?? 0,
                                );
                              },
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          '${match['score1'] ?? 0}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                    ],
                  ),
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match['player2'] ?? 'TBD',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                final currentScore = match['score2'] ?? 0;
                                if (currentScore > 0) {
                                  onScoreUpdate(
                                    match['id'],
                                    match['score1'] ?? 0,
                                    currentScore - 1,
                                  );
                                }
                              },
                            ),
                            Text(
                              '${match['score2'] ?? 0}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                onScoreUpdate(
                                  match['id'],
                                  match['score1'] ?? 0,
                                  (match['score2'] ?? 0) + 1,
                                );
                              },
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          '${match['score2'] ?? 0}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => onWinnerDeclared(match['id'], match['player1']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Player 1 Wins'),
                  ),
                  ElevatedButton(
                    onPressed: () => onWinnerDeclared(match['id'], match['player2']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Player 2 Wins'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const _UpcomingMatchCard({
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Match ${match['matchNumber']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'UPCOMING',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match['player1'] ?? 'TBD',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  match['player2'] ?? 'TBD',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Scheduled: ${DateFormat('MMM d, h:mm a').format((match['scheduledTime'] as Timestamp).toDate())}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentControlPanel extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> participants;

  const _TournamentControlPanel({
    required this.tournament,
    required this.matches,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tournament Controls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildControlButton(
            context,
            'Generate Next Round',
            Icons.playlist_add,
            () {
              // Generate next round
            },
          ),
          _buildControlButton(
            context,
            'Pause Tournament',
            Icons.pause_circle,
            () {
              // Pause tournament
            },
          ),
          _buildControlButton(
            context,
            'Resume Tournament',
            Icons.play_circle,
            () {
              // Resume tournament
            },
          ),
          _buildControlButton(
            context,
            'End Tournament',
            Icons.stop_circle,
            () {
              // End tournament
            },
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickActionChip(
                context,
                'Broadcast Message',
                Icons.message,
                () {
                  // Show broadcast message dialog
                },
              ),
              _buildQuickActionChip(
                context,
                'View Bracket',
                Icons.account_tree,
                () {
                  // Show bracket view
                },
              ),
              _buildQuickActionChip(
                context,
                'Export Results',
                Icons.download,
                () {
                  // Export tournament results
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: onPressed,
    );
  }
} 