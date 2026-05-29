import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  bool _isLoading = true;
  double _savingsBalance = 0.0;
  double _sharesBalance = 0.0;
  double _cashBalance = 0.0;
  double _minBalance = 5000.0;
  double _sharePrice = 100.0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadSavingsData();
  }

  Future<void> _loadSavingsData() async {
    setState(() {
      _isLoading = true;
    });

    final summaryResult = await ApiService.getUserSummary();
    final configResult = await ApiService.getSystemConfig();

    if (mounted) {
      setState(() {
        if (summaryResult['success'] == true) {
          final data = summaryResult['data'];
          final userData = data['user'];
          _cashBalance = double.tryParse(userData['balance']?.toString() ?? '0') ?? 0.0;
          _savingsBalance = double.tryParse(userData['savings_balance']?.toString() ?? '0') ?? 0.0;
          _sharesBalance = double.tryParse(userData['shares_balance']?.toString() ?? '0') ?? 0.0;
          _transactions = data['recent_transactions'] ?? [];
        }

        if (configResult['success'] == true) {
          final config = configResult['config'];
          if (config != null) {
            _minBalance = double.tryParse(config['min_balance']?.toString() ?? '5000') ?? 5000.0;
            _sharePrice = double.tryParse(config['share_price']?.toString() ?? '100') ?? 100.0;
          }
        }

        _isLoading = false;
      });
    }
  }

  String _formatCurrency(num amount) {
    final format = NumberFormat.currency(locale: 'en_US', symbol: 'UGX ', decimalDigits: 0);
    return format.format(amount);
  }

  String _formatDateTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy • hh:mm a').format(date);
    } catch (e) {
      return isoString;
    }
  }

  // Show bottom sheet to buy shares
  void _showBuySharesSheet(BuildContext context) {
    final amountController = TextEditingController();
    bool isBuying = false;

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Buy Shares', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'Current Share Price: ${_formatCurrency(_sharePrice)} per share',
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                'Available Cash Balance: ${_formatCurrency(_cashBalance)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (UGX)',
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
                  onPressed: isBuying
                      ? null
                      : () async {
                          final amountText = amountController.text.trim();
                          if (amountText.isEmpty) return;

                          final amount = double.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid positive amount.')),
                            );
                            return;
                          }

                          if (amount > _cashBalance) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Insufficient cash balance to purchase shares.')),
                            );
                            return;
                          }

                          setModalState(() {
                            isBuying = true;
                          });

                          final res = await ApiService.buyShares(amount);

                          if (mounted) {
                            setModalState(() {
                              isBuying = false;
                            });

                            Navigator.pop(context);

                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Shares purchased successfully!'),
                                  backgroundColor: const Color(0xFF0F5132),
                                ),
                              );
                              _loadSavingsData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['error'] ?? 'Purchase failed.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5132),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: isBuying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Buy Shares', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildFilterOption('Date Range', Icons.date_range),
            _buildFilterOption('Transaction Type', Icons.category),
            _buildFilterOption('Amount Range', Icons.payments),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132)),
                child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0F5132)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadSavingsData,
        color: const Color(0xFF0F5132),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F5132)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(context),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailedBalanceCard(),
                          const SizedBox(height: 20),
                          _buildSharesCard(context),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Contribution History',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _showFilterSheet(context),
                                icon: const Icon(Icons.filter_list, size: 18),
                                label: const Text('Filter'),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F5132)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildHistoryList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/contribution_form').then((_) => _loadSavingsData()),
        backgroundColor: const Color(0xFF0F5132),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('New Deposit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F5132), Color(0xFF198754)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 5),
          const Text(
            'My Savings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing PDF statement for download...')),
              );
            },
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Saved Amount',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_savingsBalance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F5132),
            ),
          ),
          const SizedBox(height: 25),
          Container(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Min Balance', _formatCurrency(_minBalance), Icons.shield_outlined, const Color(0xFF0D6EFD)),
              _buildStatItem('Cash Balance', _formatCurrency(_cashBalance), Icons.wallet, const Color(0xFF198754)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSharesCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.blue.shade700],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Shares Capital',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatCurrency(_sharesBalance)} (${(_sharesBalance / _sharePrice).toStringAsFixed(0)} Shares)',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showBuySharesSheet(context),
            icon: const Icon(Icons.add_shopping_cart, size: 16),
            label: const Text('Buy Shares', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (_transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 10),
              Text('No contributions yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final String type = tx['transaction_type'] ?? 'DEPOSIT';
        final double amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
        final String dateStr = tx['created_at'] ?? '';
        final String desc = tx['description'] ?? 'Transaction';

        IconData icon;
        Color color;
        String sign;

        if (type == 'DEPOSIT' || type == 'LOAN_DISBURSEMENT' || type == 'DIVIDEND_PAYOUT') {
          icon = Icons.arrow_downward_rounded;
          color = Colors.green;
          sign = '+';
        } else {
          icon = Icons.arrow_upward_rounded;
          color = Colors.red;
          sign = '-';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.08),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(_formatDateTime(dateStr), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              Text(
                '$sign ${_formatCurrency(amount).replaceFirst('UGX ', '')}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}
