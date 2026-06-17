import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/app_support.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  double _savingsBalance = 0.0;
  double _sharesBalance = 0.0;
  double _loanBalance = 0.0;
  double _sharePrice = 100.0;

  @override
  void initState() {
    super.initState();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
    setState(() => _isLoading = true);
    final summaryResult = await ApiService.getUserSummary();
    final loansResult = await ApiService.getLoans();
    final configResult = await ApiService.getSystemConfig();

    if (mounted) {
      setState(() {
        if (summaryResult['success'] == true) {
          final userData = summaryResult['data']['user'];
          _savingsBalance = double.tryParse(userData['savings_balance']?.toString() ?? '0') ?? 0.0;
          _sharesBalance = double.tryParse(userData['shares_balance']?.toString() ?? '0') ?? 0.0;
        }

        if (loansResult['success'] == true) {
          final loansList = loansResult['loans'] as List<dynamic>;
          _loanBalance = loansList
              .where((l) => l['status'] == 'APPROVED')
              .fold(0.0, (sum, l) => sum + (double.tryParse(l['amount'].toString()) ?? 0.0));
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
    return NumberFormat.currency(locale: 'en_US', symbol: 'UGX ', decimalDigits: 0).format(amount);
  }

  void _showBalanceSheet(String title, String balanceText, IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 25),
            CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF009639).withOpacity(0.1),
              child: Icon(icon, color: const Color(0xFF009639), size: 35),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(
              balanceText,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF009639)),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009639),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  void _showStatementGenerator() {
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
              children: [
                const Expanded(
                  child: Text(
                    'Statement Generator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Generate a summary of your financial activity.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildStatementOption('Last 30 Days', 'Summary of recent contributions', 30),
            _buildStatementOption('Last 6 Months', 'Summary of financial history', 180),
            _buildStatementOption('Full History', 'All available transactions', 3650),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  AppSupport.generateStatement(context, periodLabel: 'Last 30 Days', days: 30);
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

  Widget _buildStatementOption(String title, String subtitle, int days) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF009639).withOpacity(0.08), shape: BoxShape.circle),
        child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF009639), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.pop(context);
        AppSupport.generateStatement(context, periodLabel: title, days: days);
      },
    );
  }

  void _showMockWithdrawal() {
    final amountController = TextEditingController();
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
                const Expanded(
                  child: Text(
                    'Cash Withdrawal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 15),
            Text('Available Balance: ${_formatCurrency(_savingsBalance)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Withdraw Amount (UGX)',
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
                onPressed: () async {
                  final text = amountController.text.trim();
                  if (text.isEmpty) return;
                  final amount = double.tryParse(text);
                  if (amount == null || amount <= 0) return;

                  if (amount > _savingsBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient balance.'), backgroundColor: Colors.red),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  final res = await ApiService.withdraw(amount);
                  if (mounted) {
                    setState(() => _isLoading = false);
                    if (res['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Withdrawal successful!'), backgroundColor: Color(0xFF009639)),
                      );
                      _fetchBalances();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['error'] ?? 'Withdrawal failed.'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009639),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading
          ? const PageShimmer()
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchBalances,
                    color: const Color(0xFF009639),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Enquiry'),
                          const SizedBox(height: 15),
                          _buildEnquiryGrid(),
                          const SizedBox(height: 30),
                          _buildSectionTitle('Transaction'),
                          const SizedBox(height: 15),
                          _buildTransactionGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 40),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Services',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Explore Our Services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildEnquiryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.15,
      children: [
        _buildServiceCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Balance Enquiry',
          onTap: () => _showBalanceSheet('Savings Balance', _formatCurrency(_savingsBalance), Icons.account_balance_wallet),
        ),
        _buildServiceCard(
          icon: Icons.pie_chart_outline,
          title: 'Share Balance',
          onTap: () => _showBalanceSheet(
            'Share Balance',
            '${_formatCurrency(_sharesBalance)}\n(${(_sharesBalance / _sharePrice).toStringAsFixed(0)} Shares)',
            Icons.pie_chart,
          ),
        ),
        _buildServiceCard(
          icon: Icons.credit_card_outlined,
          title: 'Loan Balance',
          onTap: () => _showBalanceSheet('Active Loan Balance', _formatCurrency(_loanBalance), Icons.credit_card),
        ),
        _buildServiceCard(
          icon: Icons.receipt_long_outlined,
          title: 'Mini Statement',
          onTap: _showStatementGenerator,
        ),
        _buildServiceCard(
          icon: Icons.description_outlined,
          title: 'Full Statement',
          onTap: _showStatementGenerator,
        ),
      ],
    );
  }

  Widget _buildTransactionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 1.15,
      children: [
        _buildServiceCard(
          icon: Icons.money_off_csred_outlined,
          title: 'Withdraw Cash',
          onTap: _showMockWithdrawal,
        ),
        _buildServiceCard(
          icon: Icons.swap_horiz_outlined,
          title: 'Inter Account',
          onTap: () => Navigator.pushNamed(context, '/pay'),
        ),
      ],
    );
  }

  Widget _buildServiceCard({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF009639).withOpacity(0.05),
          highlightColor: const Color(0xFF009639).withOpacity(0.02),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009639).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF009639), size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
