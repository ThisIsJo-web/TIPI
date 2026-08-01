import 'dart:async';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'intro_page.dart';
import '../services/auth_service.dart';
import '../services/supabase_profile_service.dart';
import '../widgets/glass_card.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> with TickerProviderStateMixin {
  late AnimationController _receiptController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Timer for rotating funny status text
  Timer? _statusTimer;
  int _currentStatusIndex = 0;
  
  // Controls when each receipt item prints
  int _printedItemsCount = 0;
  Timer? _itemPrinterTimer;
  
  // Total saved counter animation
  double _totalSaved = 0.0;
  Timer? _savingsTimer;
  bool _hasProfile = false;
  final AuthService _authService = AuthService();

  final List<String> _statusTexts = [
    "Naghahanap ng pinakamagandang tali ng kangkong...",
    "Hinihintay si Mama matapos makipag-tsismisan sa aisle ng de-lata...",
    "Kinukuha ang plastic bag mula sa loob ng isa pang plastic bag...",
    "Pumipila sa cashier na may dalang karton ng grocery...",
    "Sinusuyo si Ate Cashier para sa barya...",
    "Hinihingal dahil naiwan ang ecobag sa kotse...",
  ];

  final List<Map<String, String>> _receiptItems = [
    {"name": "1x Pinakamagandang Tali ng Kangkong", "price": "₱15.00"},
    {"name": "1x Toyo na gusto ni Mama", "price": "₱28.50"},
    {"name": "1x Reserbang Plastic Bag sa ilalim ng lababo", "price": "₱0.00"},
    {"name": "1x Chocnut (Emotional Support)", "price": "₱2.00"},
    {"name": "1x Pasensya sa Cashier Counter Queue", "price": "LIBRE"},
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();

    // Receipt slide-up and fade-in animation
    _receiptController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _receiptController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _receiptController,
      curve: Curves.easeIn,
    );

    // Start receipt entrance
    _receiptController.forward();

    // Dynamically print items one by one
    _itemPrinterTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (mounted) {
        setState(() {
          if (_printedItemsCount < _receiptItems.length) {
            _printedItemsCount++;
          } else {
            _itemPrinterTimer?.cancel();
          }
        });
      }
    });

    // Animate the "Total Saved" ticker
    _savingsTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (mounted) {
        setState(() {
          if (_totalSaved < 145.50) {
            _totalSaved += 3.75;
          } else {
            _totalSaved = 145.50;
            _savingsTimer?.cancel();
          }
        });
      }
    });

    // Rotate status text every 1.5 seconds
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1600), (timer) {
      if (mounted) {
        setState(() {
          _currentStatusIndex = (_currentStatusIndex + 1) % _statusTexts.length;
        });
      }
    });

    // Navigate to Home if logged in, otherwise to Login after 8.5 seconds (gives time to enjoy the witty text and read the receipt)
    Timer(const Duration(milliseconds: 8500), () {
      if (mounted) {
        Widget nextWidget;
        if (_authService.currentUser != null) {
          nextWidget = _hasProfile ? const HomePage() : const IntroPage();
        } else {
          nextWidget = const LoginPage();
        }
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextWidget,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await SupabaseProfileService.instance.getProfile(user.id);
        if (mounted) {
          setState(() {
            _hasProfile = profile != null;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking onboarding status: $e");
    }
  }

  @override
  void dispose() {
    _receiptController.dispose();
    _statusTimer?.cancel();
    _itemPrinterTimer?.cancel();
    _savingsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image with dark green overlay
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF07190B), // Extremely deep dark green
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
            ),
          ),

          // Central receipt UI
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: AnimatedBuilder(
                animation: _receiptController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: child,
                    ),
                  );
                },
                child: GlassCard(
                  opacity: 0.08,
                  blur: 20.0,
                  borderRadius: BorderRadius.circular(16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Receipt Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TIPI SUPERMARKET',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              'OFFICIAL RESIBO',
                              style: TextStyle(
                                color: Colors.lightGreenAccent.withValues(alpha: 0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'DATE: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}  ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'Courier',
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Dashed divider
                        const _DashedLine(),
                        const SizedBox(height: 12),

                        // Animated items list
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _printedItemsCount,
                            itemBuilder: (context, index) {
                              final item = _receiptItems[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'Courier',
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item['price']!,
                                      style: TextStyle(
                                        color: item['price'] == 'LIBRE' 
                                            ? Colors.lightGreenAccent 
                                            : Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                        // Render placeholders for printing progress to avoid layout shifts
                        if (_printedItemsCount < _receiptItems.length)
                          SizedBox(
                            height: (180 - (_printedItemsCount * 24)).toDouble().clamp(0, 180),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                '• ' * (_receiptItems.length - _printedItemsCount),
                                style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontFamily: 'Courier',
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),
                        const _DashedLine(),
                        const SizedBox(height: 12),

                        // Receipt Footer/Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL TIPID SAVINGS:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₱${_totalSaved.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.lightGreenAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Witty Status Ticker
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.lightGreenAccent),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _statusTexts[_currentStatusIndex],
                    key: ValueKey<int>(_currentStatusIndex),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.87),
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white30),
              ),
            );
          }),
        );
      },
    );
  }
}

