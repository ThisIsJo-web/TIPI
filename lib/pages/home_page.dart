import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../services/db_update_service.dart';
import '../services/supabase_profile_service.dart';
import 'login_page.dart';

// Modular Tab Screens
import 'home/home_tab.dart';
import 'runs/runs_tab.dart';
import 'history/history_tab.dart';
import 'profile/profile_tab.dart';
import 'search/price_search_page.dart';
import 'runs/grocery_builder_page.dart';
import 'runs/create_run_dialog.dart';
import '../services/grocery_run_service.dart';
import '../widgets/page_transitions.dart';
import '../services/theme_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final LocalDbService _dbService = LocalDbService.instance;
  final SupabaseProfileService _profileService = SupabaseProfileService.instance;
  final GroceryRunService _runService = GroceryRunService.instance;
  
  bool _dbExists = false;
  bool _isCheckingDb = true;
  int _currentIndex = 0;
  bool _isViewingSearch = false;
  Map<String, dynamic>? _activeRun;
  List<Map<String, dynamic>> _recentCompletedRuns = [];
  StreamSubscription<void>? _runSubscription;
  
  String? _selectedMarket;
  String? _selectedProvince;
  String? _detectedCity;
  String? _detectedProvince;
  
  String _userName = 'Juan';

  // Update states
  bool _updateAvailable = false;
  bool _isUpdating = false;
  double _downloadProgress = 0.0;
  Map<String, dynamic>? _updateInfo;

  @override
  void initState() {
    super.initState();
    _checkDbStatus();
    _checkForUpdates();
    _runSubscription = _runService.onRunUpdated.listen((_) {
      _loadActiveRun();
    });
  }

  @override
  void dispose() {
    _runSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    final updateService = DbUpdateService.instance;
    final update = await updateService.checkNewVersion();
    if (update != null && update['is_available'] == true) {
      setState(() {
        _updateAvailable = true;
        _updateInfo = update;
      });
    }
  }

  Future<void> _runUpdate() async {
    if (_updateInfo == null) return;
    
    setState(() {
      _isUpdating = true;
      _downloadProgress = 0.0;
    });

    final success = await DbUpdateService.instance.downloadAndApplyUpdate(
      version: _updateInfo!['remote_version'],
      releaseDate: _updateInfo!['release_date'],
      totalRecords: _updateInfo!['total_records'],
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    if (mounted) {
      setState(() {
        _isUpdating = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _updateAvailable = false;
        });
        _checkDbStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download update. Please check internet connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _syncProfilePreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await _profileService.getProfile(user.id);
      if (profile != null) {
        setState(() {
          if (profile['name'] != null) {
            _userName = profile['name'];
          }
          final prefProvince = profile['preferred_province'] as String?;
          final prefMarket = profile['preferred_market'] as String?;
          if (prefProvince != null && prefProvince.isNotEmpty) {
            _selectedProvince = prefProvince;
            _detectedProvince = prefProvince;
          }
          if (prefMarket != null && prefMarket.isNotEmpty) {
            _selectedMarket = prefMarket;
            _detectedCity = prefMarket;
          }
        });
      }
    }
  }

  Future<void> _checkDbStatus() async {
    setState(() {
      _isCheckingDb = true;
    });
    
    final exists = await _dbService.databaseFileExists();
    
    await _syncProfilePreferences();
    
    setState(() {
      _dbExists = exists;
      _isCheckingDb = false;
    });
    
    await _loadActiveRun();
    
    // Only query GPS if default market location is not set
    if (exists && (_selectedProvince == null || _selectedMarket == null)) {
      await _detectLocation();
    }
  }

  Future<void> _refreshProfileName() async {
    await _syncProfilePreferences();
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      
      // Try geocoding
      String? realCity;
      String? realProvince;
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          realCity = place.locality;
          realProvince = place.subAdministrativeArea;
        }
      } catch (e) {
        debugPrint("Geocoding failed in main coordinator: $e");
      }
      
      final nearestLoc = await _dbService.getNearestLocation(position.latitude, position.longitude);
      if (nearestLoc != null) {
        setState(() {
          _selectedProvince = nearestLoc['province'];
          _selectedMarket = nearestLoc['city'];
          
          _detectedCity = realCity ?? nearestLoc['city'];
          _detectedProvince = realProvince ?? nearestLoc['province'];
        });
      }
    } catch (e) {
      debugPrint("Error detecting location in main: $e");
    }
  }

  Future<void> _mockInitializeDatabase() async {
    setState(() {
      _isCheckingDb = true;
    });
    
    try {
      await _dbService.database;
      final exists = await _dbService.databaseFileExists();
      setState(() {
        _dbExists = exists;
      });
      if (exists) {
        await _detectLocation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database initialization failed.')),
        );
      }
      await _loadActiveRun();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database opening failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isCheckingDb = false;
      });
    }
  }

  Future<void> _loadActiveRun() async {
    final userId = _authService.currentUser?.id;
    final active = await _runService.getActiveRun(userId);
    final allRuns = await _runService.getRuns(userId);
    final completed = allRuns.where((r) => r['status'] == 'completed').toList();
    if (mounted) {
      setState(() {
        _activeRun = active;
        _recentCompletedRuns = completed.take(2).toList();
      });
    }
  }

  Future<void> _resumeRun(Map<String, dynamic> run) async {
    final result = await Navigator.push(
      context,
      SlideUpFadeRoute(
        page: GroceryBuilderPage(
          runData: run,
          userId: _authService.currentUser?.id,
          detectedCity: _detectedCity,
          detectedProvince: _detectedProvince,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadActiveRun();
    }
  }

  Future<void> _openGroceryBuilder() async {
    final createdRun = await CreateRunDialog.show(context, userId: _authService.currentUser?.id);
    if (createdRun != null && mounted) {
      final result = await Navigator.push(
        context,
        SlideUpFadeRoute(
          page: GroceryBuilderPage(
            runData: createdRun,
            userId: _authService.currentUser?.id,
            detectedCity: _detectedCity,
            detectedProvince: _detectedProvince,
          ),
        ),
      );
      if (result == true && mounted) {
        _loadActiveRun();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingDb) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F9F7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0D5C2C))),
      );
    }

    if (!_dbExists) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F9F7),
        body: _buildSetupRequiredWidget(),
      );
    }

    if (_isViewingSearch) {
      return PriceSearchPage(
        dbExists: _dbExists,
        initialProvince: _selectedProvince,
        initialCity: _selectedMarket,
        initialDetectedProvince: _detectedProvince,
        initialDetectedCity: _detectedCity,
        updateAvailable: _updateAvailable,
        isUpdating: _isUpdating,
        downloadProgress: _downloadProgress,
        onRunUpdate: _runUpdate,
        onLocationUpdated: (city, province, dbCity, dbProvince) {
          setState(() {
            _detectedCity = city;
            _detectedProvince = province;
            _selectedMarket = dbCity;
            _selectedProvince = dbProvince;
          });
        },
        onBackPressed: () {
          setState(() {
            _isViewingSearch = false;
          });
        },
      );
    }

    Widget bodyWidget;
    switch (_currentIndex) {
      case 0:
        bodyWidget = HomeTab(
          userName: _userName,
          detectedCity: _detectedCity,
          detectedProvince: _detectedProvince,
          dbExists: _dbExists,
          activeRun: _activeRun,
          recentCompletedRuns: _recentCompletedRuns,
          onNewRunTap: _openGroceryBuilder,
          onResumeActiveRunTap: _resumeRun,
          onSavedListsTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pagbukas ng mga naka-save na listahan...')),
            );
          },
          onPriceSearchTap: () {
            setState(() {
              _isViewingSearch = true;
            });
          },
          onViewAllRunsTap: () {
            setState(() {
              _currentIndex = 2;
            });
          },
          onProfileTap: () {
            setState(() {
              _currentIndex = 3;
            });
          },
        );
        break;
      case 1:
        bodyWidget = RunsTab(
          userId: _authService.currentUser?.id,
          detectedCity: _detectedCity,
          detectedProvince: _detectedProvince,
          onCreateRunTap: _openGroceryBuilder,
        );
        break;
      case 2:
        bodyWidget = HistoryTab(userId: _authService.currentUser?.id);
        break;
      case 3:
        bodyWidget = ProfileTab(
          onBackToHomeTap: () {
            setState(() {
              _currentIndex = 0;
            });
          },
          onProfileUpdated: _refreshProfileName,
          onLogoutTap: () async {
            final navigator = Navigator.of(context);
            await _authService.signOut();
            navigator.pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        );
        break;
      default:
        bodyWidget = const Center(child: Text('Tab not found'));
    }

    final Color bgColor = ThemeService.instance.background;
    final Color primaryGreen = ThemeService.instance.primaryButtonBg;
    final Color buttonText = ThemeService.instance.primaryButtonText;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeSlideTransitionSwitcher(
          child: KeyedSubtree(
            key: ValueKey<int>(_currentIndex),
            child: bodyWidget,
          ),
        ),
      ),
      floatingActionButton: (_currentIndex == 0)
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: FloatingActionButton(
                onPressed: _openGroceryBuilder,
                backgroundColor: primaryGreen,
                shape: const CircleBorder(),
                child: Icon(Icons.add, color: buttonText),
              ),
            )
          : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSetupRequiredWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storage,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'SQLite Database Not Found',
              style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tipi needs to load the offline prices database onto the device. If this is a simulator, copy the database using the Python script or assets directory.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _mockInitializeDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D5C2C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try to Load Database', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final cardBg = ThemeService.instance.cardBg;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, 'Home'),
            _buildNavItem(1, Icons.shopping_bag_outlined, 'Runs'),
            _buildNavItem(2, Icons.history, 'History'),
            _buildNavItem(3, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final navText = ThemeService.instance.primaryButtonText;
    final unselectedIcon = ThemeService.instance.subText;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _isViewingSearch = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: isSelected ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: isSelected ? navText : unselectedIcon,
                size: 20,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: navText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
