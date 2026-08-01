import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_profile_service.dart';
import '../../services/db_update_service.dart';
import '../../services/local_db_service.dart';
import '../../services/grocery_run_service.dart';
import '../../services/telemetry_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/skeleton_widget.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onBackToHomeTap;
  final VoidCallback onLogoutTap;
  final VoidCallback onProfileUpdated;

  const ProfileTab({
    super.key,
    required this.onBackToHomeTap,
    required this.onLogoutTap,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _profileService = SupabaseProfileService.instance;

  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  bool _isDarkMode = false;
  bool _syncOverWifiOnly = true;

  final Map<String, Map<String, String>> _localizedStrings = {
    'English': {
      'profile': 'Profile',
      'quick_stats': 'Quick Stats',
      'runs_completed': 'Runs Completed',
      'total_saved': 'Total Saved',
      'budget_goal': 'Budget Goal',
      'account_settings': 'Account Settings',
      'budget_preferences': 'Budget Preferences',
      'default_location': 'Default Location & Market',
      'price_updates': 'Check for Price Updates',
      'saved_lists': 'Saved Grocery Lists',
      'app_language': 'App Language',
      'export_data': 'Export Shopping Data (CSV)',
      'help_support': 'Help & Support',
      'delete_account': 'Delete Account',
      'logout': 'Logout',
      'reset_password': 'Reset Password',
      'sync_wifi': 'Sync Over Wi-Fi Only',
      'clear_cache': 'Clear Offline Cache',
    },
    'Tagalog': {
      'profile': 'Propayl',
      'quick_stats': 'Mabilisang Stats',
      'runs_completed': 'Mga Nakumpletong Takbo',
      'total_saved': 'Kabuuang Naipon',
      'budget_goal': 'Target na Badyet',
      'account_settings': 'Mga Setting ng Account',
      'budget_preferences': 'Mga Gusto sa Badyet',
      'default_location': 'Default na Lokasyon at Merkado',
      'price_updates': 'Suriin ang mga Update sa Presyo',
      'saved_lists': 'Mga Naka-save na Listahan',
      'app_language': 'Wika ng App',
      'export_data': 'I-export ang Data ng Pamimili (CSV)',
      'help_support': 'Tulong at Suporta',
      'delete_account': 'Burahin ang Account',
      'logout': 'Mag-logout',
      'reset_password': 'I-reset ang Password',
      'sync_wifi': 'Mag-sync sa Wi-Fi Lamang',
      'clear_cache': 'Burahin ang Offline Cache',
    }
  };

  String _t(String key, String lang) {
    return _localizedStrings[lang]?[key] ?? _localizedStrings['English']![key]!;
  }

  @override
  void initState() {
    super.initState();
    // Initialise local switch state from persisted ThemeService value
    _isDarkMode = ThemeService.instance.isDarkMode.value;
    // Rebuild whenever the global theme is toggled (e.g., from another tab)
    ThemeService.instance.isDarkMode.addListener(_onThemeChanged);
    _loadUserData();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = ThemeService.instance.isDarkMode.value;
      });
    }
  }

  @override
  void dispose() {
    ThemeService.instance.isDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profileData = await _profileService.getProfile(user.id);
      if (mounted) {
        setState(() {
          _profile = profileData;
          _syncOverWifiOnly = profileData?['sync_over_wifi_only'] == true;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Edit Name dialog
  void _showEditNameSheet() {
    if (_profile == null) return;
    final nameController = TextEditingController(text: _profile!['name']);
    final user = Supabase.instance.client.auth.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Profile Name',
                style: TextStyle(color: Color(0xFF0D5C2C), fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: 10,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Nickname',
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty && user != null) {
                        final success = await _profileService.updateProfile(
                          user.id,
                          {'name': nameController.text.trim()},
                        );
                        if (success) {
                          await _loadUserData();
                          widget.onProfileUpdated();
                          if (mounted) Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C2C)),
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Edit Budget Preferences Sheet
  void _showBudgetPreferencesSheet() {
    if (_profile == null) return;
    final budgetController = TextEditingController(
      text: _profile!['budget_goal']?.toInt().toString() ?? '8000',
    );
    final alertController = TextEditingController(
      text: (_profile!['alert_threshold'] ?? 80).toString(),
    );
    String preferredMarket = _profile!['preferred_market'] ?? 'Local Palengke';
    final user = Supabase.instance.client.auth.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget & Shopping Preferences',
                    style: TextStyle(color: Color(0xFF0D5C2C), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: budgetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monthly Budget Goal (₱)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: alertController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Alert Threshold (%)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: preferredMarket,
                    decoration: InputDecoration(
                      labelText: 'Preferred Market Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Local Palengke', child: Text('Local Palengke')),
                      DropdownMenuItem(value: 'Supermarket', child: Text('Supermarket')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          preferredMarket = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final budget = double.tryParse(budgetController.text) ?? 8000.0;
                          final threshold = int.tryParse(alertController.text) ?? 80;

                          if (user != null) {
                            final success = await _profileService.updateProfile(user.id, {
                              'budget_goal': budget,
                              'alert_threshold': threshold,
                              'preferred_market': preferredMarket,
                            });
                            if (success) {
                              await _loadUserData();
                              widget.onProfileUpdated();
                              if (mounted) Navigator.pop(context);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C2C)),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // App Language Sheet
  void _showLanguageDialog() {
    if (_profile == null) return;
    String activeLang = _profile!['language'] ?? 'English';
    final user = Supabase.instance.client.auth.currentUser;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('App Language', style: TextStyle(color: Color(0xFF0D5C2C))),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('English'),
                    value: 'English',
                    groupValue: activeLang,
                    activeColor: const Color(0xFF0D5C2C),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          activeLang = val;
                        });
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Tagalog (Filipino)'),
                    value: 'Tagalog',
                    groupValue: activeLang,
                    activeColor: const Color(0xFF0D5C2C),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          activeLang = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (user != null) {
                      final success = await _profileService.updateProfile(
                        user.id,
                        {'language': activeLang},
                      );
                      if (success) {
                        await _loadUserData();
                        if (mounted) Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D5C2C)),
                  child: const Text('Select', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLocationSettingsSheet() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    List<String> provinces = [];
    List<String> markets = [];
    String? selectedProvince = _profile?['preferred_province'];
    if (selectedProvince != null && selectedProvince.isEmpty) {
      selectedProvince = null;
    }
    String? selectedMarket = _profile?['preferred_market'];
    if (selectedMarket != null && selectedMarket.isEmpty) {
      selectedMarket = null;
    }

    try {
      provinces = await LocalDbService.instance.getProvinces();
      if (selectedProvince != null && !provinces.contains(selectedProvince)) {
        selectedProvince = null;
      }

      if (selectedProvince != null && selectedProvince.isNotEmpty) {
        markets = await LocalDbService.instance.getMarkets(province: selectedProvince);
      } else {
        markets = await LocalDbService.instance.getMarkets();
      }

      if (selectedMarket != null && !markets.contains(selectedMarket)) {
        selectedMarket = null;
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Default Location & Market',
                    style: TextStyle(color: Color(0xFF0D5C2C), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedProvince,
                    hint: const Text('Select Province'),
                    decoration: InputDecoration(
                      labelText: 'Province',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        final newMarkets = await LocalDbService.instance.getMarkets(province: val);
                        setModalState(() {
                          selectedProvince = val;
                          selectedMarket = null;
                          markets = newMarkets;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: (selectedMarket == null || !markets.contains(selectedMarket)) ? null : selectedMarket,
                    hint: const Text('Select Market'),
                    decoration: InputDecoration(
                      labelText: 'Market',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: markets.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedMarket = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final success = await _profileService.updateProfile(user.id, {
                            'preferred_province': selectedProvince,
                            'preferred_market': selectedMarket,
                          });
                          if (success) {
                            await _loadUserData();
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D5C2C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPopNotifier(String message, IconData icon, Color iconColor) {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => NotificationBubble(
        message: message,
        icon: icon,
        iconColor: iconColor,
        onDismissed: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  void _checkForPriceUpdates() async {
    setState(() => _isLoading = true);
    final versionInfo = await DbUpdateService.instance.checkNewVersion();
    setState(() => _isLoading = false);

    if (versionInfo == null) {
      if (!mounted) return;
      _showPopNotifier(
        'Failed to check for updates. Try again later.',
        Icons.error_outline,
        Colors.red,
      );
      return;
    }

    final isAvailable = versionInfo['is_available'] as bool? ?? false;
    final remoteVersion = versionInfo['remote_version'] as int? ?? 0;
    final localVersion = versionInfo['local_version'] as int? ?? 0;

    if (!mounted) return;

    if (!isAvailable) {
      _showPopNotifier(
        'Database is up-to-date (Ver. $localVersion).',
        Icons.check_circle_outline,
        const Color(0xFF10B981),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _isDarkMode ? const Color(0xFF111A16) : Colors.white,
              title: Text(
                'Database Update Available',
                style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A new commodity pricing database version is available (Ver. $remoteVersion).',
                    style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                    color: const Color(0xFF10B981),
                    backgroundColor: _isDarkMode ? const Color(0xFF1E2D27) : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress > 0 
                      ? 'Downloading: ${(progress * 100).toInt()}%'
                      : 'Preparing download...',
                    style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white54 : Colors.grey),
                  ),
                ],
              ),
              actions: progress > 0 ? [] : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() {
                      progress = 0.01;
                    });
                    final success = await DbUpdateService.instance.downloadAndApplyUpdate(
                      version: remoteVersion,
                      releaseDate: versionInfo['release_date'] ?? '',
                      totalRecords: versionInfo['total_records'] ?? 0,
                      onProgress: (p) {
                        setDialogState(() {
                          progress = p;
                        });
                      },
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _showPopNotifier(
                        success ? 'Database updated successfully!' : 'Update failed.',
                        success ? Icons.check_circle : Icons.error,
                        success ? const Color(0xFF10B981) : Colors.red,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  child: const Text('Update Now', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _exportShoppingData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Work in Progress', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This feature is currently under development.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF0D5C2C))),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    final confirmController = TextEditingController();
    bool isMatch = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete Account?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will delete all your local cache and remote grocery runs history. This action cannot be undone.'),
                const SizedBox(height: 16),
                const Text('Type "Delete My Account" to confirm:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  onChanged: (val) {
                    setDialogState(() {
                      isMatch = val == 'Delete My Account';
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Delete My Account',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isMatch
                    ? () async {
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          final db = await GroceryRunService.instance.cacheDb;
                          await db.delete('cached_runs');
                          await db.delete('cached_items');

                          try {
                            await Supabase.instance.client.rpc('delete_current_user');
                          } catch (e, stack) {
                            TelemetryService.instance.logError(e, stack, "deleting remote user auth account via RPC");
                            // Fallback to mark local profile as disabled/deleted
                            await _profileService.updateProfile(user.id, {
                              'active_since': 'deleted_${DateTime.now().millisecondsSinceEpoch}',
                            });
                          }

                          widget.onLogoutTap();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _resetPassword() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(user.email!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset email sent to ${user.email}!'),
              backgroundColor: const Color(0xFF0D5C2C),
            ),
          );
        }
      } catch (e, stack) {
        TelemetryService.instance.logError(e, stack, "resetting password");
      }
    }
  }

  void _clearOfflineCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?', style: TextStyle(color: Colors.red)),
        content: const Text('This will clear your local cached runs and force re-synchronization from Supabase.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final db = await GroceryRunService.instance.cacheDb;
      await db.delete('cached_runs');
      await db.delete('cached_items');
      await _loadUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline cache cleared successfully!')),
        );
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Help & Support', style: TextStyle(color: Color(0xFF0D5C2C), fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('What is Tipi?', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Tipi is an offline-first budget companion that helps Filipino shoppers check public market prices and stay within their grocery limits.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text('How to update prices?', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Once connected to the internet, Tipi will check for price database updates. You can trigger updates from the Price Search screen.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
                SizedBox(height: 12),
                Text('Contact Support:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text(
                  'Email: support@tipi-diskarte.ph',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF0D5C2C))),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 24),
            SkeletonWidget(width: 80, height: 80, borderRadius: 40),
            SizedBox(height: 16),
            SkeletonWidget(width: 140, height: 20),
            SizedBox(height: 8),
            SkeletonWidget(width: 110, height: 14),
            SizedBox(height: 24),
            SkeletonWidget(width: double.infinity, height: 180, borderRadius: 16),
            SizedBox(height: 24),
            SkeletonWidget(width: double.infinity, height: 240, borderRadius: 16),
          ],
        ),
      );
    }

    final name = _profile?['name'] ?? 'Guest';
    final activeSince = _profile?['active_since'] ?? 'Oct 2023';
    final runsCompleted = _profile?['runs_completed'] ?? 0;
    final totalSaved = _profile?['total_saved'] ?? 0.0;
    final budgetGoal = _profile?['budget_goal'] ?? 0.0;
    final language = _profile?['language'] ?? 'English';

    final Color bgColor = ThemeService.instance.background;
    final Color cardColor = ThemeService.instance.cardBg;
    final Color mainTextColor = ThemeService.instance.cardText;
    final Color subTextColor = ThemeService.instance.subText;
    final Color dividerColor = _isDarkMode ? Colors.grey.shade800 : Colors.grey[200]!;
    final Color themeGreenText = ThemeService.instance.greenText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeGreenText),
          onPressed: widget.onBackToHomeTap,
        ),
        title: Text(
          _t('profile', language),
          style: TextStyle(color: themeGreenText, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: themeGreenText),
            onPressed: widget.onBackToHomeTap,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF55C57A), width: 3),
                  ),
                  child: ClipOval(
                    child: Container(
                      width: 90,
                      height: 90,
                      color: const Color(0xFFE2F0D9),
                      child: const Icon(Icons.person, color: Color(0xFF0D5C2C), size: 50),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showEditNameSheet,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: themeGreenText, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(name, style: TextStyle(color: mainTextColor, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Active since $activeSince', style: TextStyle(color: subTextColor, fontSize: 13)),
            const SizedBox(height: 24),

            // Quick Stats Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bar_chart, color: themeGreenText, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _t('quick_stats', language),
                        style: TextStyle(color: mainTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQuickStatRow(_t('runs_completed', language), '$runsCompleted', mainTextColor),
                  const SizedBox(height: 10),
                  _buildQuickStatRow(_t('total_saved', language), '₱${totalSaved.toStringAsFixed(0)}', themeGreenText),
                  const SizedBox(height: 10),
                  _buildQuickStatRow(_t('budget_goal', language), '₱${budgetGoal.toStringAsFixed(0)}/mo', const Color(0xFFB58900)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CATEGORY 1: Account & Security
            _buildSectionHeader('ACCOUNT & SECURITY', subTextColor),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _buildSettingsRow(
                    icon: Icons.person_outline,
                    iconColor: themeGreenText,
                    bgColor: const Color(0xFFE2F0D9),
                    title: _t('account_settings', language),
                    onTap: _showEditNameSheet,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.lock_outline,
                    iconColor: Colors.blueGrey,
                    bgColor: const Color(0xFFECEFF1),
                    title: _t('reset_password', language),
                    onTap: _resetPassword,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.file_download_outlined,
                    iconColor: Colors.teal,
                    bgColor: const Color(0xFFE0F2F1),
                    title: _t('export_data', language),
                    onTap: _exportShoppingData,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.delete_forever_outlined,
                    iconColor: Colors.redAccent,
                    bgColor: const Color(0xFFFFFBFA),
                    title: _t('delete_account', language),
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CATEGORY 2: Shopping Preferences
            _buildSectionHeader('SHOPPING PREFERENCES', subTextColor),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _buildSettingsRow(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFFB58900),
                    bgColor: const Color(0xFFF9F2E6),
                    title: _t('budget_preferences', language),
                    onTap: _showBudgetPreferencesSheet,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.language,
                    iconColor: Colors.grey[700]!,
                    bgColor: const Color(0xFFF0F0F0),
                    title: _t('app_language', language),
                    subtitle: language,
                    onTap: _showLanguageDialog,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  SwitchListTile(
                    title: Text(
                      _isDarkMode ? 'Dark Mode' : 'Light Mode',
                      style: TextStyle(color: mainTextColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    value: _isDarkMode,
                    activeColor: themeGreenText,
                    onChanged: (bool value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      ThemeService.instance.toggleTheme(value);
                    },
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFECEFF1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: _isDarkMode ? Colors.amber : Colors.blueGrey,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CATEGORY 3: Offline Cache & Updates
            _buildSectionHeader('OFFLINE CACHE & UPDATES', subTextColor),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _buildSettingsRow(
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFF1E824C),
                    bgColor: const Color(0xFFE2F0D9),
                    title: _t('default_location', language),
                    onTap: _showLocationSettingsSheet,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.cloud_download_outlined,
                    iconColor: themeGreenText,
                    bgColor: const Color(0xFFE2F0D9),
                    title: _t('price_updates', language),
                    onTap: _checkForPriceUpdates,
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  SwitchListTile(
                    title: Text(
                      _t('sync_wifi', language),
                      style: TextStyle(color: mainTextColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    value: _syncOverWifiOnly,
                    activeColor: themeGreenText,
                    onChanged: (bool value) async {
                      setState(() {
                        _syncOverWifiOnly = value;
                      });
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user != null) {
                        await _profileService.updateProfile(user.id, {
                          'sync_over_wifi_only': value,
                        });
                      }
                    },
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(color: Color(0xFFE0F2F1), shape: BoxShape.circle),
                      child: const Icon(Icons.wifi, color: Colors.teal, size: 20),
                    ),
                  ),
                  Divider(height: 1, indent: 60, color: dividerColor),
                  _buildSettingsRow(
                    icon: Icons.delete_outline,
                    iconColor: Colors.deepOrange,
                    bgColor: const Color(0xFFFBE9E7),
                    title: _t('clear_cache', language),
                    onTap: _clearOfflineCache,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // CATEGORY 4: Support & Legal
            _buildSectionHeader('SUPPORT & LEGAL', subTextColor),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dividerColor),
              ),
              child: Column(
                children: [
                  _buildSettingsRow(
                    icon: Icons.help_outline,
                    iconColor: Colors.grey[700]!,
                    bgColor: const Color(0xFFF0F0F0),
                    title: _t('help_support', language),
                    onTap: _showHelpDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Outlined red logout button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onLogoutTap,
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                label: Text(
                  _t('logout', language),
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red[200]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFFFFFBFA),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
        child: Text(
          title,
          style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF7F9F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _isDarkMode ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.grey, fontSize: 11),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }
}

class NotificationBubble extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismissed;

  const NotificationBubble({
    super.key,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.onDismissed,
  });

  @override
  State<NotificationBubble> createState() => _NotificationBubbleState();
}

class _NotificationBubbleState extends State<NotificationBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
    );

    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    // Spring scale pop effect
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
    ]).animate(curved);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    // Slide up from bottom
    _offset = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Start dismiss timer
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode.value;
    final bgColor = isDark ? const Color(0xFF111A16) : Colors.white;
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final borderColor = isDark ? const Color(0xFF22312C) : const Color(0xFFE2E8F0);

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 48.0, left: 24, right: 24),
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _opacity,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: widget.iconColor, size: 22),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
