import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum ContentPageType { faq, terms, help }

class ContentScreen extends StatelessWidget {
  final ContentPageType type;

  const ContentScreen({super.key, required this.type});

  String get _title {
    switch (type) {
      case ContentPageType.faq:
        return 'FAQs';
      case ContentPageType.terms:
        return 'Terms of Service';
      case ContentPageType.help:
        return 'Help Center';
    }
  }

  List<_ContentSection> get _sections {
    switch (type) {
      case ContentPageType.faq:
        return const [
          _ContentSection(
            'How do I deposit savings?',
            'Go to Savings → Make Contribution, enter the amount, and confirm. Deposits reflect on your dashboard balance.',
          ),
          _ContentSection(
            'How do I apply for a loan?',
            'Open Loans → Apply for Loan. Your borrowing limit is based on your savings balance and SACCO policy.',
          ),
          _ContentSection(
            'How do I repay a loan?',
            'Ensure you have cash balance, then open Loans and tap Repay Active Loan on your approved loan.',
          ),
          _ContentSection(
            'How do I transfer money?',
            'Go to Pay → Transfer Money, enter the recipient email and amount from your cash balance.',
          ),
          _ContentSection(
            'How do I update my profile?',
            'Open Profile from the menu, tap Edit, update your name or phone, then Save Changes.',
          ),
        ];
      case ContentPageType.terms:
        return const [
          _ContentSection(
            'Membership',
            'By using this app you agree to abide by Youth SACCO Nansana bylaws and membership requirements.',
          ),
          _ContentSection(
            'Savings & Shares',
            'All deposits and share purchases are subject to SACCO minimum balance rules and admin approval where required.',
          ),
          _ContentSection(
            'Loans',
            'Loan applications are reviewed by SACCO administrators. Approved loans carry interest as configured in system settings.',
          ),
          _ContentSection(
            'Privacy',
            'Your personal data is used only for SACCO operations. We do not sell your information to third parties.',
          ),
          _ContentSection(
            'Account Security',
            'Keep your login credentials confidential. Report suspicious activity to support@youthsacco.com immediately.',
          ),
        ];
      case ContentPageType.help:
        return const [
          _ContentSection(
            'Getting Started',
            'Complete registration, verify your email via MFA at login, then explore Home, Savings, Loans, and Services.',
          ),
          _ContentSection(
            'Connection Issues',
            'If the app cannot reach the server, open Login → Connection Settings and verify the backend URL is correct.',
          ),
          _ContentSection(
            'Forgot Password',
            'On the login screen tap Forgot Password, enter your email, and use the reset code sent to your inbox.',
          ),
          _ContentSection(
            'Need More Help?',
            'Email support@youthsacco.com or call +256 700 123456 during business hours (Mon–Fri, 8am–5pm).',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(8, topPadding + 8, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final section = _sections[index];
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section.body,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSection {
  final String title;
  final String body;
  const _ContentSection(this.title, this.body);
}
