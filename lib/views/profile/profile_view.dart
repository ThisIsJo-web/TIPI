import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/custom_alert.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  String _selectedLanguage = "English";
  String _selectedMarket = "Panabo Public Market";

  final List<String> _languages = ["English", "Tagalog"];
  final List<String> _markets = ["Panabo Public Market", "Tagum Public Market"];

  bool _isLoading = false;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final user = ApiService.instance.currentUser;
    _nameController = TextEditingController(text: user?.name ?? "");
    _budgetController = TextEditingController(text: user?.budgetGoal.toStringAsFixed(2) ?? "2000.00");
    _selectedLanguage = user?.language ?? "English";
    _selectedMarket = user?.preferredMarket ?? "Panabo Public Market";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _successMessage = null;
    });

    final name = _nameController.text.trim();
    final budgetGoal = double.parse(_budgetController.text);

    final success = await ApiService.instance.updateProfile(
      name: name,
      budgetGoal: budgetGoal,
      language: _selectedLanguage,
      preferredProvince: "Davao del Norte",
      preferredMarket: _selectedMarket,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (success) {
        _successMessage = TranslationService.instance.t('profile_updated');
        CustomAlert.show(context, message: _successMessage!, isSuccess: true);
      } else {
        _successMessage = TranslationService.instance.t('profile_failed');
        CustomAlert.show(context, message: _successMessage!, isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.instance.currentUser;
    final isDark = ThemeService.instance.isDarkMode.value;

    return Scaffold(
      backgroundColor: ThemeService.instance.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text(
          TranslationService.instance.t('profile_title').toUpperCase(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Account Header Card
              Card(
                color: ThemeService.instance.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: ThemeService.instance.primaryLight,
                        child: Text(
                          (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : "U",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ThemeService.instance.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? "Saver User",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? "",
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${TranslationService.instance.t('active')} since: ${user?.activeSince ?? ''}",
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _successMessage == TranslationService.instance.t('profile_updated')
                        ? Colors.green.shade50 
                        : Colors.red.shade50,
                    border: Border.all(
                      color: _successMessage == TranslationService.instance.t('profile_updated')
                          ? Colors.green.shade200 
                          : Colors.red.shade200,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _successMessage!,
                    style: TextStyle(
                      color: _successMessage == TranslationService.instance.t('profile_updated') ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Text(
                "Personal Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              CustomTextField(
                label: TranslationService.instance.t('name_label'),
                controller: _nameController,
                validator: (val) => val == null || val.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: TranslationService.instance.t('budget_goal_label'),
                controller: _budgetController,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return "Budget is required";
                  if (double.tryParse(val) == null) return "Enter a valid number";
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Text(
                "Preferences",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // Dropdown preferences
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: InputDecoration(labelText: TranslationService.instance.t('settings_language')),
                items: _languages.map((l) {
                  return DropdownMenuItem(value: l, child: Text(l));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLanguage = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedMarket,
                decoration: const InputDecoration(labelText: "Preferred Davao del Norte Market"),
                items: _markets.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedMarket = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                text: TranslationService.instance.t('save_changes'),
                onPressed: _save,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
