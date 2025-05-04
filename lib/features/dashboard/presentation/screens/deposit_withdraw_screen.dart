import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

class DepositWithdrawScreen extends StatefulWidget {
  const DepositWithdrawScreen({super.key});

  @override
  State<DepositWithdrawScreen> createState() => _DepositWithdrawScreenState();
}

class _DepositWithdrawScreenState extends State<DepositWithdrawScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double? _depositAmount;
  bool _isSubmitting = false;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _utrController = TextEditingController();
  File? _paymentImage;
  bool _isUploadingProof = false;
  final String _cloudName = 'YOUR_CLOUD_NAME';
  final String _uploadPreset = 'YOUR_UPLOAD_PRESET';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit & Withdraw'),
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.2),
          ),
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(text: 'Deposit'),
            Tab(text: 'Withdraw'),
            Tab(text: 'Account'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildDepositTab(context),
            Center(child: Text('Withdraw (Coming soon)', style: TextStyle(color: Colors.white))),
            Center(child: Text('Account (Coming soon)', style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Glassmorphic bank details card
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.13),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bank Name: BANK OF INDIA', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCopyRow(context, 'A/C No', '475810110007938'),
                _buildCopyRow(context, 'IFSC Code', 'BKID0004758'),
                _buildCopyRow(context, 'Account Name', 'DIPAK KUMAR RAJWAR'),
                const SizedBox(height: 8),
                Text('Min Amount: 300', style: Theme.of(context).textTheme.bodyMedium),
                Text('Max Amount: 500000', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info box
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: const Text(
              '1. Deposit money only in the above available accounts to get the fastest credits and avoid possible delays.\n'
              '2. Deposits made 45 minutes after the account removal from the site are valid & will be added to their wallets.\n'
              '3. Site is not responsible for money deposited to Old, Inactive or Closed accounts.\n'
              '4. After deposit, add your UTR and amount to receive balance.\n'
              '5. NEFT receiving time varies from 40 minutes to 2 hours.\n'
              '6. In case of account modification: payment valid for 1 hour after changing account details in deposit page.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 24),
          // Amount input and submit
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Enter amount',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.7),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    setState(() {
                      _depositAmount = double.tryParse(val);
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                onPressed: _isSubmitting ? null : () async {
                  if (_depositAmount == null || _depositAmount! < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')),
                    );
                    return;
                  }
                  setState(() => _isSubmitting = true);
                  // TODO: Replace with real userId
                  final userId = 'demoUser';
                  await FirebaseFirestore.instance.collection('deposits').add({
                    'userId': userId,
                    'amount': _depositAmount,
                    'status': 'PENDING',
                    'createdAt': DateTime.now(),
                  });
                  setState(() => _isSubmitting = false);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.celebration, color: Theme.of(context).colorScheme.primary, size: 64),
                          const SizedBox(height: 16),
                          Text('Deposit Submitted!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Your deposit request is pending review.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                  _amountController.clear();
                  setState(() => _depositAmount = null);
                },
                child: _isSubmitting ? const CircularProgressIndicator() : const Text('SUBMIT'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // UTR input and file upload
          TextField(
            controller: _utrController,
            decoration: InputDecoration(
              labelText: '6 to 12 Digit UTR Number',
              filled: true,
              fillColor: Colors.white.withOpacity(0.7),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            onPressed: _isUploadingProof ? null : () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              if (_utrController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter UTR number')),
                );
                return;
              }
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery);
              if (picked == null) return;
              setState(() => _isUploadingProof = true);
              final imageUrl = await _uploadToCloudinary(File(picked.path));
              setState(() => _isUploadingProof = false);
              if (imageUrl == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image upload failed')),
                );
                return;
              }
              // Find latest pending deposit for this user
              final deposits = await FirebaseFirestore.instance
                .collection('deposits')
                .where('userId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'PENDING')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
              if (deposits.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No pending deposit found. Please submit amount first.')),
                );
                return;
              }
              final depositDoc = deposits.docs.first.reference;
              await depositDoc.update({
                'utr': _utrController.text,
                'proofUrl': imageUrl,
                'status': 'UNDER_REVIEW',
              });
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.blue, size: 64),
                      const SizedBox(height: 16),
                      Text('Payment Proof Uploaded!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Your deposit is now under review.', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
              _utrController.clear();
              setState(() => _paymentImage = null);
            },
            icon: _isUploadingProof
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
            label: const Text('Upload Payment Proof'),
          ),
          const SizedBox(height: 32),
          // Transaction history table (mock)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.2,
              ),
            ),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.green.withOpacity(0.15)),
              columns: const [
                DataColumn(label: Text('TRANSACTION NO')),
                DataColumn(label: Text('AMOUNT')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('DATE')),
              ],
              rows: [
                _buildTransactionRow('512365897800', '300.00', 'APPROVED', '03-05-2025 09:15'),
                _buildTransactionRow('512364485515', '300.00', 'APPROVED', '03-05-2025 09:10'),
                _buildTransactionRow('512359565588', '300.00', 'APPROVED', '03-05-2025 08:55'),
                _buildTransactionRow('512141418564', '300.00', 'APPROVED', '01-05-2025 10:20'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied!')),
            );
          },
        ),
      ],
    );
  }

  DataRow _buildTransactionRow(String txn, String amount, String status, String date) {
    return DataRow(
      cells: [
        DataCell(Text(txn)),
        DataCell(Text(amount)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'APPROVED' ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == 'APPROVED' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Text(date)),
      ],
    );
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
} 