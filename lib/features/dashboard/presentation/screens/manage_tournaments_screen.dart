import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';

class ManageTournamentsScreen extends ConsumerStatefulWidget {
  const ManageTournamentsScreen({super.key});

  @override
  ConsumerState<ManageTournamentsScreen> createState() => _ManageTournamentsScreenState();
}

class _ManageTournamentsScreenState extends ConsumerState<ManageTournamentsScreen> {
  String _selectedStatus = 'upcoming';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Filter by Status',
              border: OutlineInputBorder(),
            ),
            items: ['upcoming', 'ongoing', 'completed'].map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status[0].toUpperCase() + status.substring(1)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedStatus = value);
              }
            },
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
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final tournaments = snapshot.data?.docs ?? [];
              if (tournaments.isEmpty) {
                return const Center(child: Text('No tournaments found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tournamentSnapshot = tournaments[index];
                  final tournament = Tournament.fromMap(
                    tournamentSnapshot.data() as Map<String, dynamic>,
                    tournamentSnapshot.id,
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  tournament.title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) => _handleAction(value, tournament),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                  if (tournament.status == 'upcoming')
                                    const PopupMenuItem(
                                      value: 'start',
                                      child: Text('Start Tournament'),
                                    ),
                                  if (tournament.status == 'ongoing')
                                    const PopupMenuItem(
                                      value: 'end',
                                      child: Text('End Tournament'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Game: ${tournament.game}'),
                          Text('Type: ${tournament.type}'),
                          Text('Entry Fee: ${tournament.entryFee} coins'),
                          Text('Prize Pool: ${tournament.prizePool} coins'),
                          Text('Slots: ${tournament.availableSlots}/${tournament.totalSlots}'),
                          Text('Start Time: ${tournament.startTime.toString()}'),
                          Text('End Time: ${tournament.endTime.toString()}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _viewParticipants(tournament),
                            child: const Text('View Participants'),
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
      ],
    );
  }

  Future<void> _handleAction(String action, Tournament tournament) async {
    switch (action) {
      case 'edit':
        // TODO: Implement edit tournament
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Tournament'),
            content: const Text('Are you sure you want to delete this tournament?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(tournament.id)
                .delete();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tournament deleted successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting tournament: $e')),
              );
            }
          }
        }
        break;
      case 'start':
        try {
          await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournament.id)
              .update({'status': 'ongoing'});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tournament started successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error starting tournament: $e')),
            );
          }
        }
        break;
      case 'end':
        // TODO: Navigate to results screen
        break;
    }
  }

  Future<void> _viewParticipants(Tournament tournament) async {
    final participants = await FirebaseFirestore.instance
        .collection('tournamentRegistrations')
        .where('tournamentId', isEqualTo: tournament.id)
        .get();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Participants - ${tournament.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: participants.docs.length,
            itemBuilder: (context, index) {
              final registration = participants.docs[index].data();
              return ListTile(
                title: Text(registration['username']),
                subtitle: Text('Registered at: ${registration['registeredAt'].toDate()}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 