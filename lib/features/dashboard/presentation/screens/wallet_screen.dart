import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:games_pro/models/wallet_transaction.dart';
import 'package:games_pro/models/app_user.dart';
import 'package:intl/intl.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  AppUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddCoinsModal() {
    final TextEditingController _amountController = TextEditingController();
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Coins', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final amount = int.tryParse(_amountController.text.trim());
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid amount')),
                        );
                        return;
                      }
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                      await userRef.update({'coins': FieldValue.increment(amount)});
                      final transaction = WalletTransaction(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        uid: user.uid,
                        amount: amount,
                        type: 'earn',
                        description: 'Coins added',
                        timestamp: DateTime.now(),
                      );
                      await FirebaseFirestore.instance
                        .collection('walletTransactions')
                        .doc(transaction.id)
                        .set(transaction.toMap());
                      if (mounted) {
                        Navigator.pop(context);
                        setState(() {
                          if (_currentUser != null) {
                            _currentUser = _currentUser!.copyWith(coins: _currentUser!.coins + amount);
                          }
                        });
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.celebration, color: Theme.of(context).colorScheme.primary, size: 64),
                                const SizedBox(height: 16),
                                Text('Coins Added!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Your wallet has been updated.', textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Add Coins'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Available Balance',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_currentUser?.coins ?? 0} coins',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.7),
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                onPressed: _showAddCoinsModal,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Coins'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.7),
                                  foregroundColor: Colors.green,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  // TODO: Implement withdraw
                                },
                                icon: const Icon(Icons.money_off),
                                label: const Text('Withdraw'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('walletTransactions')
                          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: \\${snapshot.error}', style: const TextStyle(color: Colors.white)));
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final transactions = snapshot.data!.docs
                            .map((doc) => WalletTransaction.fromMap(
                                doc.data() as Map<String, dynamic>, doc.id))
                            .toList();

                        if (transactions.isEmpty) {
                          return const Center(
                            child: Text('No transactions found', style: TextStyle(color: Colors.white70)),
                          );
                        }

                        return ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = transactions[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                  width: 1.2,
                                ),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  transaction.type == 'earn'
                                      ? Icons.add_circle
                                      : Icons.remove_circle,
                                  color: transaction.type == 'earn'
                                      ? Colors.green
                                      : Colors.red,
                                  size: 32,
                                ),
                                title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  DateFormat('MMM dd, yyyy HH:mm').format(transaction.timestamp),
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                trailing: Text(
                                  '\\${transaction.type == 'earn' ? '+' : '-'}${transaction.amount}',
                                  style: TextStyle(
                                    color: transaction.type == 'earn'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
} 