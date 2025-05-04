import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:games_pro/models/tournament_registration.dart';
import 'package:games_pro/models/wallet_transaction.dart';
import 'package:games_pro/models/app_user.dart';

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  bool _isLoading = false;
  bool _isRegistered = false;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkRegistration();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _currentUser = AppUser.fromMap(userDoc.data()!);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _checkRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final registrationDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .collection('registrations')
          .doc(user.uid)
          .get();

      setState(() {
        _isRegistered = registrationDoc.exists;
      });
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _joinTournament() async {
    if (_currentUser == null) return;

    setState(() => _isLoading = true);

    try {
      // Check if tournament is full
      if (widget.tournament.filledSlots >= widget.tournament.totalSlots) {
        throw Exception('Tournament is full');
      }

      // Check if user has enough coins
      if (_currentUser!.coins < widget.tournament.entryFee) {
        throw Exception('Insufficient coins');
      }

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      // Update tournament filled slots
      final tournamentRef = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id);
      batch.update(tournamentRef, {
        'filledSlots': FieldValue.increment(1),
      });

      // Create registration
      final registration = TournamentRegistration(
        id: '',
        userId: _currentUser!.uid,
        tournamentId: widget.tournament.id,
        username: _currentUser!.username,
        registeredAt: DateTime.now(),
      );

      final registrationRef = tournamentRef
          .collection('registrations')
          .doc(_currentUser!.uid);
      batch.set(registrationRef, registration.toMap());

      // Update user coins
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);
      batch.update(userRef, {
        'coins': FieldValue.increment(-widget.tournament.entryFee),
      });

      // Create wallet transaction
      final transaction = WalletTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        uid: _currentUser!.uid,
        amount: -widget.tournament.entryFee,
        type: 'spend',
        description: 'Tournament entry fee: ${widget.tournament.title}',
        timestamp: DateTime.now(),
      );

      final transactionRef = FirebaseFirestore.instance
          .collection('walletTransactions')
          .doc(transaction.id);
      batch.set(transactionRef, transaction.toMap());

      // Commit the batch
      await batch.commit();

      setState(() {
        _isRegistered = true;
        _currentUser = _currentUser!.copyWith(
          coins: _currentUser!.coins - widget.tournament.entryFee,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the tournament')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournament.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.network(
              widget.tournament.imageUrl,
              height: 200,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.tournament.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.tournament.game} - ${widget.tournament.type}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Entry Fee',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${widget.tournament.entryFee} coins',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Prize Pool',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${widget.tournament.prizePool} coins',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Slots',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${widget.tournament.filledSlots}/${widget.tournament.totalSlots}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Map',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            widget.tournament.map,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Rules',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.tournament.rules),
                  const SizedBox(height: 16),
                  if (widget.tournament.sponsor != null) ...[
                    Text(
                      'Sponsored by',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(widget.tournament.sponsor!),
                    const SizedBox(height: 16),
                  ],
                  if (!_isRegistered && widget.tournament.status == 'upcoming')
                    ElevatedButton(
                      onPressed: _isLoading ? null : _joinTournament,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Join Tournament'),
                    ),
                  if (_isRegistered)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'You are registered for this tournament',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 