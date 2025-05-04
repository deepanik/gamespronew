import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form fields
  String _title = '';
  String _body = '';
  String _type = 'all'; // all, tournament, announcement
  String? _tournamentId;

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
              decoration: const InputDecoration(labelText: 'Notification Title'),
              validator: (value) => value?.isEmpty ?? true ? 'Please enter a title' : null,
              onSaved: (value) => _title = value ?? '',
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Notification Body'),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Please enter a message' : null,
              onSaved: (value) => _body = value ?? '',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Notification Type'),
              value: _type,
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All Users'),
                ),
                DropdownMenuItem(
                  value: 'tournament',
                  child: Text('Tournament Participants'),
                ),
                DropdownMenuItem(
                  value: 'announcement',
                  child: Text('Announcement'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            if (_type == 'tournament') ...[
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tournaments')
                    .where('status', isEqualTo: 'upcoming')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  final tournaments = snapshot.data?.docs ?? [];
                  if (tournaments.isEmpty) {
                    return const Text('No upcoming tournaments found');
                  }

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Tournament'),
                    value: _tournamentId,
                    items: tournaments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Text(data['title']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _tournamentId = value);
                      }
                    },
                    validator: (value) {
                      if (_type == 'tournament' && (value == null || value.isEmpty)) {
                        return 'Please select a tournament';
                      }
                      return null;
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendNotification,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Send Notification'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final notifications = snapshot.data?.docs ?? [];
                if (notifications.isEmpty) {
                  return const Text('No notifications sent yet');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(notification['title']),
                        subtitle: Text(notification['body']),
                        trailing: Text(
                          notification['createdAt'].toDate().toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      // Get target device tokens
      final tokens = await _getTargetDeviceTokens();

      if (tokens.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No target users found')),
          );
        }
        return;
      }

      // Send notification to each device
      for (final token in tokens) {
        await FirebaseMessaging.instance.sendMessage(
          data: {
            'title': _title,
            'body': _body,
            'type': _type,
            if (_tournamentId != null) 'tournamentId': _tournamentId!,
          },
        );
      }

      // Save notification to Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _title,
        'body': _body,
        'type': _type,
        if (_tournamentId != null) 'tournamentId': _tournamentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification sent successfully')),
        );
        _formKey.currentState!.reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending notification: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<String>> _getTargetDeviceTokens() async {
    final query = FirebaseFirestore.instance.collection('users');

    switch (_type) {
      case 'all':
        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => doc.data()['deviceId'] as String?)
            .where((token) => token != null)
            .cast<String>()
            .toList();

      case 'tournament':
        if (_tournamentId == null) return [];
        final registrations = await FirebaseFirestore.instance
            .collection('tournamentRegistrations')
            .where('tournamentId', isEqualTo: _tournamentId)
            .get();
        final userIds = registrations.docs.map((doc) => doc.data()['userId'] as String).toList();
        final users = await query.where('uid', whereIn: userIds).get();
        return users.docs
            .map((doc) => doc.data()['deviceId'] as String?)
            .where((token) => token != null)
            .cast<String>()
            .toList();

      default:
        return [];
    }
  }
} 