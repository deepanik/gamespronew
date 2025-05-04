import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_pro/models/tournament.dart';
import 'package:games_pro/models/tournament_registration.dart';
import 'package:games_pro/models/wallet_transaction.dart';
import 'package:games_pro/models/app_user.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final Tournament tournament;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
  });

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isRegistered = false;
  AppUser? _currentUser;
  late ConfettiController _confettiController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  // Payment modal state
  int _selectedPaymentMethod = 0; // 0: Wallet, 1: UPI/Bank
  File? _paymentImage;
  final TextEditingController _utrController = TextEditingController();
  bool _isUploading = false;

  // Cloudinary config
  final String _cloudName = 'YOUR_CLOUD_NAME';
  final String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkRegistration();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animationController.dispose();
    super.dispose();
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

      _confettiController.play();
      _animationController.forward(from: 0.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Successfully joined the tournament'),
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
                Text(e.toString()),
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

  void _showPaymentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Payment Method', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Radio<int>(
                          value: 0,
                          groupValue: _selectedPaymentMethod,
                          onChanged: (v) => setModalState(() => _selectedPaymentMethod = v!),
                        ),
                        const Text('Wallet'),
                        const SizedBox(width: 24),
                        Radio<int>(
                          value: 1,
                          groupValue: _selectedPaymentMethod,
                          onChanged: (v) => setModalState(() => _selectedPaymentMethod = v!),
                        ),
                        const Text('Direct UPI/Bank Transfer'),
                      ],
                    ),
                    if (_selectedPaymentMethod == 1) ...[
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            setModalState(() => _paymentImage = File(picked.path));
                          }
                        },
                        child: _paymentImage == null
                            ? Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                                ),
                                child: const Center(child: Text('Upload Payment Screenshot', style: TextStyle(fontWeight: FontWeight.w500))),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_paymentImage!, height: 120, width: double.infinity, fit: BoxFit.cover),
                              ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _utrController,
                        decoration: InputDecoration(
                          labelText: 'Enter UTR Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isUploading
                            ? null
                            : () async {
                                if (_selectedPaymentMethod == 0) {
                                  Navigator.pop(context);
                                  _joinTournament();
                                } else {
                                  if (_paymentImage == null || _utrController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please upload image and enter UTR number')),
                                    );
                                    return;
                                  }
                                  setModalState(() => _isUploading = true);
                                  final url = await _uploadToCloudinary(_paymentImage!);
                                  setModalState(() => _isUploading = false);
                                  if (url != null) {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      await FirebaseFirestore.instance
                                        .collection('tournaments')
                                        .doc(widget.tournament.id)
                                        .collection('paymentProofs')
                                        .doc(user.uid)
                                        .set({
                                          'utr': _utrController.text,
                                          'imageUrl': url,
                                          'userId': user.uid,
                                          'submittedAt': FieldValue.serverTimestamp(),
                                        });
                                    }
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Payment proof submitted!')), 
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Image upload failed')), 
                                    );
                                  }
                                }
                              },
                        child: _isUploading
                            ? const CircularProgressIndicator.adaptive()
                            : Text(_selectedPaymentMethod == 0 ? 'Pay & Join' : 'Submit Payment Proof'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _cancelRegistration() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final tournamentRef = FirebaseFirestore.instance.collection('tournaments').doc(widget.tournament.id);
      final registrationRef = tournamentRef.collection('registrations').doc(_currentUser!.uid);
      final userRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(registrationRef);
      batch.update(tournamentRef, {'filledSlots': FieldValue.increment(-1)});
      batch.update(userRef, {'coins': FieldValue.increment(widget.tournament.entryFee)});
      await batch.commit();
      setState(() {
        _isRegistered = false;
        _currentUser = _currentUser!.copyWith(coins: _currentUser!.coins + widget.tournament.entryFee);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration cancelled and coins refunded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel registration: $e')),
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
        title: Text(widget.tournament.title),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(top: 32, bottom: 16),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    child: Text(
                      widget.tournament.title.isNotEmpty ? widget.tournament.title[0].toUpperCase() : '?',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tournament.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.tournament.game} - ${widget.tournament.type}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Entry Fee', style: Theme.of(context).textTheme.bodySmall),
                                Text('${widget.tournament.entryFee} coins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Prize Pool', style: Theme.of(context).textTheme.bodySmall),
                                Text('${widget.tournament.prizePool} coins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                                Text('Slots', style: Theme.of(context).textTheme.bodySmall),
                                Text('${widget.tournament.filledSlots}/${widget.tournament.totalSlots}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Map', style: Theme.of(context).textTheme.bodySmall),
                                Text(widget.tournament.map, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Rules', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(widget.tournament.rules, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        if (widget.tournament.sponsor != null) ...[
                          Text('Sponsored by', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(widget.tournament.sponsor!, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 16),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _isRegistered
                              ? Column(
                                  children: [
                                    ScaleTransition(
                                      scale: _scaleAnimation,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.withOpacity(0.2),
                                              Colors.green.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.green),
                                            const SizedBox(width: 8),
                                            Text(
                                              'You are registered!',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.withOpacity(0.7),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: _isLoading ? null : _cancelRegistration,
                                        child: _isLoading 
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text('Cancel Registration'),
                                      ),
                                    ),
                                    // Private match details
                                    if (widget.tournament.roomCode != null && widget.tournament.roomPassword != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                              Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                            ],
                                          ),
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
                                                Icon(Icons.vpn_key, color: Theme.of(context).colorScheme.primary),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Private Match Details',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            _buildCopyableText(
                                              'Room Code: ${widget.tournament.roomCode}',
                                              widget.tournament.roomCode!,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildCopyableText(
                                              'Room Password: ${widget.tournament.roomPassword}',
                                              widget.tournament.roomPassword!,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    // Watch button
                                    if (widget.tournament.youtubeLink != null && widget.tournament.youtubeLink!.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () async {
                                            final url = widget.tournament.youtubeLink!;
                                            if (await canLaunchUrl(Uri.parse(url))) {
                                              await launchUrl(Uri.parse(url));
                                            } else {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Could not launch YouTube')),
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.play_circle_outline),
                                          label: const Text('Watch on YouTube'),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _showPaymentModal,
                                    child: const Text('Join Tournament'),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableText(String label, String value) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.copy, color: Colors.white),
                const SizedBox(width: 8),
                Text('$label copied to clipboard'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              Icons.copy,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
} 