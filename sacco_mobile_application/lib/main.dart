import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'theme/app_colors.dart';

// Import screens
import 'screens/splash1.dart';
import 'screens/splash2.dart';
import 'screens/splash3.dart';
import 'screens/public/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/services_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/main_container.dart';
import 'screens/registration_success_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/forms/contribution_form.dart';
import 'screens/forms/loan_application_form.dart';
import 'screens/mfa_verification_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/info/content_screen.dart';


void main() async {
  // Ensure Flutter bindings are initialised before calling async platform code
  WidgetsFlutterBinding.ensureInitialized();
  // Load any user-saved custom backend URL from persistent storage
  await ApiService.loadSavedBaseUrl();
  runApp(const SaccoApp());
}

// Root widget of the application
class SaccoApp extends StatelessWidget {
  const SaccoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade100),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),

      // Initial screen displayed when app starts
      initialRoute: '/',

      // Named routes for navigation
      routes: {
        '/': (context) => const Splash1(),
        '/splash2': (context) => const Splash2(),
        '/splash3': (context) => const Splash3(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const MainContainer(),
        '/services': (context) => const ServicesScreen(),
        '/savings': (context) => const SavingsScreen(),
        '/loans': (context) => const LoansScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/registration_success': (context) => const RegistrationSuccessScreen(),
        '/pay': (context) => const PaymentScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/contribution_form': (context) => const ContributionForm(),
        '/loan_application_form': (context) => const LoanApplicationForm(),
        '/mfa_verification': (context) => const MfaVerificationScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/faq': (context) => const ContentScreen(type: ContentPageType.faq),
        '/terms': (context) => const ContentScreen(type: ContentPageType.terms),
        '/help': (context) => const ContentScreen(type: ContentPageType.help),
      },
    );
  }
}
