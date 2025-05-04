import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumTournamentDetailsScreen extends StatefulWidget {
  final String tournamentId;

  const PremiumTournamentDetailsScreen({
    super.key,
    required this.tournamentId,
  });

  @override
  State<PremiumTournamentDetailsScreen> createState() => _PremiumTournamentDetailsScreenState();
}

class _PremiumTournamentDetailsScreenState extends State<PremiumTournamentDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _tournament;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _matches = [];
  bool _isJoined = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTournamentData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        _isJoined = (tournament['participants'] as List).contains(user.uid);
        _participants = [];
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

  Future<void> _joinTournament() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'participants': FieldValue.arrayUnion([user.uid]),
      });

      setState(() => _isJoined = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined tournament!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveTournament() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'participants': FieldValue.arrayRemove([user.uid]),
      });

      setState(() => _isJoined = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully left tournament')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error leaving tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTournament() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'status': 'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament started!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _endTournament() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'status': 'completed',
        'endedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament ended!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Bracket'),
                    Tab(text: 'Participants'),
                    Tab(text: 'Rules'),
                  ],
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildBracketTab(),
                _buildParticipantsTab(),
                _buildRulesTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
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
          Text(
            _tournament!['title'],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          _buildStatusChip(),
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'Description',
            content: _tournament!['description'],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Prize Pool',
            content: '\$${_tournament!['prizePool'].toStringAsFixed(2)}',
            icon: Icons.emoji_events,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Entry Fee',
            content: '\$${_tournament!['entryFee'].toStringAsFixed(2)}',
            icon: Icons.payment,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Format',
            content: _tournament!['format'],
            icon: Icons.format_list_bulleted,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Start Time',
            content: DateFormat('MMMM d, y • h:mm a')
                .format((_tournament!['startTime'] as Timestamp).toDate()),
            icon: Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildBracketTab() {
    if (_matches.isEmpty) {
      return const Center(
        child: Text('No matches scheduled yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match['player1'] ?? 'TBD',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        match['score1']?.toString() ?? '-',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        match['score2']?.toString() ?? '-',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        match['player2'] ?? 'TBD',
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                if (match['winner'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Winner: ${match['winner']}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticipantsTab() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text('No participants yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: participant['profilePicUrl'] != null
                  ? NetworkImage(participant['profilePicUrl'])
                  : null,
              child: participant['profilePicUrl'] == null
                  ? Text(participant['username'][0].toUpperCase())
                  : null,
            ),
            title: Text(participant['username']),
            subtitle: Text('Joined ${DateFormat('MMM d').format((participant['joinedAt'] as Timestamp).toDate())}'),
            trailing: _isAdmin
                ? IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Colors.red,
                    onPressed: () {
                      // Remove participant
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildRulesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: 'General Rules',
            content: _tournament!['rules']?['general'] ?? 'No general rules specified',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Game Rules',
            content: _tournament!['rules']?['game'] ?? 'No game-specific rules specified',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Prize Distribution',
            content: _tournament!['rules']?['prizes'] ?? 'No prize distribution specified',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isAdmin) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _tournament!['status'] == 'upcoming'
                    ? _startTournament
                    : _endTournament,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tournament!['status'] == 'upcoming'
                      ? Colors.green
                      : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _tournament!['status'] == 'upcoming'
                      ? 'Start Tournament'
                      : 'End Tournament',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isJoined ? _leaveTournament : _joinTournament,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isJoined ? Colors.red : Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isJoined ? 'Leave Tournament' : 'Join Tournament'),
            ),
          ),
        ],
      ),
    );
  }
} 