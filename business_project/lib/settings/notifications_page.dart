import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _newBusinessAlerts = true;
  bool _reviewReminders = true;
  bool _promotionsOffers = true;
  bool _weeklyDigest = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
      _emailNotifications = prefs.getBool('email_notifications') ?? false;
      _newBusinessAlerts = prefs.getBool('new_business_alerts') ?? true;
      _reviewReminders = prefs.getBool('review_reminders') ?? true;
      _promotionsOffers = prefs.getBool('promotions_offers') ?? true;
      _weeklyDigest = prefs.getBool('weekly_digest') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'General',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.notifications_active,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications on your device',
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
              _saveSetting('push_notifications', value);
            },
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.email,
            title: 'Email Notifications',
            subtitle: 'Receive notifications via email',
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
              _saveSetting('email_notifications', value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Content',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingTile(
            icon: Icons.store,
            title: 'New Business Alerts',
            subtitle: 'Get notified when new businesses join',
            value: _newBusinessAlerts,
            onChanged: (value) {
              setState(() => _newBusinessAlerts = value);
              _saveSetting('new_business_alerts', value);
            },
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.rate_review,
            title: 'Review Reminders',
            subtitle: 'Reminders to review places you visited',
            value: _reviewReminders,
            onChanged: (value) {
              setState(() => _reviewReminders = value);
              _saveSetting('review_reminders', value);
            },
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.local_offer,
            title: 'Promotions & Offers',
            subtitle: 'Special deals and promotional offers',
            value: _promotionsOffers,
            onChanged: (value) {
              setState(() => _promotionsOffers = value);
              _saveSetting('promotions_offers', value);
            },
          ),
          const SizedBox(height: 8),
          _buildSettingTile(
            icon: Icons.email_outlined,
            title: 'Weekly Digest',
            subtitle: 'Weekly summary of new startups',
            value: _weeklyDigest,
            onChanged: (value) {
              setState(() => _weeklyDigest = value);
              _saveSetting('weekly_digest', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22,
            color: const Color(0xFF1565C0),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF1565C0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}