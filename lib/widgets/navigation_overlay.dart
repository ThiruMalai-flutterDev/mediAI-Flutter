import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../theme/app_colors.dart';

class NavigationOverlay extends StatelessWidget {
  final bool isVisible;
  final Animation<double> animation;
  final VoidCallback onClose;
  final Function(String) onMenuTap;
  final String? userName;
  final String? userRole;

  const NavigationOverlay({
    Key? key,
    required this.isVisible,
    required this.animation,
    required this.onClose,
    required this.onMenuTap,
    this.userName,
    this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Transform.translate(
            offset: Offset(-60.w * (1 - animation.value), 0),
            child: Container(
              width: 55.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryGradient[0].withOpacity(0.95),
                    AppColors.primaryGradient[1].withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20.w),
                  bottomRight: Radius.circular(20.w),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(5, 0),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: AppColors.primaryGradient[0].withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
                  child: Column(
                    children: [
                      // Hospital Logo Section with Close Icon
                      _buildHeaderSection(),
                      
                      SizedBox(height: 2.h),
                      
                      // Menu Items with scrolling
                      Expanded(
                        child: _buildMenuItems(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1.h, horizontal: 2.w),
      child: Row(
        children: [
          // Logo and App Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo
                Image.asset(
                  'assets/images/applogo.jpg',
                  width: 25.w,
                  height: 12.w,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          
          // Close Icon
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: EdgeInsets.all(1.5.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6.w),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                 Icons.keyboard_double_arrow_left,
                color: AppColors.white,
                size: 4.w,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMenuItems() {
    final menuItems = [
      {'icon': Icons.chat_bubble_outline, 'title': 'Chat Bot'},
      {'icon': Icons.medical_services, 'title': 'List Book'},
      {'icon': Icons.auto_awesome, 'title': 'AI Question Builder'},
      {'icon': Icons.quiz, 'title': 'Online Exam'},
      {'icon': Icons.school, 'title': 'Lesson Plan'},
      {'icon': Icons.history, 'title': 'History'},
      {'icon': Icons.person, 'title': 'Profile'},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: menuItems.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> item = entry.value;
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutCubic,
            child: _buildMenuItem(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              onTap: () => onMenuTap(item['title'] as String),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.5.h, horizontal: 1.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.w),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10.w),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: EdgeInsets.all(1.5.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6.w),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.white,
                    size: 4.w,
                  ),
                ),
                
                SizedBox(width: 2.5.w),
                
                // Text Content
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 3.5.w,
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.white.withOpacity(0.6),
                  size: 3.w,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
