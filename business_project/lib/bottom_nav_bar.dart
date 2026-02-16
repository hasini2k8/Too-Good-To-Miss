import 'package:flutter/material.dart';
import 'customer_home_page.dart';
import 'mapPage.dart';
import 'ai_chatbot_page.dart';
import 'profile_page.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1565C0),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavIcon(context, Icons.home, 0, 'Home'),
            _buildNavIcon(context, Icons.location_on, 1, 'Map'),
            _buildNavIcon(context, Icons.camera_alt, 2, 'AI Chat'),
            _buildNavIcon(context, Icons.settings, 3, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(
    BuildContext context,
    IconData icon,
    int index,
    String label,
  ) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        // Don't navigate if already on the current page
        if (index == selectedIndex) return;

        // Navigate to the appropriate page
        Widget page;
        switch (index) {
          case 0:
            page = const CustomerHomePage();
            break;
          case 1:
            page = const MapPage();
            break;
          case 2:
            page = const AIChatbotPage();
            break;
          case 3:
            page = const ProfilePage();
            break;
          default:
            return;
        }

        // Use pushReplacement to avoid stacking pages
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => page,
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.lightBlue[300] : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}