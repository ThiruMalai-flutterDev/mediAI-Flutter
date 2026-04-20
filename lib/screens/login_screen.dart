import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../responsive/responsive_widget.dart';
import '../responsive/responsive_utils.dart';
import '../viewmodels/login_view_model.dart';
import '../widgets/custom_gradient_background.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRememberMeState();
  }

  void _loadRememberMeState() async {
    try {
      final storage = await StorageService.getInstance();
      final rememberMe = storage.getBool('remember_me');
      final savedUsername = storage.getUserName() ?? '';

      // Validate saved email format
      final emailRegex =
          RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      bool isValidEmail =
          savedUsername.isNotEmpty && emailRegex.hasMatch(savedUsername);

      if (mounted) {
        setState(() {
          _rememberMe = rememberMe;
          if (rememberMe && isValidEmail) {
            _usernameController.text = savedUsername;
          } else if (rememberMe && !isValidEmail && savedUsername.isNotEmpty) {
            // Clear invalid email from storage
            print('Clearing invalid email from storage: $savedUsername');
            storage.clearUserData();
            _rememberMe = false;
          }
        });
      }
    } catch (e) {
      // Handle error silently, use default values
      print('Error loading remember me state: $e');
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomGradientBackground(
        child: SafeArea(
          child: Consumer<LoginViewModel>(
            builder: (context, viewModel, child) {
              return _buildMobileLayout(context, viewModel);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, LoginViewModel viewModel) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.isMobile(context) ? 6.w : 4.w,
              vertical: 2.h,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Enhanced Login Title with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: ResponsiveText(
                        'Welcome Back',
                        fontSize: ResponsiveUtils.isMobile(context) ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(
                        height:
                            ResponsiveUtils.isMobile(context) ? 1.h : 1.5.h),

                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.isMobile(context) ? 16 : 18,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),

                    SizedBox(
                        height: ResponsiveUtils.isMobile(context) ? 4.h : 6.h),

                    // Enhanced form container
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveUtils.isMobile(context)
                            ? double.infinity
                            : 400,
                      ),
                      padding: EdgeInsets.all(
                          ResponsiveUtils.isMobile(context) ? 5.w : 4.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                            ResponsiveUtils.isMobile(context) ? 16 : 20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Username Field
                          _buildEnhancedUsernameField(),
                          SizedBox(
                              height: ResponsiveUtils.isMobile(context)
                                  ? 2.h
                                  : 3.h),

                          // Password Field
                          _buildEnhancedPasswordField(),
                          SizedBox(
                              height: ResponsiveUtils.isMobile(context)
                                  ? 1.5.h
                                  : 2.h),

                          // Remember Me Checkbox
                          _buildRememberMeCheckbox(),
                          SizedBox(
                              height: ResponsiveUtils.isMobile(context)
                                  ? 2.h
                                  : 3.h),

                          // Confirm Button
                          _buildEnhancedConfirmButton(viewModel),
                          SizedBox(
                              height: ResponsiveUtils.isMobile(context)
                                  ? 1.5.h
                                  : 2.h),

                          // Forget Password Link
                          _buildForgetPasswordLink(),
                        ],
                      ),
                    ),

                    SizedBox(
                        height: ResponsiveUtils.isMobile(context) ? 3.h : 4.h),

                    // Social Login Options
                    // _buildSocialLoginOptions(viewModel),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgetPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: () {
          // Handle forget password
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Forget Password functionality',
                style: TextStyle(color: Colors.black),
              ),
              backgroundColor: Colors.white,
            ),
          );
        },
        child: Text(
          'Forget Password?',
          style: TextStyle(
            fontSize: ResponsiveUtils.isMobile(context) ? 14 : 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Widget _buildSocialLoginOptions(LoginViewModel viewModel) {
  //   return Column(
  //     children: [
  //       // Google Login
  //       _buildSocialLoginButton(
  //         icon: _buildGoogleIcon(),
  //         text: 'Continue with Google',
  //         onTap: () => _handleGoogleLogin(viewModel),
  //       ),
  //       SizedBox(height: 2.h),

  //       // Facebook Login
  //       _buildSocialLoginButton(
  //         icon: _buildFacebookIcon(),
  //         text: 'Continue with Facebook',
  //         onTap: () => _handleFacebookLogin(viewModel),
  //       ),
  //     ],
  //   );
  // }

  void _handleLogin(LoginViewModel viewModel) {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate email format
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    viewModel.login(username, password, rememberMe: _rememberMe).then((_) {
      if (!viewModel.hasError && !viewModel.isLoading) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (viewModel.hasError) {
        // Show server response message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              viewModel.errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _handleLogin(viewModel);
              },
            ),
          ),
        );
      }
    });
  }

  Widget _buildEnhancedUsernameField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(ResponsiveUtils.isMobile(context) ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _usernameController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          color: Colors.white,
          fontSize: ResponsiveUtils.isMobile(context) ? 16 : 14.sp,
        ),
        decoration: InputDecoration(
          hintText: 'Username or Email',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: ResponsiveUtils.isMobile(context) ? 14 : 12.sp,
          ),
          prefixIcon: Icon(
            Icons.person_outline,
            color: Colors.white.withOpacity(0.8),
            size: ResponsiveUtils.isMobile(context) ? 20 : 18.sp,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: ResponsiveUtils.isMobile(context) ? 16 : 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(ResponsiveUtils.isMobile(context) ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleLogin(context.read<LoginViewModel>()),
        style: TextStyle(
          color: Colors.white,
          fontSize: ResponsiveUtils.isMobile(context) ? 16 : 14.sp,
        ),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: ResponsiveUtils.isMobile(context) ? 14 : 12.sp,
          ),
          prefixIcon: Icon(
            Icons.lock_outline,
            color: Colors.white.withOpacity(0.8),
            size: ResponsiveUtils.isMobile(context) ? 20 : 18.sp,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withOpacity(0.8),
              size: ResponsiveUtils.isMobile(context) ? 20 : 18.sp,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: ResponsiveUtils.isMobile(context) ? 16 : 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
            borderSide: BorderSide(
              color: Colors.white,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedConfirmButton(LoginViewModel viewModel) {
    return Container(
      width: double.infinity,
      height: ResponsiveUtils.isMobile(context) ? 50 : 6.h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(ResponsiveUtils.isMobile(context) ? 10 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: viewModel.isLoading ? null : () => _handleLogin(viewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                ResponsiveUtils.isMobile(context) ? 10 : 12),
          ),
        ),
        child: viewModel.isLoading
            ? SizedBox(
                width: ResponsiveUtils.isMobile(context) ? 24 : 20.sp,
                height: ResponsiveUtils.isMobile(context) ? 24 : 20.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              )
            : Text(
                'Sign In',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: ResponsiveUtils.isMobile(context) ? 16 : 13.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Container(
            width: ResponsiveUtils.isMobile(context) ? 20 : 18.sp,
            height: ResponsiveUtils.isMobile(context) ? 20 : 18.sp,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
              color: _rememberMe ? Colors.white : Colors.transparent,
            ),
            child: _rememberMe
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).primaryColor,
                    size: ResponsiveUtils.isMobile(context) ? 14 : 12.sp,
                  )
                : null,
          ),
        ),
        SizedBox(width: ResponsiveUtils.isMobile(context) ? 12 : 2.w),
        GestureDetector(
          onTap: () {
            setState(() {
              _rememberMe = !_rememberMe;
            });
          },
          child: Text(
            'Remember Me',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: ResponsiveUtils.isMobile(context) ? 14 : 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
