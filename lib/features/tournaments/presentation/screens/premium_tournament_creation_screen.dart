import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PremiumTournamentCreationScreen extends StatefulWidget {
  const PremiumTournamentCreationScreen({super.key});

  @override
  State<PremiumTournamentCreationScreen> createState() => _PremiumTournamentCreationScreenState();
}

class _PremiumTournamentCreationScreenState extends State<PremiumTournamentCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _streamUrlController = TextEditingController();
  final _minTeamSizeController = TextEditingController(text: '1');
  final _maxTeamSizeController = TextEditingController(text: '10');
  
  DateTime? _startDate;
  TimeOfDay? _startTime;
  String _selectedGame = 'Free Fire';
  String _selectedFormat = 'Single Elimination';
  String _selectedType = 'Public';
  String _registrationType = 'Solo'; // 'Solo' or 'Team-based'
  File? _bannerImage;
  bool _isLoading = false;
  
  final List<String> _games = [
    'Free Fire',
    'PUBG Mobile',
    'Call of Duty Mobile',
    'BGMI',
    'Valorant',
    'CS:GO',
    'Dota 2',
    'League of Legends',
  ];
  
  final List<String> _formats = [
    'Single Elimination',
    'Double Elimination',
    'Round Robin',
    'Swiss System',
    'Battle Royale',
  ];
  
  final List<String> _types = [
    'Public',
    'Private',
    'Invite Only',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prizePoolController.dispose();
    _entryFeeController.dispose();
    _maxParticipantsController.dispose();
    _streamUrlController.dispose();
    _minTeamSizeController.dispose();
    _maxTeamSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickBannerImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bannerImage = File(picked.path));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start date and time')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      // TODO: Upload banner image to storage and get URL

      await FirebaseFirestore.instance.collection('tournaments').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'game': _selectedGame,
        'format': _selectedFormat,
        'type': _selectedType,
        'prizePool': double.parse(_prizePoolController.text),
        'entryFee': double.parse(_entryFeeController.text),
        'maxParticipants': int.parse(_maxParticipantsController.text),
        'startTime': startDateTime,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'upcoming',
        'participants': [],
        'bracket': _generateInitialBracket(),
        'streamUrl': _streamUrlController.text.trim(),
        'registrationType': _registrationType,
        'minTeamSize': _registrationType == 'Team-based' ? int.parse(_minTeamSizeController.text) : null,
        'maxTeamSize': _registrationType == 'Team-based' ? int.parse(_maxTeamSizeController.text) : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament created successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating tournament: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _generateInitialBracket() {
    // Generate initial bracket structure based on format
    return {
      'format': _selectedFormat,
      'rounds': [],
      'matches': [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _createTournament,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBannerSection(),
                  const SizedBox(height: 24),
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildTournamentDetailsSection(),
                  const SizedBox(height: 24),
                  _buildPrizeAndEntrySection(),
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                  const SizedBox(height: 32),
                  _buildCreateButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBannerSection() {
    return GestureDetector(
      onTap: _pickBannerImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          image: _bannerImage != null
              ? DecorationImage(
                  image: FileImage(_bannerImage!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _bannerImage == null
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 48),
                    SizedBox(height: 8),
                    Text('Add Tournament Banner'),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Tournament Title',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _streamUrlController,
          decoration: const InputDecoration(
            labelText: 'Live Stream URL (YouTube/Twitch)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.live_tv),
          ),
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildTournamentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tournament Details',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Registration Type:'),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('Solo'),
              selected: _registrationType == 'Solo',
              onSelected: (selected) {
                if (selected) setState(() => _registrationType = 'Solo');
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Team-based'),
              selected: _registrationType == 'Team-based',
              onSelected: (selected) {
                if (selected) setState(() => _registrationType = 'Team-based');
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedGame,
          decoration: const InputDecoration(
            labelText: 'Game',
            border: OutlineInputBorder(),
          ),
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
          value: _selectedFormat,
          decoration: const InputDecoration(
            labelText: 'Tournament Format',
            border: OutlineInputBorder(),
          ),
          items: _formats.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Text(format),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedFormat = value);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: const InputDecoration(
            labelText: 'Tournament Type',
            border: OutlineInputBorder(),
          ),
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
    );
  }

  Widget _buildPrizeAndEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prize Pool & Entry',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _prizePoolController,
          decoration: const InputDecoration(
            labelText: 'Prize Pool (\$)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter prize pool';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _entryFeeController,
          decoration: const InputDecoration(
            labelText: 'Entry Fee (\$)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.payment),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter entry fee';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _maxParticipantsController,
          decoration: const InputDecoration(
            labelText: 'Max Participants',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter max participants';
            }
            if (int.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        if (_registrationType == 'Team-based') ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minTeamSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Min Team Size',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter min size';
                    }
                    final min = int.tryParse(value);
                    final max = int.tryParse(_maxTeamSizeController.text);
                    if (min == null || min < 1) {
                      return 'Invalid min size';
                    }
                    if (max != null && min > max) {
                      return 'Min > Max';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _maxTeamSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Max Team Size',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter max size';
                    }
                    final max = int.tryParse(value);
                    final min = int.tryParse(_minTeamSizeController.text);
                    if (max == null || max < 1) {
                      return 'Invalid max size';
                    }
                    if (min != null && max < min) {
                      return 'Max < Min';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Start Date'),
          subtitle: Text(
            _startDate == null
                ? 'Select date'
                : DateFormat('MMMM d, y').format(_startDate!),
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: _selectDate,
        ),
        ListTile(
          title: const Text('Start Time'),
          subtitle: Text(
            _startTime == null
                ? 'Select time'
                : _startTime!.format(context),
          ),
          trailing: const Icon(Icons.access_time),
          onTap: _selectTime,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createTournament,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Create Tournament',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
} 