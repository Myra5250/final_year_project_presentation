import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_support.dart';
import '../widgets/shimmer_loading.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _fullName = 'Member Name';
  String _email = 'email@example.com';
  String _phone = '';
  String _memberId = 'SACCO-XXXX';

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    final profileResult = await ApiService.getProfile();
    Map<String, dynamic>? user;

    if (profileResult['success'] == true) {
      user = profileResult['user'] as Map<String, dynamic>;
    } else {
      user = await ApiService.getUser();
    }

    if (mounted && user != null) {
      setState(() {
        _fullName = user!['full_name'] ?? user['username'] ?? 'Member';
        _email = user['email'] ?? '';
        _phone = user['phone_number'] ?? '';
        _memberId = 'SACCO-2026-${user['id']}';
        _nameController.text = _fullName;
        _phoneController.text = _phone;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        _nameController.text = _fullName;
        _phoneController.text = _phone;
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your full name');
      return;
    }
    if (phone.isEmpty || phone.length != 10 || !RegExp(r'^\d+$').hasMatch(phone)) {
      _showSnackBar('Phone number must be exactly 10 digits');
      return;
    }

    setState(() => _isSaving = true);
    final result = await ApiService.updateProfile(fullName: name, phoneNumber: phone);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      final user = result['user'] as Map<String, dynamic>;
      setState(() {
        _fullName = user['full_name'] ?? name;
        _phone = user['phone_number'] ?? phone;
        _isEditing = false;
      });
      _showSnackBar('Profile updated successfully');
    } else {
      _showSnackBar(result['error'] ?? 'Failed to update profile');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLogout() async {
    await ApiService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showChangePasswordSheet() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: currentController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setModalState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: obscureNew,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final current = currentController.text;
                          final newPass = newController.text;
                          final confirm = confirmController.text;
                          if (current.isEmpty || newPass.isEmpty) {
                            _showSnackBar('Please fill in all password fields');
                            return;
                          }
                          if (newPass.length < 6) {
                            _showSnackBar('New password must be at least 6 characters');
                            return;
                          }
                          if (newPass != confirm) {
                            _showSnackBar('New passwords do not match');
                            return;
                          }
                          setModalState(() => isSaving = true);
                          final result = await ApiService.changePassword(
                            currentPassword: current,
                            newPassword: newPass,
                          );
                          if (!ctx.mounted) return;
                          setModalState(() => isSaving = false);
                          if (result['success'] == true) {
                            Navigator.pop(ctx);
                            _showSnackBar('Password changed successfully');
                          } else {
                            _showSnackBar(result['error'] ?? 'Failed to change password');
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const PageShimmer()
          : Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isEditing) ...[
                          _buildEditForm(),
                          const SizedBox(height: 16),
                          _buildSaveCancelRow(),
                        ] else ...[
                          _buildInfoCard(),
                        ],
                        const SizedBox(height: 28),
                        _buildSectionTitle('Account'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _ProfileMenuItem(
                            icon: Icons.badge_outlined,
                            title: 'Member ID',
                            subtitle: _memberId,
                            showChevron: false,
                          ),
                          _ProfileMenuItem(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            subtitle: _email,
                            showChevron: false,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Security'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _ProfileMenuItem(
                            icon: Icons.lock_outline,
                            title: 'Change Password',
                            subtitle: 'Update your login password',
                            onTap: _showChangePasswordSheet,
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Support'),
                        const SizedBox(height: 12),
                        _buildMenuCard([
                          _ProfileMenuItem(
                            icon: Icons.help_outline_rounded,
                            title: 'Help Center',
                            subtitle: 'Guides and troubleshooting',
                            onTap: () => AppSupport.openHelp(context),
                          ),
                          _ProfileMenuItem(
                            icon: Icons.quiz_outlined,
                            title: 'FAQs',
                            subtitle: 'Common questions answered',
                            onTap: () => AppSupport.openFaq(context),
                          ),
                          _ProfileMenuItem(
                            icon: Icons.description_outlined,
                            title: 'Terms of Service',
                            subtitle: 'Read our policies',
                            onTap: () => AppSupport.openTerms(context),
                          ),
                          _ProfileMenuItem(
                            icon: Icons.mail_outline,
                            title: 'Contact Support',
                            subtitle: AppSupport.supportEmail,
                            onTap: () => AppSupport.showContactSheet(context),
                          ),
                        ]),
                        const SizedBox(height: 32),
                        _buildLogoutButton(),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'Version 1.0.3',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, topPadding + 8, 20, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _goHome,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                tooltip: 'Back to Home',
              ),
              const Expanded(
                child: Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isEditing)
                TextButton.icon(
                  onPressed: _toggleEdit,
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  label: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 52),
              ),
              if (!_isEditing)
                GestureDetector(
                  onTap: _toggleEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Active Member',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(label: 'Full Name', value: _fullName),
          const Divider(height: 24),
          _InfoRow(label: 'Phone', value: _phone.isNotEmpty ? _phone : 'Not set'),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '0700000000',
              prefixIcon: Icon(Icons.phone_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email ($_email) cannot be changed here. Contact support if needed.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveCancelRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : _toggleEdit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(List<_ProfileMenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: const Text(
          'Logout',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: AppColors.surface,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      trailing: showChevron ? const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20) : null,
    );
  }
}
