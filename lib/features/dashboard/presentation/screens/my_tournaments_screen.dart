import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:games_pro/models/tournament_registration.dart';
import 'package:games_pro/features/auth/providers/auth_provider.dart';

class MyTournamentsScreen extends ConsumerWidget {
  const MyTournamentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Center(child: Text('Please sign in to view your tournaments'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournamentRegistrations')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final registrations = snapshot.data?.docs ?? [];
        if (registrations.isEmpty) {
          return const Center(child: Text('You have not registered for any tournaments yet'));
        }

        return ListView.builder(
          itemCount: registrations.length,
          itemBuilder: (context, index) {
            final registration = TournamentRegistration.fromMap(
              registrations[index].data() as Map<String, dynamic>,
              registrations[index].id,
            );

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(registration.tournamentId)
                  .get(),
              builder: (context, tournamentSnapshot) {
                if (tournamentSnapshot.hasError) {
                  return ListTile(
                    title: Text('Error loading tournament: ${tournamentSnapshot.error}'),
                  );
                }

                if (tournamentSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: CircularProgressIndicator(),
                  );
                }

                final tournament = Tournament.fromMap(
                  tournamentSnapshot.data?.data() as Map<String, dynamic>,
                  tournamentSnapshot.data?.id ?? '',
                );

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(tournament.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Game: ${tournament.game}'),
                        Text('Type: ${tournament.type}'),
                        Text('Status: ${tournament.status}'),
                        Text('Start Time: ${tournament.startTime.toLocal()}'),
                      ],
                    ),
                    trailing: Text('Entry Fee: \$${tournament.entryFee}'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
} 