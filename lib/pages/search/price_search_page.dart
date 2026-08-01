import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/local_db_service.dart';
import '../../widgets/skeleton_widget.dart';
import '../../services/theme_service.dart';

class PriceSearchPage extends StatefulWidget {
  final bool dbExists;
  final String? initialProvince;
  final String? initialCity;
  final String? initialDetectedProvince;
  final String? initialDetectedCity;
  final Function(String? city, String? province, String? dbCity, String? dbProvince) onLocationUpdated;
  final VoidCallback onBackPressed;

  // Updates features
  final bool updateAvailable;
  final bool isUpdating;
  final double downloadProgress;
  final VoidCallback onRunUpdate;

  const PriceSearchPage({
    super.key,
    required this.dbExists,
    this.initialProvince,
    this.initialCity,
    this.initialDetectedProvince,
    this.initialDetectedCity,
    required this.onLocationUpdated,
    required this.onBackPressed,
    required this.updateAvailable,
    required this.isUpdating,
    required this.downloadProgress,
    required this.onRunUpdate,
  });

  @override
  State<PriceSearchPage> createState() => _PriceSearchPageState();
}

class _PriceSearchPageState extends State<PriceSearchPage> {
  final LocalDbService _dbService = LocalDbService.instance;
  Timer? _debounce;

  bool _isSearching = false;
  bool _isLocating = false;

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedMarket;
  String? _selectedProvince;
  String? _detectedCity;
  String? _detectedProvince;

  List<Map<String, dynamic>> _searchResults = [];
  List<String> _categories = [];
  List<String> _provinces = [];
  List<String> _markets = [];

  @override
  void initState() {
    super.initState();
    _selectedProvince = widget.initialProvince;
    _selectedMarket = widget.initialCity;
    _detectedCity = widget.initialDetectedCity;
    _detectedProvince = widget.initialDetectedProvince;

    if (widget.dbExists) {
      _loadFilterOptions().then((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final cats = await _dbService.getCategories();
      final provs = await _dbService.getProvinces();
      final mkts = await _dbService.getMarkets(province: _selectedProvince);
      if (mounted) {
        setState(() {
          _categories = cats;
          _provinces = provs;
          _markets = mkts;
        });
      }
    } catch (e) {
      debugPrint("Error loading filters: $e");
    }
  }

  Future<void> _performSearch() async {
    if (!widget.dbExists) return;

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      final results = await _dbService.searchPrices(
        query: _searchQuery,
        category: _selectedCategory,
        market: _selectedMarket,
        province: _selectedProvince,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      debugPrint("Error performing search: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _detectLocation() async {
    if (mounted) {
      setState(() {
        _isLocating = true;
      });
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (e) {
        debugPrint("Precise position timed out, trying last known position...");
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw Exception("Could not acquire location coordinates.");
      }

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
        debugPrint("Geocoding failed in search: $e");
      }

      final nearestLoc = await _dbService.getNearestLocation(position.latitude, position.longitude);
      if (nearestLoc != null) {
        if (mounted) {
          setState(() {
            _selectedProvince = nearestLoc['province'];
            _selectedMarket = nearestLoc['city'];

            _detectedCity = realCity ?? nearestLoc['city'];
            _detectedProvince = realProvince ?? nearestLoc['province'];
          });
        }

        // Notify parent coordinator
        widget.onLocationUpdated(
          _detectedCity,
          _detectedProvince,
          _selectedMarket,
          _selectedProvince,
        );

        await _loadFilterOptions();
        await _performSearch();

        if (mounted) {
          final displayCity = _detectedCity ?? _selectedMarket ?? "";
          final displayProvince = _detectedProvince ?? _selectedProvince ?? "";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location detected! Shopping in: $displayCity ($displayProvince)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error detecting location: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location detection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = ThemeService.instance.background;
    final greenColor = ThemeService.instance.greenText;
    final primaryGreen = ThemeService.instance.primaryButtonBg;
    final buttonText = ThemeService.instance.primaryButtonText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final subText = ThemeService.instance.subText;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: greenColor),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          'Price Search',
          style: TextStyle(color: greenColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: greenColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isUpdating)
            Container(
              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFE2F0D9),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Downloading monthly update... ${(widget.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: greenColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: widget.downloadProgress,
                    color: greenColor,
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
          else if (widget.updateAvailable)
            Container(
              color: primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New monthly price update available!',
                    style: TextStyle(color: buttonText, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: widget.onRunUpdate,
                    style: TextButton.styleFrom(
                      backgroundColor: buttonText,
                      foregroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          _buildSearchHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isSearching ? 'Searching...' : 'Found ${_searchResults.length} items',
                  style: TextStyle(color: subText, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? _buildSkeletonResults()
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          'No prices found.\nTry typing another commodity.',
                          style: TextStyle(color: subText),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return _buildPriceRow(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    final cardBg = ThemeService.instance.cardBg;
    final greenColor = ThemeService.instance.greenText;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey[200]!;
    final borderCol = isDark ? Colors.grey.shade800 : Colors.grey[300]!;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: dividerColor)),
      ),
      child: Column(
        children: [
          TextField(
            style: TextStyle(color: textThemeColor),
            decoration: InputDecoration(
              hintText: 'Search commodity (e.g. Rice, Potato)',
              hintStyle: TextStyle(color: subText.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search, color: subText),
              filled: true,
              fillColor: isDark ? Colors.grey.shade800 : const Color(0xFFF0F2F1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                _performSearch();
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, color: greenColor, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _selectedProvince != null
                      ? (_selectedMarket != null && _selectedMarket != _selectedProvince
                          ? 'Shopping in: $_selectedMarket, $_selectedProvince'
                          : 'Shopping in: $_selectedProvince')
                      : 'Showing all locations',
                  style: TextStyle(
                    color: greenColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProvince,
                      isExpanded: true,
                      hint: Text('All Provinces', style: TextStyle(color: subText, fontSize: 13)),
                      dropdownColor: cardBg,
                      style: TextStyle(color: textThemeColor, fontSize: 13),
                      icon: Icon(Icons.arrow_drop_down, color: subText),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Provinces', style: TextStyle(color: textThemeColor)),
                        ),
                        ..._provinces.map((p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p, overflow: TextOverflow.ellipsis, style: TextStyle(color: textThemeColor)),
                        )),
                      ],
                      onChanged: (val) async {
                        setState(() {
                          _selectedProvince = val;
                          _selectedMarket = null;
                        });
                        widget.onLocationUpdated(
                          _detectedCity,
                          _detectedProvince,
                          null,
                          val,
                        );
                        await _loadFilterOptions();
                        _performSearch();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLocating ? null : _detectLocation,
                icon: _isLocating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(greenColor),
                        ),
                      )
                    : Icon(Icons.my_location, color: greenColor, size: 20),
                tooltip: 'Detect Location',
                style: IconButton.styleFrom(
                  backgroundColor: cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: borderCol),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      hint: Text('Category', style: TextStyle(color: subText, fontSize: 13)),
                      dropdownColor: cardBg,
                      style: TextStyle(color: textThemeColor, fontSize: 13),
                      icon: Icon(Icons.arrow_drop_down, color: subText),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Categories', style: TextStyle(color: textThemeColor)),
                        ),
                        ..._categories.map((c) => DropdownMenuItem<String>(
                          value: c,
                          child: Text(c, overflow: TextOverflow.ellipsis, style: TextStyle(color: textThemeColor)),
                        )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val;
                        });
                        _performSearch();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMarket,
                      isExpanded: true,
                      hint: Text('City', style: TextStyle(color: subText, fontSize: 13)),
                      dropdownColor: cardBg,
                      style: TextStyle(color: textThemeColor, fontSize: 13),
                      icon: Icon(Icons.arrow_drop_down, color: subText),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Cities', style: TextStyle(color: textThemeColor)),
                        ),
                        ..._markets.map((m) => DropdownMenuItem<String>(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis, style: TextStyle(color: textThemeColor)),
                        )),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedMarket = val;
                        });
                        widget.onLocationUpdated(
                          _detectedCity,
                          _detectedProvince,
                          val,
                          _selectedProvince,
                        );
                        _performSearch();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: 4,
      itemBuilder: (context, index) {
        return const PriceSearchSkeletonItem();
      },
    );
  }

  Widget _buildPriceRow(Map<String, dynamic> item) {
    final commodity = item['commodity'] ?? 'Unknown';
    final market = item['market'] ?? 'Unknown';
    final price = item['price'] != null ? '₱${item['price'].toStringAsFixed(2)}' : 'N/A';
    final unit = item['unit'] ?? 'KG';
    final date = item['date'] ?? 'N/A';
    final region = item['admin1'] ?? 'N/A';
    final province = item['admin2'] ?? 'N/A';

    final cardBg = ThemeService.instance.cardBg;
    final textThemeColor = ThemeService.instance.cardText;
    final subText = ThemeService.instance.subText;
    final greenColor = ThemeService.instance.greenText;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey[200]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  commodity,
                  style: TextStyle(color: textThemeColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                price,
                style: TextStyle(color: greenColor, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Per $unit • $market',
                style: TextStyle(color: subText, fontSize: 13),
              ),
              Text(
                date,
                style: TextStyle(color: subText.withOpacity(0.7), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, color: subText.withOpacity(0.7), size: 12),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$province, $region',
                  style: TextStyle(color: subText.withOpacity(0.7), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $commodity to active run!'),
                    backgroundColor: greenColor,
                  ),
                );
              },
              icon: Icon(Icons.add_shopping_cart, color: greenColor, size: 16),
              label: Text(
                'Add to List',
                style: TextStyle(
                  color: greenColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: greenColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PriceSearchSkeletonItem extends StatelessWidget {
  const PriceSearchSkeletonItem({super.key});

  @override
  Widget build(BuildContext context) {
    final cardBg = ThemeService.instance.cardBg;
    final isDark = ThemeService.instance.isDarkMode.value;
    final dividerColor = isDark ? Colors.grey.shade800 : const Color(0xFFEEEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonWidget(width: 140, height: 16),
              SkeletonWidget(width: 60, height: 18),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonWidget(width: 100, height: 12),
              SkeletonWidget(width: 80, height: 10),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonWidget(width: 120, height: 12),
          const SizedBox(height: 16),
          Divider(height: 1, color: dividerColor),
          const SizedBox(height: 12),
          const SkeletonWidget(width: double.infinity, height: 32, borderRadius: 12),
        ],
      ),
    );
  }
}
