import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  bool _isLoading = true;
  double _cashBalance = 0.0;
  List<dynamic> _loansList = [];

  // System dynamic configs
  double _loanMultiplier = 3.0;
  double _savingsBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLoansData();
  }

  Future<void> _loadLoansData() async {
    setState(() {
      _isLoading = true;
    });

    final summaryResult = await ApiService.getUserSummary();
    final configResult = await ApiService.getSystemConfig();
    final loansResult = await ApiService.getLoans();

    if (mounted) {
      setState(() {
        if (summaryResult['success'] == true) {
          final data = summaryResult['data'];
          final userData = data['user'];
          _cashBalance = double.tryParse(userData['balance']?.toString() ?? '0') ?? 0.0;
          _savingsBalance = double.tryParse(userData['savings_balance']?.toString() ?? '0') ?? 0.0;
        }

        if (configResult['success'] == true) {
          final config = configResult['config'];
          if (config != null) {
            _loanMultiplier = double.tryParse(config['loan_multiplier']?.toString() ?? '3.0') ?? 3.0;
          }
        }

        if (loansResult['success'] == true) {
          _loansList = loansResult['loans'] ?? [];
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
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return isoString;
    }
  }

  // Handle repay loan modal sheet
  void _showRepayLoanSheet(BuildContext context, Map<String, dynamic> loan) {
    final amountController = TextEditingController();
    bool isRepaying = false;
    final int loanId = loan['id'];
    final double loanAmount = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0.0;

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
                      'Repay Loan',
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
                'Loan ID: #$loanId • Original Amount: ${_formatCurrency(loanAmount)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
                  labelText: 'Repayment Amount (UGX)',
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
                  onPressed: isRepaying
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
                              const SnackBar(content: Text('Insufficient cash balance to repay loan.')),
                            );
                            return;
                          }

                          setModalState(() {
                            isRepaying = true;
                          });

                          final res = await ApiService.repayLoan(loanId, amount);

                          if (mounted) {
                            setModalState(() {
                              isRepaying = false;
                            });

                            Navigator.pop(context);

                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? 'Loan repayment successful!'),
                                  backgroundColor: const Color(0xFF009639),
                                ),
                              );
                              _loadLoansData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['error'] ?? 'Repayment failed.'),
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
                  child: isRepaying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Repay Loan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
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
            const Text('Loan Help & FAQ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildHelpItem('How to apply?', 'Total borrowing is limited to $_loanMultiplier times your savings.'),
            _buildHelpItem('Interest rates', 'We charge a dynamic interest rate as configured by the SACCO Admin.'),
            _buildHelpItem('Repayment', 'Repay easily using cash from your main balance. Deposit cash to repay!'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009639)),
                child: const Text('Got it', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find active loan in our list
    final activeLoans = _loansList.where((l) => l['status'] == 'APPROVED').toList();
    final Map<String, dynamic>? primaryActiveLoan = activeLoans.isNotEmpty ? activeLoans.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadLoansData,
        color: const Color(0xFF009639),
        child: _isLoading
            ? const PageShimmer()
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
                          if (primaryActiveLoan != null) ...[
                            _buildActiveLoanCard(primaryActiveLoan),
                            const SizedBox(height: 30),
                          ],
                          const Text(
                            'My Loan Applications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 15),
                          _buildLoanHistoryList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/loan_application_form').then((_) => _loadLoansData()),
        backgroundColor: const Color(0xFF009639),
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text('Apply for Loan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 5),
          const Text(
            'My Loans',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showHelpSheet(context),
            icon: const Icon(Icons.help_outline, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLoanCard(Map<String, dynamic> loan) {
    final double amount = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0.0;
    final int duration = int.tryParse(loan['duration_months']?.toString() ?? '1') ?? 1;
    final double interest = double.tryParse(loan['interest_rate']?.toString() ?? '5') ?? 5.0;
    final String startDateStr = loan['approved_at'] ?? loan['applied_at'] ?? '';

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Active Loan Balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF009639).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'On Track',
                  style: TextStyle(color: Color(0xFF009639), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(child: _buildLoanStat('Duration', '$duration Months')),
              Expanded(child: _buildLoanStat('Disbursed', startDateStr.isNotEmpty ? _formatDateTime(startDateStr) : 'N/A')),
              Expanded(child: _buildLoanStat('Interest', '$interest%')),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _showRepayLoanSheet(context, loan),
              icon: const Icon(Icons.monetization_on, color: Colors.white),
              label: const Text('Repay Active Loan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009639),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLoanStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildLoanHistoryList() {
    if (_loansList.isEmpty) {
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
              Text('No loan applications yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _loansList.length,
      itemBuilder: (context, index) {
        final loan = _loansList[index];
        final double amount = double.tryParse(loan['amount']?.toString() ?? '0') ?? 0.0;
        final String status = loan['status'] ?? 'PENDING';
        final String reason = loan['reason'] ?? 'Loan';
        final String dateStr = loan['applied_at'] ?? '';

        Color color;
        IconData icon;

        switch (status) {
          case 'APPROVED':
            color = const Color(0xFF00B84A);
            icon = Icons.check_circle_outline;
            break;
          case 'REJECTED':
            color = Colors.red.shade400;
            icon = Icons.cancel_outlined;
            break;
          case 'PAID':
            color = const Color(0xFF007A2E);
            icon = Icons.done_all;
            break;
          default: // PENDING
            color = const Color(0xFF009639);
            icon = Icons.pending_actions;
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Applied: ${_formatDateTime(dateStr)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(amount).replaceFirst('UGX ', ''),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    status,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
