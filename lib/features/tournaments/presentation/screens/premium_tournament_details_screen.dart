import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../teams/models/team_model.dart';
import '../../../teams/presentation/screens/team_profile_screen.dart';

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
  List<Map<String, dynamic>> _registeredTeams = [];
  List<TeamModel> _myTeams = [];
  bool _isTeamBased = false;
  int _minTeamSize = 1;
  int _maxTeamSize = 100;
  Map<String, Map<String, dynamic>> _teamInfoCache = {};

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
      final isTeamBased = tournament['registrationType'] == 'Team-based';
      setState(() {
        _tournament = tournament;
        _isAdmin = tournament['createdBy'] == user.uid;
        _isJoined = (tournament['participants'] as List).contains(user.uid);
        _participants = [];
        _matches = tournament['bracket']?['matches'] ?? [];
        _isTeamBased = isTeamBased;
        _minTeamSize = tournament['minTeamSize'] ?? 1;
        _maxTeamSize = tournament['maxTeamSize'] ?? 100;
      });

      // Load participant details (users or teams)
      if (isTeamBased) {
        final teamDocs = await Future.wait(
          (tournament['participants'] as List).map((teamId) =>
            FirebaseFirestore.instance.collection('teams').doc(teamId).get()),
        );
        setState(() {
          _registeredTeams = teamDocs
              .where((doc) => doc.exists)
              .map((doc) => doc.data()!)
              .toList();
        });
        // Load my teams (where user is captain/admin)
        final myTeamsSnapshot = await FirebaseFirestore.instance
            .collection('teams')
            .where('members', arrayContains: user.uid)
            .get();
        final myTeams = myTeamsSnapshot.docs
            .map((doc) => TeamModel.fromMap(doc.data(), doc.id))
            .where((team) => team.roles[user.uid] == 'captain' || team.roles[user.uid] == 'admin')
            .toList();
        setState(() {
          _myTeams = myTeams;
        });
      } else {
        // Load participant user details
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
      }
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

  Future<void> _registerTeam(String teamId) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'participants': FieldValue.arrayUnion([teamId]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team registered successfully!')),
        );
        _loadTournamentData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMatchDetails(Map<String, dynamic> match, Map<String, dynamic>? team1, Map<String, dynamic>? team2) async {
    final playerStats = match['playerStats'] as Map<String, dynamic>?;
    List<Map<String, dynamic>> team1Stats = [];
    List<Map<String, dynamic>> team2Stats = [];
    String? team1MvpId;
    String? team2MvpId;
    if (playerStats != null) {
      if (team1 != null && playerStats[team1['id']] != null) {
        team1Stats = List<Map<String, dynamic>>.from(playerStats[team1['id']]);
        if (team1Stats.isNotEmpty) {
          team1MvpId = team1Stats.reduce((a, b) => (a['score'] ?? 0) > (b['score'] ?? 0) ? a : b)['userId'];
        }
      }
      if (team2 != null && playerStats[team2['id']] != null) {
        team2Stats = List<Map<String, dynamic>>.from(playerStats[team2['id']]);
        if (team2Stats.isNotEmpty) {
          team2MvpId = team2Stats.reduce((a, b) => (a['score'] ?? 0) > (b['score'] ?? 0) ? a : b)['userId'];
        }
      }
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTeamBracketTile(team1),
                  const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildTeamBracketTile(team2, alignEnd: true),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('Score: ${match['score1'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Score: ${match['score2'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              if (match['winner'] != null)
                Text('Winner: '
                  '${team1 != null && match['winner'] == match['player1'] ? team1['name'] : team2 != null && match['winner'] == match['player2'] ? team2['name'] : match['winner']}',
                  style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (team1 != null) ...[
                Text('Team 1 Members:', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    if (team1Stats.isNotEmpty)
                      for (final stat in team1Stats)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(stat['userId']).get(),
                          builder: (context, snap) {
                            if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                            final user = snap.data!.data() as Map<String, dynamic>?;
                            final isMvp = stat['userId'] == team1MvpId;
                            return Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(user?['username'] ?? 'Unknown'),
                                  if (stat['score'] != null) Text(' • ${stat['score']}'),
                                  if (stat['kills'] != null) Text(' Kills: ${stat['kills']}'),
                                  if (isMvp) const Text(' ⭐', style: TextStyle(color: Colors.amber)),
                                ],
                              ),
                              backgroundColor: isMvp ? Colors.amber[100] : null,
                            );
                          },
                        )
                    else
                      for (final m in (team1['members'] as List? ?? []))
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(m).get(),
                          builder: (context, snap) {
                            if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                            final user = snap.data!.data() as Map<String, dynamic>?;
                            return Chip(label: Text(user?['username'] ?? 'Unknown'));
                          },
                        ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (team2 != null) ...[
                Text('Team 2 Members:', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    if (team2Stats.isNotEmpty)
                      for (final stat in team2Stats)
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(stat['userId']).get(),
                          builder: (context, snap) {
                            if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                            final user = snap.data!.data() as Map<String, dynamic>?;
                            final isMvp = stat['userId'] == team2MvpId;
                            return Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(user?['username'] ?? 'Unknown'),
                                  if (stat['score'] != null) Text(' • ${stat['score']}'),
                                  if (stat['kills'] != null) Text(' Kills: ${stat['kills']}'),
                                  if (isMvp) const Text(' ⭐', style: TextStyle(color: Colors.amber)),
                                ],
                              ),
                              backgroundColor: isMvp ? Colors.amber[100] : null,
                            );
                          },
                        )
                    else
                      for (final m in (team2['members'] as List? ?? []))
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(m).get(),
                          builder: (context, snap) {
                            if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                            final user = snap.data!.data() as Map<String, dynamic>?;
                            return Chip(label: Text(user?['username'] ?? 'Unknown'));
                          },
                        ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  _buildAnalyticsSection(),
                ],
              ),
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
          if (_tournament!['streamUrl'] != null && _tournament!['streamUrl'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.live_tv, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Live Now', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: WebView(
                    initialUrl: _tournament!['streamUrl'],
                    javascriptMode: JavascriptMode.unrestricted,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
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
        if (_isTeamBased) {
          // Team-based: fetch team info for player1/player2
          return FutureBuilder<List<Map<String, dynamic>?>>(
            future: Future.wait([
              _getTeamInfo(match['player1']),
              _getTeamInfo(match['player2']),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Card(child: ListTile(title: Text('Loading teams...')));
              }
              final team1 = snapshot.data![0];
              final team2 = snapshot.data![1];
              return GestureDetector(
                onTap: () => _showMatchDetails(match, team1, team2),
                child: Card(
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
                              child: _buildTeamBracketTile(team1),
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
                              child: _buildTeamBracketTile(team2, alignEnd: true),
                            ),
                          ],
                        ),
                        if (match['winner'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Winner: ${team1 != null && match['winner'] == match['player1'] ? team1['name'] : team2 != null && match['winner'] == match['player2'] ? team2['name'] : match['winner']}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          // ... existing code for solo ...
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
        }
      },
    );
  }

  Future<Map<String, dynamic>?> _getTeamInfo(String? teamId) async {
    if (teamId == null) return null;
    if (_teamInfoCache.containsKey(teamId)) return _teamInfoCache[teamId];
    final doc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
    if (doc.exists) {
      _teamInfoCache[teamId] = doc.data()!;
      return doc.data()!;
    }
    return null;
  }

  Widget _buildTeamBracketTile(Map<String, dynamic>? team, {bool alignEnd = false}) {
    if (team == null) {
      return Text('TBD', textAlign: alignEnd ? TextAlign.end : TextAlign.start);
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamProfileScreen(teamId: team['id']),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (team['logoUrl'] != null && team['logoUrl'].toString().isNotEmpty)
            CircleAvatar(
              backgroundImage: NetworkImage(team['logoUrl']),
              radius: 16,
            ),
          if (team['logoUrl'] == null || team['logoUrl'].toString().isEmpty)
            CircleAvatar(
              child: Text(team['name'][0].toUpperCase()),
              radius: 16,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              team['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    if (_isTeamBased) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_myTeams.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Register Your Team', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._myTeams.map((team) {
                    final alreadyRegistered = (_tournament!['participants'] as List).contains(team.id);
                    final teamSize = team.members.length;
                    final sizeOk = teamSize >= _minTeamSize && teamSize <= _maxTeamSize;
                    final userHasTeamRegistered = _myTeams.any((t) => (_tournament!['participants'] as List).contains(t.id));
                    String? reason;
                    if (alreadyRegistered) {
                      reason = 'Already registered';
                    } else if (userHasTeamRegistered) {
                      reason = 'You have already registered a team';
                    } else if (!sizeOk) {
                      reason = 'Team must have $_minTeamSize-${_maxTeamSize} members';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tooltip(
                        message: reason ?? '',
                        child: ElevatedButton(
                          onPressed: (alreadyRegistered || userHasTeamRegistered || !sizeOk)
                              ? null
                              : () => _registerTeam(team.id),
                          child: Text(
                            alreadyRegistered
                                ? 'Already Registered: ${team.name}'
                                : !sizeOk
                                    ? 'Ineligible: ${team.name}'
                                    : userHasTeamRegistered
                                        ? 'You have already registered a team'
                                        : 'Register: ${team.name}',
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Registered Teams', style: Theme.of(context).textTheme.titleLarge),
          ),
          if (_registeredTeams.isEmpty)
            const Center(child: Text('No teams registered yet.'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _registeredTeams.length,
              itemBuilder: (context, index) {
                final team = _registeredTeams[index];
                return Card(
                  child: ListTile(
                    leading: team['logoUrl'] != null && team['logoUrl'].toString().isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(team['logoUrl']))
                        : CircleAvatar(child: Text(team['name'][0].toUpperCase())),
                    title: Text(team['name']),
                    subtitle: Text('Members: ${(team['members'] as List).length}'),
                  ),
                );
              },
            ),
        ],
      );
    }

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

  Future<void> _exportAnalyticsCsv(List<String> sortedTeams, Map<String, int> teamWins, Map<String, int> teamGames, List<String> sortedPlayers, Map<String, Map<String, dynamic>> playerTotals, Map<String, int> playerGames) async {
    final buffer = StringBuffer();
    buffer.writeln('Team Analytics');
    buffer.writeln('Team Name,Win Rate (%),Wins,Games');
    for (final teamId in sortedTeams) {
      final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      final team = teamDoc.data();
      final winRate = ((teamWins[teamId] ?? 0) / (teamGames[teamId] ?? 1) * 100).toStringAsFixed(1);
      buffer.writeln('${team?['name'] ?? teamId},$winRate,${teamWins[teamId] ?? 0},${teamGames[teamId] ?? 0}');
    }
    buffer.writeln();
    buffer.writeln('Player Analytics');
    buffer.writeln('Username,Avg Score,Avg Kills,Games');
    for (final userId in sortedPlayers) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final user = userDoc.data();
      final avgScore = playerGames[userId]! > 0 ? (playerTotals[userId]!['score'] / playerGames[userId]!).toStringAsFixed(1) : '0';
      final avgKills = playerGames[userId]! > 0 ? (playerTotals[userId]!['kills'] / playerGames[userId]!).toStringAsFixed(1) : '0';
      buffer.writeln('${user?['username'] ?? userId},$avgScore,$avgKills,${playerGames[userId] ?? 0}');
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/tournament_analytics.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Tournament Analytics');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analytics exported!')));
    }
  }

  Widget _buildAnalyticsSection() {
    if (_matches.isEmpty) return const SizedBox();
    // Team win rates
    final Map<String, int> teamWins = {};
    final Map<String, int> teamGames = {};
    final Map<String, Map<String, dynamic>> playerTotals = {};
    final Map<String, int> playerGames = {};
    for (final match in _matches) {
      if (match['winner'] != null) {
        teamWins[match['winner']] = (teamWins[match['winner']] ?? 0) + 1;
      }
      for (final teamId in [match['player1'], match['player2']]) {
        if (teamId != null) teamGames[teamId] = (teamGames[teamId] ?? 0) + 1;
      }
      // Player stats
      final playerStats = match['playerStats'] as Map<String, dynamic>?;
      if (playerStats != null) {
        for (final teamEntry in playerStats.entries) {
          for (final stat in (teamEntry.value as List)) {
            final userId = stat['userId'];
            if (userId == null) continue;
            playerTotals[userId] ??= {'kills': 0, 'score': 0};
            playerTotals[userId]['kills'] += stat['kills'] ?? 0;
            playerTotals[userId]['score'] += stat['score'] ?? 0;
            playerGames[userId] = (playerGames[userId] ?? 0) + 1;
          }
        }
      }
    }
    // Sort teams by win rate
    final sortedTeams = teamGames.keys.toList()
      ..sort((a, b) {
        final aRate = (teamWins[a] ?? 0) / (teamGames[a] ?? 1);
        final bRate = (teamWins[b] ?? 0) / (teamGames[b] ?? 1);
        return bRate.compareTo(aRate);
      });
    // Sort players by average score
    final sortedPlayers = playerTotals.keys.toList()
      ..sort((a, b) {
        final aAvg = playerGames[a]! > 0 ? playerTotals[a]!['score'] / playerGames[a]! : 0;
        final bAvg = playerGames[b]! > 0 ? playerTotals[b]!['score'] / playerGames[b]! : 0;
        return bAvg.compareTo(aAvg);
      });
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tournament Analytics', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export Analytics',
                onPressed: () => _exportAnalyticsCsv(sortedTeams, teamWins, teamGames, sortedPlayers, playerTotals, playerGames),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sortedTeams.isNotEmpty) ...[
            Text('Team Win Rates', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sortedTeams.take(3).map((teamId) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('teams').doc(teamId).get(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                final team = snap.data!.data() as Map<String, dynamic>?;
                final winRate = ((teamWins[teamId] ?? 0) / (teamGames[teamId] ?? 1) * 100).toStringAsFixed(1);
                return ListTile(
                  leading: team != null && team['logoUrl'] != null && team['logoUrl'].toString().isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(team['logoUrl']))
                      : CircleAvatar(child: Text(team != null ? team['name'][0].toUpperCase() : '?')),
                  title: Text(team != null ? team['name'] : 'Unknown'),
                  subtitle: Text('Win Rate: $winRate%'),
                );
              },
            )),
            const SizedBox(height: 16),
          ],
          if (sortedPlayers.isNotEmpty) ...[
            Text('Top Player Averages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...sortedPlayers.take(3).map((userId) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, snap) {
                if (!snap.hasData || !snap.data!.exists) return const SizedBox();
                final user = snap.data!.data() as Map<String, dynamic>?;
                final avgScore = playerGames[userId]! > 0 ? (playerTotals[userId]!['score'] / playerGames[userId]!).toStringAsFixed(1) : '0';
                final avgKills = playerGames[userId]! > 0 ? (playerTotals[userId]!['kills'] / playerGames[userId]!).toStringAsFixed(1) : '0';
                return ListTile(
                  leading: user != null && user['profilePicUrl'] != null
                      ? CircleAvatar(backgroundImage: NetworkImage(user['profilePicUrl']))
                      : CircleAvatar(child: Text(user != null ? user['username'][0].toUpperCase() : '?')),
                  title: Text(user != null ? user['username'] : 'Unknown'),
                  subtitle: Text('Avg Score: $avgScore • Avg Kills: $avgKills'),
                );
              },
            )),
          ],
        ],
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