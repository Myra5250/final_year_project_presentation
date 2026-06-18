import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ─── Dynamic Base URL ────────────────────────────────────────────────────────
  // In RELEASE builds → automatically uses the deployed Render backend.
  // In DEBUG builds   → uses localhost (change _devDefault for your local IP).
  // A custom URL saved by the user in Settings always takes priority.

  /// 🚀 PRODUCTION: Paste your Railway URL here once deployed.
  /// Format: https://your-app-name.up.railway.app/api
  static const String _productionUrl = 'https://YOUR-APP.up.railway.app/api';

  /// 🛠  DEVELOPMENT: Local server address.
  static const String _devDefault = 'http://127.0.0.1:8000/api';

  static String get _platformDefault {
    if (kReleaseMode) {
      // Production build — always use the deployed backend.
      return _productionUrl;
    }
    // Debug / profile build — use local dev server.
    // Android emulator: change to http://10.0.2.2:8000/api
    return _devDefault;
  }

  // Runtime-changeable URL (starts with the platform default; may be
  // overwritten by loadSavedBaseUrl() or by the Connection Settings panel).
  static String baseUrl = _platformDefault;

  /// Call once at app startup (e.g. in main() before runApp).
  /// Loads any URL the user previously saved in Settings.
  static Future<void> loadSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_base_url');
    if (saved != null && saved.isNotEmpty) {
      baseUrl = saved;
    } else {
      baseUrl = _platformDefault;
    }
  }

  /// Persist a custom URL and switch to it immediately.
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_base_url', url);
    baseUrl = url;
  }

  /// Reset to the platform default and clear any saved custom URL.
  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('custom_base_url');
    baseUrl = _platformDefault;
  }

  // ─── Health Check ────────────────────────────────────────────────────────────
  /// Returns true if the server at [url] responds to /health within 5 s.
  static Future<bool> testConnection(String url) async {
    try {
      // Normalise: strip trailing slash then append /health
      final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      // Try /health relative to the api root
      final healthUrl = base.replaceAll('/api', '') + '/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Session Helpers ─────────────────────────────────────────────────────────
  static Future<bool> saveSession(String token, Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_info', json.encode(user));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user_info');
    if (userStr != null) {
      return json.decode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_info');
    await prefs.remove('remember_me');
  }

  static Future<void> updateLocalUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_info', json.encode(user));
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('remember_me') ?? false;
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', value);
  }

  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final user = await getUser();
    return token != null && user != null;
  }

  // ─── Common Headers ──────────────────────────────────────────────────────────
  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        if (resBody['requires_mfa'] == true) {
          // MFA required – do not save session yet
          return {'success': true, 'requires_mfa': true, 'email': resBody['email']};
        }
        // Fallback if MFA ever gets disabled
        final token = resBody['token'];
        final user  = resBody['user'];
        await saveSession(token, user);
        return {'success': true, 'message': resBody['message'] ?? 'Login successful', 'user': user};
      } else {
        return {'success': false, 'error': resBody['message'] ?? resBody['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot connect to server at $baseUrl.\n'
            'Make sure the backend is running and the address is correct.',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyMfa(String email, String code, bool rememberMe) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/verify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code}),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        final token = resBody['token'];
        final user = resBody['user'];
        await saveSession(token, user);
        await setRememberMe(rememberMe);
        return {'success': true, 'message': 'Login successful', 'user': user};
      }
      return {'success': false, 'error': resBody['message'] ?? 'Invalid or expired code'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      return {'success': response.statusCode == 200, 'email': resBody['email'], 'message': resBody['message']};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'code': code, 'new_password': newPassword}),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': resBody['message'] ?? 'Password reset successfully'};
      }
      return {'success': false, 'error': resBody['message'] ?? 'Invalid or expired code'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> register(
      String username, String email, String password, String phone, String fullName) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'phone_number': phone,
          'full_name': fullName,
        }),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': resBody['message'] ?? 'Registration successful'};
      } else {
        return {'success': false, 'error': resBody['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Cannot connect to server at $baseUrl.\n'
            'Make sure the backend is running and the address is correct.',
      };
    }
  }

  // ─── System Config ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/config'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return {'success': true, 'config': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Failed to load system configuration'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Profile ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': resBody['user']};
      }
      return {'success': false, 'error': resBody['error'] ?? resBody['message'] ?? 'Failed to load profile'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile'),
        headers: await _getHeaders(),
        body: json.encode({
          'full_name': fullName,
          'phone_number': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        final user = resBody['user'] as Map<String, dynamic>;
        final existing = await getUser();
        if (existing != null) {
          final merged = {...existing, ...user};
          await updateLocalUser(merged);
        } else {
          await updateLocalUser(user);
        }
        return {
          'success': true,
          'message': resBody['message'] ?? 'Profile updated successfully',
          'user': user,
        };
      }
      return {'success': false, 'error': resBody['error'] ?? resBody['message'] ?? 'Failed to update profile'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user/change-password'),
        headers: await _getHeaders(),
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ).timeout(const Duration(seconds: 8));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': resBody['message'] ?? 'Password changed successfully'};
      }
      return {'success': false, 'error': resBody['error'] ?? resBody['message'] ?? 'Failed to change password'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── User Summary ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUserSummary() async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/user/summary/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'data': json.decode(response.body)};
      }
      final resBody = json.decode(response.body);
      return {'success': false, 'error': resBody['error'] ?? 'Failed to load user summary'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Transactions ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTransactions() async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/transactions/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'transactions': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Failed to load transactions'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Loans ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getLoans() async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.get(
        Uri.parse('$baseUrl/loans/$userId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'loans': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Failed to load loans'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> applyLoan(
      double amount, int durationMonths, String reason) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/loans/apply'),
        headers: await _getHeaders(),
        body: json.encode({
          'user_id': userId,
          'amount': amount,
          'duration_months': durationMonths,
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': resBody['message'] ?? 'Loan application submitted successfully'};
      }
      return {'success': false, 'error': resBody['error'] ?? 'Failed to submit loan application'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> repayLoan(int loanId, double amount) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/loans/repay'),
        headers: await _getHeaders(),
        body: json.encode({'user_id': userId, 'loan_id': loanId, 'amount': amount}),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'Loan repayment successful',
          'reference': resBody['reference'],
        };
      }
      return {'success': false, 'error': resBody['error'] ?? 'Failed to repay loan'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Deposit ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> deposit(double amount) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/deposit'),
        headers: await _getHeaders(),
        body: json.encode({'user_id': userId, 'amount': amount}),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'Deposit successful',
          'reference': resBody['reference'],
        };
      }
      return {'success': false, 'error': resBody['error'] ?? 'Failed to deposit'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Withdraw ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> withdraw(double amount) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/withdraw'),
        headers: await _getHeaders(),
        body: json.encode({'user_id': userId, 'amount': amount}),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'Withdrawal successful',
          'reference': resBody['reference'],
        };
      }
      return {'success': false, 'error': resBody['error'] ?? 'Failed to withdraw'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Shares ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> buyShares(double amount) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/shares/buy'),
        headers: await _getHeaders(),
        body: json.encode({'user_id': userId, 'amount': amount}),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'Shares purchased successfully',
          'reference': resBody['reference'],
        };
      }
      return {'success': false, 'error': resBody['error'] ?? 'Failed to purchase shares'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Transfer ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> transfer(String receiverEmail, double amount) async {
    try {
      final user = await getUser();
      if (user == null) return {'success': false, 'error': 'User session not found'};

      final userId = user['id'];
      final response = await http.post(
        Uri.parse('$baseUrl/transfer'),
        headers: await _getHeaders(),
        body: json.encode({
          'sender_id': userId,
          'receiver_email': receiverEmail,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 5));

      final resBody = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': resBody['message'] ?? 'Transfer successful',
          'reference': resBody['reference'],
        };
      }
      return {'success': false, 'error': resBody['error'] ?? 'Transfer failed'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  // ─── Notifications ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'notifications': json.decode(response.body)};
      }
      return {'success': false, 'error': 'Failed to load notifications'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(int id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Notification marked as read'};
      }
      return {'success': false, 'error': 'Failed to update notification'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'All notifications marked as read'};
      }
      return {'success': false, 'error': 'Failed to update notifications'};
    } catch (e) {
      return {'success': false, 'error': 'Cannot connect to server.'};
    }
  }
}
