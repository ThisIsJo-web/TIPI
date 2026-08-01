import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'loading_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _rememberMe = true;
  bool _isSignUp = false;
  bool _isLoading = false;
  
  final TextEditingController _emailPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Hide status bar (top bar) globally
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.bottom]);
  }

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSuccessPopup(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _SuccessDialog(email: email);
      },
    ).then((_) {
      setState(() {
        _isSignUp = false;
        _passwordController.clear();
      });
    });
  }

  Future<void> _handleAuth() async {
    final input = _emailPhoneController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Palihug isulod ang email ug password.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        // Sign Up
        await _authService.signUpWithEmail(email: input, password: password);
        if (mounted) {
          _showSuccessPopup(input);
        }
      } else {
        // Sign In
        await _authService.signInWithEmail(email: input, password: password);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoadingPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardVisible = keyboardHeight > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/background.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.green.shade900,
                  child: const Center(
                    child: Text(
                      'Background Image Not Found',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.topCenter,
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 40.0),
                              child: GlassCard(
                                opacity: 0.08,
                                blur: 25.0,
                                borderRadius: BorderRadius.circular(28.0),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'TIPI',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      
                                      // Animated Title Description
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Text(
                                          _isSignUp ? 'Create a grocery companion account' : 'Login to your grocery companion',
                                          key: ValueKey<bool>(_isSignUp),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      // Distinct Custom Sliding Tab Selector
                                      Container(
                                        height: 44,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                        child: Stack(
                                          children: [
                                            // Sliding background selector pill
                                            AnimatedAlign(
                                              alignment: _isSignUp ? Alignment.centerRight : Alignment.centerLeft,
                                              duration: const Duration(milliseconds: 250),
                                              curve: Curves.easeInOut,
                                              child: Container(
                                                width: MediaQuery.of(context).size.width * 0.36,
                                                height: 38,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.lightGreenAccent,
                                                  borderRadius: BorderRadius.circular(19),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.15),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _isSignUp = false;
                                                      });
                                                    },
                                                    child: Center(
                                                      child: Text(
                                                        'Log In',
                                                        style: TextStyle(
                                                          color: !_isSignUp ? Colors.black : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      setState(() {
                                                        _isSignUp = true;
                                                      });
                                                    },
                                                    child: Center(
                                                      child: Text(
                                                        'Sign Up',
                                                        style: TextStyle(
                                                          color: _isSignUp ? Colors.black : Colors.white70,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      CustomTextField(
                                        label: 'Email',
                                        hintText: 'e.g. user@email.com',
                                        prefixIcon: Icons.email_outlined,
                                        controller: _emailPhoneController,
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          CustomTextField(
                                            label: 'Password',
                                            hintText: '••••••••',
                                            prefixIcon: Icons.lock_outline,
                                            isPassword: true,
                                            controller: _passwordController,
                                          ),
                                          if (!_isSignUp) ...[
                                            const SizedBox(height: 8),
                                            TextButton(
                                              onPressed: () {},
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Forgot?',
                                                style: TextStyle(
                                                  color: Colors.lightGreenAccent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      if (!_isSignUp)
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                activeColor: Colors.lightGreenAccent,
                                                checkColor: Colors.black,
                                                side: const BorderSide(color: Colors.white54, width: 1.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                onChanged: (val) {
                                                  setState(() {
                                                    _rememberMe = val ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Remember Me',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      
                                      const SizedBox(height: 28),
                                      
                                      _isLoading
                                          ? const CircularProgressIndicator(color: Colors.lightGreenAccent)
                                          : AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 200),
                                              child: PrimaryButton(
                                                key: ValueKey<bool>(_isSignUp),
                                                text: _isSignUp ? 'Sign Up' : 'Magsugod Na',
                                                onPressed: _handleAuth,
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Overlapping Logo
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                backgroundImage: AssetImage('assets/images/logo.png'),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Switcher Links outside card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? 'Naa na kay account?' : 'Bag-o pa diri?',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                _isSignUp ? 'Login Here' : 'Create Account',
                                style: const TextStyle(
                                  color: Colors.lightGreenAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isKeyboardVisible ? 0.0 : 1.0,
                          curve: Curves.easeInOut,
                          child: IgnorePointer(
                            ignoring: isKeyboardVisible,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              height: isKeyboardVisible ? 0.0 : 110.0,
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.location_on_outlined, color: Colors.lightGreenAccent, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'CURRENTLY SERVING DAVAO DEL NORTE',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Text('Privacy Policy', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                        SizedBox(width: 16),
                                        Icon(Icons.circle, color: Colors.white24, size: 4),
                                        SizedBox(width: 16),
                                        Text('Terms of Use', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// Custom animated check bubble pop dialog
class _SuccessDialog extends StatefulWidget {
  final String email;
  const _SuccessDialog({required this.email});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F0D9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0D5C2C),
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Created!',
              style: TextStyle(
                color: Color(0xFF0D5C2C),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm your email first!',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We sent a verification link to:\n${widget.email}\n\nPlease check your inbox and tap the link to verify your account before logging in.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5C2C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it, check email',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
