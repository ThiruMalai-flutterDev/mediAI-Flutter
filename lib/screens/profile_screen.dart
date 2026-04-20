import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/storage_service.dart';
import '../viewmodels/login_view_model.dart';
import '../router/custom_routes.dart';
import '../responsive/responsive_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _username;
  String? _email;
  String? _mobileNumber;
  String? _userId;
  bool? _isPasswordSet;
  int? _role;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final storage = await StorageService.getInstance();
      setState(() {
        _username = storage.getUserName();
        _email = storage.getUserEmail();
        _mobileNumber = storage.getString('mobileNumber');
        _userId = storage.getUserId();
        _isPasswordSet = storage.getBool('isPasswordSet');
        _role = storage.getInt('role');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false, // Don't add bottom padding since we're in a tab view
        child: _isLoading
            ? _buildLoadingWidget()
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 2.h),
                      _buildProfileInfo(),
                      SizedBox(height: 2.h),
                      _buildAppInfo(),
                      SizedBox(height: 2.h), // Add bottom padding for tab bar
                    ],
                  ),
                ),
              ),
      ),
    );
  }


  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryPurple,
          ),
          SizedBox(height: ResponsiveUtils.getHeight(context, 4)),
          Text(
            'Loading profile...',
            style: TextStyle(
              fontSize: 3.5.w,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.primaryGradient,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(4.w),
          bottomRight: Radius.circular(4.w),
        ),
      ),
      child: Column(
        children: [
          // Profile Avatar
          CircleAvatar(
            radius: 15.w,
            backgroundColor: AppColors.white,
            child: Icon(
              Icons.person,
              size: 15.w,
              color: AppColors.primaryPurple,
            ),
          ),
          SizedBox(height: 3.h),
          
          // User Name
          Text(
            _username ?? 'User',
            style: TextStyle(
              fontSize: 5.w,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
          SizedBox(height: 1.h),
          
          // Email
          if (_email != null) ...[
            Text(
              _email!,
              style: TextStyle(
                fontSize: 3.5.w,
                color: AppColors.white.withOpacity(0.9),
              ),
            ),
            SizedBox(height: 0.5.h),
          ],
          
          // Mobile Number
          if (_mobileNumber != null) ...[
            Text(
              _mobileNumber!,
              style: TextStyle(
                fontSize: 3.5.w,
                color: AppColors.white.withOpacity(0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Information',
            style: TextStyle(
              fontSize: 4.5.w,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
            ),
          ),
          SizedBox(height: 3.h),
          
          _buildInfoRow(Icons.person, 'Username', _username ?? 'Not available'),
          _buildInfoRow(Icons.email, 'Email', _email ?? 'Not available'),
          _buildInfoRow(Icons.phone, 'Mobile', _mobileNumber ?? 'Not available'),
          if (_userId != null) _buildInfoRow(Icons.fingerprint, 'User ID', _userId!),
          _buildInfoRow(Icons.verified_user, 'Status', 'Active'),
          if (_isPasswordSet != null) _buildInfoRow(Icons.lock, 'Password Set', _isPasswordSet! ? 'Yes' : 'No'),
          if (_role != null) _buildInfoRow(Icons.admin_panel_settings, 'Role', _getRoleName(_role!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primaryPurple,
            size: 5.w,
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 3.w,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 3.5.w,
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2.w),
        ),
        child: Icon(
          icon,
          color: AppColors.primaryPurple,
          size: 5.w,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 3.5.w,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryPurple,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 2.8.w,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey[400],
        size: 4.w,
      ),
      onTap: onTap,
    );
  }


  String _getRoleName(int role) {
    switch (role) {
      case 1:
        return 'Admin';
      case 2:
        return 'Doctor';
      case 3:
        return 'Nurse';
      case 4:
        return 'Patient';
      default:
        return 'User';
    }
  }

  Widget _buildAppInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(4.w),
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
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: _logout,
          ),
        ],
      ),
    );
  }



  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, 4.5),
            fontWeight: FontWeight.bold,
            color: AppColors.primaryPurple,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontSize: 3.5.w,
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 3.5.w,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.w),
              ),
            ),
            child: Text(
              'Logout',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 3.5.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Logging out...',
                  style: TextStyle(
                    fontSize: 3.5.w,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Perform logout
      final loginViewModel = context.read<LoginViewModel>();
      await loginViewModel.logout();
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Navigate to login screen
        await CustomRoutes.toLoginScreen(context);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
