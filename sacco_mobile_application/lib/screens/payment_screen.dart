import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  double _cashBalance = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final res = await ApiService.getUserSummary();
    if (mounted && res['success'] == true) {
      setState(() {
        final userData = res['data']['user'];
        _cashBalance = double.tryParse(userData['balance']?.toString() ?? '0') ?? 0.0;
      });
    }
  }

  String _formatCurrency(num amount) {
    final format = NumberFormat.currency(locale: 'en_US', symbol: 'UGX ', decimalDigits: 0);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Action / Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildPaymentGrid(context),
                  const SizedBox(height: 30),
                  const Text(
                    'Quick Pay Utilities',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildRecentPayees(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF009639), Color(0xFF00B84A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'Payments & Transfers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Available Cash Balance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _formatCurrency(_cashBalance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.3,
      children: [
        _buildPaymentCategory(context, Icons.swap_horiz, 'Transfer Money', const Color(0xFF009639), isRealTransfer: true),
        _buildPaymentCategory(context, Icons.phone_android, 'Airtime', const Color(0xFF00B84A)),
        _buildPaymentCategory(context, Icons.electric_bolt, 'Electricity', const Color(0xFF007A2E)),
        _buildPaymentCategory(context, Icons.water_drop, 'Water', const Color(0xFF009639)),
        _buildPaymentCategory(context, Icons.tv, 'TV Subscription', const Color(0xFF00B84A)),
        _buildPaymentCategory(context, Icons.school, 'School Fees', const Color(0xFF007A2E)),
      ],
    );
  }

  Widget _buildPaymentCategory(BuildContext context, IconData icon, String label, Color color, {bool isRealTransfer = false}) {
    return InkWell(
      onTap: () {
        if (isRealTransfer) {
          _showTransferSheet(context);
        } else {
          _showUtilityPaymentSheet(context, label);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 13,
                color: isRealTransfer ? const Color(0xFF007A2E) : Colors.black87
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPayees() {
    return Column(
      children: [
        _buildPayeeItem('NWSC Water', 'Utility', Icons.water_drop, const Color(0xFF009639)),
        _buildPayeeItem('Umeme Yaka', 'Utility', Icons.electric_bolt, const Color(0xFF00B84A)),
        _buildPayeeItem('MTN Airtime', 'Personal', Icons.phone_android, const Color(0xFF007A2E)),
      ],
    );
  }

  Widget _buildPayeeItem(String name, String type, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(type, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // Real Money Transfer bottom sheet
  void _showTransferSheet(BuildContext context) {
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    bool isTransferring = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 25,
            right: 25,
            top: 25,
            bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Transfer to Member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'Available Cash Balance: ${_formatCurrency(_cashBalance)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Recipient Email Address',
                  hintText: 'member@example.com',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Transfer Amount (UGX)',
                  prefixText: 'UGX ',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isTransferring
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final amountText = amountController.text.trim();

                          if (email.isEmpty || amountText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill in all fields.')),
                            );
                            return;
                          }

                          final amount = double.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid positive amount.')),
                            );
                            return;
                          }

                          if (amount > _cashBalance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Insufficient cash balance to make this transfer.')),
                            );
                            return;
                          }

                          setModalState(() {
                            isTransferring = true;
                          });

                          final res = await ApiService.transfer(email, amount);

                          if (mounted) {
                            setModalState(() {
                              isTransferring = false;
                            });

                            Navigator.pop(context);

                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Transfer successful!'),
                                  backgroundColor: const Color(0xFF009639),
                                ),
                              );
                              _loadBalance();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['error'] ?? 'Transfer failed.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009639),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isTransferring
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Initiate Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Utility mock payment sheet
  void _showUtilityPaymentSheet(BuildContext context, String title) {
    final accountController = TextEditingController();
    final amountController = TextEditingController();
    bool isPaying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 25,
          right: 25,
          top: 25,
          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pay $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: accountController,
              decoration: InputDecoration(
                labelText: 'Account / Reference / Phone Number',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Amount (UGX)',
                prefixText: 'UGX ',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  final amountText = amountController.text.trim();
                  if (amountText.isEmpty) return;

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mock Payment of $title Successful!'),
                      backgroundColor: const Color(0xFF00B84A),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009639),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
