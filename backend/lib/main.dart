import 'package:flutter/material.dart';

// Import screens
import 'screens/splash1.dart';
import 'screens/splash2.dart';
import 'screens/splash3.dart';
import 'screens/public/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/savings_screen.dart';
import 'screens/loans_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/main_container.dart';
import 'screens/registration_success_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/forms/contribution_form.dart';
import 'screens/forms/loan_application_form.dart';


void main() {
  // Entry point of the Flutter application
  runApp(const SaccoApp());
}

// Root widget of the application
class SaccoApp extends StatelessWidget {
  const SaccoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

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
        '/savings': (context) => const SavingsScreen(),
        '/loans': (context) => const LoansScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/registration_success': (context) => const RegistrationSuccessScreen(),
        '/pay': (context) => const PaymentScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/contribution_form': (context) => const ContributionForm(),
        '/loan_application_form': (context) => const LoanApplicationForm(),
      },
    );
  }
}
