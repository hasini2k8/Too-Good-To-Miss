import 'package:flutter/material.dart';
import 'login_page.dart';
import 'services/auth_service.dart';
import 'settings/edit_profile_page.dart';
import 'settings/notifications_page.dart';
import 'settings/privacy_security_page.dart';
import 'settings/help_support_page.dart';
import 'settings/about_page.dart';
import 'bottom_nav_bar.dart';
import 'pixel_pet_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String userName = 'Loading...';
  String userEmail = 'Loading...';
  int points = 0;
  int reviewsPosted = 0;
  int placesVisited = 0;
  int favorites = 0;
  String memberSince = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    _loadUserData();

    // Listen to the global stats notifier so any place-visit / review / bookmark
    // from ANY page triggers a refresh here automatically.
    AuthService.statsVersion.addListener(_onStatsChanged);
  }

  void _onStatsChanged() {
    // Called whenever AuthService.updateUser() succeeds anywhere in the app.
    if (mounted) _refreshUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh whenever this page becomes visible (e.g. navigating back from map page).
    // _loadUserData handles the very first load; subsequent calls use _refreshUserData.
    if (!_isLoading) _refreshUserData();
  }

  @override
  void dispose() {
    AuthService.statsVersion.removeListener(_onStatsChanged);
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _applyUserData(user);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUserData() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _applyUserData(user));
    }
  }

  void _applyUserData(Map<String, dynamic> user) {
    userName = user['username'] ?? 'User';
    userEmail = user['email'] ?? '';
    points = user['points'] ?? 0;
    reviewsPosted = user['reviewsPosted'] ?? 0;
    placesVisited = user['placesVisited'] ?? 0;
    favorites = user['favorites'] ?? 0;

    try {
      final dateTime = DateTime.parse(user['memberSince']);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      memberSince = '${months[dateTime.month - 1]} ${dateTime.year}';
    } catch (_) {
      memberSince = 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFE8F4F8),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: RefreshIndicator(
        onRefresh: _refreshUserData,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white),
                              onPressed: _refreshUserData,
                              tooltip: 'Refresh stats',
                            ),
                          ),
                        ),
                        _buildProfilePicture(),
                        const SizedBox(height: 16),
                        Text(
                          userName,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Member since $memberSince',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Points card ──────────────────────────────────────────
                  _buildPointsCard(),

                  const SizedBox(height: 20),

                  // ── Pixel Pet ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: PixelPetWidget(onPointsChanged: _refreshUserData),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats grid ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard('Reviews',
                              reviewsPosted.toString(),
                              Icons.rate_review, Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard('Visited',
                              placesVisited.toString(),
                              Icons.location_on, Colors.green),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStatCard('Favorites', favorites.toString(),
                        Icons.favorite, Colors.red,
                        isWide: true),
                  ),

                  const SizedBox(height: 20),

                  _buildPointsBreakdown(),
                  const SizedBox(height: 20),
                  _buildAchievements(),
                  const SizedBox(height: 20),
                  _buildSettingsOptions(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 3),
    );
  }

  // ── Widgets (identical visuals, unchanged) ────────────────────────────────

  Widget _buildProfilePicture() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 3),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple[200]!, Colors.purple[400]!],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.purple.withOpacity(0.5),
                    blurRadius: 15,
                    offset: const Offset(0, 5)),
              ],
            ),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2), blurRadius: 5)
                ],
              ),
              child: const Icon(Icons.edit,
                  size: 16, color: Color(0xFF1565C0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars,
                    size: 32, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 12),
                const Text('Total Points',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              points.toString(),
              style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('🔥 Keep exploring!',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsBreakdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Points Breakdown',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0))),
            const SizedBox(height: 12),
            _buildPointsRow('📌 Bookmarks', favorites, 5),
            const SizedBox(height: 8),
            _buildPointsRow('✍️ Reviews', reviewsPosted, 10),
            const SizedBox(height: 8),
            _buildPointsRow('📍 Places Visited', placesVisited, 2),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Points',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                Text(points.toString(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Achievements',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAchievementBadge('🏆', 'Explorer', placesVisited >= 5),
              _buildAchievementBadge('⭐', 'Reviewer', reviewsPosted >= 3),
              _buildAchievementBadge('💎', 'VIP', points >= 100),
              _buildAchievementBadge('🎯', 'Elite', points >= 500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSettingsOption(Icons.person_outline, 'Edit Profile', () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const EditProfilePage()),
            );
            if (result == true) _refreshUserData();
          }),
          _buildSettingsOption(Icons.notifications_outlined, 'Notifications',
              () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationsPage()),
            );
          }),
          _buildSettingsOption(
              Icons.security_outlined, 'Privacy & Security', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const PrivacySecurityPage()),
            );
          }),
          _buildSettingsOption(Icons.help_outline, 'Help & Support', () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const HelpSupportPage()),
            );
          }),
          _buildSettingsOption(Icons.info_outline, 'About', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutPage()),
            );
          }),
          const SizedBox(height: 8),
          _buildSettingsOption(Icons.logout, 'Logout', () {
            _showLogoutDialog(context);
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildPointsRow(String label, int count, int pointsPerItem) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$label ($count × $pointsPerItem)',
            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Text('${count * pointsPerItem} pts',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800])),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color,
      {bool isWide = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(value,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 12),
                Text(value,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
              ],
            ),
    );
  }

  Widget _buildAchievementBadge(
      String emoji, String label, bool unlocked) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: unlocked ? Colors.white : Colors.grey[200],
            shape: BoxShape.circle,
            boxShadow: unlocked
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: Text(emoji,
                style: TextStyle(
                    fontSize: 32,
                    color: unlocked ? null : Colors.grey[400])),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: unlocked
                    ? const Color(0xFF1565C0)
                    : Colors.grey[400])),
      ],
    );
  }

  Widget _buildSettingsOption(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 22,
              color: isDestructive ? Colors.red : const Color(0xFF1565C0)),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : Colors.black87)),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}