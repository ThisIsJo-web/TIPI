import 'package:flutter/material.dart';
import '../../services/grocery_run_service.dart';
import '../../services/theme_service.dart';

class CreateRunDialog extends StatefulWidget {
  final String? userId;

  const CreateRunDialog({super.key, this.userId});

  static Future<Map<String, dynamic>?> show(BuildContext context, {String? userId}) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CreateRunDialog(userId: userId),
    );
  }

  @override
  State<CreateRunDialog> createState() => _CreateRunDialogState();
}

class _CreateRunDialogState extends State<CreateRunDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Palengke Run');
    _budgetController = TextEditingController(text: '2000');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    final createdRun = await GroceryRunService.instance.createRunHeader(
      userId: widget.userId,
      name: name,
      budget: budget,
    );

    if (mounted) {
      Navigator.of(context).pop(createdRun);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final fieldFill = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
    final borderCol = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: greenColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, color: greenColor),
          ),
          const SizedBox(width: 12),
          Text(
            'New Grocery Run',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textThemeColor),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Grocery Run Name',
                  labelStyle: TextStyle(color: subText),
                  hintText: 'e.g. Weekly Groceries',
                  hintStyle: TextStyle(color: subText.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.edit_note, color: subText),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a run name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textThemeColor),
                decoration: InputDecoration(
                  labelText: 'Budget Goal (₱)',
                  labelStyle: TextStyle(color: subText),
                  hintText: 'e.g. 2000',
                  hintStyle: TextStyle(color: subText.withValues(alpha: 0.6)),
                  prefixIcon: Icon(Icons.payments_outlined, color: subText),
                  filled: true,
                  fillColor: fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: greenColor, width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter a budget';
                  if (double.tryParse(val.trim()) == null) return 'Enter a valid number';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: subText)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: buttonText, strokeWidth: 2),
                )
              : Text('Create Run', style: TextStyle(color: buttonText, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
