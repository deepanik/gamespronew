import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateTournamentScreen extends ConsumerStatefulWidget {
  final Tournament? tournament;
  const CreateTournamentScreen({Key? key, this.tournament}) : super(key: key);

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPrivate = false;
  File? _bannerImage;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();
  final TextEditingController _entryFeeController = TextEditingController();
  final TextEditingController _prizePoolController = TextEditingController();
  final TextEditingController _totalSlotsController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _roomPasswordController = TextEditingController();
  final TextEditingController _youtubeLinkController = TextEditingController();
  String _selectedGame = 'Free Fire';
  String _selectedType = 'Solo';
  String _selectedMap = 'Bermuda';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  DateTime? _startTime;
  String? _bannerUrl;

  // Cloudinary config
  final String _cloudName = 'YOUR_CLOUD_NAME';
  final String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  final List<String> _games = ['Free Fire', 'PUBG Mobile', 'Call of Duty Mobile', 'BGMI'];
  final List<String> _types = ['Solo', 'Duo', 'Squad'];
  final List<String> _maps = ['Bermuda', 'Purgatory', 'Kalahari', 'Alpine'];

  @override
  void initState() {
    super.initState();
    if (widget.tournament != null) {
      final t = widget.tournament!;
      _titleController.text = t.title;
      _descriptionController.text = t.description;
      _selectedGame = t.game;
      _selectedType = t.type;
      _selectedMap = t.map;
      _entryFeeController.text = t.entryFee.toString();
      _prizePoolController.text = t.prizePool.toString();
      _totalSlotsController.text = t.totalSlots.toString();
      _rulesController.text = t.rules;
      _roomCodeController.text = t.roomCode ?? '';
      _roomPasswordController.text = t.roomPassword ?? '';
      _youtubeLinkController.text = t.youtubeLink ?? '';
      _startTime = t.startTime;
      _bannerUrl = t.bannerUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    _totalSlotsController.dispose();
    _roomCodeController.dispose();
    _roomPasswordController.dispose();
    _youtubeLinkController.dispose();
    super.dispose();
  }

  Future<String?> _uploadToCloudinary(File imageFile) async {
    final url = 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final response = await request.send();
    if (response.statusCode == 200) {
      final res = await response.stream.bytesToString();
      final data = json.decode(res);
      return data['secure_url'];
    }
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bannerImage = File(picked.path));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveTournament() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? bannerUrl;
      if (_bannerImage != null) {
        bannerUrl = await _uploadToCloudinary(_bannerImage!);
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'game': _selectedGame,
        'type': _selectedType,
        'map': _selectedMap,
        'entryFee': int.tryParse(_entryFeeController.text.trim()) ?? 0,
        'prizePool': int.tryParse(_prizePoolController.text.trim()) ?? 0,
        'totalSlots': int.tryParse(_totalSlotsController.text.trim()) ?? 0,
        'rules': _rulesController.text.trim(),
        'startTime': DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        'status': 'upcoming',
        'bannerUrl': bannerUrl,
        'roomCode': _isPrivate ? _roomCodeController.text.trim() : null,
        'roomPassword': _isPrivate ? _roomPasswordController.text.trim() : null,
        'youtubeLink': _youtubeLinkController.text.trim().isEmpty ? null : _youtubeLinkController.text.trim(),
        'sponsor': null,
        'filledSlots': 0,
        'createdAt': DateTime.now(),
        'createdBy': '', // Set current admin UID if available
        'imageUrl': bannerUrl ?? '',
        'prizeDistribution': 0,
        'winners': [],
      };

      if (widget.tournament == null) {
        // Create new tournament
        await FirebaseFirestore.instance.collection('tournaments').add(data);
      } else {
        // Update existing tournament
        await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament!.id).update(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(widget.tournament == null ? 'Tournament created!' : 'Tournament updated!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Error: $e'),
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
        title: Text(widget.tournament == null ? 'Create Tournament' : 'Edit Tournament'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Image
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: _bannerImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Banner Image',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(_bannerImage!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Basic Info
            _buildSection(
              title: 'Basic Information',
              children: [
                _buildTextField(
                  controller: _titleController,
                  label: 'Tournament Title',
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 3,
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter a description' : null,
                ),
              ],
            ),

            // Game Details
            _buildSection(
              title: 'Game Details',
              children: [
                _buildDropdown(
                  value: _selectedGame,
                  items: _games,
                  onChanged: (value) => setState(() => _selectedGame = value!),
                  label: 'Game',
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  value: _selectedType,
                  items: _types,
                  onChanged: (value) => setState(() => _selectedType = value!),
                  label: 'Type',
                ),
                const SizedBox(height: 16),
                _buildDropdown(
                  value: _selectedMap,
                  items: _maps,
                  onChanged: (value) => setState(() => _selectedMap = value!),
                  label: 'Map',
                ),
              ],
            ),

            // Tournament Settings
            _buildSection(
              title: 'Tournament Settings',
              children: [
                _buildTextField(
                  controller: _entryFeeController,
                  label: 'Entry Fee (coins)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter entry fee';
                    if (int.tryParse(value!) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _prizePoolController,
                  label: 'Prize Pool (coins)',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter prize pool';
                    if (int.tryParse(value!) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _totalSlotsController,
                  label: 'Total Slots',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Please enter total slots';
                    if (int.tryParse(value!) == null) return 'Please enter a valid number';
                    return null;
                  },
                ),
              ],
            ),

            // Schedule
            _buildSection(
              title: 'Schedule',
              children: [
                ListTile(
                  title: Text('Date: ${_selectedDate.toString().split(' ')[0]}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _selectDate,
                ),
                ListTile(
                  title: Text('Time: ${_selectedTime.format(context)}'),
                  trailing: const Icon(Icons.access_time),
                  onTap: _selectTime,
                ),
              ],
            ),

            // Rules
            _buildSection(
              title: 'Rules',
              children: [
                _buildTextField(
                  controller: _rulesController,
                  label: 'Tournament Rules',
                  maxLines: 5,
                  validator: (value) => value?.isEmpty ?? true ? 'Please enter rules' : null,
                ),
              ],
            ),

            // Private Match Settings
            _buildSection(
              title: 'Private Match Settings',
              children: [
                SwitchListTile(
                  title: const Text('Private Match'),
                  value: _isPrivate,
                  onChanged: (value) => setState(() => _isPrivate = value),
                ),
                if (_isPrivate) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _roomCodeController,
                    label: 'Room Code',
                    validator: (value) => _isPrivate && (value?.isEmpty ?? true) ? 'Please enter room code' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _roomPasswordController,
                    label: 'Room Password',
                    validator: (value) => _isPrivate && (value?.isEmpty ?? true) ? 'Please enter room password' : null,
                  ),
                ],
              ],
            ),

            // YouTube Link
            _buildSection(
              title: 'Streaming',
              children: [
                _buildTextField(
                  controller: _youtubeLinkController,
                  label: 'YouTube Stream Link (Optional)',
                ),
              ],
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTournament,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.tournament == null ? 'Create Tournament' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String label,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }
} 