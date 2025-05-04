import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:games_pro/models/tournament_registration.dart';
import 'package:games_pro/models/app_user.dart';
import 'package:games_pro/features/tournament/presentation/screens/create_tournament_screen.dart';
import 'package:games_pro/features/tournament/presentation/screens/tournament_detail_screen.dart';
import 'package:games_pro/features/tournament/presentation/screens/tournament_participants_screen.dart';
import 'package:fl_chart/fl_chart.dart';

class TournamentManagementScreen extends ConsumerStatefulWidget {
  const TournamentManagementScreen({super.key});

  @override
  ConsumerState<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends ConsumerState<TournamentManagementScreen> {
  String _selectedStatus = 'all';
  final List<String> _statuses = ['all', 'upcoming', 'live', 'completed'];
  bool _isLoading = false;

  Future<void> _updateTournamentStatus(Tournament tournament, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Tournament status updated to $newStatus'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error updating status: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _distributePrizes(Tournament tournament) async {
    if (tournament.status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only distribute prizes for completed tournaments'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Get all registrations for this tournament
      final registrations = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournament.id)
          .collection('registrations')
          .get();

      // Calculate prize distribution
      final totalParticipants = registrations.docs.length;
      if (totalParticipants == 0) {
        throw Exception('No participants in tournament');
      }

      // Example prize distribution (can be customized)
      final firstPrize = (tournament.prizePool * 0.5).round();
      final secondPrize = (tournament.prizePool * 0.3).round();
      final thirdPrize = (tournament.prizePool * 0.2).round();

      // Update user coins in a batch
      final batch = FirebaseFirestore.instance.batch();
      
      // First place
      if (registrations.docs.isNotEmpty) {
        final firstPlace = registrations.docs[0];
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(firstPlace.data()['userId']);
        batch.update(userRef, {
          'coins': FieldValue.increment(firstPrize),
        });
      }

      // Second place
      if (registrations.docs.length > 1) {
        final secondPlace = registrations.docs[1];
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(secondPlace.data()['userId']);
        batch.update(userRef, {
          'coins': FieldValue.increment(secondPrize),
        });
      }

      // Third place
      if (registrations.docs.length > 2) {
        final thirdPlace = registrations.docs[2];
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(thirdPlace.data()['userId']);
        batch.update(userRef, {
          'coins': FieldValue.increment(thirdPrize),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Prizes distributed successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error distributing prizes: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteDialog(Tournament tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Delete Tournament'),
          ],
        ),
        content: Text('Are you sure you want to delete "${tournament.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTournament(tournament);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTournament(Tournament tournament) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Tournament deleted'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error deleting tournament: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForceEndDialog(Tournament tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.flag, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Force End Tournament'),
          ],
        ),
        content: Text('Are you sure you want to force end "${tournament.title}"? This will set its status to completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _forceEndTournament(tournament);
            },
            child: const Text('Force End'),
          ),
        ],
      ),
    );
  }

  Future<void> _forceEndTournament(Tournament tournament) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('tournaments').doc(tournament.id).update({'status': 'completed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.flag, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Tournament forcibly ended'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Error force ending tournament: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Tournaments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateTournamentScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Dashboard
          _StatisticsDashboard(),
          // Status Filter
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.85),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
            ),
            child: Row(
              children: _statuses.map((status) {
                final isSelected = _selectedStatus == status;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedStatus = status);
                      },
                      backgroundColor: Theme.of(context).cardColor,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      checkmarkColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Tournaments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedStatus == 'all'
                  ? FirebaseFirestore.instance.collection('tournaments').snapshots()
                  : FirebaseFirestore.instance
                      .collection('tournaments')
                      .where('status', isEqualTo: _selectedStatus)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tournaments = snapshot.data!.docs
                    .map((doc) => Tournament.fromMap(doc.data() as Map<String, dynamic>, doc.id))
                    .toList()
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));

                if (tournaments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.tour,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tournaments found',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final tournament = tournaments[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              tournament.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${tournament.game} - ${tournament.type}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            trailing: _buildStatusChip(tournament.status),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TournamentDetailScreen(tournament: tournament),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${tournament.filledSlots}/${tournament.totalSlots} slots',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  '${tournament.entryFee} coins',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (tournament.status == 'upcoming') ...[
                                  _buildActionButton(
                                    icon: Icons.play_arrow,
                                    label: 'Start',
                                    onPressed: () => _updateTournamentStatus(tournament, 'live'),
                                  ),
                                ],
                                if (tournament.status == 'live') ...[
                                  _buildActionButton(
                                    icon: Icons.stop,
                                    label: 'End',
                                    onPressed: () => _updateTournamentStatus(tournament, 'completed'),
                                  ),
                                ],
                                if (tournament.status == 'completed') ...[
                                  _buildActionButton(
                                    icon: Icons.attach_money,
                                    label: 'Distribute Prizes',
                                    onPressed: () => _distributePrizes(tournament),
                                  ),
                                ],
                                if (tournament.status != 'completed') ...[
                                  _buildActionButton(
                                    icon: Icons.flag,
                                    label: 'Force End',
                                    onPressed: () => _showForceEndDialog(tournament),
                                  ),
                                ],
                                _buildActionButton(
                                  icon: Icons.delete,
                                  label: 'Delete',
                                  onPressed: () => _showDeleteDialog(tournament),
                                ),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  label: 'Edit',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CreateTournamentScreen(
                                          tournament: tournament,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.people,
                                  label: 'Participants',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TournamentParticipantsScreen(
                                          tournament: tournament,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'upcoming':
        color = Colors.blue;
        break;
      case 'live':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatisticsDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        final stats = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  _StatCard(
                    label: 'Tournaments',
                    value: stats['totalTournaments'].toString(),
                    icon: Icons.emoji_events,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Participants',
                    value: stats['totalParticipants'].toString(),
                    icon: Icons.people,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Prize Pool',
                    value: '${stats['totalPrizePool']} coins',
                    icon: Icons.attach_money,
                    color: Colors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if ((stats['topWinners'] as List).isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.leaderboard, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Top Winners', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate((stats['topWinners'] as List).length, (i) {
                        final winner = stats['topWinners'][i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(child: Text('${i + 1}')), // Rank
                              const SizedBox(width: 8),
                              Expanded(child: Text(winner['username'] ?? 'Unknown')),
                              Text('${winner['wins']} wins', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if ((stats['tournamentCounts'] as Map).isNotEmpty)
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (stats['tournamentCounts'].values as Iterable<int>).fold<int>(0, (a, b) => a > b ? a : b).toDouble() + 2,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final keys = stats['tournamentCounts'].keys.toList();
                              if (value.toInt() < 0 || value.toInt() >= keys.length) return const SizedBox();
                              return Text(keys[value.toInt()].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(stats['tournamentCounts'].length, (i) {
                        final count = stats['tournamentCounts'].values.toList()[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              width: 18,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final tournamentsSnap = await FirebaseFirestore.instance.collection('tournaments').get();
    final tournaments = tournamentsSnap.docs;
    final totalTournaments = tournaments.length;
    int totalParticipants = 0;
    int totalPrizePool = 0;
    Map<String, int> winnerCounts = {};
    Map<String, String> winnerNames = {};
    Map<String, int> tournamentCounts = {'upcoming': 0, 'live': 0, 'completed': 0};
    for (final doc in tournaments) {
      final data = doc.data() as Map<String, dynamic>;
      totalPrizePool += data['prizePool'] ?? 0;
      tournamentCounts[data['status'] ?? 'upcoming'] = (tournamentCounts[data['status'] ?? 'upcoming'] ?? 0) + 1;
      // Count participants
      final regSnap = await FirebaseFirestore.instance.collection('tournaments').doc(doc.id).collection('registrations').get();
      totalParticipants += regSnap.docs.length;
      // Count winners
      if (data['winners'] != null && data['winners'] is List) {
        for (final winnerId in List<String>.from(data['winners'])) {
          winnerCounts[winnerId] = (winnerCounts[winnerId] ?? 0) + 1;
        }
      }
    }
    // Fetch winner usernames
    for (final winnerId in winnerCounts.keys) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(winnerId).get();
      winnerNames[winnerId] = userDoc.data()?['username'] ?? 'Unknown';
    }
    // Top winners
    final topWinners = winnerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topWinnersList = topWinners.take(3).map((e) => {
      'userId': e.key,
      'username': winnerNames[e.key],
      'wins': e.value,
    }).toList();
    return {
      'totalTournaments': totalTournaments,
      'totalParticipants': totalParticipants,
      'totalPrizePool': totalPrizePool,
      'topWinners': topWinnersList,
      'tournamentCounts': tournamentCounts,
    };
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
} 