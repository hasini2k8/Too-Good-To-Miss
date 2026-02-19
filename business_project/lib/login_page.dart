import 'package:flutter/material.dart';
import 'signup_page.dart';
import 'services/auth_service.dart';
import 'customer_home_page.dart';
import 'business_dashboard_page.dart';
import 'widgets/puzzle_captcha_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isCaptchaVerified = false;
  bool _showCaptcha = false;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn();
  }

  Future<void> _checkIfLoggedIn() async {
    final user = await AuthService.getCurrentUser();
    if (user != null && mounted) {
      // User is already logged in, navigate to appropriate page
      if (user['userType'] == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CustomerHomePage()),
        );
      } else {
        // Get business data for business users
        final businessData = _getBusinessData(user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessDashboardPage(
              businessName: user['username'] ?? 'My Business',
              businessData: businessData,
            ),
          ),
        );
      }
    }
  }

  // Helper method to create default business data
  Map<String, dynamic> _getBusinessData(Map<String, dynamic> user) {
    return {
      'name': user['username'] ?? 'My Business',
      'icon': '🏢', // Default business icon
      'category': user['category'] ?? 'General',
      'description': user['description'] ?? 'Welcome to my business dashboard!',
      'location': user['location'] ?? 'Not specified',
      'rating': user['rating'] ?? 4.5,
    };
  }

  void _onCaptchaVerified(bool isVerified) {
    setState(() {
      _isCaptchaVerified = isVerified;
    });

    if (isVerified) {
      // Proceed with login after successful captcha
      _performLogin();
    }
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    // Show captcha before allowing login
    setState(() {
      _showCaptcha = true;
      _isCaptchaVerified = false;
    });
  }

  Future<void> _performLogin() async {
    setState(() {
      _isLoading = true;
    });

    final user = await AuthService.loginUser(
      usernameOrEmail: _usernameController.text,
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = false;
      _showCaptcha = false;
      _isCaptchaVerified = false;
    });

    if (user != null && mounted) {
      // Login successful
      if (user['userType'] == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CustomerHomePage()),
        );
      } else {
        // Get business data for business users
        final businessData = _getBusinessData(user);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessDashboardPage(
              businessName: user['username'] ?? 'My Business',
              businessData: businessData,
            ),
          ),
        );
      }
    } else {
      // Login failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: Image.asset(
                        'assets/logo-tooGoodToMiss.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Too Good to MISS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username or Email',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Show captcha if login button was pressed
                if (_showCaptcha && !_isCaptchaVerified)
                  Column(
                    children: [
                      PuzzleCaptchaWidget(
                        onVerified: _onCaptchaVerified,
                        width: MediaQuery.of(context).size.width - 48,
                        height: 150,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}