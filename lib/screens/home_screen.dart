import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../theme/app_colors.dart';
// import '../widgets/custom_app_bar.dart';
import '../widgets/navigation_overlay.dart';
import '../widgets/adaptive_app_bar.dart';
import 'chat_screen.dart';
import 'book_list_screen.dart';
import 'profile_screen.dart';
import 'chat_history_screen.dart';
import 'lesson_plan_screen.dart';
import 'ai_question_builder_screen.dart';
import 'online_exam_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _drawerAnimationController;
  late Animation<double> _drawerAnimation;
  bool _isNavigationVisible = false;
  int _currentIndex = 0;

  List<Widget> get _screens => [
    const ChatScreen(),
    BookListScreen(
      onBooksSelected: () {
        setState(() {
          _currentIndex = 0; // Switch to Chat screen
        });
      },
    ),
    const AIQuestionBuilderScreen(),
    const OnlineExamScreen(),
    const LessonPlanScreen(),
    ChatHistoryScreen(
      onSessionSelected: () {
        setState(() {
          _currentIndex = 0; // Switch to Chat screen
        });
      },
    ),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _drawerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _drawerAnimation = CurvedAnimation(
      parent: _drawerAnimationController,
      curve: Curves.elasticOut,
    );
  }

  

  @override
  void dispose() {
    _drawerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AdaptiveAppBar(
        title: _titleForIndex(_currentIndex),
        onMenuPressed: _toggleNavigation,
      ),
      body: Stack(
        children: [
          // Main Content Area
          SafeArea(
            child: _screens[_currentIndex],
          ),

          // App bar includes the menu button now
          
          // Navigation Overlay
          NavigationOverlay(
            isVisible: _isNavigationVisible,
            animation: _drawerAnimation,
            onClose: _closeNavigation,
            onMenuTap: _handleMenuTap,
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Chat';
      case 1:
        return 'Books';
      case 2:
        return 'AI Question Builder';
      case 3:
        return 'Online Exam';
      case 4:
        return 'Lesson Plan';
      case 5:
        return 'History';
      case 6:
        return 'Profile';
      default:
        return 'Mediai';
    }
  }

  

  void _toggleNavigation() {
    setState(() {
      _isNavigationVisible = !_isNavigationVisible;
    });
    if (_isNavigationVisible) {
      _drawerAnimationController.forward();
    } else {
      _drawerAnimationController.reverse();
    }
  }

  void _closeNavigation() {
    setState(() {
      _isNavigationVisible = false;
    });
    _drawerAnimationController.reverse();
  }

  void _handleMenuTap(String menuItem) {
    setState(() {
      _isNavigationVisible = false;
    });
    _drawerAnimationController.reverse();
    
    // Handle different menu items
    switch (menuItem) {
      case 'Chat Bot':
        setState(() {
          _currentIndex = 0; // Switch to Chat screen
        });
        break;
      case 'List Book':
        setState(() {
          _currentIndex = 1; // Switch to Book List screen
        });
        break;
      case 'AI Question Builder':
        setState(() {
          _currentIndex = 2; // Switch to AI Question Builder
        });
        break;
      case 'Online Exam':
        setState(() {
          _currentIndex = 3; // Switch to Online Exam screen
        });
        break;
      case 'Lesson Plan':
        setState(() {
          _currentIndex = 4; // Switch to Lesson Plan screen
        });
        break;
      case 'History':
        setState(() {
          _currentIndex = 5; // Switch to History screen
        });
        break;
      case 'Profile':
        setState(() {
          _currentIndex = 6; // Switch to Profile screen
        });
        break;
    }
  }
}

// Placeholder screens for different tabs
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 5.w,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
          SizedBox(height: 4.h),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 4.w,
              mainAxisSpacing: 4.w,
              children: [
                _buildDashboardCard(
                  icon: Icons.people,
                  title: 'Patients',
                  count: '1,234',
                  color: Colors.blue,
                ),
                _buildDashboardCard(
                  icon: Icons.local_hospital,
                  title: 'Beds',
                  count: '45',
                  color: Colors.green,
                ),
                _buildDashboardCard(
                  icon: Icons.medical_services,
                  title: 'Doctors',
                  count: '89',
                  color: Colors.orange,
                ),
                _buildDashboardCard(
                  icon: Icons.emergency,
                  title: 'Emergency',
                  count: '12',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String count,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 12.w,
              color: color,
            ),
            SizedBox(height: 2.h),
            Text(
              count,
              style: TextStyle(
                fontSize: 7.w,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 2.8.w,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


