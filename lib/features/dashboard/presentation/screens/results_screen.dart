import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .where('status', isEqualTo: 'ongoing')
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
          return const Center(child: Text('No ongoing tournaments found'));
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
                    Text(
                      tournament.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Game: ${tournament.game}'),
                    Text('Type: ${tournament.type}'),
                    Text('Prize Pool: ${tournament.prizePool} coins'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _declareWinners(tournament),
                      child: const Text('Declare Winners'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _declareWinners(Tournament tournament) async {
    final participants = await FirebaseFirestore.instance
        .collection('tournamentRegistrations')
        .where('tournamentId', isEqualTo: tournament.id)
        .get();

    if (!mounted) return;

    final winners = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Declare Winners - ${tournament.title}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select winners (up to 3):'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: participants.docs.length,
                  itemBuilder: (context, index) {
                    final registration = participants.docs[index].data();
                    return CheckboxListTile(
                      title: Text(registration['username']),
                      value: false,
                      onChanged: (value) {
                        // TODO: Implement winner selection
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Return selected winners
              Navigator.pop(context, []);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (winners == null || winners.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update tournament status and winners
      batch.update(
        FirebaseFirestore.instance.collection('tournaments').doc(tournament.id),
        {
          'status': 'completed',
          'winners': winners,
        },
      );

      // Calculate prize distribution
      final prizeDistribution = _calculatePrizeDistribution(
        tournament.prizePool,
        winners.length,
      );

      // Update winners' wallet balances and create transactions
      for (var i = 0; i < winners.length; i++) {
        final winnerId = winners[i];
        final prizeAmount = prizeDistribution[i];

        // Get user document reference
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: winnerId)
            .get();

        if (userDoc.docs.isNotEmpty) {
          final userRef = userDoc.docs.first.reference;
          
          // Update wallet balance
          batch.update(
            userRef,
            {
              'walletBalance': FieldValue.increment(prizeAmount),
            },
          );

          // Create wallet transaction
          batch.set(
            FirebaseFirestore.instance.collection('walletTransactions').doc(),
            {
              'userId': winnerId,
              'amount': prizeAmount,
              'type': 'earn',
              'description': 'Prize money from ${tournament.title}',
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Winners declared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declaring winners: $e')),
        );
      }
    }
  }

  List<int> _calculatePrizeDistribution(int totalPrize, int numberOfWinners) {
    switch (numberOfWinners) {
      case 1:
        return [totalPrize];
      case 2:
        return [
          (totalPrize * 0.6).round(),
          (totalPrize * 0.4).round(),
        ];
      case 3:
        return [
          (totalPrize * 0.5).round(),
          (totalPrize * 0.3).round(),
          (totalPrize * 0.2).round(),
        ];
      default:
        return [];
    }
  }
} 