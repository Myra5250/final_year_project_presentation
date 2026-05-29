import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_images.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _LoginUser {
  final int id;
  final String username;
  final String email;
  _LoginUser({required this.id, required this.username, required this.email});
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _fullName = 'Member';
  double _balance = 0.0;
  double _savingsBalance = 0.0;
  double _sharesBalance = 0.0;
  double _activeLoanBalance = 0.0;
  double _sharePrice = 100.0;
  int _unreadNotificationsCount = 0;
  bool _isBalanceVisible = true;
  
  List<dynamic> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Get current user session info
    final user = await ApiService.getUser();
    if (user != null) {
      setState(() {
        _fullName = user['full_name'] ?? user['username'] ?? 'Member';
      });
    }

    // 2. Fetch fresh user summary, active loans, notifications, and system config
    final summaryResult = await ApiService.getUserSummary();
    final loansResult = await ApiService.getLoans();
    final notificationsResult = await ApiService.getNotifications();
    final configResult = await ApiService.getSystemConfig();

    if (mounted) {
      setState(() {
        if (summaryResult['success'] == true) {
          final data = summaryResult['data'];
          final userData = data['user'];
          _balance = double.tryParse(userData['balance']?.toString() ?? '0') ?? 0.0;
          _savingsBalance = double.tryParse(userData['savings_balance']?.toString() ?? '0') ?? 0.0;
          _sharesBalance = double.tryParse(userData['shares_balance']?.toString() ?? '0') ?? 0.0;
          _recentTransactions = data['recent_transactions'] ?? [];
        }

        if (loansResult['success'] == true) {
          final loansList = loansResult['loans'] as List<dynamic>;
          // Calculate sum of active approved loans
          _activeLoanBalance = loansList
              .where((l) => l['status'] == 'APPROVED')
              .fold(0.0, (sum, l) => sum + (double.tryParse(l['amount'].toString()) ?? 0.0));
        }

        if (notificationsResult['success'] == true) {
          final List<dynamic> notifs = notificationsResult['notifications'] ?? [];
          _unreadNotificationsCount = notifs.where((n) => n['is_unread'] == true || n['is_unread'] == 1).length;
        }

        if (configResult['success'] == true) {
          final config = configResult['config'];
          if (config != null) {
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
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF0F5132),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F5132)),
              )
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
                          _buildBalanceCard(),
                          const SizedBox(height: 30),
                          _buildSectionHeader(context, 'Quick Actions'),
                          const SizedBox(height: 15),
                          _buildQuickActionsGrid(context),
                          const SizedBox(height: 30),
                          _buildSectionHeader(context, 'Recent Activity'),
                          const SizedBox(height: 15),
                          _buildRecentActivityList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    _fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/notifications').then((_) => _loadDashboardData());
            },
            icon: Badge(
              label: _unreadNotificationsCount > 0 ? Text(_unreadNotificationsCount.toString()) : null,
              isLabelVisible: _unreadNotificationsCount > 0,
              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F5132), Color(0xFF1E7E34)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5132).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Savings Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBalanceVisible = !_isBalanceVisible;
                  });
                },
                child: Icon(
                  _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isBalanceVisible ? _formatCurrency(_savingsBalance) : 'UGX*****',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _buildBalanceStat(
                'Shares Balance',
                '${_formatCurrency(_sharesBalance)} (${(_sharesBalance / _sharePrice).toStringAsFixed(0)} Shares)',
                Icons.pie_chart,
                Colors.white,
                labelColor: Colors.white70,
              ),
              const Spacer(),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              const Spacer(),
              _buildBalanceStat(
                'Active Loan',
                _activeLoanBalance > 0 ? _formatCurrency(_activeLoanBalance) : 'No Loan',
                Icons.account_balance_wallet,
                const Color(0xFFFFC107),
                labelColor: Colors.white70,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value, IconData icon, Color color, {Color labelColor = Colors.grey}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Row(
          children: [
            if (title == 'Recent Activity')
              IconButton(
                onPressed: () => _showStatementGenerator(context),
                icon: Icon(Icons.description_outlined, color: Colors.green.shade700, size: 20),
                tooltip: 'Generate Statement',
              ),
            TextButton(
              onPressed: () {
                if (title == 'Quick Actions') return;
                Navigator.pushNamed(context, title == 'Recent Activity' ? '/savings' : '/loans').then((_) => _loadDashboardData());
              },
              child: Text('See All', style: TextStyle(color: Colors.green.shade700)),
            ),
          ],
        ),
      ],
    );
  }

  void _showStatementGenerator(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Statement Generator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Generate a summary of your financial activity.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildStatementOption('Last 30 Days', 'Summary of recent contributions'),
            _buildStatementOption('Last 6 Months', 'Summary of financial history'),
            _buildStatementOption('Custom Range', 'Select specific dates'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Statement generated successfully!'), backgroundColor: Colors.green),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Generate PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatementOption(String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
        child: Icon(Icons.picture_as_pdf_outlined, color: Colors.green.shade700, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {},
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _buildActionItem(context, Icons.savings_outlined, 'Savings', const Color(0xFF0F5132), '/contribution_form'),
        _buildActionItem(context, Icons.account_balance_outlined, 'Loans', const Color(0xFF198754), '/loan_application_form'),
        _buildActionItem(context, Icons.payments_outlined, 'Pay', const Color(0xFF0D6EFD), '/pay'),
        _buildActionItem(context, Icons.person_outline, 'Profile', const Color(0xFF6F42C1), '/profile'),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, String? route) {
    return GestureDetector(
      onTap: () {
        if (route != null) {
          Navigator.pushNamed(context, route).then((_) => _loadDashboardData());
        }
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.12), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    if (_recentTransactions.isEmpty) {
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
              Text('No recent activity', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _recentTransactions.map((tx) {
        final String type = tx['transaction_type'] ?? 'DEPOSIT';
        final double amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
        final String dateStr = tx['created_at'] ?? '';
        final String desc = tx['description'] ?? 'Transaction';

        IconData icon;
        Color color;
        String sign;

        if (type == 'DEPOSIT' || type == 'LOAN_DISBURSEMENT' || type == 'DIVIDEND_PAYOUT') {
          icon = Icons.arrow_downward;
          color = Colors.green;
          sign = '+';
        } else {
          icon = Icons.arrow_upward;
          color = Colors.red;
          sign = '-';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(dateStr),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign ${_formatCurrency(amount).replaceFirst('UGX ', '')}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
