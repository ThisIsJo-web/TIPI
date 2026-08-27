import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_alert.dart';
import '../home/home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSignUp && !_termsAccepted) {
      CustomAlert.show(context, message: "Please accept the Terms & Conditions to register.", isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final budgetGoal = double.tryParse(_budgetController.text) ?? 2000.0;

    bool success = false;
    if (_isSignUp) {
      success = await ApiService.instance.register(email, password, name, budgetGoal);
    } else {
      success = await ApiService.instance.login(email, password);
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      CustomAlert.show(
        context, 
        message: _isSignUp ? "Account registered successfully!" : "Successfully logged in!", 
        isSuccess: true
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeView()),
      );
    } else {
      final errorMsg = _isSignUp 
          ? "Registration failed. Email might already be taken."
          : "Invalid email or password credentials.";
      
      setState(() {
        _errorMessage = errorMsg;
      });
      CustomAlert.show(context, message: errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding
                  Text(
                    "TIPI",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: ThemeService.instance.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? "Create your budget helper account" : "Welcome back to smart saving",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_isSignUp) ...[
                    CustomTextField(
                      label: "Your Full Name",
                      controller: _nameController,
                      validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: "Monthly Grocery Budget Goal (PHP)",
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Budget is required";
                        if (double.tryParse(val) == null) return "Enter a valid number";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    label: "Email Address",
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Email is required";
                      if (!val.contains("@")) return "Enter a valid email address";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: "Password",
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return "Password is required";
                      if (val.length < 6) return "Password must be at least 6 characters";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_isSignUp) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          activeColor: ThemeService.instance.primary,
                          onChanged: (val) {
                            setState(() {
                              _termsAccepted = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "I agree to the Terms & Conditions. I understand that the developer is an indie creator and commodity prices are reference guides sourced from WFP (Davao del Norte only).",
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  PrimaryButton(
                    text: _isSignUp ? "REGISTER ACCOUNT" : "SIGN IN",
                    onPressed: (_isSignUp && !_termsAccepted) ? null : () => _submit(),
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp 
                          ? "Already have an account? Sign In" 
                          : "Don't have an account yet? Register",
                      style: TextStyle(
                        color: ThemeService.instance.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
