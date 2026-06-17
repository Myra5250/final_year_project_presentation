import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_images.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/app_support.dart';

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
  String? _selectedStatementPeriod;
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
        color: AppColors.primary,
        child: _isLoading
            ? const DashboardShimmer()
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
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 30),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openDrawer();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back,',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
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
              Expanded(
                child: _buildBalanceStat(
                  'Shares Balance',
                  '${_formatCurrency(_sharesBalance)} (${(_sharesBalance / _sharePrice).toStringAsFixed(0)} Shares)',
                  Icons.pie_chart,
                  Colors.white,
                  labelColor: Colors.white70,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: _buildBalanceStat(
                    'Active Loan',
                    _activeLoanBalance > 0 ? _formatCurrency(_activeLoanBalance) : 'No Loan',
                    Icons.account_balance_wallet,
                    Colors.white,
                    labelColor: Colors.white70,
                  ),
                ),
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
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: labelColor, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (title == 'Recent Activity')
          IconButton(
            onPressed: () => _showStatementGenerator(context),
            icon: Icon(Icons.description_outlined, color: AppColors.primaryLight, size: 20),
            tooltip: 'Generate Statement',
          ),
        if (title != 'Quick Actions')
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, title == 'Recent Activity' ? '/savings' : '/loans')
                  .then((_) => _loadDashboardData());
            },
            child: Text('See All', style: TextStyle(color: AppColors.primaryLight)),
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
            _buildStatementOption(context, 'Last 30 Days', 'Summary of recent contributions', 30),
            _buildStatementOption(context, 'Last 6 Months', 'Summary of financial history', 180),
            _buildStatementOption(context, 'Full History', 'All available transactions', 3650),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final period = _selectedStatementPeriod ?? 'Last 30 Days';
                  final days = period.contains('6') ? 180 : (period.contains('Full') ? 3650 : 30);
                  AppSupport.generateStatement(context, periodLabel: period, days: days);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009639),
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

  Widget _buildStatementOption(BuildContext context, String title, String subtitle, int days) {
    final isSelected = _selectedStatementPeriod == title;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
        child: Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20) : const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        setState(() => _selectedStatementPeriod = title);
        Navigator.pop(context);
        AppSupport.generateStatement(context, periodLabel: title, days: days);
      },
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildActionItem(context, Icons.savings_outlined, 'Savings', AppColors.primary, '/contribution_form')),
        Expanded(child: _buildActionItem(context, Icons.account_balance_outlined, 'Loans', AppColors.primaryLight, '/loan_application_form')),
        Expanded(child: _buildActionItem(context, Icons.payments_outlined, 'Pay', AppColors.success, '/pay')),
        Expanded(child: _buildActionItem(context, Icons.person_outline, 'Profile', AppColors.primary, '/profile')),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
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
          color = const Color(0xFF009639);
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
