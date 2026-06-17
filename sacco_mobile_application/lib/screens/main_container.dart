import 'package:flutter/material.dart';
import '../widgets/custom_images.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_support.dart';
import 'dashboard_screen.dart';
import 'services_screen.dart';
import 'savings_screen.dart';
import 'loans_screen.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ServicesScreen();
      case 2:
        return const SavingsScreen();
      case 3:
        return const LoansScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: SaccoDrawer(
        onServicesTap: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      ),
      body: _getScreen(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.grey.shade400,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view),
                label: 'Services',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.savings_outlined),
                activeIcon: Icon(Icons.savings),
                label: 'Savings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_outlined),
                activeIcon: Icon(Icons.account_balance),
                label: 'Loans',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SaccoDrawer extends StatefulWidget {
  final VoidCallback onServicesTap;

  const SaccoDrawer({super.key, required this.onServicesTap});

  @override
  State<SaccoDrawer> createState() => _SaccoDrawerState();
}

class _SaccoDrawerState extends State<SaccoDrawer> {
  String _name = 'Member';
  String _email = 'member@sacco.ug';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = await ApiService.getUser();
    if (user != null && mounted) {
      setState(() {
        _name = user['full_name'] ?? user['username'] ?? 'Member';
        _email = user['email'] ?? 'member@sacco.ug';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.drawerGradient),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 25, left: 25, right: 25),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(5),
                    child: CustomPaint(
                      painter: LogoPainter(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          // Navigation options
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 15),
              children: [
                _buildDrawerItem(Icons.person_outline, 'Profile', () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile').then((_) => _loadUserInfo());
                }),
                _buildDrawerItem(Icons.mail_outline, 'Contact us', () {
                  Navigator.pop(context);
                  AppSupport.showContactSheet(context);
                }),
                _buildDrawerItem(Icons.share_outlined, 'Refer a friend', () {
                  Navigator.pop(context);
                  AppSupport.shareReferral(context);
                }),
                _buildDrawerItem(Icons.grid_view_outlined, 'Services', () {
                  Navigator.pop(context); // close drawer
                  widget.onServicesTap(); // trigger tab switch
                }),
                _buildDrawerItem(Icons.help_outline, 'FAQS', () {
                  Navigator.pop(context);
                  AppSupport.openFaq(context);
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Divider(color: Colors.white12, height: 30),
                ),
                _buildDrawerItem(Icons.logout, 'Logout', () async {
                  Navigator.pop(context);
                  await ApiService.clearSession();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                }),
              ],
            ),
          ),
          // Powered by Footer
          const Padding(
            padding: EdgeInsets.only(bottom: 25),
            child: Text(
              'Powered by Tower Sacco',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      horizontalTitleGap: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
      splashColor: Colors.white.withOpacity(0.05),
    );
  }
}
