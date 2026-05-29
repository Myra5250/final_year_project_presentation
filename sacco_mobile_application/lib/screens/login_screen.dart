import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_images.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController  = TextEditingController();
  final _urlController       = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _rememberMe = false;
  String _passwordStrength = '';
  Color _strengthColor = Colors.transparent;

  // Connection settings
  bool _showConnectionSettings = false;
  bool _isTestingConnection   = false;
  String _connectionStatus    = '';
  bool _connectionOk          = false;

  // Brute force lockout fields
  bool _isLockedOut = false;
  int _lockoutTimeRemaining = 0; // seconds
  Timer? _lockoutTimer;

  // Maintenance mode
  bool _isMaintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
    _checkMaintenanceMode();
    _loadCurrentUrl();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // 1. Check if user is locked out due to too many failed attempts
  Future<void> _checkLockoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutEndStr = prefs.getString('lockout_end');
    if (lockoutEndStr != null) {
      final lockoutEnd = DateTime.parse(lockoutEndStr);
      final now = DateTime.now();
      if (lockoutEnd.isAfter(now)) {
        final difference = lockoutEnd.difference(now).inSeconds;
        setState(() {
          _isLockedOut = true;
          _lockoutTimeRemaining = difference;
        });
        _startLockoutTimer();
      } else {
        await prefs.remove('lockout_end');
        await prefs.setInt('failed_attempts', 0);
      }
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_lockoutTimeRemaining <= 1) {
        timer.cancel();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lockout_end');
        await prefs.setInt('failed_attempts', 0);
        setState(() {
          _isLockedOut = false;
          _lockoutTimeRemaining = 0;
        });
      } else {
        setState(() {
          _lockoutTimeRemaining--;
        });
      }
    });
  }

  // 2. Check system status (Maintenance Mode)
  Future<void> _checkMaintenanceMode() async {
    final result = await ApiService.getSystemConfig();
    if (result['success'] == true) {
      final config = result['config'];
      if (config != null && (config['maintenance_mode'] == 1 || config['maintenance_mode'] == true)) {
        setState(() {
          _isMaintenanceMode = true;
        });
        _showMaintenanceOverlay();
      }
    }
  }

  void _showMaintenanceOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Cannot dismiss
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'The Youth SACCO Nansana system is currently undergoing scheduled updates and maintenance. Please try again later.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Exit app or close dialog if testing
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Connection settings helpers ───────────────────────────────────────────
  Future<void> _loadCurrentUrl() async {
    if (mounted) {
      setState(() {
        _urlController.text = ApiService.baseUrl;
      });
    }
  }

  Future<void> _applyCustomUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus    = 'Testing connection…';
      _connectionOk        = false;
    });

    final ok = await ApiService.testConnection(url);
    await ApiService.setBaseUrl(url);

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _connectionOk        = ok;
        _connectionStatus    = ok
            ? '✓ Connected! Server is reachable.'
            : '✗ Could not reach server. Check the URL and ensure the backend is running.';
      });
    }
  }

  Widget _buildConnectionSettingsCard() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          // Toggle row
          GestureDetector(
            onTap: () => setState(() {
              _showConnectionSettings = !_showConnectionSettings;
              if (_showConnectionSettings) _loadCurrentUrl();
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0F5132).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_ethernet_rounded,
                      color: Color(0xFF0F5132), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Connection Settings',
                      style: TextStyle(
                        color: Color(0xFF0F5132),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _showConnectionSettings
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF0F5132),
                  ),
                ],
              ),
            ),
          ),

          // Expanded panel
          if (_showConnectionSettings)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
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
                  // Active URL chip
                  Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          color: Color(0xFF198754), size: 16),
                      const SizedBox(width: 6),
                      const Text('Active URL:',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ApiService.baseUrl,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0F5132),
                              fontFamily: 'monospace'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Divider(),
                  const SizedBox(height: 4),
                  const Text(
                    'Custom Backend URL',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'If using a physical device on the same Wi-Fi as your PC,\n'
                    'enter your computer\'s local IP, e.g.:\n'
                    'http://192.168.x.x:8000/api',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.x.x:8000/api',
                      prefixIcon: const Icon(Icons.dns_rounded,
                          color: Color(0xFF0F5132), size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Status banner
                  if (_connectionStatus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _connectionOk
                            ? const Color(0xFFE8F5EE)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _connectionOk
                              ? const Color(0xFF0F5132).withOpacity(0.3)
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Text(
                        _connectionStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color: _connectionOk
                              ? const Color(0xFF0F5132)
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTestingConnection
                              ? null
                              : () async {
                                  await ApiService.resetBaseUrl();
                                  setState(() {
                                    _urlController.text = ApiService.baseUrl;
                                    _connectionStatus   = '';
                                    _connectionOk       = false;
                                  });
                                },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isTestingConnection ? null : _applyCustomUrl,
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline_rounded,
                                  size: 16),
                          label: Text(
                              _isTestingConnection ? 'Testing…' : 'Apply & Test',
                              style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F5132),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 3. Handle login processing
  Future<void> _handleLogin() async {
    if (_isLockedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Too many failed attempts. Try again in $_lockoutTimeRemaining seconds.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await ApiService.login(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        // Clear failed attempts on success
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('failed_attempts', 0);

        if (result['requires_mfa'] == true) {
          // Navigate to MFA screen
          Navigator.pushNamed(
            context,
            '/mfa_verification',
            arguments: {'email': result['email'], 'rememberMe': _rememberMe},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login successful'),
              backgroundColor: const Color(0xFF0F5132),
            ),
          );
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        // Handle failed attempts & brute force lockout
        final prefs = await SharedPreferences.getInstance();
        int attempts = (prefs.getInt('failed_attempts') ?? 0) + 1;
        await prefs.setInt('failed_attempts', attempts);

        if (attempts >= 5) {
          final lockoutEnd = DateTime.now().add(const Duration(minutes: 5));
          await prefs.setString('lockout_end', lockoutEnd.toIso8601String());
          setState(() {
            _isLockedOut = true;
            _lockoutTimeRemaining = 300; // 5 minutes
          });
          _startLockoutTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many failed attempts. You have been locked out for 5 minutes.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result['error']} (Attempt $attempts/5)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 4. Client-side password strength checker
  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _strengthColor = Colors.transparent;
      });
      return;
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    setState(() {
      if (score <= 1) {
        _passwordStrength = 'Weak Password';
        _strengthColor = Colors.red;
      } else if (score == 2 || score == 3) {
        _passwordStrength = 'Medium Password';
        _strengthColor = Colors.orange;
      } else {
        _passwordStrength = 'Strong Password';
        _strengthColor = Colors.green;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // Background Design
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0F5132), Color(0xFF198754)],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                      ),
                    ),
                    
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Back Button
                            Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            
                            const SizedBox(height: 10),
                            
                            // Logo Area
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: LogoPainter(),
                                size: const Size(80, 80),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            const Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            
                            const Text(
                              'Sign in to continue',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Login Card
                            Container(
                              padding: const EdgeInsets.all(26),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey.shade100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Lockout Notice
                                  if (_isLockedOut) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.shade100),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock_clock, color: Colors.red),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Account locked for security. Try again in $_lockoutTimeRemaining seconds.',
                                              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],

                                  const Text(
                                    'Email Address',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your email',
                                      prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  const Text(
                                    'Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscureText,
                                    onChanged: _checkPasswordStrength,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your password',
                                      prefixIcon: Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                        onPressed: () {
                                          setState(() {
                                            _obscureText = !_obscureText;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  
                                  // Password strength indicator
                                  if (_passwordStrength.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: _strengthColor,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _passwordStrength,
                                          style: TextStyle(
                                            color: _strengthColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              activeColor: const Color(0xFF0F5132),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (val) => setState(() => _rememberMe = val ?? false),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Remember Me', style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // Secure connection note
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.verified_user, color: Colors.green, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'SECURE 256-BIT SSL ENCRYPTION',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 15),
                                  
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _isLoading || _isLockedOut ? null : _handleLogin,
                                      child: _isLoading 
                                        ? const SizedBox(
                                            height: 24, 
                                            width: 24, 
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                          )
                                        : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const Spacer(),
                            
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/register');
                                    },
                                    child: const Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        color: Color(0xFF0F5132),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildConnectionSettingsCard(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
