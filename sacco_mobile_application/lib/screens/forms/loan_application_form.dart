import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class LoanApplicationForm extends StatefulWidget {
  const LoanApplicationForm({super.key});

  @override
  State<LoanApplicationForm> createState() => _LoanApplicationFormState();
}

class _LoanApplicationFormState extends State<LoanApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  String _loanType = 'Emergency';
  final _amountController = TextEditingController();
  final _periodController = TextEditingController();
  bool _isLoading = false;

  // System dynamic parameters
  double _savingsBalance = 0.0;
  double _loanMultiplier = 3.0;
  bool _allowLoans = true;

  @override
  void initState() {
    super.initState();
    _loadValidationData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _loadValidationData() async {
    final summaryResult = await ApiService.getUserSummary();
    final configResult = await ApiService.getSystemConfig();

    if (mounted) {
      setState(() {
        if (summaryResult['success'] == true) {
          final userData = summaryResult['data']['user'];
          _savingsBalance = double.tryParse(userData['savings_balance']?.toString() ?? '0') ?? 0.0;
        }

        if (configResult['success'] == true) {
          final config = configResult['config'];
          if (config != null) {
            _loanMultiplier = double.tryParse(config['loan_multiplier']?.toString() ?? '3.0') ?? 3.0;
            _allowLoans = (config['allow_loans'] == 1 || config['allow_loans'] == true);
          }
        }
      });
    }
  }

  String _formatCurrency(num amount) {
    final format = NumberFormat.currency(locale: 'en_US', symbol: 'UGX ', decimalDigits: 0);
    return format.format(amount);
  }

  Future<void> _handleLoanApplication() async {
    if (!_allowLoans) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan applications are temporarily disabled by the Administrator.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountController.text.trim();
    final periodText = _periodController.text.trim();

    final amount = double.tryParse(amountText);
    final period = int.tryParse(periodText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid loan amount.')),
      );
      return;
    }

    if (period == null || period <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid repayment period.')),
      );
      return;
    }

    // Check borrowing ceiling (3x savings or multiplier x savings)
    final double borrowingCeiling = _savingsBalance * _loanMultiplier;
    if (amount > borrowingCeiling) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Requested amount exceeds borrowing limit of ${_formatCurrency(borrowingCeiling)} ($_loanMultiplier times savings)'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final reason = '$_loanType Loan';
    final result = await ApiService.applyLoan(amount, period, reason);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Loan application failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxLoan = _savingsBalance * _loanMultiplier;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Apply for Loan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_allowLoans) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Loan applications are currently disabled by the Administrator.',
                          style: TextStyle(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _buildSectionTitle('What type of loan do you need?'),
              const SizedBox(height: 12),
              _buildLoanTypeSelector(),
              const SizedBox(height: 30),
              _buildSectionTitle('How much do you need?'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                enabled: _allowLoans,
                decoration: _inputDecoration('Requested Amount', 'UGX 1,000,000'),
                validator: (value) => value == null || value.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('Repayment Period'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodController,
                keyboardType: TextInputType.number,
                enabled: _allowLoans,
                decoration: _inputDecoration('Months', '12'),
                validator: (value) => value == null || value.isEmpty ? 'Enter period' : null,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF009639).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF009639)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your max loan ceiling is $_loanMultiplier times your savings balance: ${_formatCurrency(maxLoan)}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || !_allowLoans ? null : _handleLoanApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009639),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Submit Application',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildLoanTypeSelector() {
    final types = ['Emergency', 'Business', 'Personal', 'Educational'];
    return Column(
      children: types
          .map((type) => RadioListTile<String>(
                title: Text(type),
                value: type,
                groupValue: _loanType,
                onChanged: _allowLoans
                    ? (val) => setState(() => _loanType = val!)
                    : null,
                activeColor: const Color(0xFF009639),
                contentPadding: EdgeInsets.zero,
              ))
          .toList(),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description, color: Color(0xFF009639), size: 60),
            const SizedBox(height: 16),
            const Text(
              'Application Received',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Our committee will review your application and get back to you within 24 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to loans
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF009639)),
                child: const Text('Great, thanks!', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
