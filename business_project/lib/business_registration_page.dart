import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_picker_page.dart';
import 'business_dashboard_page.dart';

class BusinessRegistrationPage extends StatefulWidget {
  const BusinessRegistrationPage({super.key});

  @override
  State<BusinessRegistrationPage> createState() =>
      _BusinessRegistrationPageState();
}

class _BusinessRegistrationPageState extends State<BusinessRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _iconController = TextEditingController();

  String _selectedCategory = 'Technology';
  bool _isVerified = false;
  double? _selectedLatitude;
  double? _selectedLongitude;

  final List<String> _categories = ['Food', 'Retail', 'Technology', 'Services'];

  void _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _locationController.text = result['address'] ?? 
            '${result['latitude']}, ${result['longitude']}';
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedLatitude == null || _selectedLongitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a location on the map')),
        );
        return;
      }

      if (!_isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete bot verification')),
        );
        return;
      }

      final businessData = {
        'name': _businessNameController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'latitude': _selectedLatitude.toString(),
        'longitude': _selectedLongitude.toString(),
        'category': _selectedCategory,
        'icon': _iconController.text,
        'rating': '5.0',
      };

      final emailBody = '''
Business Registration Request

Business Name: ${businessData['name']}
Description: ${businessData['description']}
Location: ${businessData['location']}
Latitude: ${businessData['latitude']}
Longitude: ${businessData['longitude']}
Category: ${businessData['category']}
Icon: ${businessData['icon']}

JSON Format for startups.json:
{
  "name": "${businessData['name']}",
  "description": "${businessData['description']}",
  "location": "${businessData['location']}",
  "latitude": ${businessData['latitude']},
  "longitude": ${businessData['longitude']},
  "category": "${businessData['category']}",
  "rating": 5.0,
  "icon": "${businessData['icon']}"
}
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'hasini2k8@gmail.com',
        query:
            'subject=Business Registration Request - ${businessData['name']}&body=${Uri.encodeComponent(emailBody)}',
      );

      try {
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Registration Submitted'),
                content: const Text(
                  'Your business registration has been submitted for approval. Meanwhile, you can access your business dashboard.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessDashboardPage(
                            businessName: _businessNameController.text,
                            businessData: businessData,
                          ),
                        ),
                      );
                    },
                    child: const Text('Go to Dashboard'),
                  ),
                ],
              ),
            );
          }
        } else {
          throw 'Could not launch email client';
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending email: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text(
          'Register Your Business',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Business Information',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business Name *',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter business name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Business Description *',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Location *',
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.map),
                      onPressed: _pickLocation,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Tap map icon to select location',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select location from map';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                if (_selectedLatitude != null && _selectedLongitude != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Coordinates: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _iconController,
                  decoration: InputDecoration(
                    labelText: 'Business Icon (Emoji) *',
                    prefixIcon: const Icon(Icons.emoji_emotions),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g., 🍕 🛍️ 💻',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an icon';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _isVerified,
                        onChanged: (value) {
                          setState(() {
                            _isVerified = value!;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I verify that I am not a robot',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit for Approval',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your registration will be sent to hasini2k8@gmail.com for approval',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}