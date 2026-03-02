import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileSection(
                    title: 'Account Information',
                    items: [
                      _ProfileMenuItem(Icons.person_outline, 'Full Name', 'John Doe', () => _showTopSnackBar(context, 'Profile information is private')),
                      _ProfileMenuItem(Icons.email_outlined, 'Email Address', 'john.doe@example.com', () => _showTopSnackBar(context, 'Email verification requested')),
                      _ProfileMenuItem(Icons.phone_outlined, 'Phone Number', '+256 700 000000', () => _showTopSnackBar(context, 'OTP sent for phone update')),
                      _ProfileMenuItem(Icons.badge_outlined, 'Member ID', 'SACCO-2024-089', () => _showTopSnackBar(context, 'Membership details are verified')),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildProfileSection(
                    title: 'Security & Settings',
                    items: [
                      _ProfileMenuItem(Icons.lock_outline, 'Change Password', 'Update your security', () => _showTopSnackBar(context, 'Reset link sent to email')),
                      _ProfileMenuItem(Icons.fingerprint_rounded, 'Biometric Login', 'Enabled', () => _showTopSnackBar(context, 'Biometrics toggled')),
                      _ProfileMenuItem(Icons.notifications_none_rounded, 'Notifications', 'All activity', () => _showTopSnackBar(context, 'Update notification preferences')),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildProfileSection(
                    title: 'Support',
                    items: [
                      _ProfileMenuItem(Icons.help_outline_rounded, 'Help Center', 'FAQs and Support', () => _showTopSnackBar(context, 'Opening help center...')),
                      _ProfileMenuItem(Icons.description_outlined, 'Terms of Service', 'Read our policies', () => _showTopSnackBar(context, 'Loading terms...')),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildLogoutButton(context),
                  const SizedBox(height: 20),
                  const Text('Version 1.0.2', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade900, Colors.purple.shade600],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: () => _showTopSnackBar(context, 'Uploading profile photo...'),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 60),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
            'John Doe',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Gold Member',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
// ... rest of the build sections ...
  Widget _buildProfileSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
        ),
        Container(
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
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/login');
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.red),
        label: const Text(
          'Logout Account',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.red.shade50.withOpacity(0.5),
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem(this.icon, this.title, this.subtitle, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.purple.shade700, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
    );
  }
}

