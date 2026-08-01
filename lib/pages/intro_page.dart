import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_profile_service.dart';
import 'home_page.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  
  bool _isLoading = false;
  final _profileService = SupabaseProfileService.instance;

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User session not found.");

      final name = _nameController.text.trim();
      final budget = double.tryParse(_budgetController.text) ?? 8000.0;
      final email = user.email ?? '';

      final success = await _profileService.createProfile(
        userId: user.id,
        name: name,
        budgetGoal: budget,
        email: email,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save profile. Please check connection.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2F0D9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_basket,
                      color: Color(0xFF0D5C2C),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to Tipi! 👋',
                  style: TextStyle(
                    color: Color(0xFF0D5C2C),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Let's set up your profile to customize your grocery runs and budget calculations.",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Name Input
                const Text(
                  'What is your name?',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  maxLength: 10,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                  ],
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your nickname';
                    }
                    if (val.length > 10) {
                      return 'Nickname must be 10 characters or less';
                    }
                    if (!RegExp(r'^[a-zA-Z]+$').hasMatch(val)) {
                      return 'Only letters are allowed (no spaces or symbols)';
                    }
                    return null;
                  },
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cardo',
                    hintStyle: const TextStyle(color: Colors.black38),
                    counterText: "",
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D5C2C), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Budget Input
                const Text(
                  'Monthly grocery budget (₱)',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your monthly budget';
                    }
                    if (double.tryParse(val) == null) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'e.g. 8000',
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0D5C2C), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5C2C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Get Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
