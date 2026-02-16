import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'signup_page.dart';
import 'services/auth_service.dart';
import 'customer_home_page.dart';
import 'business_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isRecaptchaVerified = false;
  String? _recaptchaToken;

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

  Future<void> _showRecaptchaDialog() async {
    final token = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RecaptchaDialog(),
    );

    if (token != null && token.isNotEmpty) {
      setState(() {
        _isRecaptchaVerified = true;
        _recaptchaToken = token;
      });
      // Proceed with login after successful reCAPTCHA
      _handleLogin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('reCAPTCHA verification failed')),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    if (!_isRecaptchaVerified) {
      // Show reCAPTCHA dialog
      await _showRecaptchaDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: Send _recaptchaToken to your backend for verification
    final user = await AuthService.loginUser(
      usernameOrEmail: _usernameController.text,
      password: _passwordController.text,
      recaptchaToken: _recaptchaToken, // Pass token to backend
    );

    setState(() {
      _isLoading = false;
      _isRecaptchaVerified = false; // Reset for next login attempt
      _recaptchaToken = null;
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

class RecaptchaDialog extends StatefulWidget {
  const RecaptchaDialog({super.key});

  @override
  State<RecaptchaDialog> createState() => _RecaptchaDialogState();
}

class _RecaptchaDialogState extends State<RecaptchaDialog> {
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Page loaded
          },
        ),
      )
      ..addJavaScriptChannel(
        'RecaptchaChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // Received reCAPTCHA token
          Navigator.of(context).pop(message.message);
        },
      )
      ..loadHtmlString(_getRecaptchaHtml());
  }

  String _getRecaptchaHtml() {
    // DEVELOPMENT TEST KEYS - These work on localhost!
    // ⚠️ Replace with your production keys before deploying!
    // Site key: Register your domain at https://www.google.com/recaptcha/admin
    const siteKey = '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI'; // Test key
    
    // For production, use your real site key:
    // const siteKey = 'YOUR_PRODUCTION_SITE_KEY';
    
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://www.google.com/recaptcha/api.js" async defer></script>
    <style>
        body {
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
        }
        .container {
            text-align: center;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h2 {
            color: #1565C0;
            margin-bottom: 20px;
        }
        #recaptcha-container {
            display: inline-block;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Verify you're human</h2>
        <div id="recaptcha-container">
            <div class="g-recaptcha" 
                 data-sitekey="$siteKey" 
                 data-callback="onRecaptchaSuccess">
            </div>
        </div>
    </div>
    
    <script>
        function onRecaptchaSuccess(token) {
            // Send token back to Flutter
            if (window.RecaptchaChannel) {
                window.RecaptchaChannel.postMessage(token);
            }
        }
    </script>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Security Check',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: WebViewWidget(controller: _webViewController),
            ),
          ],
        ),
      ),
    );
  }
}