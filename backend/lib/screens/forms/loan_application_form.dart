import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
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
              _buildSectionTitle('What type of loan do you need?'),
              const SizedBox(height: 12),
              _buildLoanTypeSelector(),
              const SizedBox(height: 30),
              _buildSectionTitle('How much do you need?'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Requested Amount', 'UGX 1,000,000'),
                validator: (value) => value == null || value.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('Repayment Period'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periodController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Months', '12'),
                validator: (value) => value == null || value.isEmpty ? 'Enter period' : null,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Max loan amount is 3x your savings (UGX 7,350,000)',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _showSuccessDialog();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text(
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
      children: types.map((type) => RadioListTile<String>(
        title: Text(type),
        value: type,
        groupValue: _loanType,
        onChanged: (val) => setState(() => _loanType = val!),
        activeColor: Colors.blue.shade800,
        contentPadding: EdgeInsets.zero,
      )).toList(),
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
            const Icon(Icons.description, color: Colors.blue, size: 60),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800),
                child: const Text('Great, thanks!', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
