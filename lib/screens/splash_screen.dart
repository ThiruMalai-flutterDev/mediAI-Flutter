import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../utils/asset_utils.dart';
import '../viewmodels/login_view_model.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _logoAnimation;
  
  bool _showLogo = false;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 6000), // 6 seconds for 4 rotations with pauses
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _rotateController.forward(); // Single forward animation instead of repeat

    // Show logo after 6 seconds of rotation
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() {
          _showLogo = true;
        });
        _logoController.forward();
      }
    });

    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 8)); // 8 seconds total (6s rotation + 2s logo)
    if (mounted) {
      // Check for auto-login
      final loginViewModel = Provider.of<LoginViewModel>(context, listen: false);
      final autoLoginSuccess = await loginViewModel.checkAutoLogin();
      
      if (autoLoginSuccess && !loginViewModel.hasError) {
        // Auto-login successful, go to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // No auto-login or failed, go to login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotateController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.primaryGradient,
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            _buildAnimatedBackground(),
            
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _fadeAnimation,
                  _rotateAnimation,
                  _logoAnimation,
                ]),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Main content area
                          Container(
                            width: 80.w,
                            height: 50.h,
                            child: Stack(
                              children: [
                                // Rotating medical icons loader
                                if (!_showLogo) _buildRotatingLoader(),
                                
                                // App logo (appears after loading)
                                if (_showLogo) _buildAppLogo(),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 3.h),
                          
                          // App title
                          Text(
                            'MEDIAI',
                            style: TextStyle(
                              fontSize: 7.w,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          
                          SizedBox(height: 1.h),
                          
                          Text(
                            'Your Medical Assistant',
                            style: TextStyle(
                              fontSize: 3.5.w,
                              color: AppColors.white.withOpacity(0.9),
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRotatingLoader() {
    return Center(
      child: AnimatedBuilder(
        animation: _rotateAnimation,
        builder: (context, child) {
          // 4 rotations of 90 degrees each with pauses
          final stepValue = _rotateAnimation.value;
          final rotationAngle = (stepValue * math.pi / 2); // 90 degrees per step
          
          return Transform.rotate(
            angle: rotationAngle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stethoscope SVG
                Container(
                  width: 20.w,
                  height: 20.w,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.w),
                    child: SvgPicture.asset(
                      'assets/icons/stethoscope.svg',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                SizedBox(width: 4.w),
                
                // Injection SVG
                Container(
                  width: 20.w,
                  height: 20.w,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.w),
                    child: SvgPicture.asset(
                      'assets/icons/injection.svg',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppLogo() {
    return Center(
      child: ScaleTransition(
        scale: _logoAnimation,
        child: Container(
          width: 35.w,
          height: 35.w,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.w),
            child: Image.asset(
              AssetUtils.appLogo,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.w),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    size: 18.w,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _rotateAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: ParticlePainter(_rotateAnimation.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double animationValue;

  ParticlePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Draw floating particles
    for (int i = 0; i < 20; i++) {
      final x = (size.width * (i * 0.1 + animationValue * 0.1)) % size.width;
      final y = (size.height * (i * 0.15 + animationValue * 0.05)) % size.height;
      final radius = 2 + (i % 3).toDouble();
      
      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint..color = AppColors.white.withOpacity(0.1 - (i % 3) * 0.02),
      );
    }

    // Draw floating medical icons
    for (int i = 0; i < 5; i++) {
      final x = (size.width * (i * 0.2 + animationValue * 0.03)) % size.width;
      final y = (size.height * (i * 0.3 + animationValue * 0.02)) % size.height;
      
      final iconPaint = Paint()
        ..color = AppColors.white.withOpacity(0.05)
        ..style = PaintingStyle.fill;

      // Draw simple cross shapes
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 8, height: 2),
        iconPaint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 2, height: 8),
        iconPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

