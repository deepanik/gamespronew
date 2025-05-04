import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key});

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form fields
  String _title = '';
  String _game = '';
  String _type = '';
  String _description = '';
  String _rules = '';
  int _entryFee = 0;
  int _prizePool = 0;
  int _slots = 0;
  DateTime _startTime = DateTime.now();

  final List<String> _games = ['Free Fire', 'PUBG Mobile', 'Call of Duty Mobile', 'BGMI'];
  final List<String> _types = ['Solo', 'Duo', 'Squad'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Tournament Title'),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter a title' : null,
              onSaved: (value) => _title = value ?? '',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Game'),
              value: _game.isEmpty ? null : _game,
              items: _games.map((game) => DropdownMenuItem(
                value: game,
                child: Text(game),
              )).toList(),
              validator: (value) => value == null ? 'Please select a game' : null,
              onChanged: (value) => setState(() => _game = value ?? ''),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Type'),
              value: _type.isEmpty ? null : _type,
              items: _types.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              )).toList(),
              validator: (value) => value == null ? 'Please select a type' : null,
              onChanged: (value) => setState(() => _type = value ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Please enter a description' : null,
              onSaved: (value) => _description = value ?? '',
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Rules'),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Please enter rules' : null,
              onSaved: (value) => _rules = value ?? '',
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Entry Fee (Coins)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter entry fee';
                final fee = int.tryParse(value!);
                if (fee == null || fee < 0) return 'Please enter a valid amount';
                return null;
              },
              onSaved: (value) => _entryFee = int.parse(value ?? '0'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Prize Pool (Coins)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter prize pool';
                final pool = int.tryParse(value!);
                if (pool == null || pool < 0) return 'Please enter a valid amount';
                return null;
              },
              onSaved: (value) => _prizePool = int.parse(value ?? '0'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Number of Slots'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Please enter number of slots';
                final slots = int.tryParse(value!);
                if (slots == null || slots < 2) return 'Please enter at least 2 slots';
                return null;
              },
              onSaved: (value) => _slots = int.parse(value ?? '0'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_startTime.toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startTime,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_startTime),
                  );
                  if (time != null) {
                    setState(() {
                      _startTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTournament,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Tournament'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final tournament = Tournament(
        id: '',
        title: _title,
        game: _game,
        imageUrl: '', // Add a default image URL or handle image upload
        type: _type,
        description: _description,
        rules: _rules,
        entryFee: _entryFee,
        prizePool: _prizePool,
        totalSlots: _slots,
        filledSlots: 0,
        startTime: _startTime,
        status: 'upcoming',
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
        createdAt: DateTime.now(),
        map: 'Default', // Add a default map
        prizeDistribution: 0,
      );

      final docRef = await FirebaseFirestore.instance.collection('tournaments').add(tournament.toMap());
      
      // Update the tournament with its ID
      await docRef.update({'id': docRef.id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament created successfully')),
        );
        _formKey.currentState!.reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating tournament: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
} 