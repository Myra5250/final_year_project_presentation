import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Shared support actions used across drawer, profile, and welcome screens.
class AppSupport {
  AppSupport._();

  static const String supportEmail = 'support@youthsacco.com';
  static const String supportPhone = '+256700123456';
  static const String faqUrl = 'https://youthsacco.com/faq';
  static const String referralMessage =
      'Join Youth SACCO Nansana — save, borrow, and grow with us! Download the Tower Sacco app today.';

  static Future<void> openEmail(BuildContext context, {String? subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: subject != null ? 'subject=${Uri.encodeComponent(subject)}' : null,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: supportEmail));
      if (context.mounted) {
        _snack(context, 'Email copied: $supportEmail');
      }
    }
  }

  static Future<void> openPhone(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: supportPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        _snack(context, 'Call us at $supportPhone');
      }
    }
  }

  static Future<void> shareReferral(BuildContext context) async {
    final user = await ApiService.getUser();
    final name = user?['full_name'] ?? user?['username'] ?? 'A friend';
    final message = '$name invites you to Youth SACCO Nansana!\n\n$referralMessage';
    await Share.share(message, subject: 'Join Youth SACCO');
    if (context.mounted) {
      _snack(context, 'Referral message shared');
    }
  }

  static void showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Contact Us', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.primary),
              title: const Text('Email'),
              subtitle: Text(supportEmail),
              onTap: () {
                Navigator.pop(ctx);
                openEmail(context, subject: 'Youth SACCO Support');
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
              title: const Text('Phone'),
              subtitle: Text(supportPhone),
              onTap: () {
                Navigator.pop(ctx);
                openPhone(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void openFaq(BuildContext context) {
    Navigator.pushNamed(context, '/faq');
  }

  static void openTerms(BuildContext context) {
    Navigator.pushNamed(context, '/terms');
  }

  static void openHelp(BuildContext context) {
    Navigator.pushNamed(context, '/help');
  }

  static Future<void> generateStatement(
    BuildContext context, {
    required String periodLabel,
    int days = 30,
  }) async {
    final result = await ApiService.getTransactions();
    if (!context.mounted) return;

    if (result['success'] != true) {
      _snack(context, result['error'] ?? 'Could not load transactions', isError: true);
      return;
    }

    final all = (result['transactions'] as List<dynamic>? ?? []);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final filtered = all.where((tx) {
      try {
        return DateTime.parse(tx['created_at'].toString()).isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    double deposits = 0;
    double withdrawals = 0;
    for (final tx in filtered) {
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
      final type = (tx['transaction_type'] ?? '').toString();
      if (type == 'DEPOSIT' || type == 'LOAN_DISBURSEMENT' || type == 'DIVIDEND_PAYOUT') {
        deposits += amount;
      } else {
        withdrawals += amount;
      }
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$periodLabel Statement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transactions: ${filtered.length}'),
            const SizedBox(height: 8),
            Text('Total in: UGX ${deposits.toStringAsFixed(0)}'),
            Text('Total out: UGX ${withdrawals.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text(
              'Net: UGX ${(deposits - withdrawals).toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(
                text: '$periodLabel Statement\nTransactions: ${filtered.length}\nIn: UGX ${deposits.toStringAsFixed(0)}\nOut: UGX ${withdrawals.toStringAsFixed(0)}',
              ));
              _snack(context, 'Statement summary copied to clipboard');
            },
            child: const Text('Copy Summary'),
          ),
        ],
      ),
    );
  }

  static void _snack(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
