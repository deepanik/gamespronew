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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Available Balance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_currentUser?.coins ?? 0} coins',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement add coins
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Coins'),
                            ),
                            ElevatedButton.icon(
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                        return Center(child: Text('Error: ${snapshot.error}'));
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
                          child: Text('No transactions found'),
                        );
                      }

                      return ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = transactions[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: Icon(
                                transaction.type == 'earn'
                                    ? Icons.add_circle
                                    : Icons.remove_circle,
                                color: transaction.type == 'earn'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              title: Text(transaction.description),
                              subtitle: Text(
                                DateFormat('MMM dd, yyyy HH:mm')
                                    .format(transaction.timestamp),
                              ),
                              trailing: Text(
                                '${transaction.type == 'earn' ? '+' : '-'}${transaction.amount}',
                                style: TextStyle(
                                  color: transaction.type == 'earn'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
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
    );
  }
} 