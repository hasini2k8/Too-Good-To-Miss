import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';
import 'login_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  final String businessName;
  final Map<String, dynamic> businessData;

  const BusinessDashboardPage({
    super.key,
    required this.businessName,
    required this.businessData,
  });

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _promotions = [];
  List<Map<String, dynamic>> _customerMessages = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _reviews = [];
  
  late TabController _analyticsTabController;

  final _promoTitleController = TextEditingController();
  final _promoDescController = TextEditingController();
  final _promoDiscountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analyticsTabController = TabController(length: 4, vsync: this);
    _loadMockData();
  }

  @override
  void dispose() {
    _analyticsTabController.dispose();
    super.dispose();
  }

  void _loadMockData() {
    // Mock customer messages
    _customerMessages = [
      {
        'customerName': 'Alice Cooper',
        'message': 'What are your business hours?',
        'time': '2 hours ago',
        'unread': true,
      },
      {
        'customerName': 'David Lee',
        'message': 'Do you offer delivery?',
        'time': '5 hours ago',
        'unread': true,
      },
      {
        'customerName': 'Emma Stone',
        'message': 'Thank you for the great service!',
        'time': '1 day ago',
        'unread': false,
      },
    ];

    // Mock notifications
    _notifications = [
      {
        'title': 'New Review',
        'message': 'You received a 5-star review!',
        'time': '1 hour ago',
        'icon': Icons.star,
        'color': Colors.amber,
      },
      {
        'title': 'New Promotion',
        'message': 'Your summer sale is now active',
        'time': '3 hours ago',
        'icon': Icons.local_offer,
        'color': Colors.orange,
      },
      {
        'title': 'Profile Update',
        'message': 'Your business info was updated',
        'time': '5 hours ago',
        'icon': Icons.business,
        'color': Colors.blue,
      },
    ];

    // Mock reviews
    _reviews = [
      {
        'customerName': 'Tom Harris',
        'rating': 5,
        'comment': 'Excellent service and great quality!',
        'date': '2024-02-15',
        'responded': false,
      },
      {
        'customerName': 'Mary Johnson',
        'rating': 4,
        'comment': 'Good experience overall, will come back.',
        'date': '2024-02-14',
        'responded': true,
      },
      {
        'customerName': 'Chris Evans',
        'rating': 5,
        'comment': 'Best in town! Highly recommend.',
        'date': '2024-02-13',
        'responded': false,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        title: Text(
          widget.businessName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Notifications badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _showNotifications(),
              ),
              if (_notifications.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_notifications.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Messages badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message, color: Colors.white),
                onPressed: () => _showMessages(),
              ),
              if (_customerMessages.where((m) => m['unread']).isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_customerMessages.where((m) => m['unread']).length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _getSelectedPage(),
      bottomNavigationBar: Container(
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
              _buildNavIcon(Icons.dashboard, 'Overview', 0),
              _buildNavIcon(Icons.edit, 'Edit', 1),
              _buildNavIcon(Icons.local_offer, 'Promos', 2),
              _buildNavIcon(Icons.analytics, 'Analytics', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewPage();
      case 1:
        return _buildEditBusinessPage();
      case 2:
        return _buildPromotionsPage();
      case 3:
        return _buildAnalyticsPage();
      default:
        return _buildOverviewPage();
    }
  }

  Widget _buildOverviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business Info Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(
                          widget.businessData['icon'],
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.businessName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.businessData['category'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.businessData['rating']} / 5.0',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        'QR Code',
                        Icons.qr_code,
                        () => _showQRCode(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        'Share',
                        Icons.share,
                        () => _shareProfile(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick Stats Grid
          const Text(
            'Today\'s Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard('Views', '1,234', Icons.visibility, '+12%', Colors.blue),
              _buildStatCard('Bookmarks', '89', Icons.bookmark, '+5%', Colors.pink),
              _buildStatCard('Promotions', '${_promotions.length}', Icons.local_offer, 'Active', Colors.green),
              _buildStatCard('Messages', '${_customerMessages.where((m) => m['unread']).length}', Icons.message, 'Unread', Colors.orange),
              _buildStatCard('Revenue', '\$2,450', Icons.attach_money, '+18%', Colors.teal),
              _buildStatCard('Reviews', '${_reviews.where((r) => !r['responded']).length}', Icons.rate_review, 'Pending', Colors.purple),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity
          _buildSectionHeader('Recent Activity', Icons.history),
          const SizedBox(height: 12),
          _buildActivityTimeline(),

          const SizedBox(height: 24),

          // Pending Reviews
          if (_reviews.where((r) => !r['responded']).isNotEmpty) ...[
            _buildSectionHeader('Reviews Awaiting Response', Icons.rate_review),
            const SizedBox(height: 12),
            ..._reviews
                .where((r) => !r['responded'])
                .take(2)
                .map((review) => _buildReviewPreviewCard(review)),
          ],
        ],
      ),
    );
  }

  Widget _buildEditBusinessPage() {
    final nameController = TextEditingController(text: widget.businessData['name']);
    final descController = TextEditingController(text: widget.businessData['description']);
    final locationController = TextEditingController(text: widget.businessData['location']);
    final phoneController = TextEditingController(text: '+1 (555) 123-4567');
    final emailController = TextEditingController(text: 'contact@business.com');
    final websiteController = TextEditingController(text: 'www.business.com');
    
    List<String> selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    TimeOfDay openTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay closeTime = const TimeOfDay(hour: 18, minute: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Business Information', Icons.business),
          const SizedBox(height: 16),
          _buildEditField('Business Name', nameController, Icons.business),
          const SizedBox(height: 16),
          _buildEditField('Description', descController, Icons.description, maxLines: 3),
          const SizedBox(height: 16),
          _buildEditField('Location', locationController, Icons.location_on),
          const SizedBox(height: 16),
          _buildEditField('Phone', phoneController, Icons.phone),
          const SizedBox(height: 16),
          _buildEditField('Email', emailController, Icons.email),
          const SizedBox(height: 16),
          _buildEditField('Website', websiteController, Icons.language),

          const SizedBox(height: 24),
          _buildSectionHeader('Business Hours', Icons.access_time),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operating Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map((day) => FilterChip(
                            label: Text(day),
                            selected: selectedDays.contains(day),
                            onSelected: (selected) {
                              // Toggle day selection
                            },
                            selectedColor: const Color(0xFF1565C0),
                            labelStyle: TextStyle(
                              color: selectedDays.contains(day) ? Colors.white : Colors.black87,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Opens'),
                        subtitle: Text(openTime.format(context)),
                        leading: const Icon(Icons.wb_sunny),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: openTime,
                          );
                          if (time != null) {
                            // Update open time
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('Closes'),
                        subtitle: Text(closeTime.format(context)),
                        leading: const Icon(Icons.nightlight_round),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: closeTime,
                          );
                          if (time != null) {
                            // Update close time
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          _buildSectionHeader('Social Media Links', Icons.share),
          const SizedBox(height: 16),
          _buildEditField('Facebook', TextEditingController(), Icons.facebook),
          const SizedBox(height: 16),
          _buildEditField('Instagram', TextEditingController(), Icons.camera_alt),
          const SizedBox(height: 16),
          _buildEditField('Twitter/X', TextEditingController(), Icons.tag),
          const SizedBox(height: 16),
          _buildEditField('LinkedIn', TextEditingController(), Icons.business_center),
          const SizedBox(height: 16),
          _buildEditField('YouTube', TextEditingController(), Icons.play_circle_outline),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ All changes saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text(
                'Save All Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Promotional Offers',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddPromoDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Promo Statistics
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPromoStat('Active', '${_promotions.where((p) => p['active']).length}', Colors.green),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildPromoStat('Inactive', '${_promotions.where((p) => !p['active']).length}', Colors.orange),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildPromoStat('Total', '${_promotions.length}', Colors.blue),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          if (_promotions.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No promotions yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Create your first promotion to attract customers', 
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _promotions.length,
              itemBuilder: (context, index) => _buildPromoCard(_promotions[index], index),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsPage() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1565C0),
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Traffic'),
                Tab(text: 'Revenue'),
                Tab(text: 'Customers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAnalyticsOverview(),
                _buildTrafficAnalytics(),
                _buildRevenueAnalytics(),
                _buildCustomerAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Overview',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          
          // Key metrics
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildMetricCard('Total Views', '12,456', '+23%', Icons.visibility, Colors.blue),
              _buildMetricCard('Conversions', '892', '+15%', Icons.trending_up, Colors.green),
              _buildMetricCard('Avg. Rating', '4.8', '+0.2', Icons.star, Colors.amber),
              _buildMetricCard('Response Time', '2.5h', '-15%', Icons.access_time, Colors.purple),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Weekly comparison
          _buildSectionHeader('Weekly Comparison', Icons.bar_chart),
          const SizedBox(height: 12),
          _buildWeeklyChart(),
        ],
      ),
    );
  }

  Widget _buildTrafficAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Traffic Sources', Icons.language),
          const SizedBox(height: 16),
          _buildTrafficSourceCard('Direct', 45, Colors.blue),
          _buildTrafficSourceCard('Search Engines', 30, Colors.green),
          _buildTrafficSourceCard('Social Media', 15, Colors.purple),
          _buildTrafficSourceCard('Referrals', 10, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildRevenueAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Revenue',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '\$24,567',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green[300], size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '+18% from last month',
                      style: TextStyle(color: Colors.green[300]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Revenue Breakdown', Icons.pie_chart),
          const SizedBox(height: 12),
          _buildRevenueBreakdownCard('Product Sales', '\$15,230', 62),
          _buildRevenueBreakdownCard('Services', '\$7,450', 30),
          _buildRevenueBreakdownCard('Other', '\$1,887', 8),
        ],
      ),
    );
  }

  Widget _buildCustomerAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Customer Insights', Icons.people),
          const SizedBox(height: 16),
          _buildCustomerInsightCard('Total Customers', '1,234', Icons.people, Colors.blue),
          const SizedBox(height: 12),
          _buildCustomerInsightCard('New This Month', '156', Icons.person_add, Colors.green),
          const SizedBox(height: 12),
          _buildCustomerInsightCard('Returning', '892', Icons.replay, Colors.purple),
          const SizedBox(height: 12),
          _buildCustomerInsightCard('Avg. Order Value', '\$89', Icons.shopping_cart, Colors.orange),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildNavIcon(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF1565C0)),
      label: Text(label, style: const TextStyle(color: Color(0xFF1565C0))),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, String trend, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTimeline() {
    final activities = [
      {'title': 'New review received', 'subtitle': '5 stars from Tom Harris', 'time': '2 hours ago', 'icon': Icons.star},
      {'title': 'Appointment booked', 'subtitle': 'John Doe - 10:00 AM', 'time': '4 hours ago', 'icon': Icons.calendar_today},
      {'title': 'Product sold', 'subtitle': 'Product A - \$29.99', 'time': '6 hours ago', 'icon': Icons.shopping_cart},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: activities.map((activity) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(activity['icon'] as IconData, 
                    color: const Color(0xFF1565C0), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        activity['subtitle'] as String,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  activity['time'] as String,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReviewPreviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1565C0),
                child: Text(
                  review['customerName'][0],
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['customerName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: List.generate(
                        review['rating'],
                        (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showRespondToReviewDialog(review),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Respond', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review['comment'], style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildPromoCard(Map<String, dynamic> promo, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  promo['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: promo['active']
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  promo['active'] ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: promo['active'] ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(promo['description'], style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            promo['discount'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _promotions[index]['active'] = !_promotions[index]['active'];
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1565C0)),
                  ),
                  child: Text(
                    promo['active'] ? 'Deactivate' : 'Activate',
                    style: const TextStyle(color: Color(0xFF1565C0)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _promotions.removeAt(index);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Promotion deleted')),
                  );
                },
                icon: const Icon(Icons.delete),
                color: Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String change, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            change,
            style: TextStyle(
              fontSize: 11,
              color: change.startsWith('+') ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) {
          final random = Random();
          final height = 50.0 + random.nextDouble() * 100;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: height,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                day,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrafficSourceCard(String source, int percentage, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                source,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdownCard(String label, String amount, int percentage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInsightCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  // Dialogs
  void _showAddPromoDialog() {
    _promoTitleController.clear();
    _promoDescController.clear();
    _promoDiscountController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Promotion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _promoTitleController,
                decoration: const InputDecoration(
                  labelText: 'Promotion Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promoDescController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _promoDiscountController,
                decoration: const InputDecoration(
                  labelText: 'Discount (e.g., 20% OFF)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_promoTitleController.text.isNotEmpty) {
                setState(() {
                  _promotions.add({
                    'title': _promoTitleController.text,
                    'description': _promoDescController.text,
                    'discount': _promoDiscountController.text,
                    'active': true,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Promotion added!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan to Visit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1565C0), width: 2),
                ),
                child: QrImageView(
                  data: 'https://business.com/${widget.businessName.toLowerCase().replaceAll(' ', '-')}',
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.businessName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR Code downloaded!')),
                  );
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('Download QR', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareProfile() {
    Clipboard.setData(
      ClipboardData(
        text: 'Check out ${widget.businessName} at https://business.com/${widget.businessName.toLowerCase().replaceAll(' ', '-')}',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Link copied to clipboard!')),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.notifications, color: Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications (${_notifications.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (notif['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(notif['icon'] as IconData, color: notif['color'] as Color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                notif['message'],
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Text(
                                notif['time'],
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.message, color: Color(0xFF1565C0)),
                  const SizedBox(width: 12),
                  Text(
                    'Customer Messages (${_customerMessages.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _customerMessages.length,
                itemBuilder: (context, index) {
                  final msg = _customerMessages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: msg['unread'] ? Colors.blue[50] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: msg['unread'] ? const Color(0xFF1565C0) : Colors.grey[200]!,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1565C0),
                        child: Text(
                          msg['customerName'][0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        msg['customerName'],
                        style: TextStyle(
                          fontWeight: msg['unread'] ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        msg['message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg['time'],
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          if (msg['unread'])
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1565C0),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        // Open message conversation
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRespondToReviewDialog(Map<String, dynamic> review) {
    final responseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to ${review['customerName']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(review['comment']),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: responseController,
              decoration: const InputDecoration(
                labelText: 'Your Response',
                border: OutlineInputBorder(),
                hintText: 'Thank you for your feedback...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = _reviews.indexOf(review);
                _reviews[index]['responded'] = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Response sent!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}